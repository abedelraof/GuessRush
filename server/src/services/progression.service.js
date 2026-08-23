const {
  XP_RUSH_COMPLETION_BONUS,
  XP_PER_CORRECT_ANSWER,
  XP_PER_BEST_STREAK_POINT,
  XP_PERFECT_RUSH_BONUS,
  XP_SCORE_CONVERSION_RATE,
  BASE_XP_PER_LEVEL,
  XP_GROWTH_PER_LEVEL,
  ACHIEVEMENTS,
} = require('../config/progression.config');

/** XP required to go from `level` to `level + 1`. */
function xpRequiredForLevel(level) {
  return BASE_XP_PER_LEVEL + (level - 1) * XP_GROWTH_PER_LEVEL;
}

/** Total lifetime XP needed to REACH `level` (level 1 needs 0). */
function cumulativeXpForLevel(level) {
  let total = 0;
  for (let l = 1; l < level; l++) total += xpRequiredForLevel(l);
  return total;
}

/**
 * Resolves a lifetime XP total into a level plus progress within that level.
 * `xpIntoLevel` / `xpForNextLevel` are what the mobile client needs to render
 * an XP progress bar without re-deriving the curve itself.
 */
function levelForXp(totalXp) {
  let level = 1;
  let cumulative = 0;
  while (true) {
    const required = xpRequiredForLevel(level);
    if (cumulative + required > totalXp) break;
    cumulative += required;
    level++;
  }
  return { level, xpIntoLevel: totalXp - cumulative, xpForNextLevel: xpRequiredForLevel(level) };
}

/**
 * Server-authoritative XP award for one completed Rush. Never derived from
 * anything the client sends — only from the session's own stored, graded
 * totals (score/correctCount/bestStreak/isPerfectRush), which are themselves
 * already server-authoritative (see sessions.controller.js submitAnswer).
 */
function calculateXpAward({ correctCount, bestStreak, rushScore, isPerfectRush }) {
  const xp =
    XP_RUSH_COMPLETION_BONUS +
    correctCount * XP_PER_CORRECT_ANSWER +
    bestStreak * XP_PER_BEST_STREAK_POINT +
    Math.round(rushScore * XP_SCORE_CONVERSION_RATE) +
    (isPerfectRush ? XP_PERFECT_RUSH_BONUS : 0);
  return Math.max(0, xp);
}

/**
 * Returns the keys of every achievement satisfied by `stats` — including
 * ones already unlocked; the caller is responsible for only inserting the
 * ones that are actually new (see applyRushProgression), which is what makes
 * awarding idempotent.
 */
function evaluateAchievements(stats) {
  return ACHIEVEMENTS.filter((a) => a.check(stats)).map((a) => a.key);
}

module.exports = { xpRequiredForLevel, cumulativeXpForLevel, levelForXp, calculateXpAward, evaluateAchievements };
