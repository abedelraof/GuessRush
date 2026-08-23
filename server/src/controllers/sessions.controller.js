const pool = require('../config/db');
const ApiError = require('../utils/ApiError');
const questionSelectionService = require('../services/questionSelection.service');
const { evaluateTiming } = require('../services/rushTiming.service');
const { scoreAnswer } = require('../services/scoring.service');
const { applyRushProgression } = require('../services/playerProgression.service');
const { levelForXp } = require('../services/progression.service');
const { ACHIEVEMENTS } = require('../config/progression.config');
const { REMOVE_ONE_USES_PER_RUSH, DOUBLE_DOWN_STREAK_THRESHOLD } = require('../config/mechanics.config');
const missionsService = require('../services/missions.service');
const dailyStreakService = require('../services/dailyStreak.service');
const eventsService = require('../services/events.service');

function describeAchievements(keys) {
  return keys
    .map((key) => ACHIEVEMENTS.find((a) => a.key === key))
    .filter(Boolean)
    .map((a) => ({ key: a.key, name: a.name, description: a.description }));
}

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

/**
 * Inserts a new game_sessions row for an already-selected, already-ordered
 * question list. Shared by a normal Rush (create, below) and Daily Rush
 * (daily-rush.controller.js) — the only difference between them is how the
 * question list was chosen; everything from here on is the same gameplay.
 */
async function insertSession(connectionOrPool, { playerId, categoryId, questionRows }) {
  const questionIds = questionRows.map((q) => q.id);
  const [result] = await connectionOrPool.query(
    `INSERT INTO game_sessions
      (player_id, category_id, question_ids, current_index, question_started_at, question_start_pinged)
     VALUES (?, ?, ?, 0, NOW(), 0)`,
    [playerId, categoryId, JSON.stringify(questionIds)]
  );
  return result.insertId;
}

/** Re-fetches specific questions and returns them in the same order as `questionIds` (SQL's `IN` doesn't preserve order). */
async function loadQuestionsInOrder(connectionOrPool, questionIds) {
  if (questionIds.length === 0) return [];
  const [rows] = await connectionOrPool.query('SELECT * FROM questions WHERE id IN (?)', [questionIds]);
  const byId = new Map(rows.map((r) => [r.id, r]));
  return questionIds.map((id) => byId.get(id)).filter(Boolean);
}

