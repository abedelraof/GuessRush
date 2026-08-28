const {
  DIFFICULTY_LEVELS,
  DIFFICULTY_PROGRESSION,
  RUSH_LENGTH,
  STREAK_RUSH_MAX_LENGTH,
  STREAK_DIFFICULTY_TIER_SIZES,
} = require('../config/rush.config');

/**
 * Fisher-Yates shuffle driven by an injectable `rng` (defaults to Math.random).
 * A normal Rush wants genuine randomness; Daily Rush (dailyRush.service.js)
 * passes a seeded deterministic RNG instead, so every player sees the exact
 * same shuffle result for today without this function needing to know why.
 */
function shuffle(arr, rng = Math.random) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

/** Pops one question from `desired`'s pool, or the nearest non-empty pool by difficulty distance. */
function takeNearest(pools, desired) {
  const desiredIdx = DIFFICULTY_LEVELS.indexOf(desired);
  const order = DIFFICULTY_LEVELS
    .map((level, idx) => ({ level, distance: Math.abs(idx - desiredIdx) }))
    .sort((a, b) => a.distance - b.distance);
  for (const { level } of order) {
    if (pools[level].length > 0) return pools[level].shift();
  }
  return null;
}

/**
 * Pure selection core: given all eligible question rows for a category (each
 * with a `difficulty`), builds up to RUSH_LENGTH questions in Rush order —
 * one per progression slot, matching the intended difficulty where possible
 * and falling back to the nearest available difficulty otherwise. Never
 * repeats a question within the Rush. If the category runs out of eligible
 * questions, the Rush simply ends up shorter than RUSH_LENGTH.
 */
function buildRush(rows, { progression = DIFFICULTY_PROGRESSION, length = RUSH_LENGTH, rng = Math.random } = {}) {
  const pools = {};
  for (const level of DIFFICULTY_LEVELS) pools[level] = shuffle(rows.filter((q) => q.difficulty === level), rng);

  const selected = [];
  for (let i = 0; i < length; i++) {
    const desired = progression[i % progression.length];
    const question = takeNearest(pools, desired);
    if (!question) break;
    selected.push(question);
  }
  return selected;
}

async function selectRushQuestions(categoryId) {
  // Required lazily so this module (and buildRush, its pure/testable core) can be
  // imported without needing a configured DB connection — e.g. from unit tests.
  const pool = require('../config/db');
  const [rows] = await pool.query('SELECT * FROM questions WHERE category_id = ?', [categoryId]);
  if (rows.length === 0) return [];
  return buildRush(rows);
}

/**
 * Like takeNearest, but skips a candidate whose `type` repeats one of `recentTypes` when a
 * different-typed question is available at the same (or nearest-fallback) difficulty — so a
 * player doesn't see e.g. five text questions in a row just because that's how the shuffle
 * happened to land. Never blocks selection: falls back to whatever's there otherwise.
 */
function takeNearestVaried(pools, desired, recentTypes) {
  const desiredIdx = DIFFICULTY_LEVELS.indexOf(desired);
  const order = DIFFICULTY_LEVELS
    .map((level, idx) => ({ level, distance: Math.abs(idx - desiredIdx) }))
    .sort((a, b) => a.distance - b.distance);
  for (const { level } of order) {
    const poolArr = pools[level];
    if (poolArr.length === 0) continue;
    const varyIdx = poolArr.findIndex((q) => !recentTypes.includes(q.type));
    return varyIdx !== -1 ? poolArr.splice(varyIdx, 1)[0] : poolArr.shift();
  }
  return null;
}

/**
 * Cross-category counterpart to buildRush, for Pick Your Rush's game modes (Quick/Chaos/
 * Streak/Chill) — `rows` isn't pre-filtered to one category (categories stay purely internal,
 * never player-chosen), and the picker actively varies question `type` slot to slot via
 * takeNearestVaried, instead of buildRush's plain difficulty-only shuffle.
 *
 * `randomizeDifficultyOrder` (Chaos Rush): instead of following `progression` slot-by-slot in
 * order, each slot's desired difficulty is itself randomly sampled — "no obvious pattern",
 * genuinely distinct from Quick Rush's steady easy->extreme ramp rather than just a reskin.
 */
function buildVariedRush(
  rows,
  {
    progression = DIFFICULTY_PROGRESSION,
    length = RUSH_LENGTH,
    rng = Math.random,
    randomizeDifficultyOrder = false,
    varietyWindow = 2,
  } = {}
) {
  const pools = {};
  for (const level of DIFFICULTY_LEVELS) pools[level] = shuffle(rows.filter((q) => q.difficulty === level), rng);

  const selected = [];
  const recentTypes = [];
  for (let i = 0; i < length; i++) {
    const desired = randomizeDifficultyOrder
      ? DIFFICULTY_LEVELS[Math.floor(rng() * DIFFICULTY_LEVELS.length)]
      : progression[i % progression.length];
    const question = takeNearestVaried(pools, desired, recentTypes);
    if (!question) break;
    selected.push(question);
    recentTypes.push(question.type);
    if (recentTypes.length > varietyWindow) recentTypes.shift();
  }
  return selected;
}

/**
 * Difficulty ramp for Streak Rush: climbs through STREAK_DIFFICULTY_TIER_SIZES, then holds at
 * 'extreme' for the remainder — an open-ended "how far can you go" Rush needs to keep
 * escalating well past where the fixed-length DIFFICULTY_PROGRESSION stops.
 */
function buildStreakProgression(length = STREAK_RUSH_MAX_LENGTH) {
  const seq = [];
  for (const level of DIFFICULTY_LEVELS) {
    const count = STREAK_DIFFICULTY_TIER_SIZES[level];
    if (!count) continue;
    for (let i = 0; i < count; i++) seq.push(level);
  }
  while (seq.length < length) seq.push('extreme');
  return seq.slice(0, length);
}

/**
 * Selects a Pick Your Rush question list for `mode` (quick_rush/chaos_rush/streak_rush/
 * chill_rush) — always across the entire question bank, never filtered to one category.
 */
async function selectVariedRushQuestions(mode) {
  // Required lazily — see selectRushQuestions's comment above.
  const pool = require('../config/db');
  const [rows] = await pool.query('SELECT * FROM questions');
  if (rows.length === 0) return [];

  if (mode === 'streak_rush') {
    return buildVariedRush(rows, {
      progression: buildStreakProgression(STREAK_RUSH_MAX_LENGTH),
      length: STREAK_RUSH_MAX_LENGTH,
    });
  }
  if (mode === 'chaos_rush') {
    return buildVariedRush(rows, { randomizeDifficultyOrder: true });
  }
  // quick_rush, chill_rush — same steady progression as a normal Rush, just cross-category.
  return buildVariedRush(rows);
}

module.exports = {
  selectRushQuestions,
  buildRush,
  buildVariedRush,
  buildStreakProgression,
  selectVariedRushQuestions,
};
