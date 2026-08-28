const test = require('node:test');
const assert = require('node:assert/strict');
const { buildVariedRush, buildStreakProgression } = require('../src/services/questionSelection.service');
const { RUSH_LENGTH, STREAK_RUSH_MAX_LENGTH, STREAK_DIFFICULTY_TIER_SIZES } = require('../src/config/rush.config');

function makeQuestions(countByDifficulty, { types = ['text'], categoryIds = [1] } = {}) {
  let id = 1;
  const rows = [];
  for (const [difficulty, count] of Object.entries(countByDifficulty)) {
    for (let i = 0; i < count; i++) {
      rows.push({
        id: id++,
        difficulty,
        type: types[i % types.length],
        category_id: categoryIds[i % categoryIds.length],
      });
    }
  }
  return rows;
}

test('buildVariedRush pulls across every category present in rows (no category filtering)', () => {
  const rows = makeQuestions(
    { easy: 20, medium: 20, hard: 20, extreme: 20 },
    { categoryIds: [1, 2, 3, 4] }
  );
  const rush = buildVariedRush(rows);
  const categoriesSeen = new Set(rush.map((q) => q.category_id));
  assert.ok(categoriesSeen.size > 1, 'expected more than one category to appear across the Rush');
});

test('buildVariedRush avoids 3+ of the same type in a row when alternatives exist', () => {
  const rows = makeQuestions(
    { easy: 20, medium: 20, hard: 20, extreme: 20 },
    { types: ['text', 'emoji', 'image', 'video', 'audio'] }
  );
  const rush = buildVariedRush(rows);
  let runLength = 1;
  for (let i = 1; i < rush.length; i++) {
    runLength = rush[i].type === rush[i - 1].type ? runLength + 1 : 1;
    assert.ok(runLength < 3, `same type repeated ${runLength}+ times in a row at index ${i}`);
  }
});

test('buildVariedRush never repeats a question and gracefully truncates on a small bank', () => {
  const rows = makeQuestions({ easy: 2, medium: 1 });
  const rush = buildVariedRush(rows);
  assert.equal(rush.length, 3);
  const ids = rush.map((q) => q.id);
  assert.equal(new Set(ids).size, ids.length);
});

test('buildVariedRush with randomizeDifficultyOrder still selects `length` questions without repeats', () => {
  const rows = makeQuestions({ easy: 20, medium: 20, hard: 20, extreme: 20 });
  const rush = buildVariedRush(rows, { randomizeDifficultyOrder: true });
  assert.equal(rush.length, RUSH_LENGTH);
  const ids = rush.map((q) => q.id);
  assert.equal(new Set(ids).size, ids.length);
});

test('buildStreakProgression ramps through the configured tiers then holds at extreme', () => {
  const seq = buildStreakProgression(STREAK_RUSH_MAX_LENGTH);
  assert.equal(seq.length, STREAK_RUSH_MAX_LENGTH);
  assert.deepEqual(seq.slice(0, STREAK_DIFFICULTY_TIER_SIZES.easy), Array(STREAK_DIFFICULTY_TIER_SIZES.easy).fill('easy'));
  const afterEasy = STREAK_DIFFICULTY_TIER_SIZES.easy;
  assert.deepEqual(
    seq.slice(afterEasy, afterEasy + STREAK_DIFFICULTY_TIER_SIZES.medium),
    Array(STREAK_DIFFICULTY_TIER_SIZES.medium).fill('medium')
  );
  assert.equal(seq[seq.length - 1], 'extreme');
});

test('buildStreakProgression truncates cleanly for a length shorter than the ramp', () => {
  const seq = buildStreakProgression(2);
  assert.deepEqual(seq, ['easy', 'easy']);
});
