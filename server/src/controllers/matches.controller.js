const pool = require('../config/db');
const ApiError = require('../utils/ApiError');
const matchmakingService = require('../services/matchmaking.service');
const realtimeService = require('../services/realtime.service');
const questionSelectionService = require('../services/questionSelection.service');
const { serializeQuestion, insertSession } = require('./sessions.controller');
const { REMOVE_ONE_USES_PER_RUSH } = require('../config/mechanics.config');
const { FRIEND_CODE_EXPIRY_MS } = require('../config/match.config');

/**
 * Shared by random-queue pairing and friend-code join: generates the shared
 * question set once, creates both players' ordinary Rush sessions against
 * it (mode='quick_rush' — see the plan's "no new game_sessions column"
 * simplification), marks the match in_progress, and pushes `match:paired`
 * to both over the socket. Returns `{ forA, forB }` (each side's own
 * session id + question list + opponent info) so the caller can also hand
 * the *requesting* player their payload directly in the REST response,
 * without depending on the socket round-trip. Returns null if the question
 * bank is empty (cancels the match rather than starting one with nothing in it).
 */
async function startMatch(matchId, playerAId, playerBId) {
  const questionRows = await questionSelectionService.selectVariedRushQuestions('quick_rush');
  if (questionRows.length === 0) {
    await pool.query("UPDATE matches SET status = 'cancelled' WHERE id = ?", [matchId]);
    return null;
  }

  const sessionAId = await insertSession(pool, { playerId: playerAId, mode: 'quick_rush', questionRows });
  const sessionBId = await insertSession(pool, { playerId: playerBId, mode: 'quick_rush', questionRows });
  const questionIds = questionRows.map((q) => q.id);

  await pool.query(
    `UPDATE matches SET player_b_id = ?, session_a_id = ?, session_b_id = ?, question_ids = ?,
      status = 'in_progress', started_at = NOW() WHERE id = ?`,
    [playerBId, sessionAId, sessionBId, JSON.stringify(questionIds), matchId]
  );

  const [[playerA]] = await pool.query('SELECT id, display_name FROM players WHERE id = ?', [playerAId]);
  const [[playerB]] = await pool.query('SELECT id, display_name FROM players WHERE id = ?', [playerBId]);
  const questions = questionRows.map(serializeQuestion);

  const forA = {
    session_id: sessionAId,
    questions,
    remove_one_uses_remaining: REMOVE_ONE_USES_PER_RUSH,
    opponent: { id: playerB.id, display_name: playerB.display_name },
  };
  const forB = {
    session_id: sessionBId,
    questions,
    remove_one_uses_remaining: REMOVE_ONE_USES_PER_RUSH,
    opponent: { id: playerA.id, display_name: playerA.display_name },
  };

  realtimeService.sendToPlayer(playerAId, { type: 'match:paired', match_id: matchId, ...forA });
  realtimeService.sendToPlayer(playerBId, { type: 'match:paired', match_id: matchId, ...forB });

  return { forA, forB };
}

/** Joins the random 1v1 queue; pairs immediately if someone else is already waiting. */
async function joinQueue(req, res) {
  const playerId = req.user.id;
  const pair = matchmakingService.joinQueue(playerId);

  if (!pair) {
    return res.json({ status: 'waiting' });
  }

  const [playerAId, playerBId] = pair;
  const [result] = await pool.query("INSERT INTO matches (mode, status, player_a_id) VALUES ('random', 'waiting', ?)", [
    playerAId,
  ]);
  const matchId = result.insertId;

  const started = await startMatch(matchId, playerAId, playerBId);
  if (!started) {
    throw new ApiError(503, 'No questions available right now.');
  }

  const mine = playerId === playerAId ? started.forA : started.forB;
  res.json({ status: 'matched', match_id: matchId, ...mine });
}

/** Leaves the random queue (e.g. the player backed out of the waiting screen). */
async function leaveQueue(req, res) {
  matchmakingService.leaveQueue(req.user.id);
  res.json({ status: 'left' });
}

