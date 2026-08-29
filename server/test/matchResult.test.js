const test = require('node:test');
const assert = require('node:assert/strict');
const { resolveMatchWinner } = require('../src/services/matchResult.service');

test('higher score wins outright, regardless of response time', () => {
  const outcome = resolveMatchWinner({ scoreA: 500, scoreB: 300, avgResponseTimeMsA: 5000, avgResponseTimeMsB: 1000 });
  assert.equal(outcome, 'a');
});

test('the other side wins when their score is higher', () => {
  const outcome = resolveMatchWinner({ scoreA: 300, scoreB: 500, avgResponseTimeMsA: 1000, avgResponseTimeMsB: 5000 });
  assert.equal(outcome, 'b');
});

test('an exact score tie breaks on faster avg response time', () => {
  const outcome = resolveMatchWinner({ scoreA: 400, scoreB: 400, avgResponseTimeMsA: 900, avgResponseTimeMsB: 1200 });
  assert.equal(outcome, 'a', 'A was faster on average, so A wins the tiebreak');
});

test('a full tie (score and avg response time both equal) is a draw', () => {
  const outcome = resolveMatchWinner({ scoreA: 400, scoreB: 400, avgResponseTimeMsA: 1000, avgResponseTimeMsB: 1000 });
  assert.equal(outcome, 'draw');
});
