const test = require('node:test');
const assert = require('node:assert/strict');
const { scoreAnswer, streakMultiplierFor, speedMultiplierFor } = require('../src/services/scoring.service');
const { BASE_SCORES } = require('../src/config/rush.config');

test('base scores match the configured difficulty tiers', () => {
  assert.equal(BASE_SCORES.easy, 100);
  assert.equal(BASE_SCORES.medium, 150);
  assert.equal(BASE_SCORES.hard, 225);
  assert.equal(BASE_SCORES.extreme, 350);
});

test('wrong answers always score 0, regardless of speed/streak', () => {
  const result = scoreAnswer({
    difficulty: 'extreme',
    isCorrect: false,
    elapsedMs: 0,
    timerSeconds: 15,
    streakAfter: 0,
  });
  assert.equal(result.score, 0);
});

test('a correct answer never scores negative even when it was slow', () => {
  const result = scoreAnswer({
    difficulty: 'easy',
    isCorrect: true,
    elapsedMs: 999_999, // way past the timer
    timerSeconds: 15,
    streakAfter: 1,
  });
  assert.ok(result.score >= 0);
  assert.equal(result.speedMultiplier, 1); // clamped, not negative
});

test('a fast correct answer scores strictly more than a slow one at the same difficulty/streak', () => {
  const fast = scoreAnswer({ difficulty: 'hard', isCorrect: true, elapsedMs: 0, timerSeconds: 15, streakAfter: 1 });
  const slow = scoreAnswer({ difficulty: 'hard', isCorrect: true, elapsedMs: 15_000, timerSeconds: 15, streakAfter: 1 });
  assert.ok(fast.score > slow.score);
  assert.equal(slow.speedMultiplier, 1); // right at the deadline: no bonus, no penalty
});

test('speedMultiplierFor is neutral (1.0) for untimed questions', () => {
  assert.equal(speedMultiplierFor(50_000, 0), 1.0);
});

test('streak multiplier tiers match spec', () => {
  assert.equal(streakMultiplierFor(1), 1.0);
  assert.equal(streakMultiplierFor(2), 1.0);
  assert.equal(streakMultiplierFor(3), 1.1);
  assert.equal(streakMultiplierFor(4), 1.2);
  assert.equal(streakMultiplierFor(5), 1.3);
  assert.equal(streakMultiplierFor(6), 1.4);
  assert.equal(streakMultiplierFor(7), 1.5);
  assert.equal(streakMultiplierFor(8), 1.6);
  assert.equal(streakMultiplierFor(20), 1.6); // 8+ caps at 1.6
});

test('streak affects final score at fixed difficulty/speed', () => {
  const lowStreak = scoreAnswer({ difficulty: 'medium', isCorrect: true, elapsedMs: 15_000, timerSeconds: 15, streakAfter: 1 });
  const highStreak = scoreAnswer({ difficulty: 'medium', isCorrect: true, elapsedMs: 15_000, timerSeconds: 15, streakAfter: 8 });
  assert.ok(highStreak.score > lowStreak.score);
});
