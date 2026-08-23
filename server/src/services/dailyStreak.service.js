const { todayDateString } = require('./dailyRush.service');

const MS_PER_DAY = 24 * 60 * 60 * 1000;

/** True if `dateString` is exactly one calendar day after `prevDateString` (both "YYYY-MM-DD", UTC). */
function isConsecutiveDay(prevDateString, dateString) {
  return Date.parse(`${dateString}T00:00:00Z`) - Date.parse(`${prevDateString}T00:00:00Z`) === MS_PER_DAY;
}

/**
 * Pure state transition for the daily play streak — separate from (and never
 * to be confused with) the in-game answer streak tracked on game_sessions.
 * Given the player's current streak state and today's server date, decides
 * what the new state should be:
 *  - same day as last time -> unchanged (a second completion today doesn't
 *    double-count; `changed: false` tells the caller to skip the write)
 *  - exactly one day after last time -> streak continues (+1)
 *  - anything else (a missed day, or the very first completion ever) -> streak
 *    resets to 1, since today's completion itself always counts
 */
function computeStreakUpdate({ lastDate, currentStreak, longestStreak }, todayDate = todayDateString()) {
  if (lastDate === todayDate) {
    return { currentStreak, longestStreak, lastDate, changed: false };
  }
  const consecutive = lastDate !== null && isConsecutiveDay(lastDate, todayDate);
  const newCurrent = consecutive ? currentStreak + 1 : 1;
  return {
    currentStreak: newCurrent,
    longestStreak: Math.max(longestStreak, newCurrent),
    lastDate: todayDate,
    changed: true,
  };
}

/**
 * Applies the daily streak update to the player's row. Must run inside the
 * same transaction as the triggering Rush's completion (sessions.controller's
 * /finish, on the in_progress -> completed transition only, and only when that
 * Rush was the official Daily Rush — see the "required daily activity" note in
 * missions.service.js), with the player row already locked FOR UPDATE by
 * applyRushProgression earlier in that same transaction, so no extra locking
 * is needed here.
 */
async function applyDailyStreak(connection, playerId) {
  const [[player]] = await connection.query(
    'SELECT daily_streak_current, daily_streak_longest, daily_streak_last_date FROM players WHERE id = ?',
    [playerId]
  );
  const lastDate = player.daily_streak_last_date
    ? new Date(player.daily_streak_last_date).toISOString().slice(0, 10)
    : null;

  const update = computeStreakUpdate({
    lastDate,
    currentStreak: player.daily_streak_current,
    longestStreak: player.daily_streak_longest,
  });

  if (!update.changed) {
    return { current: update.currentStreak, longest: update.longestStreak, extended: false };
  }

  await connection.query(
    'UPDATE players SET daily_streak_current = ?, daily_streak_longest = ?, daily_streak_last_date = ? WHERE id = ?',
    [update.currentStreak, update.longestStreak, update.lastDate, playerId]
  );
  return { current: update.currentStreak, longest: update.longestStreak, extended: true };
}

module.exports = { isConsecutiveDay, computeStreakUpdate, applyDailyStreak };
