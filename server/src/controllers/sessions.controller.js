const pool = require('../config/db');
const ApiError = require('../utils/ApiError');
const questionSelectionService = require('../services/questionSelection.service');
const { evaluateTiming } = require('../services/rushTiming.service');
const { scoreAnswer } = require('../services/scoring.service');

// mysql2 auto-parses JSON columns in some configurations but not others
// depending on column metadata — handle both a string and an already-parsed value.
function parseJsonField(value) {
  return typeof value === 'string' ? JSON.parse(value) : value;
}

function serializeQuestion(row) {
  return {
    id: row.id,
    type: row.type,
    difficulty: row.difficulty,
    label: row.label,
    prompt: row.prompt,
    media_placeholder: row.media_placeholder,
    media_duration: row.media_duration,
    emojis: row.emojis,
    options: parseJsonField(row.options),
    clues: row.clues ? parseJsonField(row.clues) : null,
    timer_seconds: row.timer_seconds,
    audio_path: row.audio_path || null,
    option_image_paths: row.option_image_paths ? parseJsonField(row.option_image_paths) : null,
    // correct_index intentionally omitted — never sent to the client.
  };
}

async function create(req, res) {
  const categoryId = Number(req.body && req.body.category_id);
  if (!categoryId) throw new ApiError(400, 'category_id is required');

  const questionRows = await questionSelectionService.selectRushQuestions(categoryId);
  if (questionRows.length === 0) {
    throw new ApiError(400, 'This category has no questions yet');
  }

  const questionIds = questionRows.map((q) => q.id);
  const [result] = await pool.query(
    `INSERT INTO game_sessions
      (player_id, category_id, question_ids, current_index, question_started_at, question_start_pinged)
     VALUES (?, ?, ?, 0, NOW(), 0)`,
    [req.user.id, categoryId, JSON.stringify(questionIds)]
  );

  res.status(201).json({
    session_id: result.insertId,
    questions: questionRows.map(serializeQuestion),
  });
}

/** Loads the session row (locked FOR UPDATE) and validates common preconditions shared by /start and /answers. */
async function loadOwnedInProgressSession(connection, sessionId, playerId) {
  const [sessionRows] = await connection.query('SELECT * FROM game_sessions WHERE id = ? FOR UPDATE', [sessionId]);
  const session = sessionRows[0];
  if (!session) throw new ApiError(404, 'Session not found');
  if (session.player_id !== playerId) throw new ApiError(403, 'Not your session');
  if (session.status !== 'in_progress') throw new ApiError(409, 'Session already finished');
  return session;
}

/**
 * The client pings this once it actually starts displaying/counting down a
 * question (e.g. once narration audio finishes), so the server's timing
 * clock reflects when the player could realistically start answering rather
 * than the moment the question merely became current. Only the first ping
 * per question is honored — later pings are ignored — so a client can't
 * reset the clock right before submitting to fake a fast answer.
 */
async function startQuestion(req, res) {
  const sessionId = Number(req.params.id);
  const questionId = Number(req.body && req.body.question_id);
  if (!questionId) throw new ApiError(400, 'question_id is required');

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const session = await loadOwnedInProgressSession(connection, sessionId, req.user.id);

    const questionIds = parseJsonField(session.question_ids);
    const expectedQuestionId = questionIds[session.current_index];
    if (questionId !== expectedQuestionId) {
      throw new ApiError(409, 'This is not the current question for this session');
    }

    if (!session.question_start_pinged) {
      await connection.query(
        'UPDATE game_sessions SET question_started_at = NOW(), question_start_pinged = 1 WHERE id = ?',
        [sessionId]
      );
    }

    await connection.commit();
    res.json({ ok: true });
  } catch (err) {
    await connection.rollback();
    throw err;
  } finally {
    connection.release();
  }
}

