// Central tuning knobs for daily missions (Phase 6 — Retention Systems). Change
// values here to retune missions without touching the evaluation logic itself.
// Follows the exact same "config declares WHAT, service applies HOW" split as
// progression.config.js's ACHIEVEMENTS.

// A correct answer this fast counts toward the "fast answers" mission — matches
// nothing else in the codebase (Speed Demon's threshold is a speed *multiplier*,
// this is a hard elapsed-time cutoff), so it gets its own constant.
const FAST_ANSWER_MS_THRESHOLD = 3000;

// Each mission's `progressFor(rush)` is handed a snapshot of ONE just-completed
// Rush (see missions.service.js's buildRushStatsForMissions) and returns how much
// that Rush contributed toward the mission's target this period — 0 if it didn't
// contribute at all. Progress accumulates across every Rush played within the
// same period (see resetPeriod) until it reaches `target`, then the mission is
// done for that period and stops accepting further progress until the period
// rolls over. This mirrors ACHIEVEMENTS' `check` pattern but accumulates instead
// of re-testing a lifetime snapshot, since missions reset periodically and
// achievements don't.
const MISSIONS = [
  {
    key: 'complete_1_rush',
    name: 'Warm Up',
    description: 'Complete 1 Rush.',
    resetPeriod: 'daily',
    target: 1,
    rewardXp: 30,
    progressFor: () => 1,
  },
  {
    key: 'answer_20_questions',
    name: 'Trivia Marathon',
    description: 'Answer 20 questions.',
    resetPeriod: 'daily',
    target: 20,
    rewardXp: 40,
    progressFor: (rush) => rush.questionsAnswered,
  },
  {
    key: 'streak_5',
    name: 'On Fire',
    description: 'Get a 5 answer streak in a single Rush.',
    resetPeriod: 'daily',
    target: 1,
    rewardXp: 40,
    progressFor: (rush) => (rush.bestStreak >= 5 ? 1 : 0),
  },
  {
    key: 'fast_5',
    name: 'Lightning Reflexes',
    description: 'Answer 5 questions correctly in under 3 seconds.',
    resetPeriod: 'daily',
    target: 5,
    rewardXp: 50,
    progressFor: (rush) => rush.fastCorrectAnswers,
  },
  {
    key: 'complete_daily_rush',
    name: "Today's Challenge",
    description: 'Complete the Daily Rush.',
    resetPeriod: 'daily',
    target: 1,
    rewardXp: 60,
    progressFor: (rush) => (rush.isDailyRush ? 1 : 0),
  },
];

module.exports = { FAST_ANSWER_MS_THRESHOLD, MISSIONS };
