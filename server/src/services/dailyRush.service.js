const { rngFromString } = require('../utils/seededRandom');
const { buildRush } = require('./questionSelection.service');

/**
 * Server's canonical "today" — UTC, never the client's or even the host
 * machine's local date. Daily Rush, the one-attempt-per-day rule, and the
 * daily leaderboard all key off this single function, so a rollover happens
 * at the same instant for every player regardless of timezone.
 */
function todayDateString(now = new Date()) {
  return now.toISOString().slice(0, 10); // "YYYY-MM-DD"
}

/** Seconds remaining until the next UTC-midnight rollover, for the mobile "time remaining" display. */
function secondsUntilNextReset(now = new Date()) {
  const nextMidnightUtc = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1, 0, 0, 0, 0);
  return Math.max(0, Math.round((nextMidnightUtc - now.getTime()) / 1000));
}

/**
 * Deterministically picks one category for the given date out of the
 * categories that actually have eligible questions — same date -> same
 * category, always, so the "fixed configuration for everyone" requirement
 * doesn't depend on iteration/insertion order beyond a stable input array.
 */
function pickDailyCategory(categoriesWithQuestions, dateString) {
  if (categoriesWithQuestions.length === 0) return null;
  const rng = rngFromString(`${dateString}:category`);
  const index = Math.floor(rng() * categoriesWithQuestions.length);
  return categoriesWithQuestions[index];
}

/**
 * Deterministically builds today's fixed question set/order from a category's
 * eligible questions — same date + same underlying question rows -> the
 * exact same Rush for every player. A different seed namespace than the
 * category pick above so the two choices don't correlate.
 */
function buildDailyRushQuestions(questionRows, dateString) {
  const rng = rngFromString(`${dateString}:questions`);
  return buildRush(questionRows, { rng });
}

/**
 * Resolves today's fixed Daily Rush configuration: which category, and which
 * questions in which order. Deterministic given the date and the current
 * question bank — every player who calls this today gets an identical result.
 */
async function getTodaysDailyRushSelection(dateString = todayDateString()) {
  // Required lazily so the pure functions above stay importable/testable without a DB connection.
  const pool = require('../config/db');

  const [categoryCounts] = await pool.query(
    `SELECT c.id, c.name FROM categories c
     WHERE EXISTS (SELECT 1 FROM questions q WHERE q.category_id = c.id)
     ORDER BY c.id`
  );
  const category = pickDailyCategory(categoryCounts, dateString);
  if (!category) return null;

  const [questionRows] = await pool.query('SELECT * FROM questions WHERE category_id = ?', [category.id]);
  const questions = buildDailyRushQuestions(questionRows, dateString);

  return { dateString, categoryId: category.id, categoryName: category.name, questions };
}

module.exports = {
  todayDateString,
  secondsUntilNextReset,
  pickDailyCategory,
  buildDailyRushQuestions,
  getTodaysDailyRushSelection,
};
