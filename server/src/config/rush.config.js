// Central tuning knobs for Rush gameplay. Change values here to retune the
// game without touching selection/scoring/gameplay logic.

const DIFFICULTY_LEVELS = ['easy', 'medium', 'hard', 'extreme'];

const RUSH_LENGTH = 10;

// Difficulty of each 0-indexed question position in a Rush.
// Questions 1-2 easy, 3-5 medium, 6-8 hard, 9-10 extreme.
const DIFFICULTY_PROGRESSION = [
  'easy', 'easy',
  'medium', 'medium', 'medium',
  'hard', 'hard', 'hard',
  'extreme', 'extreme',
];

// Streak Rush (Pick Your Rush): open-ended — the Rush ends the moment the
// player misses one, not after a fixed question count — so this is just an
// upper bound on how long a perfect run can go before the question bank
// itself runs out. buildStreakProgression() below ramps difficulty up
// through these tier sizes, then holds at 'extreme' for the remainder.
const STREAK_RUSH_MAX_LENGTH = 40;
const STREAK_DIFFICULTY_TIER_SIZES = { easy: 3, medium: 4, hard: 5 };

const BASE_SCORES = { easy: 100, medium: 150, hard: 225, extreme: 350 };

// Multiplier applied to a correct answer's score, keyed by the player's streak
// count once this answer is counted. Highest matching threshold wins.
const STREAK_MULTIPLIER_TIERS = [
  { minStreak: 8, multiplier: 1.6 },
  { minStreak: 7, multiplier: 1.5 },
  { minStreak: 6, multiplier: 1.4 },
  { minStreak: 5, multiplier: 1.3 },
  { minStreak: 4, multiplier: 1.2 },
  { minStreak: 3, multiplier: 1.1 },
  { minStreak: 1, multiplier: 1.0 },
];

// Fast correct answers earn up to this extra fraction of the base score;
// the bonus decays linearly to 0 as elapsed time approaches the question's timer.
const MAX_SPEED_BONUS_PCT = 0.5;

// Extra time (ms) the server allows past a question's timer before treating a
// late answer as a timeout, to absorb ordinary network round-trip latency.
// (Narration/UX delay before the countdown starts is handled separately by
// the /start ping resetting question_started_at — this grace is just network jitter.)
const ANSWER_GRACE_MS = 1500;

module.exports = {
  DIFFICULTY_LEVELS,
  RUSH_LENGTH,
  DIFFICULTY_PROGRESSION,
  STREAK_RUSH_MAX_LENGTH,
  STREAK_DIFFICULTY_TIER_SIZES,
  BASE_SCORES,
  STREAK_MULTIPLIER_TIERS,
  MAX_SPEED_BONUS_PCT,
  ANSWER_GRACE_MS,
};
