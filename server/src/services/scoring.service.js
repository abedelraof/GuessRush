const { BASE_SCORES, STREAK_MULTIPLIER_TIERS, MAX_SPEED_BONUS_PCT } = require('../config/rush.config');

function streakMultiplierFor(streak) {
  const tier = STREAK_MULTIPLIER_TIERS.find((t) => streak >= t.minStreak);
  return tier ? tier.multiplier : 1.0;
}

/** 1.0 at the deadline, up to 1 + MAX_SPEED_BONUS_PCT for a near-instant answer. Neutral (1.0) for untimed questions. */
function speedMultiplierFor(elapsedMs, timerSeconds) {
  if (!timerSeconds || timerSeconds <= 0) return 1.0;
  const timeLimitMs = timerSeconds * 1000;
  const clampedElapsed = Math.min(Math.max(elapsedMs, 0), timeLimitMs);
  const remainingFraction = 1 - clampedElapsed / timeLimitMs;
  return 1 + MAX_SPEED_BONUS_PCT * remainingFraction;
}

/**
 * Server-authoritative scoring for a single answer.
 * `streakAfter` is the streak count in effect once this answer is counted
 * (0 for wrong/timeout, previous streak + 1 for correct).
 * Wrong answers and timeouts always score 0 and are never negative.
 */
function scoreAnswer({ difficulty, isCorrect, elapsedMs, timerSeconds, streakAfter }) {
  const baseScore = BASE_SCORES[difficulty] ?? BASE_SCORES.easy;
  if (!isCorrect) {
    return { baseScore, speedMultiplier: 1, streakMultiplier: 1, score: 0 };
  }
  const speedMultiplier = speedMultiplierFor(elapsedMs, timerSeconds);
  const streakMultiplier = streakMultiplierFor(streakAfter);
  const score = Math.round(baseScore * speedMultiplier * streakMultiplier);
  return { baseScore, speedMultiplier, streakMultiplier, score };
}

module.exports = { scoreAnswer, streakMultiplierFor, speedMultiplierFor };
