const ApiError = require('../utils/ApiError');
const { ACHIEVEMENTS } = require('../config/progression.config');
const { levelForXp } = require('./progression.service');
const { LEVEL_UP_COINS, STREAK_MILESTONES, ACHIEVEMENT_COINS } = require('../config/rewards.config');

/** Builds the full reward catalog for a player, `unlocked` computed fresh from their current state. */
function buildCatalog(player, unlockedAchievementKeys) {
  const rewards = [];

  const level = levelForXp(player.lifetime_xp).level;
  for (let lvl = 2; lvl <= level; lvl++) {
    rewards.push({
      key: `level_${lvl}`,
      kind: 'level',
      title: `Reach Level ${lvl}`,
      description: `Level up to level ${lvl}.`,
      coins: LEVEL_UP_COINS,
      unlocked: true, // lvl <= level, by construction of this loop
    });
  }

  for (const milestone of STREAK_MILESTONES) {
    rewards.push({
      key: `streak_${milestone.days}`,
      kind: 'streak',
      title: `${milestone.days}-Day Streak`,
      description: `Reach a ${milestone.days}-day play streak.`,
      coins: milestone.coins,
      unlocked: player.daily_streak_longest >= milestone.days,
    });
  }

  for (const achievement of ACHIEVEMENTS) {
    rewards.push({
      key: `achievement_${achievement.key}`,
      kind: 'achievement',
      title: achievement.name,
      description: achievement.description,
      coins: ACHIEVEMENT_COINS,
      unlocked: unlockedAchievementKeys.has(achievement.key),
    });
  }

  return rewards;
}

/**
 * Full reward list for a player, `claimed` merged in from player_reward_claims.
 * Read-only — accepts a pool or an in-flight transaction connection, same
 * dual-use pattern as sessions.controller.js's insertSession.
 */
async function listRewardsForPlayer(connectionOrPool, playerId) {
  const [[player]] = await connectionOrPool.query(
    'SELECT lifetime_xp, daily_streak_longest FROM players WHERE id = ?',
    [playerId]
  );
  const [achievementRows] = await connectionOrPool.query(
    'SELECT achievement_key FROM player_achievements WHERE player_id = ?',
    [playerId]
  );
  const unlockedAchievementKeys = new Set(achievementRows.map((r) => r.achievement_key));

  const [claimRows] = await connectionOrPool.query(
    'SELECT reward_key FROM player_reward_claims WHERE player_id = ?',
    [playerId]
  );
  const claimedKeys = new Set(claimRows.map((r) => r.reward_key));

  return buildCatalog(player, unlockedAchievementKeys).map((r) => ({ ...r, claimed: claimedKeys.has(r.key) }));
}

/**
 * Claims one reward, crediting its coins. Must run inside the caller's own
 * transaction. Locks the player row first (before re-deriving the catalog),
 * same ordering as dailyRush.controller.js's /start — that's what serializes
 * two concurrent claims for the same player rather than racing them.
 */
async function claimReward(connection, playerId, rewardKey) {
  await connection.query('SELECT id FROM players WHERE id = ? FOR UPDATE', [playerId]);

  const rewards = await listRewardsForPlayer(connection, playerId);
  const reward = rewards.find((r) => r.key === rewardKey);
  if (!reward) throw new ApiError(404, 'Unknown reward');
  if (!reward.unlocked) throw new ApiError(409, 'This reward is not unlocked yet');
  if (reward.claimed) throw new ApiError(409, 'This reward was already claimed');

  try {
    await connection.query('INSERT INTO player_reward_claims (player_id, reward_key, coins) VALUES (?, ?, ?)', [
      playerId,
      rewardKey,
      reward.coins,
    ]);
  } catch (err) {
    // Belt-and-suspenders: the FOR UPDATE lock above already prevents this in
    // practice, but the UNIQUE constraint is the real backstop if that ever changes.
    if (err.code === 'ER_DUP_ENTRY') throw new ApiError(409, 'This reward was already claimed');
    throw err;
  }
  await connection.query('UPDATE players SET coins = coins + ? WHERE id = ?', [reward.coins, playerId]);

  const [[updated]] = await connection.query('SELECT coins FROM players WHERE id = ?', [playerId]);
  return { key: rewardKey, coinsAwarded: reward.coins, coinsTotal: updated.coins };
}

module.exports = { listRewardsForPlayer, claimReward };