async function create(req, res) {
  const categoryId = Number(req.body && req.body.category_id);
  if (!categoryId) throw new ApiError(400, 'category_id is required');

  const questionRows = await questionSelectionService.selectRushQuestions(categoryId);
  if (questionRows.length === 0) {
    throw new ApiError(400, 'This category has no questions yet');
  }

  const sessionId = await insertSession(pool, { playerId: req.user.id, categoryId, questionRows });

  res.status(201).json({
    session_id: sessionId,
    questions: questionRows.map(serializeQuestion),
    remove_one_uses_remaining: REMOVE_ONE_USES_PER_RUSH,
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

/**
 * Reveals the next clue of the current (progressive) question. Persisted
 * server-side (game_sessions.current_clue_count) so the client can't reveal
 * clues locally without the reduced score that comes with them — submitAnswer
 * reads this same column, never anything the client claims at answer time.
 */
async function revealClue(req, res) {
  const sessionId = Number(req.params.id);

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const session = await loadOwnedInProgressSession(connection, sessionId, req.user.id);

    const questionIds = parseJsonField(session.question_ids);
    const currentQuestionId = questionIds[session.current_index];
    const [[question]] = await connection.query('SELECT * FROM questions WHERE id = ?', [currentQuestionId]);
    if (!question) throw new ApiError(404, 'Question not found');
    if (question.type !== 'progressive') throw new ApiError(400, 'This question does not support clues');

    const [[existingAnswer]] = await connection.query(
      'SELECT id FROM answers WHERE session_id = ? AND question_id = ?',
      [sessionId, currentQuestionId]
    );
    if (existingAnswer) throw new ApiError(409, 'This question was already answered');

    const clues = question.clues ? parseJsonField(question.clues) : [];
    if (session.current_clue_count >= clues.length) {
      throw new ApiError(400, 'No more clues to reveal');
    }

    const newCount = session.current_clue_count + 1;
    await connection.query('UPDATE game_sessions SET current_clue_count = ? WHERE id = ?', [newCount, sessionId]);
    await connection.commit();

    res.json({ clues_revealed: newCount, clue_text: clues[newCount - 1], clues_total: clues.length });
  } catch (err) {
    await connection.rollback();
    throw err;
  } finally {
    connection.release();
  }
}

/**
 * Spends one Remove One use (if any remain) to eliminate a random incorrect
 * option from the current question. Idempotent per question: calling this
 * again before answering just re-returns the same removed index rather than
 * spending a second use or re-rolling — see the early-return below.
 */
async function useRemoveOne(req, res) {
  const sessionId = Number(req.params.id);

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const session = await loadOwnedInProgressSession(connection, sessionId, req.user.id);

    if (session.remove_one_used_at_index === session.current_index && session.removed_option_index !== null) {
      await connection.commit();
      return res.json({
        removed_option_index: session.removed_option_index,
        uses_remaining: session.remove_one_uses_remaining,
      });
    }

    if (session.remove_one_uses_remaining <= 0) {
      throw new ApiError(409, 'No Remove One uses remaining');
    }

    const questionIds = parseJsonField(session.question_ids);
    const currentQuestionId = questionIds[session.current_index];
    const [[existingAnswer]] = await connection.query(
      'SELECT id FROM answers WHERE session_id = ? AND question_id = ?',
      [sessionId, currentQuestionId]
    );
    if (existingAnswer) throw new ApiError(409, 'This question was already answered');

    const [[question]] = await connection.query('SELECT * FROM questions WHERE id = ?', [currentQuestionId]);
    if (!question) throw new ApiError(404, 'Question not found');
    const options = parseJsonField(question.options);
    const wrongIndices = options.map((_, i) => i).filter((i) => i !== question.correct_index);
    const removedIndex = wrongIndices[Math.floor(Math.random() * wrongIndices.length)];

    const newUses = session.remove_one_uses_remaining - 1;
    await connection.query(
      `UPDATE game_sessions SET remove_one_uses_remaining = ?, remove_one_used_at_index = ?, removed_option_index = ?
       WHERE id = ?`,
      [newUses, session.current_index, removedIndex, sessionId]
    );

    await connection.commit();
    res.json({ removed_option_index: removedIndex, uses_remaining: newUses });
  } catch (err) {
    await connection.rollback();
    throw err;
  } finally {
    connection.release();
  }
}

/**
 * Records the player's Safe/Risky choice for a Double Down offer that's
 * currently active for the current question (see submitAnswer, which is what
 * actually creates an offer once per Rush). Rejected if there's no matching
 * offer — a client can't invent one for an arbitrary question.
 */
async function chooseDoubleDown(req, res) {
  const sessionId = Number(req.params.id);
  const choice = req.body && req.body.choice;
  if (choice !== 'safe' && choice !== 'risky') {
    throw new ApiError(400, "choice must be 'safe' or 'risky'");
  }

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const session = await loadOwnedInProgressSession(connection, sessionId, req.user.id);

    if (session.double_down_offered_at_index !== session.current_index) {
      throw new ApiError(409, 'Double Down is not currently offered for this question');
    }

    const questionIds = parseJsonField(session.question_ids);
    const currentQuestionId = questionIds[session.current_index];
    const [[existingAnswer]] = await connection.query(
      'SELECT id FROM answers WHERE session_id = ? AND question_id = ?',
      [sessionId, currentQuestionId]
    );
    if (existingAnswer) throw new ApiError(409, 'This question was already answered');

    await connection.query(
      'UPDATE game_sessions SET double_down_choice_index = ?, double_down_choice = ? WHERE id = ?',
      [session.current_index, choice, sessionId]
    );
    await connection.commit();
    res.json({ choice });
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

    // Strategic mechanics (Phase 5): all three are read from server-persisted session
    // state, never from anything in this request body — that's what makes them
    // server-authoritative. cluesRevealed defaults to 1 (the free first clue) for
    // every question, progressive or not; it only ever moves for progressive
    // questions, via /reveal-clue.
    const cluesRevealed = session.current_clue_count;
    const removeOneUsed = session.remove_one_used_at_index === session.current_index;
    const doubleDownChoice =
      session.double_down_choice_index === session.current_index ? session.double_down_choice : null;

    const {
      baseScore, speedMultiplier, streakMultiplier, clueMultiplier, doubleDownMultiplier, score: answerScore,
    } = scoreAnswer({
      difficulty: question.difficulty,
      isCorrect,
      elapsedMs: serverElapsedMs,
      timerSeconds: question.timer_seconds,
      streakAfter,
      cluesRevealed,
      doubleDownChoice,
    });

    try {
      await connection.query(
        `INSERT INTO answers
          (session_id, question_id, selected_index, is_correct, response_time_ms, server_elapsed_ms, timed_out,
           difficulty, base_score, speed_multiplier, streak_multiplier, streak_after, score,
           clues_revealed, clue_multiplier, remove_one_used, double_down_choice, double_down_multiplier)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          sessionId, questionId, selectedIndex, isCorrect, clientResponseTimeMs, serverElapsedMs, timedOut,
          question.difficulty, baseScore, speedMultiplier, streakMultiplier, streakAfter, answerScore,
          cluesRevealed, clueMultiplier, removeOneUsed, doubleDownChoice || 'none', doubleDownMultiplier,
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

    // Double Down: offered once per Rush, the moment streak first reaches the threshold,
    // for the very next question — never re-offered afterward whether accepted, declined,
    // or ignored. session.double_down_offered_at_index is only ever written once (here).
    let newDoubleDownOfferedAtIndex = session.double_down_offered_at_index;
    let doubleDownOffer = null;
    if (newDoubleDownOfferedAtIndex === null && streakAfter >= DOUBLE_DOWN_STREAK_THRESHOLD && !rushComplete) {
      newDoubleDownOfferedAtIndex = nextIndex;
      doubleDownOffer = { question_id: questionIds[nextIndex] };
    }

    await connection.query(
      `UPDATE game_sessions SET
        score = ?, streak = ?, best_streak = ?, correct_count = ?, wrong_count = ?,
        current_index = ?, question_started_at = ?, question_start_pinged = 0, current_clue_count = 1,
        double_down_offered_at_index = ?
       WHERE id = ?`,
      [
        newScore, streakAfter, newBestStreak, newCorrectCount, newWrongCount,
        nextIndex, rushComplete ? null : new Date(), newDoubleDownOfferedAtIndex, sessionId,
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
      clues_revealed: cluesRevealed,
      clue_multiplier: clueMultiplier,
      remove_one_used: removeOneUsed,
      remove_one_uses_remaining: session.remove_one_uses_remaining,
      double_down_choice: doubleDownChoice || 'none',
      double_down_multiplier: doubleDownMultiplier,
      double_down_offer: doubleDownOffer,
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

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const [sessionRows] = await connection.query('SELECT * FROM game_sessions WHERE id = ? FOR UPDATE', [sessionId]);
    const session = sessionRows[0];
    if (!session) throw new ApiError(404, 'Session not found');
    if (session.player_id !== req.user.id) throw new ApiError(403, 'Not your session');
    if (session.status !== 'in_progress' && session.status !== 'completed') {
      throw new ApiError(409, 'Could not finish session');
    }

    const total = session.correct_count + session.wrong_count;
    const isPerfectRush = total > 0 && session.wrong_count === 0;

    const [answerRows] = await connection.query('SELECT server_elapsed_ms FROM answers WHERE session_id = ?', [sessionId]);
    const sumResponseTimeMs = answerRows.reduce((sum, a) => sum + a.server_elapsed_ms, 0);
    const avgResponseTimeMs = answerRows.length ? Math.round(sumResponseTimeMs / answerRows.length) : 0;

    // Whether this session is the official Daily Rush attempt — read here (inside
    // the transaction) because missions/streak both need it before commit; the
    // richer rank/best-score version (buildDailyInfo) still runs after commit,
    // unchanged, since ranking against other completed players is display-only.
    const [[dailyLink]] = await connection.query('SELECT daily_date FROM daily_rush_attempts WHERE session_id = ?', [
      sessionId,
    ]);

    // Progression (XP/level/records/achievements), mission progress, and the daily
    // streak are all applied exactly once, only on the in_progress -> completed
    // transition. A repeat call to /finish (retry, double-tap, refetching the
    // summary) must NEVER re-award any of them — it just replays what was already
    // granted, read back from the player's current persisted record.
    const justCompleted = session.status === 'in_progress';
    let progression;
    let newlyCompletedMissions = [];
    let xpMultiplierApplied = 1;

    if (justCompleted) {
      // Lock the player's own row FIRST, before touching player_mission_progress.
      // That table's rows don't exist until a mission first progresses, so two
      // concurrent /finish calls for the same player (different sessions) would
      // otherwise both race an INSERT IGNORE against a row that isn't there yet —
      // under InnoDB gap-locking that's a deadlock, not a clean duplicate-key
      // error, exactly like the daily_rush_attempts race fixed in Phase 4. The
      // player row always exists, so locking it here genuinely serializes the
      // two transactions before either reaches missions.service. applyRushProgression's
      // own FOR UPDATE below just re-acquires the same already-held lock.
      await connection.query('SELECT id FROM players WHERE id = ? FOR UPDATE', [req.user.id]);

      // Missions first: they only read this Rush's own session/answers data, so
      // there's no ordering dependency on the players write below — but folding
      // their reward into that SAME write (via bonusXp) means one combined
      // players UPDATE instead of two, and keeps xp_awarded/session accounting
      // (below) a single source of truth for "what this Rush granted".
      const rushStats = await missionsService.buildRushStatsForMissions(connection, {
        sessionId,
        questionsAnswered: total,
        bestStreak: session.best_streak,
        isDailyRush: Boolean(dailyLink),
      });
      const missionResult = await missionsService.evaluateMissionProgress(connection, req.user.id, rushStats);
      newlyCompletedMissions = missionResult.completedMissions;
      xpMultiplierApplied = eventsService.xpMultiplierAt(new Date());

      await connection.query(`UPDATE game_sessions SET status = 'completed', ended_at = NOW() WHERE id = ?`, [sessionId]);

      const applied = await applyRushProgression(connection, {
        playerId: req.user.id,
        rushScore: session.score,
        correctCount: session.correct_count,
        bestStreak: session.best_streak,
        isPerfectRush,
        sumResponseTimeMs,
        questionsAnswered: total,
        accuracyPct: total > 0 ? Math.round((session.correct_count / total) * 100) : 0,
        bonusXp: missionResult.rewardXpTotal,
        xpMultiplier: xpMultiplierApplied,
      });

      await connection.query('UPDATE game_sessions SET xp_awarded = ?, progression_applied = 1 WHERE id = ?', [
        applied.xpAwarded,
        sessionId,
      ]);

      // The daily streak is keyed to completing the official Daily Rush specifically
      // (the app's existing "one required daily activity" concept — see Phase 4's
      // one-attempt-per-day rule) rather than any Rush, so it stays a distinct
      // concept from both the in-game answer streak and from "played today".
      if (dailyLink) {
        await dailyStreakService.applyDailyStreak(connection, req.user.id);
      }

      progression = applied;
    } else {
      const [[player]] = await connection.query('SELECT * FROM players WHERE id = ?', [req.user.id]);
      const levelInfo = levelForXp(player.lifetime_xp);
      progression = {
        xpAwarded: session.xp_awarded,
        lifetimeXp: player.lifetime_xp,
        level: levelInfo.level,
        leveledUp: false,
        xpIntoLevel: levelInfo.xpIntoLevel,
        xpForNextLevel: levelInfo.xpForNextLevel,
        isNewBestScore: false,
        isNewBestStreak: false,
        newlyUnlockedAchievements: [],
      };
    }

    const [[streakRow]] = await connection.query(
      'SELECT daily_streak_current, daily_streak_longest FROM players WHERE id = ?',
      [req.user.id]
    );

    await connection.commit();

    // Daily Rush enrichment: this session is a Daily Rush attempt iff it's linked from
    // daily_rush_attempts. No column on game_sessions needed — the link table is the
    // single source of truth for "was this the official Daily Rush". Read-only and only
    // meaningful once the completion above is actually committed, so it runs after —
    // never mix a second pool connection into the still-open transaction above.
    const dailyInfo = await buildDailyInfo(sessionId, req.user.id, session.score);

    const questionIds = parseJsonField(session.question_ids);
    const endedAt = justCompleted ? new Date() : session.ended_at;
    const durationMs = endedAt ? new Date(endedAt).getTime() - new Date(session.started_at).getTime() : 0;

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
      is_perfect_rush: isPerfectRush,
      // Lifetime progression — server-authoritative, applied once (see above).
      xp_awarded: progression.xpAwarded,
      lifetime_xp: progression.lifetimeXp,
      level: progression.level,
      leveled_up: progression.leveledUp,
      xp_into_level: progression.xpIntoLevel,
      xp_for_next_level: progression.xpForNextLevel,
      is_new_personal_best: progression.isNewBestScore,
      is_new_best_streak: progression.isNewBestStreak,
      newly_unlocked_achievements: describeAchievements(progression.newlyUnlockedAchievements),
      // Retention systems (Phase 6) — mission rewards/XP multiplier are already
      // folded into xp_awarded above; these are just the "what happened" detail.
      newly_completed_missions: newlyCompletedMissions,
      xp_multiplier_applied: xpMultiplierApplied,
      daily_streak_current: streakRow.daily_streak_current,
      daily_streak_longest: streakRow.daily_streak_longest,
      ...(dailyInfo || { is_daily_rush: false }),
    });
  } catch (err) {
    await connection.rollback();
    // The player-row lock above (justCompleted branch) closes the common concurrent-
    // completion deadlock, but a /finish racing an in-flight /daily-rush/start for the
    // same player (opposite lock ordering: that endpoint locks the player row before
    // touching any session) can still deadlock the two transactions — same narrow,
    // transient window documented in daily-rush.controller.js's /start. Retryable, not a real error.
    if (err.code === 'ER_LOCK_DEADLOCK') {
      throw new ApiError(409, 'Please try again.');
    }
    throw err;
  } finally {
    connection.release();
  }
}

async function buildDailyInfo(sessionId, playerId, score) {
  const [[dailyLink]] = await pool.query('SELECT daily_date FROM daily_rush_attempts WHERE session_id = ?', [
    sessionId,
  ]);
  if (!dailyLink) return null;

  // Same tie-break as the leaderboard itself (score desc, earliest-achieved wins ties):
  // anyone with a strictly higher score outranks us, and on an exact tie, anyone who
  // finished before we did (per this session's own now-committed ended_at) does too.
  // (This session naturally excludes itself: neither clause is true when compared to itself.)
  const [[rankRow]] = await pool.query(
    `SELECT COUNT(*) + 1 AS \`rank\`
     FROM daily_rush_attempts dra JOIN game_sessions gs ON gs.id = dra.session_id
     WHERE dra.daily_date = ? AND gs.status = 'completed'
       AND (gs.score > ? OR (gs.score = ? AND gs.ended_at < (SELECT ended_at FROM game_sessions WHERE id = ?)))`,
    [dailyLink.daily_date, score, score, sessionId]
  );
  const [[prevBestRow]] = await pool.query(
    `SELECT MAX(gs.score) AS best FROM daily_rush_attempts dra
     JOIN game_sessions gs ON gs.id = dra.session_id
     WHERE dra.player_id = ? AND dra.daily_date < ? AND gs.status = 'completed'`,
    [playerId, dailyLink.daily_date]
  );
  const previousBest = prevBestRow.best;

  return {
    is_daily_rush: true,
    daily_date: dailyLink.daily_date,
    daily_rank: rankRow.rank,
    daily_previous_best_score: previousBest,
    is_new_daily_best: previousBest === null || score > previousBest,
  };
}

module.exports = {
  create,
  startQuestion,
  submitAnswer,
  finish,
  revealClue,
  useRemoveOne,
  chooseDoubleDown,
  // Shared with daily-rush.controller.js — see insertSession's comment.
  serializeQuestion,
  parseJsonField,
  insertSession,
  loadQuestionsInOrder,
};
