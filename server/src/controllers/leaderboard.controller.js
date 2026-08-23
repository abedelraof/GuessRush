const pool = require('../config/db');
const { todayDateString } = require('../services/dailyRush.service');

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;

function clampLimit(raw) {
  const n = Number(raw) || DEFAULT_LIMIT;
  return Math.min(Math.max(n, 1), MAX_LIMIT);
}

/**
 * Global: each player's single best completed Rush (optionally scoped to one
 * category), ranked by score desc. Deliberately reuses game_sessions rather
 * than players.best_rush_score (Phase 3's lifetime personal-best column) —
 * that column isn't category-scoped, and this needs to support category
 * filtering the way the original leaderboard endpoint already did.
 */
async function rankedGlobalRows(categoryId) {
  const where = categoryId ? 'AND gs.category_id = ?' : '';
  const params = categoryId ? [categoryId] : [];
  const [rows] = await pool.query(
    `WITH best_sessions AS (
       SELECT gs.player_id, gs.score, gs.best_streak, gs.ended_at,
              ROW_NUMBER() OVER (PARTITION BY gs.player_id ORDER BY gs.score DESC, gs.ended_at ASC) AS rn
       FROM game_sessions gs
       WHERE gs.status = 'completed' ${where}
     )
     SELECT bs.player_id, p.display_name, bs.score, bs.best_streak, bs.ended_at,
            RANK() OVER (ORDER BY bs.score DESC, bs.ended_at ASC) AS \`rank\`
     FROM best_sessions bs
     JOIN players p ON p.id = bs.player_id
     WHERE bs.rn = 1
     ORDER BY \`rank\``,
    params
  );
  return rows;
}

/** Daily: today's one official attempt per player, ranked by score desc (tie: earliest finish). */
async function rankedDailyRows(dateString) {
  const [rows] = await pool.query(
    `SELECT dra.player_id, p.display_name, gs.score, gs.best_streak, gs.ended_at,
            RANK() OVER (ORDER BY gs.score DESC, gs.ended_at ASC) AS \`rank\`
     FROM daily_rush_attempts dra
     JOIN game_sessions gs ON gs.id = dra.session_id
     JOIN players p ON p.id = dra.player_id
     WHERE dra.daily_date = ? AND gs.status = 'completed'
     ORDER BY \`rank\``,
    [dateString]
  );
  return rows;
}

function serializeEntry(row) {
  return {
    rank: row.rank,
    player_id: row.player_id,
    display_name: row.display_name,
    score: row.score,
    best_streak: row.best_streak,
  };
}

/**
 * GET /api/leaderboard?period=global|daily&category_id=&limit=&offset=
 *
 * Ranking is computed set-at-a-time in SQL (window functions), never
 * client-suppliable — the client only chooses which view to look at.
 * `me` is always included (null if unranked yet) so the app can highlight
 * the current player's position even when they're off the visible page;
 * pagination happens in JS after the ranked set is computed rather than a
 * second SQL query, since RANK() already has to materialize the full
 * partition regardless of any LIMIT, and this keeps "my rank" a lookup
 * against the same result instead of a separate query that could disagree
 * with it under concurrent writes.
 */
async function list(req, res) {
  const period = req.query.period === 'daily' ? 'daily' : 'global';
  const categoryId = req.query.category_id ? Number(req.query.category_id) : null;
  const limit = clampLimit(req.query.limit);
  const offset = Math.max(Number(req.query.offset) || 0, 0);
  const dateString = todayDateString();

  const rows = period === 'daily' ? await rankedDailyRows(dateString) : await rankedGlobalRows(categoryId);

  const page = rows.slice(offset, offset + limit);
  const myRow = rows.find((r) => r.player_id === req.user.id);

  res.json({
    period,
    date: period === 'daily' ? dateString : null,
    total: rows.length,
    limit,
    offset,
    entries: page.map(serializeEntry),
    me: myRow ? serializeEntry(myRow) : null,
  });
}

module.exports = { list, rankedGlobalRows };
