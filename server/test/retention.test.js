const test = require('node:test');
const assert = require('node:assert/strict');
const { isConsecutiveDay, computeStreakUpdate } = require('../src/services/dailyStreak.service');
const { activeEventsAt, xpMultiplierAt } = require('../src/services/events.service');
const { MISSIONS, FAST_ANSWER_MS_THRESHOLD } = require('../src/config/missions.config');
const { periodKeyFor, evaluateMissionProgress } = require('../src/services/missions.service');
const { applyRushProgression } = require('../src/services/playerProgression.service');

// ---- dailyStreak.service ----

test('isConsecutiveDay: exactly one calendar day apart is consecutive', () => {
  assert.equal(isConsecutiveDay('2026-08-23', '2026-08-24'), true);
});

test('isConsecutiveDay: same day is not consecutive', () => {
  assert.equal(isConsecutiveDay('2026-08-24', '2026-08-24'), false);
});

test('isConsecutiveDay: a missed day (gap of 2+) is not consecutive', () => {
  assert.equal(isConsecutiveDay('2026-08-22', '2026-08-24'), false);
});

test('isConsecutiveDay: crosses a month boundary correctly', () => {
  assert.equal(isConsecutiveDay('2026-08-31', '2026-09-01'), true);
});

test('computeStreakUpdate: first-ever completion starts the streak at 1', () => {
  const result = computeStreakUpdate({ lastDate: null, currentStreak: 0, longestStreak: 0 }, '2026-08-24');
  assert.deepEqual(result, { currentStreak: 1, longestStreak: 1, lastDate: '2026-08-24', changed: true });
});

test('computeStreakUpdate: a consecutive day extends the streak', () => {
  const result = computeStreakUpdate({ lastDate: '2026-08-23', currentStreak: 4, longestStreak: 4 }, '2026-08-24');
  assert.deepEqual(result, { currentStreak: 5, longestStreak: 5, lastDate: '2026-08-24', changed: true });
});

test('computeStreakUpdate: a missed day resets the streak to 1, not 0', () => {
  const result = computeStreakUpdate({ lastDate: '2026-08-20', currentStreak: 7, longestStreak: 7 }, '2026-08-24');
  assert.deepEqual(result, { currentStreak: 1, longestStreak: 7, lastDate: '2026-08-24', changed: true });
});

test('computeStreakUpdate: longest streak is preserved through a reset, never decreases', () => {
  const result = computeStreakUpdate({ lastDate: '2026-08-01', currentStreak: 10, longestStreak: 10 }, '2026-08-24');
  assert.equal(result.currentStreak, 1);
  assert.equal(result.longestStreak, 10);
});

test('computeStreakUpdate: a duplicate completion on the same day is a no-op (changed: false)', () => {
  const result = computeStreakUpdate({ lastDate: '2026-08-24', currentStreak: 3, longestStreak: 5 }, '2026-08-24');
  assert.deepEqual(result, { currentStreak: 3, longestStreak: 5, lastDate: '2026-08-24', changed: false });
});

test('computeStreakUpdate: a new streak can eventually exceed the previous longest', () => {
  const day1 = computeStreakUpdate({ lastDate: null, currentStreak: 0, longestStreak: 3 }, '2026-08-01');
  const day2 = computeStreakUpdate(
    { lastDate: day1.lastDate, currentStreak: day1.currentStreak, longestStreak: day1.longestStreak },
    '2026-08-02'
  );
  const day3 = computeStreakUpdate(
    { lastDate: day2.lastDate, currentStreak: day2.currentStreak, longestStreak: day2.longestStreak },
    '2026-08-03'
  );
  const day4 = computeStreakUpdate(
    { lastDate: day3.lastDate, currentStreak: day3.currentStreak, longestStreak: day3.longestStreak },
    '2026-08-04'
  );
  assert.equal(day4.currentStreak, 4);
  assert.equal(day4.longestStreak, 4); // exceeded the old longest of 3
});

// ---- events.service ----

test('activeEventsAt: an event inside its window is active', () => {
  const active = activeEventsAt(new Date('2026-08-24T12:00:00Z'));
  assert.ok(active.some((e) => e.key === 'double_xp_launch_event'));
});

