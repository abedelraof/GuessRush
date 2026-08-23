const { SPEED_DEMON_SPEED_MULTIPLIER } = require('../config/progression.config');
const { levelForXp, calculateXpAward, evaluateAchievements } = require('./progression.service');

/** True if this player has ever answered a question at/above the Speed Demon threshold. */
async function hasInsaneSpeedAnswer(connection, playerId) {
  const [[row]] = await connection.query(
    `SELECT EXISTS(
       SELECT 1 FROM answers a
       JOIN game_sessions gs ON gs.id = a.session_id
       WHERE gs.player_id = ? AND a.is_correct = 1 AND a.speed_multiplier >= ?
     ) AS found`,
    [playerId, SPEED_DEMON_SPEED_MULTIPLIER]
  );
  return Boolean(row.found);
}

/**
 * Applies one completed Rush's progression to the player's persistent record:
 * awards XP, recomputes level, updates lifetime stats and personal records,
 * and unlocks any newly-satisfied achievements. Must run inside the same
 * transaction as the game_sessions completion write, with the player row
 * locked (FOR UPDATE), so this only ever runs once per session — the caller
 * (sessions.controller.finish) is responsible for only invoking this on the
 * in_progress -> completed transition, never on a repeat /finish call.
 */
async function applyRushProgression(connection, {
  playerId, rushScore, correctCount, bestStreak, isPerfectRush, sumResponseTimeMs, questionsAnswered, accuracyPct,
  // Phase 6 (Retention Systems): bonusXp folds in this Rush's mission rewards
  // (see missions.service.evaluateMissionProgress) so they land in the SAME
  // players write as the Rush's own XP, rather than a second UPDATE. xpMultiplier
  // is any currently-active event's effect (see events.service.xpMultiplierAt) —
  // applied to the combined total, since "Double XP" means all XP earned, not
  // just the Rush-derived portion. Both default to the identity (0, 1) so every
  // existing caller/test is unaffected.
  bonusXp = 0, xpMultiplier = 1,
}) {
  const [[player]] = await connection.query('SELECT * FROM players WHERE id = ? FOR UPDATE', [playerId]);

  const xpAwarded = Math.round((calculateXpAward({ correctCount, bestStreak, rushScore, isPerfectRush }) + bonusXp) * xpMultiplier);
  const previousLevel = levelForXp(player.lifetime_xp).level;
  const newLifetimeXp = player.lifetime_xp + xpAwarded;
  const levelInfo = levelForXp(newLifetimeXp);
  const leveledUp = levelInfo.level > previousLevel;

  const newRushesCompleted = player.rushes_completed + 1;
  const newQuestionsAnswered = player.questions_answered + questionsAnswered;
  const newQuestionsCorrect = player.questions_correct + correctCount;
  const newTotalResponseTimeMs = player.total_response_time_ms + sumResponseTimeMs;
  const newPerfectRushCount = player.perfect_rush_count + (isPerfectRush ? 1 : 0);

  const isNewBestScore = rushScore > player.best_rush_score;
  const isNewBestStreak = bestStreak > player.best_streak;
  const newBestRushScore = Math.max(player.best_rush_score, rushScore);
  const newBestStreak = Math.max(player.best_streak, bestStreak);
  const newBestAccuracyPct = Math.max(player.best_accuracy_pct, accuracyPct);

  const avgResponseTimeMs = questionsAnswered > 0 ? Math.round(sumResponseTimeMs / questionsAnswered) : null;
  const newFastestAvgResponseTimeMs =
    avgResponseTimeMs !== null &&
    (player.fastest_avg_response_time_ms === null || avgResponseTimeMs < player.fastest_avg_response_time_ms)
      ? avgResponseTimeMs
      : player.fastest_avg_response_time_ms;

  await connection.query(
    `UPDATE players SET
      level = ?, lifetime_xp = ?, rushes_completed = ?, questions_answered = ?, questions_correct = ?,
      total_response_time_ms = ?, best_rush_score = ?, best_streak = ?, best_accuracy_pct = ?,
      fastest_avg_response_time_ms = ?, perfect_rush_count = ?
     WHERE id = ?`,
    [
      levelInfo.level, newLifetimeXp, newRushesCompleted, newQuestionsAnswered, newQuestionsCorrect,
      newTotalResponseTimeMs, newBestRushScore, newBestStreak, newBestAccuracyPct,
      newFastestAvgResponseTimeMs, newPerfectRushCount, playerId,
    ]
  );

  const insaneSpeed = await hasInsaneSpeedAnswer(connection, playerId);
  const statsSnapshot = {
    rushesCompleted: newRushesCompleted,
    perfectRushCount: newPerfectRushCount,
    bestStreak: newBestStreak,
    questionsAnswered: newQuestionsAnswered,
    hasInsaneSpeedAnswer: insaneSpeed,
  };

  const newlyUnlocked = [];
  for (const key of evaluateAchievements(statsSnapshot)) {
    // INSERT IGNORE + the UNIQUE(player_id, achievement_key) constraint is what makes this
    // idempotent — a key that's already unlocked is silently skipped (affectedRows === 0).
    const [result] = await connection.query(
      'INSERT IGNORE INTO player_achievements (player_id, achievement_key) VALUES (?, ?)',
      [playerId, key]
    );
    if (result.affectedRows > 0) newlyUnlocked.push(key);
  }

  return {
    xpAwarded,
    lifetimeXp: newLifetimeXp,
    level: levelInfo.level,
    leveledUp,
    xpIntoLevel: levelInfo.xpIntoLevel,
    xpForNextLevel: levelInfo.xpForNextLevel,
    isNewBestScore,
    isNewBestStreak,
    newlyUnlockedAchievements: newlyUnlocked,
  };
}

module.exports = { applyRushProgression, hasInsaneSpeedAnswer };
