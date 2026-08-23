const { ANSWER_GRACE_MS } = require('../config/rush.config');

/**
 * Server-authoritative correctness/timeout determination for one answer.
 * `elapsedMs` MUST come from a server-side clock (question_started_at → now),
 * never from a client-reported value — that's the whole point of this function.
 *
 * A timeout is either an explicit client-reported timeout (selectedIndex -1)
 * or a late submission that arrives after the question's timer plus a small
 * network-jitter grace window, regardless of what the client claims it picked.
 */
function evaluateTiming({ selectedIndex, correctIndex, elapsedMs, timerSeconds }) {
  const deadlineMs = timerSeconds > 0 ? timerSeconds * 1000 + ANSWER_GRACE_MS : null;
  const timedOut = selectedIndex === -1 || (deadlineMs !== null && elapsedMs > deadlineMs);
  const isCorrect = !timedOut && selectedIndex === correctIndex;
  return { isCorrect, timedOut };
}

module.exports = { evaluateTiming };
