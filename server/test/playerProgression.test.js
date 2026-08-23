const test = require('node:test');
const assert = require('node:assert/strict');
const { applyRushProgression } = require('../src/services/playerProgression.service');

/**
 * Stands in for a mysql2 PoolConnection: routes each query by a recognizable
 * prefix to canned responses, and mutates an in-memory `player` row exactly
 * like the real UPDATE would, so applyRushProgression's orchestration logic
 * (locking, computing, writing, achievement idempotency) is exercised without
 * a real database. `unlockedAchievements` simulates rows that already exist
 * from a previous Rush, so INSERT IGNORE against them is a true no-op —
 * mirroring the UNIQUE(player_id, achievement_key) constraint.
 */
function fakeConnection({ player, insaneSpeed = false, unlockedAchievements = [] }) {
  const unlocked = new Set(unlockedAchievements);
  const queries = [];
  return {
    queries,
    unlocked,
    async query(sql, params) {
      queries.push(sql.trim());
      if (sql.includes('FROM players WHERE id = ? FOR UPDATE')) {
        return [[player]];
      }
      if (sql.includes('SELECT EXISTS(')) {
        return [[{ found: insaneSpeed ? 1 : 0 }]];
      }
      if (sql.startsWith('UPDATE players SET')) {
        const [
          level, lifetimeXp, rushesCompleted, questionsAnswered, questionsCorrect,
          totalResponseTimeMs, bestRushScore, bestStreak, bestAccuracyPct,
          fastestAvgResponseTimeMs, perfectRushCount,
        ] = params;
        Object.assign(player, {
          level, lifetime_xp: lifetimeXp, rushes_completed: rushesCompleted,
          questions_answered: questionsAnswered, questions_correct: questionsCorrect,
          total_response_time_ms: totalResponseTimeMs, best_rush_score: bestRushScore,
          best_streak: bestStreak, best_accuracy_pct: bestAccuracyPct,
          fastest_avg_response_time_ms: fastestAvgResponseTimeMs, perfect_rush_count: perfectRushCount,
        });
        return [{ affectedRows: 1 }];
      }
      if (sql.startsWith('INSERT IGNORE INTO player_achievements')) {
        const key = params[1];
        if (unlocked.has(key)) return [{ affectedRows: 0 }];
        unlocked.add(key);
        return [{ affectedRows: 1 }];
      }
      throw new Error(`fakeConnection: unexpected query: ${sql}`);
    },
  };
}

function freshPlayer(overrides = {}) {
  return {
    id: 1,
    level: 1,
    lifetime_xp: 0,
    rushes_completed: 0,
    questions_answered: 0,
    questions_correct: 0,
    total_response_time_ms: 0,
    best_rush_score: 0,
    best_streak: 0,
    best_accuracy_pct: 0,
    fastest_avg_response_time_ms: null,
    perfect_rush_count: 0,
    ...overrides,
  };
}

test('a brand-new player completing their first Rush is awarded XP and the First Rush achievement', async () => {
  const player = freshPlayer();
  const conn = fakeConnection({ player });

  const result = await applyRushProgression(conn, {
    playerId: 1, rushScore: 500, correctCount: 5, bestStreak: 3, isPerfectRush: false,
    sumResponseTimeMs: 15000, questionsAnswered: 10, accuracyPct: 50,
  });

  assert.ok(result.xpAwarded > 0);
  assert.equal(player.lifetime_xp, result.xpAwarded);
  assert.equal(player.rushes_completed, 1);
  assert.deepEqual(result.newlyUnlockedAchievements, ['first_rush']);
});

test('personal records only update when this Rush actually beats the previous one', async () => {
  const player = freshPlayer({ best_rush_score: 1000, best_streak: 8 });
  const conn = fakeConnection({ player, unlockedAchievements: ['first_rush'] });

  const worse = await applyRushProgression(conn, {
    playerId: 1, rushScore: 400, correctCount: 4, bestStreak: 3, isPerfectRush: false,
    sumResponseTimeMs: 8000, questionsAnswered: 8, accuracyPct: 50,
  });
  assert.equal(worse.isNewBestScore, false);
  assert.equal(worse.isNewBestStreak, false);
  assert.equal(player.best_rush_score, 1000); // untouched
  assert.equal(player.best_streak, 8); // untouched

  const better = await applyRushProgression(conn, {
    playerId: 1, rushScore: 1500, correctCount: 10, bestStreak: 9, isPerfectRush: false,
    sumResponseTimeMs: 9000, questionsAnswered: 10, accuracyPct: 100,
  });
  assert.equal(better.isNewBestScore, true);
  assert.equal(better.isNewBestStreak, true);
  assert.equal(player.best_rush_score, 1500);
  assert.equal(player.best_streak, 9);
});

