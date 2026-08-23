const test = require('node:test');
const assert = require('node:assert/strict');
const {
  todayDateString,
  secondsUntilNextReset,
  pickDailyCategory,
  buildDailyRushQuestions,
} = require('../src/services/dailyRush.service');

test('todayDateString uses UTC, not host-local time, and formats as YYYY-MM-DD', () => {
  // A moment that's a different calendar day in UTC than in, say, US Pacific time.
  const almostMidnightUtc = new Date('2026-08-23T23:30:00.000Z');
  assert.equal(todayDateString(almostMidnightUtc), '2026-08-23');
});

test('secondsUntilNextReset counts down to the next UTC midnight, not local midnight', () => {
  const oneHourBeforeUtcMidnight = new Date('2026-08-23T23:00:00.000Z');
  assert.equal(secondsUntilNextReset(oneHourBeforeUtcMidnight), 3600);

  const exactlyUtcMidnight = new Date('2026-08-24T00:00:00.000Z');
  assert.equal(secondsUntilNextReset(exactlyUtcMidnight), 24 * 3600);
});

test('pickDailyCategory: same date always picks the same category from a fixed list', () => {
  const categories = [{ id: 1, name: 'Movies' }, { id: 2, name: 'Music' }, { id: 3, name: 'Trivia' }];
  const first = pickDailyCategory(categories, '2026-08-23');
  const second = pickDailyCategory(categories, '2026-08-23');
  assert.deepEqual(first, second);
});

test('pickDailyCategory: different dates can (and eventually do) pick different categories', () => {
  const categories = Array.from({ length: 8 }, (_, i) => ({ id: i + 1, name: `Cat ${i + 1}` }));
  const picks = new Set();
  for (let d = 1; d <= 30; d++) {
    const date = `2026-08-${String(d).padStart(2, '0')}`;
    picks.add(pickDailyCategory(categories, date).id);
  }
  assert.ok(picks.size > 1, 'expected the daily category to rotate across a month, not stay fixed');
});

test('pickDailyCategory: empty category list returns null instead of throwing', () => {
  assert.equal(pickDailyCategory([], '2026-08-23'), null);
});

test('buildDailyRushQuestions: identical inputs (same date, same question rows) produce an identical Rush', () => {
  const rows = Array.from({ length: 20 }, (_, i) => ({
    id: i + 1,
    difficulty: ['easy', 'medium', 'hard', 'extreme'][i % 4],
  }));
  const first = buildDailyRushQuestions(rows, '2026-08-23');
  const second = buildDailyRushQuestions(rows, '2026-08-23');
  assert.deepEqual(first.map((q) => q.id), second.map((q) => q.id));
});

test('buildDailyRushQuestions: two different simulated players requesting "today" get the same set (the actual point of Daily Rush)', () => {
  const rows = Array.from({ length: 20 }, (_, i) => ({
    id: i + 1,
    difficulty: ['easy', 'medium', 'hard', 'extreme'][i % 4],
  }));
  const today = '2026-08-23';
  const playerA = buildDailyRushQuestions(rows, today); // independent calls, as separate requests would make
  const playerB = buildDailyRushQuestions(rows, today);
  assert.deepEqual(playerA.map((q) => q.id), playerB.map((q) => q.id));
});

test('buildDailyRushQuestions: a different date produces a different (or at least not-guaranteed-same) order', () => {
  const rows = Array.from({ length: 20 }, (_, i) => ({
    id: i + 1,
    difficulty: ['easy', 'medium', 'hard', 'extreme'][i % 4],
  }));
  const day1 = buildDailyRushQuestions(rows, '2026-08-23').map((q) => q.id);
  const day2 = buildDailyRushQuestions(rows, '2026-08-24').map((q) => q.id);
  assert.notDeepEqual(day1, day2);
});
