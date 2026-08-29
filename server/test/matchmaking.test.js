const test = require('node:test');
const assert = require('node:assert/strict');
const { enqueue, dequeue, tryPair, evictStale, generateInviteCode } = require('../src/services/matchmaking.service');

test('enqueue adds a new player and is a no-op for one already queued', () => {
  let queue = enqueue([], 1, 100);
  queue = enqueue(queue, 2, 200);
  assert.deepEqual(queue, [
    { playerId: 1, joinedAt: 100 },
    { playerId: 2, joinedAt: 200 },
  ]);

  const unchanged = enqueue(queue, 1, 999);
  assert.deepEqual(unchanged, queue, 'joining twice does not duplicate or bump the timestamp');
});

test('dequeue removes exactly the given player', () => {
  const queue = [
    { playerId: 1, joinedAt: 100 },
    { playerId: 2, joinedAt: 200 },
  ];
  assert.deepEqual(dequeue(queue, 1), [{ playerId: 2, joinedAt: 200 }]);
  assert.deepEqual(dequeue(queue, 999), queue, 'removing a player not in the queue is a no-op');
});

test('tryPair returns null with fewer than two waiting', () => {
  assert.deepEqual(tryPair([]), { pair: null, queue: [] });
  const one = [{ playerId: 1, joinedAt: 100 }];
  assert.deepEqual(tryPair(one), { pair: null, queue: one });
});

test('tryPair pairs the two longest-waiting players, regardless of insertion order', () => {
  const queue = [
    { playerId: 3, joinedAt: 300 },
    { playerId: 1, joinedAt: 100 },
    { playerId: 2, joinedAt: 200 },
  ];
  const { pair, queue: remaining } = tryPair(queue);
  assert.deepEqual(pair, [1, 2]);
  assert.deepEqual(remaining, [{ playerId: 3, joinedAt: 300 }]);
});

test('evictStale removes only entries at or past the timeout, in order', () => {
  const queue = [
    { playerId: 1, joinedAt: 0 },
    { playerId: 2, joinedAt: 50 },
    { playerId: 3, joinedAt: 90 },
  ];
  const { queue: remaining, evicted } = evictStale(queue, 100, 50);
  assert.deepEqual(evicted, [1, 2], 'waiting exactly the timeout counts as stale too');
  assert.deepEqual(remaining, [{ playerId: 3, joinedAt: 90 }]);
});

test('generateInviteCode produces the configured length from the configured alphabet', () => {
  const code = generateInviteCode();
  assert.equal(code.length, 6);
  assert.match(code, /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]+$/, 'excludes ambiguous characters like 0/O/1/I');
});

test('generateInviteCode is deterministic given a seeded rng', () => {
  let calls = 0;
  const sequence = [0.01, 0.99, 0.5, 0.0, 0.33, 0.66];
  const rng = () => sequence[calls++];
  const code = generateInviteCode(rng);
  assert.equal(code.length, 6);
  // Same seed sequence -> same code, exercising the actual index math rather than just format.
  calls = 0;
  assert.equal(generateInviteCode(rng), code);
});
