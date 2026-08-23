const pool = require('../config/db');
const missionsService = require('../services/missions.service');
const eventsService = require('../services/events.service');
const { rankedGlobalRows } = require('./leaderboard.controller');

/**
 * Aggregates the retention-system data the Home screen needs that ISN'T
 * already covered by an existing endpoint — level, personal best, and Daily
 * Rush status all already come from GET /api/profile and GET /api/daily-rush/today,
 * so this deliberately doesn't duplicate them. Just the new pieces: daily
 * streak, today's mission progress, currently-active events, and where the
 * player currently stands on the global leaderboard.
 */
async function getHome(req, res) {
  const [[player]] = await pool.query(
    'SELECT daily_streak_current, daily_streak_longest FROM players WHERE id = ?',
    [req.user.id]
  );

  const missions = await missionsService.getMissionsStatus(req.user.id);

  const now = new Date();
  const activeEvents = eventsService.activeEventsAt(now).map((e) => ({
    key: e.key,
    name: e.name,
    description: e.description,
    type: e.type,
    multiplier: e.multiplier,
    ends_at: e.endsAt,
  }));

  const rankedRows = await rankedGlobalRows(null);
  const myRow = rankedRows.find((r) => r.player_id === req.user.id);

  res.json({
    daily_streak: {
      current: player.daily_streak_current,
      longest: player.daily_streak_longest,
    },
    missions,
    active_events: activeEvents,
    leaderboard_position: myRow ? { rank: myRow.rank, total: rankedRows.length } : null,
  });
}

module.exports = { getHome };