test('activeEventsAt: before startsAt is not active', () => {
  const active = activeEventsAt(new Date('2020-01-01T00:00:00Z'));
  assert.equal(active.length, 0);
});

test('activeEventsAt: at/after endsAt is not active (end is exclusive)', () => {
  const active = activeEventsAt(new Date('2030-01-01T00:00:00Z'));
  assert.equal(active.length, 0);
});

test('xpMultiplierAt: 1 (neutral) when no xp_multiplier event is active', () => {
  assert.equal(xpMultiplierAt(new Date('2020-01-01T00:00:00Z')), 1);
});

test('xpMultiplierAt: matches the active Double XP event\'s configured multiplier', () => {
  assert.equal(xpMultiplierAt(new Date('2026-08-24T12:00:00Z')), 2);
});

// ---- missions.config: progressFor pure functions ----

function missionByKey(key) {
  return MISSIONS.find((m) => m.key === key);
}

test('complete_1_rush: any completed Rush contributes exactly 1, regardless of its stats', () => {
  assert.equal(missionByKey('complete_1_rush').progressFor({}), 1);
});

test('answer_20_questions: contributes exactly this Rush\'s question count', () => {
  assert.equal(missionByKey('answer_20_questions').progressFor({ questionsAnswered: 7 }), 7);
});

test('streak_5: contributes 1 only if this Rush\'s best streak reached 5, else 0', () => {
  assert.equal(missionByKey('streak_5').progressFor({ bestStreak: 5 }), 1);
  assert.equal(missionByKey('streak_5').progressFor({ bestStreak: 8 }), 1);
  assert.equal(missionByKey('streak_5').progressFor({ bestStreak: 4 }), 0);
});

test('fast_5: contributes exactly this Rush\'s count of sub-threshold correct answers', () => {
  assert.equal(missionByKey('fast_5').progressFor({ fastCorrectAnswers: 3 }), 3);
});

test('complete_daily_rush: contributes 1 only when this Rush was the official Daily Rush', () => {
  assert.equal(missionByKey('complete_daily_rush').progressFor({ isDailyRush: true }), 1);
  assert.equal(missionByKey('complete_daily_rush').progressFor({ isDailyRush: false }), 0);
});

test('FAST_ANSWER_MS_THRESHOLD is a sane positive value used consistently by missions.service', () => {
  assert.ok(FAST_ANSWER_MS_THRESHOLD > 0);
});

// ---- missions.service: periodKeyFor ----

test('periodKeyFor("daily") matches the server/UTC date string, not local time', () => {
  assert.equal(periodKeyFor('daily', new Date('2026-08-24T23:59:59Z')), '2026-08-24');
});

test('periodKeyFor throws on an unconfigured reset period rather than silently misbehaving', () => {
  assert.throws(() => periodKeyFor('monthly', new Date()));
});

// ---- missions.service: evaluateMissionProgress (fake connection, no DB) ----

/**
 * Minimal in-memory stand-in for player_mission_progress, enough to exercise
 * evaluateMissionProgress's accumulate/cap/complete-once logic without a real
 * database — same philosophy as playerProgression.test.js's fakeConnection.
 */
function fakeMissionConnection() {
  const rows = new Map(); // "playerId:missionKey:periodKey" -> { id, progress, completed_at }
  let nextId = 1;
  const key = (playerId, missionKey, periodKey) => `${playerId}:${missionKey}:${periodKey}`;
  return {
    rows,
    async query(sql, params) {
      if (sql.startsWith('INSERT IGNORE INTO player_mission_progress')) {
        const [playerId, missionKey, periodKey] = params;
        const k = key(playerId, missionKey, periodKey);
        if (!rows.has(k)) rows.set(k, { id: nextId++, progress: 0, completed_at: null });
        return [{}];
      }
      if (sql.startsWith('SELECT id, progress, completed_at FROM player_mission_progress')) {
        const [playerId, missionKey, periodKey] = params;
        return [[rows.get(key(playerId, missionKey, periodKey))]];
      }
      if (sql.startsWith('UPDATE player_mission_progress SET progress')) {
        const [progress, completedAt, id] = params;
        for (const row of rows.values()) {
          if (row.id === id) {
            row.progress = progress;
            row.completed_at = completedAt;
          }
        }
        return [{}];
      }
      throw new Error(`fakeMissionConnection: unexpected query: ${sql}`);
    },
  };
}

