const pool = require('../config/db');
const ApiError = require('../utils/ApiError');
const { levelForXp } = require('../services/progression.service');
const { ACHIEVEMENTS } = require('../config/progression.config');

/** Full persistent profile: level/XP progress, lifetime stats, personal records, achievements. */
async function getProfile(req, res) {
  const [[player]] = await pool.query('SELECT * FROM players WHERE id = ?', [req.user.id]);
  if (!player) throw new ApiError(404, 'Player not found');

  const [unlockedRows] = await pool.query(
    'SELECT achievement_key, unlocked_at FROM player_achievements WHERE player_id = ?',
    [req.user.id]
  );
  const unlockedByKey = new Map(unlockedRows.map((r) => [r.achievement_key, r.unlocked_at]));

  const levelInfo = levelForXp(player.lifetime_xp);

  res.json({
    display_name: player.display_name,
    level: levelInfo.level,
    lifetime_xp: player.lifetime_xp,
    xp_into_level: levelInfo.xpIntoLevel,
    xp_for_next_level: levelInfo.xpForNextLevel,
    stats: {
      rushes_completed: player.rushes_completed,
      questions_answered: player.questions_answered,
      questions_correct: player.questions_correct,
      accuracy_pct:
        player.questions_answered > 0 ? Math.round((player.questions_correct / player.questions_answered) * 100) : 0,
      avg_response_time_ms:
        player.questions_answered > 0 ? Math.round(player.total_response_time_ms / player.questions_answered) : 0,
    },
    records: {
      best_rush_score: player.best_rush_score,
      best_streak: player.best_streak,
      best_accuracy_pct: player.best_accuracy_pct,
      fastest_avg_response_time_ms: player.fastest_avg_response_time_ms,
      perfect_rush_count: player.perfect_rush_count,
    },
    achievements: ACHIEVEMENTS.map((a) => ({
      key: a.key,
      name: a.name,
      description: a.description,
      unlocked: unlockedByKey.has(a.key),
      unlocked_at: unlockedByKey.get(a.key) || null,
    })),
  });
}

module.exports = { getProfile };