test('an achievement already unlocked on a prior Rush is never re-awarded (idempotent)', async () => {
  const player = freshPlayer({ rushes_completed: 1, lifetime_xp: 300 });
  const conn = fakeConnection({ player, unlockedAchievements: ['first_rush'] });

  const result = await applyRushProgression(conn, {
    playerId: 1, rushScore: 200, correctCount: 3, bestStreak: 2, isPerfectRush: false,
    sumResponseTimeMs: 6000, questionsAnswered: 6, accuracyPct: 50,
  });

  // rushes_completed is now 2, which still only satisfies 'first_rush' (>=1) among
  // the thresholds in play here — and it was already unlocked, so nothing new fires.
  assert.deepEqual(result.newlyUnlockedAchievements, []);
});

test('a perfect Rush unlocks First Perfect Rush and increments the perfect-Rush count', async () => {
  const player = freshPlayer({ rushes_completed: 1 });
  const conn = fakeConnection({ player, unlockedAchievements: ['first_rush'] });

  const result = await applyRushProgression(conn, {
    playerId: 1, rushScore: 900, correctCount: 10, bestStreak: 10, isPerfectRush: true,
    sumResponseTimeMs: 20000, questionsAnswered: 10, accuracyPct: 100,
  });

  assert.equal(player.perfect_rush_count, 1);
  assert.ok(result.newlyUnlockedAchievements.includes('first_perfect_rush'));
  assert.ok(result.newlyUnlockedAchievements.includes('streak_10'));
  assert.ok(result.newlyUnlockedAchievements.includes('streak_5'));
});

test('Speed Demon only unlocks when the player has an INSANE-speed answer on record', async () => {
  const notYet = freshPlayer();
  const notYetConn = fakeConnection({ player: notYet, insaneSpeed: false });
  const r1 = await applyRushProgression(notYetConn, {
    playerId: 1, rushScore: 100, correctCount: 1, bestStreak: 1, isPerfectRush: false,
    sumResponseTimeMs: 1000, questionsAnswered: 1, accuracyPct: 100,
  });
  assert.ok(!r1.newlyUnlockedAchievements.includes('speed_demon'));

  const hasIt = freshPlayer();
  const hasItConn = fakeConnection({ player: hasIt, insaneSpeed: true });
  const r2 = await applyRushProgression(hasItConn, {
    playerId: 1, rushScore: 100, correctCount: 1, bestStreak: 1, isPerfectRush: false,
    sumResponseTimeMs: 1000, questionsAnswered: 1, accuracyPct: 100,
  });
  assert.ok(r2.newlyUnlockedAchievements.includes('speed_demon'));
});

test('leveledUp is only true when the awarded XP actually crosses a level threshold', async () => {
  // Start 1 XP short of level 2, award just enough to tip over.
  const { cumulativeXpForLevel } = require('../src/services/progression.service');
  const almostLevel2 = cumulativeXpForLevel(2) - 1;
  const player = freshPlayer({ lifetime_xp: almostLevel2 });
  const conn = fakeConnection({ player, unlockedAchievements: ['first_rush'] });

  const result = await applyRushProgression(conn, {
    playerId: 1, rushScore: 0, correctCount: 0, bestStreak: 0, isPerfectRush: false,
    sumResponseTimeMs: 0, questionsAnswered: 0, accuracyPct: 0,
  });

  assert.equal(result.leveledUp, true);
  assert.equal(result.level, 2);
});

test('fastest average response time only updates when this Rush is actually faster', async () => {
  const player = freshPlayer({ fastest_avg_response_time_ms: 2000 });
  const conn = fakeConnection({ player, unlockedAchievements: ['first_rush'] });

  // 10 questions summing to 30000ms -> avg 3000ms, slower than the recorded 2000ms.
  await applyRushProgression(conn, {
    playerId: 1, rushScore: 100, correctCount: 5, bestStreak: 2, isPerfectRush: false,
    sumResponseTimeMs: 30000, questionsAnswered: 10, accuracyPct: 50,
  });
  assert.equal(player.fastest_avg_response_time_ms, 2000); // unchanged

  // 10 questions summing to 5000ms -> avg 500ms, faster.
  await applyRushProgression(conn, {
    playerId: 1, rushScore: 100, correctCount: 5, bestStreak: 2, isPerfectRush: false,
    sumResponseTimeMs: 5000, questionsAnswered: 10, accuracyPct: 50,
  });
  assert.equal(player.fastest_avg_response_time_ms, 500);
});