test('evaluateMissionProgress: progress accumulates across multiple Rushes within the same period', async () => {
  const connection = fakeMissionConnection();
  const now = new Date('2026-08-24T10:00:00Z');
  await evaluateMissionProgress(connection, 1, { questionsAnswered: 8, bestStreak: 0, fastCorrectAnswers: 0, isDailyRush: false }, now);
  const result = await evaluateMissionProgress(
    connection, 1, { questionsAnswered: 8, bestStreak: 0, fastCorrectAnswers: 0, isDailyRush: false }, now
  );
  const row = connection.rows.get('1:answer_20_questions:2026-08-24');
  assert.equal(row.progress, 16);
  assert.equal(row.completed_at, null);
  assert.deepEqual(result.completedMissions.map((m) => m.key), []); // complete_1_rush already completed on the first call
});

test('evaluateMissionProgress: reaching target completes the mission and reports its reward once', async () => {
  const connection = fakeMissionConnection();
  const now = new Date('2026-08-24T10:00:00Z');
  const result = await evaluateMissionProgress(
    connection, 1, { questionsAnswered: 20, bestStreak: 0, fastCorrectAnswers: 0, isDailyRush: false }, now
  );
  const keys = result.completedMissions.map((m) => m.key);
  assert.ok(keys.includes('answer_20_questions'));
  assert.ok(keys.includes('complete_1_rush'));
  assert.equal(result.rewardXpTotal, missionByKey('answer_20_questions').rewardXp + missionByKey('complete_1_rush').rewardXp);
});

test('evaluateMissionProgress: progress is capped at target, never overflows past it', async () => {
  const connection = fakeMissionConnection();
  const now = new Date('2026-08-24T10:00:00Z');
  await evaluateMissionProgress(connection, 1, { questionsAnswered: 25, bestStreak: 0, fastCorrectAnswers: 0, isDailyRush: false }, now);
  const row = connection.rows.get('1:answer_20_questions:2026-08-24');
  assert.equal(row.progress, 20); // not 25
});

test('evaluateMissionProgress: a mission already completed this period does not re-trigger or gain further progress', async () => {
  const connection = fakeMissionConnection();
  const now = new Date('2026-08-24T10:00:00Z');
  await evaluateMissionProgress(connection, 1, { questionsAnswered: 20, bestStreak: 0, fastCorrectAnswers: 0, isDailyRush: false }, now);
  const result = await evaluateMissionProgress(
    connection, 1, { questionsAnswered: 5, bestStreak: 0, fastCorrectAnswers: 0, isDailyRush: false }, now
  );
  const row = connection.rows.get('1:answer_20_questions:2026-08-24');
  assert.equal(row.progress, 20); // unchanged by the second Rush's 5 more questions
  assert.deepEqual(result.completedMissions, []); // duplicate progress after completion reports nothing new
});

test('evaluateMissionProgress: a Rush that contributes nothing to a mission does not touch its row at all', async () => {
  const connection = fakeMissionConnection();
  const now = new Date('2026-08-24T10:00:00Z');
  await evaluateMissionProgress(connection, 1, { questionsAnswered: 0, bestStreak: 0, fastCorrectAnswers: 0, isDailyRush: false }, now);
  assert.equal(connection.rows.has('1:streak_5:2026-08-24'), false);
});

test('evaluateMissionProgress: a new day is a fresh period — no row carries over from the previous day', async () => {
  const connection = fakeMissionConnection();
  await evaluateMissionProgress(
    connection, 1, { questionsAnswered: 20, bestStreak: 0, fastCorrectAnswers: 0, isDailyRush: false },
    new Date('2026-08-24T10:00:00Z')
  );
  const result = await evaluateMissionProgress(
    connection, 1, { questionsAnswered: 3, bestStreak: 0, fastCorrectAnswers: 0, isDailyRush: false },
    new Date('2026-08-25T10:00:00Z')
  );
  assert.ok(result.completedMissions.some((m) => m.key === 'complete_1_rush')); // completes again on the new day
  const row = connection.rows.get('1:answer_20_questions:2026-08-25');
  assert.equal(row.progress, 3); // independent of 2026-08-24's row, which stays at 20
});