/** Creates a friend-invite match and returns its short code. No opponent/sessions yet. */
async function createFriendMatch(req, res) {
  const playerId = req.user.id;

  let code;
  for (let attempt = 0; attempt < 10; attempt++) {
    const candidate = matchmakingService.generateInviteCode();
    const [existing] = await pool.query("SELECT id FROM matches WHERE invite_code = ? AND status = 'waiting'", [
      candidate,
    ]);
    if (existing.length === 0) {
      code = candidate;
      break;
    }
  }
  if (!code) {
    throw new ApiError(503, 'Could not generate an invite code — try again.');
  }

  const [result] = await pool.query(
    "INSERT INTO matches (mode, status, invite_code, player_a_id) VALUES ('friend', 'waiting', ?, ?)",
    [code, playerId]
  );
  res.status(201).json({ match_id: result.insertId, invite_code: code });
}

/** Joins a friend-invite match by code, pairing with whoever created it. */
async function joinFriendMatch(req, res) {
  const playerId = req.user.id;
  const code = (req.params.code || '').trim().toUpperCase();

  // age_seconds is computed by MySQL itself (created_at and NOW() both come from
  // the same clock) rather than diffing created_at against this process's own
  // Date.now() — comparing a DB timestamp against the app server's clock is only
  // ever correct if the two processes' clocks agree, which isn't a safe thing to
  // assume across containers/hosts.
  const [rows] = await pool.query(
    'SELECT *, TIMESTAMPDIFF(SECOND, created_at, NOW()) AS age_seconds FROM matches WHERE invite_code = ?',
    [code]
  );
  const match = rows[0];
  if (!match) throw new ApiError(404, 'Invite code not found.');
  if (match.player_a_id === playerId) throw new ApiError(400, "You can't join your own invite.");

  if (match.status === 'waiting' && match.age_seconds * 1000 > FRIEND_CODE_EXPIRY_MS) {
    await pool.query("UPDATE matches SET status = 'cancelled' WHERE id = ? AND status = 'waiting'", [match.id]);
    throw new ApiError(410, 'This invite code has expired.');
  }

  // Atomic claim: the conditional UPDATE only ever succeeds for one concurrent
  // joiner (a second request sees affectedRows === 0 and is correctly rejected),
  // no separate transaction/row-lock needed for a single-statement guard like this.
  const [claim] = await pool.query("UPDATE matches SET status = 'in_progress' WHERE id = ? AND status = 'waiting'", [
    match.id,
  ]);
  if (claim.affectedRows === 0) {
    throw new ApiError(409, 'This invite has already been used or expired.');
  }

  const started = await startMatch(match.id, match.player_a_id, playerId);
  if (!started) {
    throw new ApiError(503, 'No questions available right now.');
  }
  res.json({ status: 'matched', match_id: match.id, ...started.forB });
}

/** Poll fallback for match status/result — for a client that reconnects, or just missed the socket push. */
async function getMatch(req, res) {
  const matchId = Number(req.params.id);
  const [rows] = await pool.query('SELECT * FROM matches WHERE id = ?', [matchId]);
  const match = rows[0];
  if (!match) throw new ApiError(404, 'Match not found');
  if (match.player_a_id !== req.user.id && match.player_b_id !== req.user.id) {
    throw new ApiError(403, 'Not your match');
  }

  if (match.status !== 'completed') {
    return res.json({ status: match.status });
  }

  const [[sessionA]] = await pool.query('SELECT score FROM game_sessions WHERE id = ?', [match.session_a_id]);
  const [[sessionB]] = await pool.query('SELECT score FROM game_sessions WHERE id = ?', [match.session_b_id]);
  res.json({
    status: 'completed',
    match_id: match.id,
    winner_player_id: match.winner_player_id,
    scores: { a: sessionA ? sessionA.score : null, b: sessionB ? sessionB.score : null },
  });
}

module.exports = { joinQueue, leaveQueue, createFriendMatch, joinFriendMatch, getMatch };
