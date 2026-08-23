const { DIFFICULTY_LEVELS, DIFFICULTY_PROGRESSION, RUSH_LENGTH } = require('../config/rush.config');

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

module.exports = { selectRushQuestions, buildRush };
