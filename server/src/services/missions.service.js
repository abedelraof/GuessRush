const { MISSIONS, FAST_ANSWER_MS_THRESHOLD } = require('../config/missions.config');
const { todayDateString } = require('./dailyRush.service');

/**
 * The period key a mission's progress is scoped to — missions with the same
 * key+period share one row, and a new period starts a fresh one automatically
 * (nothing to "reset": a never-seen period_key just has no row yet). Only
 * 'daily' is used by the current MISSIONS config, but the switch is here so a
 * future 'weekly' mission is a config addition, not a rewrite.
 */
function periodKeyFor(resetPeriod, now = new Date()) {
  if (resetPeriod === 'daily') return todayDateString(now);
  throw new Error(`missions.service: unknown resetPeriod "${resetPeriod}"`);
}

/**
 * Gathers everything MISSIONS' progressFor() functions need from one
 * just-completed Rush. Must run inside the same transaction/connection as the
 * rest of sessions.controller's /finish, before that Rush's own answers are
 * touched by anything else, so the counts reflect exactly this Rush.
 */
async function buildRushStatsForMissions(connection, { sessionId, questionsAnswered, bestStreak, isDailyRush }) {
  const [[fastRow]] = await connection.query(
    'SELECT COUNT(*) AS n FROM answers WHERE session_id = ? AND is_correct = 1 AND server_elapsed_ms < ?',
    [sessionId, FAST_ANSWER_MS_THRESHOLD]
  );
  return { questionsAnswered, bestStreak, isDailyRush, fastCorrectAnswers: fastRow.n };
}

/**
 * Applies one completed Rush's contribution to every mission's progress for
 * its current period, in a fixed order (MISSIONS' own array order) so
 * concurrent /finish calls from the same player always lock rows in the same
 * sequence — the same deadlock-avoidance principle as the player-row lock in
 * daily-rush.controller.js's /start. A mission already completed this period
 * is left alone (extra progress doesn't re-trigger or overflow past target).
 * Must run inside the same transaction as the Rush's completion write.
 */
async function evaluateMissionProgress(connection, playerId, rushStats, now = new Date()) {
  const completed = [];

  for (const mission of MISSIONS) {
    const delta = mission.progressFor(rushStats);
    if (!delta) continue; // this Rush didn't move this mission — no row churn for a no-op

    const periodKey = periodKeyFor(mission.resetPeriod, now);

    await connection.query(
      'INSERT IGNORE INTO player_mission_progress (player_id, mission_key, period_key, progress) VALUES (?, ?, ?, 0)',
      [playerId, mission.key, periodKey]
    );
    const [[row]] = await connection.query(
      'SELECT id, progress, completed_at FROM player_mission_progress WHERE player_id = ? AND mission_key = ? AND period_key = ? FOR UPDATE',
      [playerId, mission.key, periodKey]
    );
    if (row.completed_at) continue; // already done this period

    const newProgress = Math.min(mission.target, row.progress + delta);
    const justCompleted = newProgress >= mission.target;

    await connection.query('UPDATE player_mission_progress SET progress = ?, completed_at = ? WHERE id = ?', [
      newProgress,
      justCompleted ? now : null,
      row.id,
    ]);

    if (justCompleted) completed.push(mission);
  }

  const rewardXpTotal = completed.reduce((sum, m) => sum + m.rewardXp, 0);
  return {
    rewardXpTotal,
    completedMissions: completed.map((m) => ({ key: m.key, name: m.name, reward_xp: m.rewardXp })),
  };
}

/**
 * Read-only view of every mission's current-period progress for the Home
 * screen — never creates or mutates a player_mission_progress row (a GET must
 * stay side-effect-free), so a mission not yet touched this period is simply
 * reported at 0/target from the config alone.
 */
async function getMissionsStatus(playerId, now = new Date()) {
  const pool = require('../config/db');
  const periodKeys = [...new Set(MISSIONS.map((m) => periodKeyFor(m.resetPeriod, now)))];
  const [rows] = await pool.query(
    'SELECT mission_key, period_key, progress, completed_at FROM player_mission_progress WHERE player_id = ? AND period_key IN (?)',
    [playerId, periodKeys]
  );
  const byKey = new Map(rows.map((r) => [`${r.mission_key}:${r.period_key}`, r]));

  return MISSIONS.map((mission) => {
    const periodKey = periodKeyFor(mission.resetPeriod, now);
    const row = byKey.get(`${mission.key}:${periodKey}`);
    return {
      key: mission.key,
      name: mission.name,
      description: mission.description,
      reset_period: mission.resetPeriod,
      target: mission.target,
      reward_xp: mission.rewardXp,
      progress: row ? row.progress : 0,
      completed: Boolean(row && row.completed_at),
    };
  });
}

module.exports = { periodKeyFor, buildRushStatsForMissions, evaluateMissionProgress, getMissionsStatus };
