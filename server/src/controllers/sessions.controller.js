const pool = require('../config/db');
const ApiError = require('../utils/ApiError');

const XP_PER_CORRECT = 250;

// mysql2 auto-parses JSON columns in some configurations but not others
// depending on column metadata — handle both a string and an already-parsed value.
function parseJsonField(value) {
  return typeof value === 'string' ? JSON.parse(value) : value;
}

function serializeQuestion(row) {
  return {
    id: row.id,
    type: row.type,
    label: row.label,
    prompt: row.prompt,
    media_placeholder: row.media_placeholder,
    media_duration: row.media_duration,
    emojis: row.emojis,
    options: parseJsonField(row.options),
    clues: row.clues ? parseJsonField(row.clues) : null,
    timer_seconds: row.timer_seconds,
    // correct_index intentionally omitted — never sent to the client.
  };
}

async function create(req, res) {
  const categoryId = Number(req.body && req.body.category_id);
  if (!categoryId) throw new ApiError(400, 'category_id is required');

  const [questionRows] = await pool.query(
    'SELECT * FROM questions WHERE category_id = ? ORDER BY id',
    [categoryId]
  );
  if (questionRows.length === 0) {
    throw new ApiError(400, 'This category has no questions yet');
  }

  const questionIds = questionRows.map((q) => q.id);
  const [result] = await pool.query(
    `INSERT INTO game_sessions (player_id, category_id, question_ids) VALUES (?, ?, ?)`,
    [req.user.id, categoryId, JSON.stringify(questionIds)]
  );

  res.status(201).json({
    session_id: result.insertId,
    questions: questionRows.map(serializeQuestion),
  });
}

async function submitAnswer(req, res) {
  const sessionId = Number(req.params.id);
  const questionId = Number(req.body && req.body.question_id);
  const selectedIndex = Number(req.body && req.body.selected_index);
  const responseTimeMs = Number(req.body && req.body.response_time_ms) || 0;

  if (!questionId) throw new ApiError(400, 'question_id is required');
  if (!Number.isInteger(selectedIndex) || selectedIndex < -1) {
    throw new ApiError(400, 'selected_index must be -1 (timeout) or a non-negative index');
  }

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const [sessionRows] = await connection.query(
      'SELECT * FROM game_sessions WHERE id = ? FOR UPDATE',
      [sessionId]
    );
    const session = sessionRows[0];
    if (!session) throw new ApiError(404, 'Session not found');
    if (session.player_id !== req.user.id) throw new ApiError(403, 'Not your session');
    if (session.status !== 'in_progress') throw new ApiError(409, 'Session already finished');

    const questionIds = parseJsonField(session.question_ids);
    if (!questionIds.includes(questionId)) {
      throw new ApiError(400, 'This question does not belong to this session');
    }

    const [questionRows] = await connection.query('SELECT * FROM questions WHERE id = ?', [questionId]);
    const question = questionRows[0];
    if (!question) throw new ApiError(404, 'Question not found');

    const options = parseJsonField(question.options);
    if (selectedIndex !== -1 && selectedIndex >= options.length) {
      throw new ApiError(400, 'selected_index out of range');
    }

    const isCorrect = selectedIndex === question.correct_index;

    try {
      await connection.query(
        `INSERT INTO answers (session_id, question_id, selected_index, is_correct, response_time_ms)
         VALUES (?, ?, ?, ?, ?)`,
        [sessionId, questionId, selectedIndex, isCorrect, responseTimeMs]
      );
    } catch (err) {
      if (err.code === 'ER_DUP_ENTRY') {
        throw new ApiError(409, 'This question was already answered');
      }
      throw err;
    }

    let { score, streak, best_streak: bestStreak, correct_count: correctCount, wrong_count: wrongCount } = session;
    let xpGained = 0;
    if (isCorrect) {
      xpGained = XP_PER_CORRECT;
      score += xpGained;
      streak += 1;
      bestStreak = Math.max(bestStreak, streak);
      correctCount += 1;
    } else {
      streak = 0;
      wrongCount += 1;
    }

    await connection.query(
      `UPDATE game_sessions SET score=?, streak=?, best_streak=?, correct_count=?, wrong_count=? WHERE id=?`,
      [score, streak, bestStreak, correctCount, wrongCount, sessionId]
    );

    await connection.commit();

    res.json({
      is_correct: isCorrect,
      correct_index: question.correct_index,
      score,
      streak,
      best_streak: bestStreak,
      xp_gained: xpGained,
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

  const total = session.correct_count + session.wrong_count;
  res.json({
    session_id: session.id,
    score: session.score,
    correct_count: session.correct_count,
    wrong_count: session.wrong_count,
    best_streak: session.best_streak,
    accuracy_pct: total > 0 ? Math.round((session.correct_count / total) * 100) : 0,
  });
}

module.exports = { create, submitAnswer, finish };
