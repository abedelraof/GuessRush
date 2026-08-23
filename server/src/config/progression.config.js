// Central tuning knobs for persistent player progression (lifetime XP, levels,
// achievements). Change values here to retune progression without touching
// the award/leveling logic itself.

// ---- XP award (per completed Rush) ----
// Rush Score (per-Rush, difficulty/speed/streak-weighted) is distinct from
// lifetime XP (cross-Rush progression) — XP folds in a slice of that score
// plus flat bonuses for the things Rush Score doesn't directly reward
// (showing up, a deep streak, a flawless run).
const XP_RUSH_COMPLETION_BONUS = 50;
const XP_PER_CORRECT_ANSWER = 10;
const XP_PER_BEST_STREAK_POINT = 3;
const XP_PERFECT_RUSH_BONUS = 100;
const XP_SCORE_CONVERSION_RATE = 0.1;

// ---- Level curve ----
// XP required to go from `level` to `level + 1` grows linearly:
// level 1->2 needs BASE_XP_PER_LEVEL, each level after that needs
// XP_GROWTH_PER_LEVEL more than the one before it.
const BASE_XP_PER_LEVEL = 100;
const XP_GROWTH_PER_LEVEL = 50;

// ---- Achievements ----
// Matches the mobile client's "INSANE!" speed-feedback threshold (Phase 2)
// so Speed Demon means the same thing players already associate with that label.
const SPEED_DEMON_SPEED_MULTIPLIER = 1.4;

// Each `check` runs against a plain stats snapshot (see progression.service.js)
// built from the player's own persisted, server-authoritative counters —
// never from anything the client sends directly.
const ACHIEVEMENTS = [
  { key: 'first_rush', name: 'First Rush', description: 'Complete your first Rush.', check: (s) => s.rushesCompleted >= 1 },
  { key: 'first_perfect_rush', name: 'First Perfect Rush', description: 'Complete a Rush with zero wrong answers.', check: (s) => s.perfectRushCount >= 1 },
  { key: 'streak_5', name: '5 Streak', description: 'Reach a streak of 5 correct answers in a row.', check: (s) => s.bestStreak >= 5 },
  { key: 'streak_10', name: '10 Streak', description: 'Reach a streak of 10 correct answers in a row.', check: (s) => s.bestStreak >= 10 },
  { key: 'speed_demon', name: 'Speed Demon', description: 'Answer a question at INSANE speed.', check: (s) => s.hasInsaneSpeedAnswer },
  { key: 'rushes_10', name: '10 Rushes Completed', description: 'Complete 10 Rushes.', check: (s) => s.rushesCompleted >= 10 },
  { key: 'questions_100', name: '100 Questions Answered', description: 'Answer 100 questions.', check: (s) => s.questionsAnswered >= 100 },
];

module.exports = {
  XP_RUSH_COMPLETION_BONUS,
  XP_PER_CORRECT_ANSWER,
  XP_PER_BEST_STREAK_POINT,
  XP_PERFECT_RUSH_BONUS,
  XP_SCORE_CONVERSION_RATE,
  BASE_XP_PER_LEVEL,
  XP_GROWTH_PER_LEVEL,
  SPEED_DEMON_SPEED_MULTIPLIER,
  ACHIEVEMENTS,
};
