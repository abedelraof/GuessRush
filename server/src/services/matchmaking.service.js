const { QUEUE_TIMEOUT_MS, INVITE_CODE_LENGTH, INVITE_CODE_ALPHABET } = require('../config/match.config');

// ---- Pure, unit-testable core (no shared state, no I/O) ----

/** Adds playerId to the queue at `now`, unless it's already in there. */
function enqueue(queue, playerId, now) {
  if (queue.some((entry) => entry.playerId === playerId)) return queue;
  return [...queue, { playerId, joinedAt: now }];
}

function dequeue(queue, playerId) {
  return queue.filter((entry) => entry.playerId !== playerId);
}

/**
 * Pairs the two longest-waiting players, if at least two are waiting.
 * Returns `{ pair, queue }` — `pair` is null (and `queue` unchanged) if
 * fewer than two players are waiting.
 */
function tryPair(queue) {
  if (queue.length < 2) return { pair: null, queue };
  const sorted = [...queue].sort((a, b) => a.joinedAt - b.joinedAt);
  const [first, second, ...rest] = sorted;
  return { pair: [first.playerId, second.playerId], queue: rest };
}

/** Returns `{ queue, evicted }` — entries waiting `timeoutMs` or longer are evicted. */
function evictStale(queue, now, timeoutMs) {
  const remaining = [];
  const evicted = [];
  for (const entry of queue) {
    if (now - entry.joinedAt >= timeoutMs) evicted.push(entry.playerId);
    else remaining.push(entry);
  }
  return { queue: remaining, evicted };
}

/** A short, hand-typeable invite code — excludes visually-ambiguous characters (see match.config.js). */
function generateInviteCode(rng = Math.random) {
  let code = '';
  for (let i = 0; i < INVITE_CODE_LENGTH; i++) {
    code += INVITE_CODE_ALPHABET[Math.floor(rng() * INVITE_CODE_ALPHABET.length)];
  }
  return code;
}

// ---- Stateful singleton ----
// A plain module-scope array is a valid, dependency-free queue as long as this
// runs as a single process (see the plan's architecture note — no Redis/pub-sub
// needed at the app's current single-container scale). Would need to move to a
// shared store the moment this runs as more than one instance.
let queue = [];

/**
 * Adds `playerId` to the queue and immediately tries to pair. Returns the
 * paired `[playerIdA, playerIdB]` if a pair formed (which may or may not
 * include `playerId`, depending on queue order), or null if still waiting.
 */
function joinQueue(playerId) {
  queue = enqueue(queue, playerId, Date.now());
  const result = tryPair(queue);
  queue = result.queue;
  return result.pair;
}

function leaveQueue(playerId) {
  queue = dequeue(queue, playerId);
}

/** Called periodically (see server.js) — returns the playerIds evicted for waiting too long. */
function sweepQueue() {
  const result = evictStale(queue, Date.now(), QUEUE_TIMEOUT_MS);
  queue = result.queue;
  return result.evicted;
}

/** Test-only: resets the in-memory queue between test cases. */
function _resetQueueForTests() {
  queue = [];
}

module.exports = {
  enqueue,
  dequeue,
  tryPair,
  evictStale,
  generateInviteCode,
  joinQueue,
  leaveQueue,
  sweepQueue,
  _resetQueueForTests,
};