// ---- playerProgression.service: bonusXp / xpMultiplier (Phase 6 additions) ----

function fakeProgressionConnection(player) {
  return {
    async query(sql, params) {
      if (sql.includes('FROM players WHERE id = ? FOR UPDATE')) return [[player]];
      if (sql.includes('SELECT EXISTS(')) return [[{ found: 0 }]];
      if (sql.startsWith('UPDATE players SET')) {
        player.level = params[0];
        player.lifetime_xp = params[1];
        return [{ affectedRows: 1 }];
      }
      if (sql.startsWith('INSERT IGNORE INTO player_achievements')) return [{ affectedRows: 0 }];
      throw new Error(`fakeProgressionConnection: unexpected query: ${sql}`);
    },
  };
}

function freshPlayer() {
  return {
    id: 1, level: 1, lifetime_xp: 0, rushes_completed: 0, questions_answered: 0, questions_correct: 0,
    total_response_time_ms: 0, best_rush_score: 0, best_streak: 0, best_accuracy_pct: 0,
    fastest_avg_response_time_ms: null, perfect_rush_count: 0,
  };
}

test('applyRushProgression: bonusXp/xpMultiplier default to a no-op (0, 1) for existing callers', async () => {
  const player = freshPlayer();
  const withoutBonus = await applyRushProgression(fakeProgressionConnection(player), {
    playerId: 1, rushScore: 100, correctCount: 5, bestStreak: 3, isPerfectRush: false,
    sumResponseTimeMs: 5000, questionsAnswered: 10, accuracyPct: 50,
  });
  const player2 = freshPlayer();
  const withExplicitNoop = await applyRushProgression(fakeProgressionConnection(player2), {
    playerId: 1, rushScore: 100, correctCount: 5, bestStreak: 3, isPerfectRush: false,
    sumResponseTimeMs: 5000, questionsAnswered: 10, accuracyPct: 50, bonusXp: 0, xpMultiplier: 1,
  });
  assert.equal(withoutBonus.xpAwarded, withExplicitNoop.xpAwarded);
});

test('applyRushProgression: bonusXp (mission rewards) is added before any multiplier is applied', async () => {
  const base = await applyRushProgression(fakeProgressionConnection(freshPlayer()), {
    playerId: 1, rushScore: 100, correctCount: 5, bestStreak: 3, isPerfectRush: false,
    sumResponseTimeMs: 5000, questionsAnswered: 10, accuracyPct: 50,
  });
  const withBonus = await applyRushProgression(fakeProgressionConnection(freshPlayer()), {
    playerId: 1, rushScore: 100, correctCount: 5, bestStreak: 3, isPerfectRush: false,
    sumResponseTimeMs: 5000, questionsAnswered: 10, accuracyPct: 50, bonusXp: 70,
  });
  assert.equal(withBonus.xpAwarded, base.xpAwarded + 70);
});

test('applyRushProgression: xpMultiplier (an active event) doubles the combined Rush XP + mission bonus', async () => {
  const base = await applyRushProgression(fakeProgressionConnection(freshPlayer()), {
    playerId: 1, rushScore: 100, correctCount: 5, bestStreak: 3, isPerfectRush: false,
    sumResponseTimeMs: 5000, questionsAnswered: 10, accuracyPct: 50, bonusXp: 70,
  });
  const doubled = await applyRushProgression(fakeProgressionConnection(freshPlayer()), {
    playerId: 1, rushScore: 100, correctCount: 5, bestStreak: 3, isPerfectRush: false,
    sumResponseTimeMs: 5000, questionsAnswered: 10, accuracyPct: 50, bonusXp: 70, xpMultiplier: 2,
  });
  assert.equal(doubled.xpAwarded, base.xpAwarded * 2);
});
