/**
 * Compares two finished sides of a 1v1 match. Higher score wins; an exact
 * score tie breaks on faster avg response time — the same tiebreak
 * `buildDailyInfo` in sessions.controller.js already uses for the Daily
 * Rush leaderboard (score desc, then earliest-finish). Returns 'a', 'b', or
 * 'draw' (a draw needs both score AND avg response time to tie exactly).
 */
function resolveMatchWinner({ scoreA, scoreB, avgResponseTimeMsA, avgResponseTimeMsB }) {
  if (scoreA !== scoreB) return scoreA > scoreB ? 'a' : 'b';
  if (avgResponseTimeMsA !== avgResponseTimeMsB) return avgResponseTimeMsA < avgResponseTimeMsB ? 'a' : 'b';
  return 'draw';
}

module.exports = { resolveMatchWinner };
