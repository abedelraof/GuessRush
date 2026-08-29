const pool = require('../config/db');
const realtimeService = require('./realtime.service');
const { resolveMatchWinner } = require('./matchResult.service');

/**
 * Called from sessions.controller.js's submitAnswer, after grading — pushes
 * the opponent a presence-only update (just the new question index, never
 * correctness or score; see the plan's "presence-only reveal" decision).
 * Best-effort: a failure here must never break the underlying answer flow.
 */
async function pushOpponentProgress(sessionId, currentIndex) {
  try {
    const [[match]] = await pool.query(
      "SELECT * FROM matches WHERE (session_a_id = ? OR session_b_id = ?) AND status = 'in_progress'",
      [sessionId, sessionId]
    );
    if (!match) return;
    const opponentPlayerId = match.session_a_id === sessionId ? match.player_b_id : match.player_a_id;
    if (!opponentPlayerId) return;
    realtimeService.sendToPlayer(opponentPlayerId, {
      type: 'match:opponent_progress',
      match_id: match.id,
      current_index: currentIndex,
    });
  } catch (err) {
    console.error('pushOpponentProgress failed (non-fatal):', err);
  }
}

async function avgResponseTimeForSession(sessionId) {
  const [rows] = await pool.query('SELECT server_elapsed_ms FROM answers WHERE session_id = ?', [sessionId]);
  if (rows.length === 0) return 0;
  return rows.reduce((sum, r) => sum + r.server_elapsed_ms, 0) / rows.length;
}

/**
 * Called from sessions.controller.js's finish(), after a session transitions
 * to 'completed' — resolves the match once BOTH sides are done (does nothing
 * if the other side hasn't finished yet, or this session isn't part of a
 * match at all). Best-effort, same reasoning as pushOpponentProgress above.
 */
async function resolveMatchIfBothDone(sessionId) {
  try {
    const [[match]] = await pool.query(
      "SELECT * FROM matches WHERE (session_a_id = ? OR session_b_id = ?) AND status = 'in_progress'",
      [sessionId, sessionId]
    );
    if (!match) return;

    const [[sessionA]] = await pool.query('SELECT status, score FROM game_sessions WHERE id = ?', [match.session_a_id]);
    const [[sessionB]] = await pool.query('SELECT status, score FROM game_sessions WHERE id = ?', [match.session_b_id]);
    if (!sessionA || !sessionB || sessionA.status !== 'completed' || sessionB.status !== 'completed') return;

    const [avgA, avgB] = await Promise.all([
      avgResponseTimeForSession(match.session_a_id),
      avgResponseTimeForSession(match.session_b_id),
    ]);

    const outcome = resolveMatchWinner({
      scoreA: sessionA.score,
      scoreB: sessionB.score,
      avgResponseTimeMsA: avgA,
      avgResponseTimeMsB: avgB,
    });
    const winnerPlayerId = outcome === 'draw' ? null : outcome === 'a' ? match.player_a_id : match.player_b_id;

    const [update] = await pool.query(
      "UPDATE matches SET status = 'completed', winner_player_id = ?, ended_at = NOW() WHERE id = ? AND status = 'in_progress'",
      [winnerPlayerId, match.id]
    );
    if (update.affectedRows === 0) return; // already resolved (e.g. a concurrent disconnect-forfeit)

    const payload = {
      type: 'match:result',
      match_id: match.id,
      winner_player_id: winnerPlayerId,
      scores: { a: sessionA.score, b: sessionB.score },
    };
    realtimeService.sendToPlayer(match.player_a_id, payload);
    realtimeService.sendToPlayer(match.player_b_id, payload);
  } catch (err) {
    console.error('resolveMatchIfBothDone failed (non-fatal):', err);
  }
}

/**
 * Registered with realtime.service.js as the disconnect-grace-expiry handler
 * (see match.config.js's DISCONNECT_GRACE_MS). If neither side has answered
 * anything yet, the match is voided rather than counted as a forfeit.
 */
async function handleDisconnectGraceExpired(playerId) {
  try {
    const [[match]] = await pool.query(
      "SELECT * FROM matches WHERE (player_a_id = ? OR player_b_id = ?) AND status = 'in_progress'",
      [playerId, playerId]
    );
    if (!match) return;
    // A brief disconnect right as the match resolves normally is harmless — don't
    // race a forfeit against the legitimate both-finished resolution above.
    if (realtimeService.isConnected(playerId)) return;

    const [answersA] = await pool.query('SELECT id FROM answers WHERE session_id = ? LIMIT 1', [match.session_a_id]);
    const [answersB] = await pool.query('SELECT id FROM answers WHERE session_id = ? LIMIT 1', [match.session_b_id]);
    const neitherHasAnswered = answersA.length === 0 && answersB.length === 0;
    const opponentPlayerId = match.player_a_id === playerId ? match.player_b_id : match.player_a_id;

    if (neitherHasAnswered) {
      const [update] = await pool.query(
        "UPDATE matches SET status = 'cancelled', ended_at = NOW() WHERE id = ? AND status = 'in_progress'",
        [match.id]
      );
      if (update.affectedRows === 0) return;
      realtimeService.sendToPlayer(opponentPlayerId, { type: 'match:cancelled', match_id: match.id });
      return;
    }

    const [update] = await pool.query(
      "UPDATE matches SET status = 'completed', winner_player_id = ?, ended_at = NOW() WHERE id = ? AND status = 'in_progress'",
      [opponentPlayerId, match.id]
    );
    if (update.affectedRows === 0) return;
    realtimeService.sendToPlayer(opponentPlayerId, {
      type: 'match:result',
      match_id: match.id,
      winner_player_id: opponentPlayerId,
      forfeit: true,
    });
  } catch (err) {
    console.error('handleDisconnectGraceExpired failed (non-fatal):', err);
  }
}

realtimeService.setGraceExpiredHandler(handleDisconnectGraceExpired);

module.exports = { pushOpponentProgress, resolveMatchIfBothDone };
