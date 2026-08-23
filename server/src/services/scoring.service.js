const { BASE_SCORES, STREAK_MULTIPLIER_TIERS, MAX_SPEED_BONUS_PCT } = require('../config/rush.config');
const { CLUE_SCORE_MULTIPLIERS, DOUBLE_DOWN_RISKY_MULTIPLIER } = require('../config/mechanics.config');

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
 * Score multiplier for a progressive question, keyed by how many clues were
 * revealed before answering (1 = only the first, free clue). Neutral (1.0)
 * for non-progressive questions, which never advance cluesRevealed past 1.
 */
function clueMultiplierFor(cluesRevealed) {
  const index = Math.min(Math.max(cluesRevealed, 1), CLUE_SCORE_MULTIPLIERS.length) - 1;
  return CLUE_SCORE_MULTIPLIERS[index];
}

/** Double Down multiplier: only "risky" changes anything, and only on a correct answer. */
function doubleDownMultiplierFor(choice, isCorrect) {
  if (choice === 'risky' && isCorrect) return DOUBLE_DOWN_RISKY_MULTIPLIER;
  return 1.0;
}

/**
 * Server-authoritative scoring for a single answer.
 * `streakAfter` is the streak count in effect once this answer is counted
 * (0 for wrong/timeout, previous streak + 1 for correct).
 * `cluesRevealed` (progressive questions only) and `doubleDownChoice`
 * ('safe' | 'risky' | null) are read from server-persisted session state by
 * the caller, never trusted from the request body directly — see
 * sessions.controller.js's submitAnswer.
 * Wrong answers and timeouts always score 0 and are never negative.
 */
function scoreAnswer({ difficulty, isCorrect, elapsedMs, timerSeconds, streakAfter, cluesRevealed = 1, doubleDownChoice = null }) {
  const baseScore = BASE_SCORES[difficulty] ?? BASE_SCORES.easy;
  const clueMultiplier = clueMultiplierFor(cluesRevealed);
  const doubleDownMultiplier = doubleDownMultiplierFor(doubleDownChoice, isCorrect);

  if (!isCorrect) {
    return { baseScore, speedMultiplier: 1, streakMultiplier: 1, clueMultiplier, doubleDownMultiplier, score: 0 };
  }
  const speedMultiplier = speedMultiplierFor(elapsedMs, timerSeconds);
  const streakMultiplier = streakMultiplierFor(streakAfter);
  const score = Math.round(baseScore * speedMultiplier * streakMultiplier * clueMultiplier * doubleDownMultiplier);
  return { baseScore, speedMultiplier, streakMultiplier, clueMultiplier, doubleDownMultiplier, score };
}

module.exports = { scoreAnswer, streakMultiplierFor, speedMultiplierFor, clueMultiplierFor, doubleDownMultiplierFor };
