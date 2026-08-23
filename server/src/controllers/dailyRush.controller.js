const pool = require('../config/db');
const ApiError = require('../utils/ApiError');
const dailyRushService = require('../services/dailyRush.service');
const { serializeQuestion, parseJsonField, insertSession, loadQuestionsInOrder } = require('./sessions.controller');
const { REMOVE_ONE_USES_PER_RUSH } = require('../config/mechanics.config');

/**
 * Status check for the Home screen — never creates or mutates anything, safe
 * to call as often as needed. `available` covers both "haven't started yet"
 * and "started earlier today but didn't finish" (resumable via /start).
 */
async function today(req, res) {
  const dateString = dailyRushService.todayDateString();

  const [[attempt]] = await pool.query(
    `SELECT dra.session_id, gs.status, gs.score, gs.ended_at
     FROM daily_rush_attempts dra JOIN game_sessions gs ON gs.id = dra.session_id
     WHERE dra.player_id = ? AND dra.daily_date = ?`,
    [req.user.id, dateString]
  );

  const [[bestRow]] = await pool.query(
    `SELECT MAX(gs.score) AS best_score
     FROM daily_rush_attempts dra JOIN game_sessions gs ON gs.id = dra.session_id
     WHERE dra.player_id = ? AND gs.status = 'completed'`,
    [req.user.id]
  );

  let todayRank = null;
  if (attempt && attempt.status === 'completed') {
    const [[rankRow]] = await pool.query(
      `SELECT COUNT(*) + 1 AS \`rank\`
       FROM daily_rush_attempts dra JOIN game_sessions gs ON gs.id = dra.session_id
       WHERE dra.daily_date = ? AND gs.status = 'completed'
         AND (gs.score > ? OR (gs.score = ? AND gs.ended_at < ?))`,
      [dateString, attempt.score, attempt.score, attempt.ended_at]
    );
    todayRank = rankRow.rank;
  }

  res.json({
    date: dateString,
    seconds_until_reset: dailyRushService.secondsUntilNextReset(),
    available: !attempt || attempt.status === 'in_progress',
    completed: Boolean(attempt && attempt.status === 'completed'),
    session_id: attempt ? attempt.session_id : null,
    today_score: attempt && attempt.status === 'completed' ? attempt.score : null,
    today_rank: todayRank,
    best_score: bestRow.best_score,
  });
}

/**
 * Starts (or resumes) today's official Daily Rush. The UNIQUE(player_id, daily_date)
 * constraint on daily_rush_attempts is what actually enforces "one official attempt" —
 * this handler just makes the common paths pleasant: a first call creates it, a repeat
 * call while unfinished resumes the same session, and a repeat call after completion
 * is rejected rather than silently starting a second attempt.
 */
async function start(req, res) {
  const dateString = dailyRushService.todayDateString();
  const playerId = req.user.id;

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    // Lock the player's own row first — it always exists, unlike the daily_rush_attempts
    // row this handler might be about to create. Locking a row that may not exist yet
    // locks nothing at all, so two concurrent first-ever /start calls would both see
    // "no attempt yet" and both try to INSERT, racing on the UNIQUE constraint (which
    // under InnoDB gap-locking manifests as a deadlock, not a clean duplicate-key error).
    // Locking the always-present player row genuinely serializes concurrent requests
    // from the same player: the second one blocks here until the first commits, then
    // correctly sees the daily_rush_attempts row the first one just created.
    await connection.query('SELECT id FROM players WHERE id = ? FOR UPDATE', [playerId]);

    const [[existing]] = await connection.query(
      `SELECT dra.session_id, gs.status, gs.current_index, gs.question_ids, gs.remove_one_uses_remaining
       FROM daily_rush_attempts dra JOIN game_sessions gs ON gs.id = dra.session_id
       WHERE dra.player_id = ? AND dra.daily_date = ? FOR UPDATE`,
      [playerId, dateString]
    );

    if (existing) {
      if (existing.status === 'completed') {
        throw new ApiError(409, "Today's Daily Rush has already been completed");
      }
      const questionIds = parseJsonField(existing.question_ids);
      const questionRows = await loadQuestionsInOrder(connection, questionIds);
      await connection.commit();
      return res.status(200).json({
        session_id: existing.session_id,
        current_index: existing.current_index,
        questions: questionRows.map(serializeQuestion),
        date: dateString,
        remove_one_uses_remaining: existing.remove_one_uses_remaining,
      });
    }

    const selection = await dailyRushService.getTodaysDailyRushSelection(dateString);
    if (!selection || selection.questions.length === 0) {
      throw new ApiError(400, 'No Daily Rush is available yet — the question bank is empty.');
    }

    const sessionId = await insertSession(connection, {
      playerId,
      categoryId: selection.categoryId,
      questionRows: selection.questions,
    });

    try {
      await connection.query('INSERT INTO daily_rush_attempts (player_id, daily_date, session_id) VALUES (?, ?, ?)', [
        playerId,
        dateString,
        sessionId,
      ]);
    } catch (err) {
      // Belt-and-suspenders: the FOR UPDATE lock above already prevents this in practice,
      // but the UNIQUE constraint is the real backstop if that ever changes.
      if (err.code === 'ER_DUP_ENTRY') throw new ApiError(409, "Today's Daily Rush has already been started");
      throw err;
    }

    await connection.commit();
    res.status(201).json({
      session_id: sessionId,
      current_index: 0,
      questions: selection.questions.map(serializeQuestion),
      date: dateString,
      remove_one_uses_remaining: REMOVE_ONE_USES_PER_RUSH,
    });
  } catch (err) {
    await connection.rollback();
    // Narrow window: locking the player row first (above) fixes the common race, but a
    // /daily-rush/start racing an in-flight /finish on the very same session can still
    // deadlock the two opposite lock orderings — InnoDB detects it and aborts one side.
    // That's a transient condition, not a real error, so surface it as retryable.
    if (err.code === 'ER_LOCK_DEADLOCK') {
      throw new ApiError(409, 'Please try again.');
    }
    throw err;
  } finally {
    connection.release();
  }
}

module.exports = { today, start };