async function submitAnswer(req, res) {
  const sessionId = Number(req.params.id);
  const questionId = Number(req.body && req.body.question_id);
  const selectedIndex = Number(req.body && req.body.selected_index);
  const clientResponseTimeMs = Number(req.body && req.body.response_time_ms) || 0;

  if (!questionId) throw new ApiError(400, 'question_id is required');
  if (!Number.isInteger(selectedIndex) || selectedIndex < -1) {
    throw new ApiError(400, 'selected_index must be -1 (timeout) or a non-negative index');
  }

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const session = await loadOwnedInProgressSession(connection, sessionId, req.user.id);

    const questionIds = parseJsonField(session.question_ids);
    if (!questionIds.includes(questionId)) {
      throw new ApiError(400, 'This question does not belong to this session');
    }

    const [existingAnswer] = await connection.query(
      'SELECT id FROM answers WHERE session_id = ? AND question_id = ?',
      [sessionId, questionId]
    );
    if (existingAnswer.length > 0) throw new ApiError(409, 'This question was already answered');

    const expectedQuestionId = questionIds[session.current_index];
    if (questionId !== expectedQuestionId) {
      throw new ApiError(409, 'Rush questions must be answered in order');
    }

    const [questionRows] = await connection.query('SELECT * FROM questions WHERE id = ?', [questionId]);
    const question = questionRows[0];
    if (!question) throw new ApiError(404, 'Question not found');

    const options = parseJsonField(question.options);
    if (selectedIndex !== -1 && selectedIndex >= options.length) {
      throw new ApiError(400, 'selected_index out of range');
    }

    // Server-authoritative elapsed time: from when this question's clock started
    // (either the /start ping or the fallback set when it became current) to now.
    // The client-reported response_time_ms is stored for analytics only, never trusted here.
    const startedAtMs = session.question_started_at ? new Date(session.question_started_at).getTime() : Date.now();
    const serverElapsedMs = Math.max(0, Date.now() - startedAtMs);

    const { isCorrect, timedOut } = evaluateTiming({
      selectedIndex,
      correctIndex: question.correct_index,
      elapsedMs: serverElapsedMs,
      timerSeconds: question.timer_seconds,
    });

    const streakAfter = isCorrect ? session.streak + 1 : 0;
    const { baseScore, speedMultiplier, streakMultiplier, score: answerScore } = scoreAnswer({
      difficulty: question.difficulty,
      isCorrect,
      elapsedMs: serverElapsedMs,
      timerSeconds: question.timer_seconds,
      streakAfter,
    });

    try {
      await connection.query(
        `INSERT INTO answers
          (session_id, question_id, selected_index, is_correct, response_time_ms, server_elapsed_ms, timed_out,
           difficulty, base_score, speed_multiplier, streak_multiplier, streak_after, score)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          sessionId, questionId, selectedIndex, isCorrect, clientResponseTimeMs, serverElapsedMs, timedOut,
          question.difficulty, baseScore, speedMultiplier, streakMultiplier, streakAfter, answerScore,
        ]
      );
    } catch (err) {
      if (err.code === 'ER_DUP_ENTRY') {
        throw new ApiError(409, 'This question was already answered');
      }
      throw err;
    }

    const newScore = session.score + answerScore;
    const newBestStreak = Math.max(session.best_streak, streakAfter);
    const newCorrectCount = session.correct_count + (isCorrect ? 1 : 0);
    const newWrongCount = session.wrong_count + (isCorrect ? 0 : 1);
    const nextIndex = session.current_index + 1;
    const rushComplete = nextIndex >= questionIds.length;

    await connection.query(
      `UPDATE game_sessions SET
        score = ?, streak = ?, best_streak = ?, correct_count = ?, wrong_count = ?,
        current_index = ?, question_started_at = ?, question_start_pinged = 0
       WHERE id = ?`,
      [
        newScore, streakAfter, newBestStreak, newCorrectCount, newWrongCount,
        nextIndex, rushComplete ? null : new Date(), sessionId,
      ]
    );

    await connection.commit();

    res.json({
      is_correct: isCorrect,
      timed_out: timedOut,
      correct_index: question.correct_index,
      difficulty: question.difficulty,
      base_score: baseScore,
      speed_multiplier: speedMultiplier,
      streak_multiplier: streakMultiplier,
      answer_score: answerScore,
      xp_gained: answerScore,
      score: newScore,
      streak: streakAfter,
      best_streak: newBestStreak,
      server_elapsed_ms: serverElapsedMs,
      questions_remaining: Math.max(0, questionIds.length - nextIndex),
      rush_complete: rushComplete,
    });
  } catch (err) {
    await connection.rollback();
    throw err;
  } finally {
    connection.release();
  }
}

async function finish(req, res) {
  const sessionId = Number(req.params.id);

  const [result] = await pool.query(
    `UPDATE game_sessions SET status='completed', ended_at=NOW()
     WHERE id=? AND player_id=? AND status='in_progress'`,
    [sessionId, req.user.id]
  );

  const [rows] = await pool.query('SELECT * FROM game_sessions WHERE id = ? AND player_id = ?', [
    sessionId,
    req.user.id,
  ]);
  const session = rows[0];
  if (!session) throw new ApiError(404, 'Session not found');

  if (result.affectedRows === 0 && session.status !== 'completed') {
    throw new ApiError(409, 'Could not finish session');
  }

  const [answerRows] = await pool.query('SELECT server_elapsed_ms FROM answers WHERE session_id = ?', [sessionId]);
  const avgResponseTimeMs = answerRows.length
    ? Math.round(answerRows.reduce((sum, a) => sum + a.server_elapsed_ms, 0) / answerRows.length)
    : 0;

  const [[priorBestRow]] = await pool.query(
    `SELECT MAX(score) AS best_score, MAX(best_streak) AS best_streak FROM game_sessions
     WHERE player_id = ? AND category_id = ? AND status = 'completed' AND id != ?`,
    [req.user.id, session.category_id, sessionId]
  );
  const personalBestScore = priorBestRow.best_score;
  const isNewPersonalBest = personalBestScore === null || session.score > personalBestScore;
  const personalBestStreak = priorBestRow.best_streak;
  const isNewBestStreak = personalBestStreak === null || session.best_streak > personalBestStreak;

  const total = session.correct_count + session.wrong_count;
  const questionIds = parseJsonField(session.question_ids);
  const durationMs = session.ended_at
    ? new Date(session.ended_at).getTime() - new Date(session.started_at).getTime()
    : 0;

  res.json({
    session_id: session.id,
    score: session.score,
    questions_total: questionIds.length,
    questions_answered: total,
    correct_count: session.correct_count,
    wrong_count: session.wrong_count,
    best_streak: session.best_streak,
    accuracy_pct: total > 0 ? Math.round((session.correct_count / total) * 100) : 0,
    avg_response_time_ms: avgResponseTimeMs,
    duration_ms: durationMs,
    personal_best_score: personalBestScore,
    is_new_personal_best: isNewPersonalBest,
    personal_best_streak: personalBestStreak,
    is_new_best_streak: isNewBestStreak,
    is_perfect_rush: total > 0 && session.wrong_count === 0,
  });
}

module.exports = { create, startQuestion, submitAnswer, finish };
