const test = require('node:test');
const assert = require('node:assert/strict');
const { buildRush } = require('../src/services/questionSelection.service');
const { DIFFICULTY_PROGRESSION, RUSH_LENGTH } = require('../src/config/rush.config');

function makeQuestions(countByDifficulty) {
  let id = 1;
  const rows = [];
  for (const [difficulty, count] of Object.entries(countByDifficulty)) {
    for (let i = 0; i < count; i++) rows.push({ id: id++, difficulty, category_id: 1 });
  }
  return rows;
}

test('a fully-stocked category selects exactly RUSH_LENGTH questions matching the progression', () => {
  const rows = makeQuestions({ easy: 10, medium: 10, hard: 10, extreme: 10 });
  const rush = buildRush(rows);
  assert.equal(rush.length, RUSH_LENGTH);
  rush.forEach((q, i) => assert.equal(q.difficulty, DIFFICULTY_PROGRESSION[i]));
});

test('never repeats a question within the same Rush', () => {
  const rows = makeQuestions({ easy: 10, medium: 10, hard: 10, extreme: 10 });
  const rush = buildRush(rows);
  const ids = rush.map((q) => q.id);
  assert.equal(new Set(ids).size, ids.length);
});

test('random selection varies run to run when a difficulty pool has more than one option', () => {
  const rows = makeQuestions({ easy: 20, medium: 20, hard: 20, extreme: 20 });
  const runs = new Set();
  for (let i = 0; i < 20; i++) {
    runs.add(buildRush(rows).map((q) => q.id).join(','));
  }
  assert.ok(runs.size > 1, 'expected selection order/content to vary across runs');
});

test('falls back to the nearest available difficulty when the desired one is exhausted', () => {
  // No 'easy' questions at all — the two easy slots (progression[0], [1]) must fall back
  // to 'medium', the nearest difficulty, rather than being skipped or crashing.
  const rows = makeQuestions({ medium: 10, hard: 10, extreme: 10 });
  const rush = buildRush(rows);
  assert.equal(rush.length, RUSH_LENGTH);
  assert.equal(rush[0].difficulty, 'medium');
  assert.equal(rush[1].difficulty, 'medium');
});

test('gracefully handles a category with fewer than RUSH_LENGTH eligible questions', () => {
  const rows = makeQuestions({ easy: 2, medium: 1 });
  const rush = buildRush(rows);
  assert.equal(rush.length, 3); // uses everything available, doesn't pad or fail
  const ids = rush.map((q) => q.id);
  assert.equal(new Set(ids).size, ids.length);
});

test('an empty category yields an empty Rush, not an error', () => {
  assert.deepEqual(buildRush([]), []);
});
