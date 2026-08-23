const test = require('node:test');
const assert = require('node:assert/strict');
const { scoreAnswer, clueMultiplierFor, doubleDownMultiplierFor } = require('../src/services/scoring.service');
const { CLUE_SCORE_MULTIPLIERS, DOUBLE_DOWN_RISKY_MULTIPLIER } = require('../src/config/mechanics.config');

// ---- Clue scoring (progressive questions) ----

test('clueMultiplierFor matches the spec example: clue 1 = 100%, clue 2 = 80%, clue 3 = 60%', () => {
  assert.equal(clueMultiplierFor(1), 1.0);
  assert.equal(clueMultiplierFor(2), 0.8);
  assert.equal(clueMultiplierFor(3), 0.6);
});

test('clueMultiplierFor clamps to the last configured tier if a question has more clues than the table', () => {
  const lastTier = CLUE_SCORE_MULTIPLIERS[CLUE_SCORE_MULTIPLIERS.length - 1];
  assert.equal(clueMultiplierFor(CLUE_SCORE_MULTIPLIERS.length + 5), lastTier);
});

test('clueMultiplierFor treats 0 the same as 1 (never divides by zero / goes out of bounds)', () => {
  assert.equal(clueMultiplierFor(0), 1.0);
});

test('revealing more clues strictly reduces a correct answer\'s score, never increases it', () => {
  const clue1 = scoreAnswer({ difficulty: 'medium', isCorrect: true, elapsedMs: 5000, timerSeconds: 15, streakAfter: 1, cluesRevealed: 1 });
  const clue2 = scoreAnswer({ difficulty: 'medium', isCorrect: true, elapsedMs: 5000, timerSeconds: 15, streakAfter: 1, cluesRevealed: 2 });
  const clue3 = scoreAnswer({ difficulty: 'medium', isCorrect: true, elapsedMs: 5000, timerSeconds: 15, streakAfter: 1, cluesRevealed: 3 });
  assert.ok(clue1.score > clue2.score);
  assert.ok(clue2.score > clue3.score);
});

test('clue count has no effect on a wrong answer — still 0, not reduced further', () => {
  const result = scoreAnswer({ difficulty: 'medium', isCorrect: false, elapsedMs: 5000, timerSeconds: 15, streakAfter: 0, cluesRevealed: 3 });
  assert.equal(result.score, 0);
});

test('cluesRevealed defaults to 1 (full score) when omitted — non-progressive questions are unaffected', () => {
  const withDefault = scoreAnswer({ difficulty: 'easy', isCorrect: true, elapsedMs: 0, timerSeconds: 0, streakAfter: 1 });
  const explicitClue1 = scoreAnswer({ difficulty: 'easy', isCorrect: true, elapsedMs: 0, timerSeconds: 0, streakAfter: 1, cluesRevealed: 1 });
  assert.equal(withDefault.score, explicitClue1.score);
  assert.equal(withDefault.clueMultiplier, 1.0);
});

// ---- Double Down risk/reward ----

test('doubleDownMultiplierFor: risky + correct = the configured bonus multiplier', () => {
  assert.equal(doubleDownMultiplierFor('risky', true), DOUBLE_DOWN_RISKY_MULTIPLIER);
});

test('doubleDownMultiplierFor: risky + wrong is neutral — no extra penalty beyond the normal 0-score miss', () => {
  assert.equal(doubleDownMultiplierFor('risky', false), 1.0);
});

test('doubleDownMultiplierFor: safe never changes the multiplier, correct or wrong', () => {
  assert.equal(doubleDownMultiplierFor('safe', true), 1.0);
  assert.equal(doubleDownMultiplierFor('safe', false), 1.0);
});

test('doubleDownMultiplierFor: no choice (null) behaves exactly like safe', () => {
  assert.equal(doubleDownMultiplierFor(null, true), 1.0);
});

test('a risky correct answer scores exactly double a safe correct answer, all else equal', () => {
  const safe = scoreAnswer({ difficulty: 'hard', isCorrect: true, elapsedMs: 5000, timerSeconds: 15, streakAfter: 3, doubleDownChoice: 'safe' });
  const risky = scoreAnswer({ difficulty: 'hard', isCorrect: true, elapsedMs: 5000, timerSeconds: 15, streakAfter: 3, doubleDownChoice: 'risky' });
  assert.equal(risky.score, safe.score * DOUBLE_DOWN_RISKY_MULTIPLIER);
});

test('a risky WRONG answer never scores worse than a safe wrong answer would have (both 0, no penalty)', () => {
  const safe = scoreAnswer({ difficulty: 'hard', isCorrect: false, elapsedMs: 5000, timerSeconds: 15, streakAfter: 0, doubleDownChoice: 'safe' });
  const risky = scoreAnswer({ difficulty: 'hard', isCorrect: false, elapsedMs: 5000, timerSeconds: 15, streakAfter: 0, doubleDownChoice: 'risky' });
  assert.equal(safe.score, 0);
  assert.equal(risky.score, 0);
});

// ---- Composition: clues and Double Down can stack (e.g. a progressive question during a Double Down) ----

test('clue and double-down multipliers compose multiplicatively, not additively', () => {
  const base = scoreAnswer({ difficulty: 'medium', isCorrect: true, elapsedMs: 5000, timerSeconds: 15, streakAfter: 1 });
  const both = scoreAnswer({
    difficulty: 'medium', isCorrect: true, elapsedMs: 5000, timerSeconds: 15, streakAfter: 1,
    cluesRevealed: 2, doubleDownChoice: 'risky',
  });
  const expected = Math.round(base.score * 0.8 * DOUBLE_DOWN_RISKY_MULTIPLIER);
  assert.equal(both.score, expected);
});
