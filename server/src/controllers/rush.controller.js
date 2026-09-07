const pool = require('../config/db');
const ApiError = require('../utils/ApiError');
const questionSelectionService = require('../services/questionSelection.service');
const { serializeQuestion, insertSession } = require('./sessions.controller');
const { REMOVE_ONE_USES_PER_RUSH } = require('../config/mechanics.config');

// Pick Your Rush's four game modes (see the "Pick Your Rush" screen on the client) — the
// player picks one of these instead of a category; question selection stays cross-category
// internally (questionSelection.service.js's selectVariedRushQuestions).
const VALID_MODES = ['quick_rush', 'chaos_rush', 'streak_rush', 'chill_rush'];

/**
 * Starts a Pick Your Rush session for one of VALID_MODES. Mirrors sessions.controller.js's
 * create() (the legacy single-category flow) and dailyRush.controller.js's start() — same
 * insertSession/serializeQuestion plumbing, the only difference is how the question list is
 * chosen and that there's no category_id to record.
 */
async function start(req, res) {
  const mode = req.body && req.body.mode;
  if (!VALID_MODES.includes(mode)) {
    throw new ApiError(400, `mode must be one of: ${VALID_MODES.join(', ')}`);
  }

  const questionRows = await questionSelectionService.selectVariedRushQuestions(mode);
  if (questionRows.length === 0) {
    throw new ApiError(400, 'No questions available yet');
  }

  const sessionId = await insertSession(pool, { playerId: req.user.id, mode, questionRows });

  // Chill Rush is "no pressure" — the client must never see a timer to count down in the
  // first place. Grading itself is separately made timer-less server-side in submitAnswer.
  const forceNoTimer = mode === 'chill_rush';
  const questions = questionRows.map((row) =>
    serializeQuestion(forceNoTimer ? { ...row, timer_seconds: 0 } : row)
  );

  res.status(201).json({
    session_id: sessionId,
    questions,
    remove_one_uses_remaining: REMOVE_ONE_USES_PER_RUSH,
  });
}

module.exports = { start };
