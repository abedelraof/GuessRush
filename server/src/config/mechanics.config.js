// Central tuning knobs for Phase 5 strategic mechanics — clue scoring,
// power-ups, and the Double Down risk/reward decision. Kept separate from
// rush.config.js (core Rush/scoring) since these are additive layers on top
// of that base scoring, not the base itself.

// ---- Progressive question clues ----
// Score multiplier keyed by how many clues were revealed before answering
// (1 clue = index 0). Answering on clue 1 keeps full score; each further
// clue trades score for information. Clamped to the last entry if a
// question somehow has more clues than this table covers.
const CLUE_SCORE_MULTIPLIERS = [1.0, 0.8, 0.6, 0.4, 0.2];

// ---- Remove One power-up ----
// How many uses a player gets per Rush. Purely an inventory constraint —
// no direct scoring penalty (see scoring.service.js) — the tension is
// "spend it now or save it for a harder question," not "is it worth the points."
const REMOVE_ONE_USES_PER_RUSH = 1;

// ---- Double Down risk/reward ----
// Offered once per Rush, the first time the player's streak reaches this
// threshold, for the very next question. The window doesn't reopen if declined.
const DOUBLE_DOWN_STREAK_THRESHOLD = 3;
// Correct + risky: score for that answer is multiplied by this. Wrong/timeout
// + risky: score is 0, same as an ordinary miss — no additional penalty, so
// "risky" can never score worse than "safe" would have, only the same or better.
const DOUBLE_DOWN_RISKY_MULTIPLIER = 2.0;

module.exports = {
  CLUE_SCORE_MULTIPLIERS,
  REMOVE_ONE_USES_PER_RUSH,
  DOUBLE_DOWN_STREAK_THRESHOLD,
  DOUBLE_DOWN_RISKY_MULTIPLIER,
};
