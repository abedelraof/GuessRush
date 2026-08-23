const test = require('node:test');
const assert = require('node:assert/strict');
const {
  xpRequiredForLevel,
  cumulativeXpForLevel,
  levelForXp,
  calculateXpAward,
  evaluateAchievements,
} = require('../src/services/progression.service');
const { BASE_XP_PER_LEVEL, XP_GROWTH_PER_LEVEL } = require('../src/config/progression.config');

test('xpRequiredForLevel grows linearly per the configured curve', () => {
  assert.equal(xpRequiredForLevel(1), BASE_XP_PER_LEVEL);
  assert.equal(xpRequiredForLevel(2), BASE_XP_PER_LEVEL + XP_GROWTH_PER_LEVEL);
  assert.equal(xpRequiredForLevel(3), BASE_XP_PER_LEVEL + 2 * XP_GROWTH_PER_LEVEL);
});

test('cumulativeXpForLevel: level 1 needs 0, later levels sum the requirements before them', () => {
  assert.equal(cumulativeXpForLevel(1), 0);
  assert.equal(cumulativeXpForLevel(2), xpRequiredForLevel(1));
  assert.equal(cumulativeXpForLevel(3), xpRequiredForLevel(1) + xpRequiredForLevel(2));
});

test('levelForXp: 0 XP is level 1 with nothing into it', () => {
  const info = levelForXp(0);
  assert.equal(info.level, 1);
  assert.equal(info.xpIntoLevel, 0);
  assert.equal(info.xpForNextLevel, xpRequiredForLevel(1));
});

test('levelForXp: exactly enough XP crosses into the next level, one short does not', () => {
  const needed = cumulativeXpForLevel(2); // XP to reach level 2
  assert.equal(levelForXp(needed - 1).level, 1);
  assert.equal(levelForXp(needed).level, 2);
  assert.equal(levelForXp(needed).xpIntoLevel, 0);
});

test('levelForXp is consistent with cumulativeXpForLevel across several levels', () => {
  for (let level = 1; level <= 10; level++) {
    const xp = cumulativeXpForLevel(level);
    assert.equal(levelForXp(xp).level, level, `cumulative XP for level ${level} should resolve back to level ${level}`);
  }
});

test('calculateXpAward: completion bonus alone for a shutout Rush (0 correct, not perfect)', () => {
  const xp = calculateXpAward({ correctCount: 0, bestStreak: 0, rushScore: 0, isPerfectRush: false });
  assert.equal(xp, 50); // XP_RUSH_COMPLETION_BONUS
});

test('calculateXpAward: perfect Rush adds the perfect-Rush bonus on top', () => {
  const normal = calculateXpAward({ correctCount: 10, bestStreak: 10, rushScore: 3000, isPerfectRush: false });
  const perfect = calculateXpAward({ correctCount: 10, bestStreak: 10, rushScore: 3000, isPerfectRush: true });
  assert.equal(perfect - normal, 100); // XP_PERFECT_RUSH_BONUS
});

test('calculateXpAward: more correct answers and a longer streak both increase XP', () => {
  const base = calculateXpAward({ correctCount: 2, bestStreak: 1, rushScore: 200, isPerfectRush: false });
  const moreCorrect = calculateXpAward({ correctCount: 8, bestStreak: 1, rushScore: 200, isPerfectRush: false });
  const longerStreak = calculateXpAward({ correctCount: 2, bestStreak: 8, rushScore: 200, isPerfectRush: false });
  assert.ok(moreCorrect > base);
  assert.ok(longerStreak > base);
});

test('calculateXpAward never goes negative', () => {
  const xp = calculateXpAward({ correctCount: 0, bestStreak: 0, rushScore: 0, isPerfectRush: false });
  assert.ok(xp >= 0);
});

test('evaluateAchievements: each achievement fires only once its own threshold is met', () => {
  const none = evaluateAchievements({
    rushesCompleted: 0, perfectRushCount: 0, bestStreak: 0, questionsAnswered: 0, hasInsaneSpeedAnswer: false,
  });
  assert.deepEqual(none, []);

  const firstRushOnly = evaluateAchievements({
    rushesCompleted: 1, perfectRushCount: 0, bestStreak: 2, questionsAnswered: 10, hasInsaneSpeedAnswer: false,
  });
  assert.deepEqual(firstRushOnly, ['first_rush']);

  const everything = evaluateAchievements({
    rushesCompleted: 10, perfectRushCount: 1, bestStreak: 10, questionsAnswered: 100, hasInsaneSpeedAnswer: true,
  });
  assert.deepEqual(
    everything.sort(),
    ['first_rush', 'first_perfect_rush', 'streak_5', 'streak_10', 'speed_demon', 'rushes_10', 'questions_100'].sort()
  );
});

test('evaluateAchievements: streak_10 implies streak_5 is also satisfied (both returned)', () => {
  const keys = evaluateAchievements({
    rushesCompleted: 1, perfectRushCount: 0, bestStreak: 10, questionsAnswered: 5, hasInsaneSpeedAnswer: false,
  });
  assert.ok(keys.includes('streak_5'));
  assert.ok(keys.includes('streak_10'));
});
