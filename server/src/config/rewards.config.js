// Central catalog for the Rewards screen — one-time, claimable coin bonuses
// layered on top of milestones the app already tracks elsewhere (level,
// daily-play streak, achievements). Distinct from economy.config.js, which
// tunes the ongoing coins-per-answer earn rate rather than one-off claims.

// ---- Level-up rewards ----
// Flat coin bonus per level reached, starting at level 2 (level 1 is where
// every player starts, nothing to "reach"). Uncapped — rewards.service.js
// only ever lists levels up to the player's current one, so this never
// needs a matching level cap.
const LEVEL_UP_COINS = 50;

// ---- Daily-streak milestones ----
// Keyed off `daily_streak_longest` (a permanent high-water mark — see
// dailyStreak.service.js), not `daily_streak_current`, so a lapsed streak
// can never unclaim a milestone already reached.
const STREAK_MILESTONES = [
  { days: 3, coins: 30 },
  { days: 7, coins: 75 },
  { days: 14, coins: 150 },
  { days: 30, coins: 400 },
  { days: 100, coins: 1500 },
];

// ---- Achievement unlock rewards ----
// Flat, same for every achievement — they're already differentiated by
// prestige/description; coins here are just a simple top-up.
const ACHIEVEMENT_COINS = 25;

module.exports = {
  LEVEL_UP_COINS,
  STREAK_MILESTONES,
  ACHIEVEMENT_COINS,
};
