const test = require('node:test');
const assert = require('node:assert/strict');
const { evaluateTiming } = require('../src/services/rushTiming.service');

test('normal answer: correct and on time', () => {
  const { isCorrect, timedOut } = evaluateTiming({
    selectedIndex: 2,
    correctIndex: 2,
    elapsedMs: 3000,
    timerSeconds: 15,
  });
  assert.equal(isCorrect, true);
  assert.equal(timedOut, false);
});

test('normal answer: wrong but on time', () => {
  const { isCorrect, timedOut } = evaluateTiming({
    selectedIndex: 1,
    correctIndex: 2,
    elapsedMs: 3000,
    timerSeconds: 15,
  });
  assert.equal(isCorrect, false);
  assert.equal(timedOut, false);
});

test('answer arriving right at the deadline (before grace) still counts', () => {
  const { isCorrect, timedOut } = evaluateTiming({
    selectedIndex: 2,
    correctIndex: 2,
    elapsedMs: 15_000, // exactly timer_seconds, no grace consumed
    timerSeconds: 15,
  });
  assert.equal(timedOut, false);
  assert.equal(isCorrect, true);
});

test('explicit client timeout (-1) is always a timeout, never correct', () => {
  const { isCorrect, timedOut } = evaluateTiming({
    selectedIndex: -1,
    correctIndex: 2,
    elapsedMs: 500,
    timerSeconds: 15,
  });
  assert.equal(timedOut, true);
  assert.equal(isCorrect, false);
});

test('late submission past timer + grace is a server-side timeout even if the pick was correct', () => {
  const { isCorrect, timedOut } = evaluateTiming({
    selectedIndex: 2,
    correctIndex: 2,
    elapsedMs: 20_000, // 15s timer + 1.5s grace exceeded
    timerSeconds: 15,
  });
  assert.equal(timedOut, true);
  assert.equal(isCorrect, false);
});

test('a late submission within the network-jitter grace window is not a timeout', () => {
  const { isCorrect, timedOut } = evaluateTiming({
    selectedIndex: 2,
    correctIndex: 2,
    elapsedMs: 16_000, // 1s past the 15s timer, inside the 1.5s grace
    timerSeconds: 15,
  });
  assert.equal(timedOut, false);
  assert.equal(isCorrect, true);
});

test('untimed questions (timer_seconds 0) never time out', () => {
  const { isCorrect, timedOut } = evaluateTiming({
    selectedIndex: 0,
    correctIndex: 0,
    elapsedMs: 999_999,
    timerSeconds: 0,
  });
  assert.equal(timedOut, false);
  assert.equal(isCorrect, true);
});

test('outcome depends only on server-clocked elapsedMs, never on a claimed selection alone', () => {
  // Simulates a manipulated client claiming a huge elapsed-looking submission
  // arrives instantly by server clock — elapsedMs is what the server measured,
  // so a small elapsedMs here always passes regardless of what the client sent
  // elsewhere (e.g. its own response_time_ms, which this function never sees).
  const { timedOut } = evaluateTiming({ selectedIndex: 0, correctIndex: 0, elapsedMs: 100, timerSeconds: 15 });
  assert.equal(timedOut, false);
});
