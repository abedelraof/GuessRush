const pool = require('../config/db');

async function list(req, res) {
  const limit = Math.min(Number(req.query.limit) || 20, 100);
  const categoryId = req.query.category_id ? Number(req.query.category_id) : null;

  const params = [];
  let where = "gs.status = 'completed'";
  if (categoryId) {
    where += ' AND gs.category_id = ?';
    params.push(categoryId);
  }
  params.push(limit);

  const [rows] = await pool.query(
    `SELECT gs.id AS session_id, gs.score, gs.best_streak, gs.category_id,
            p.display_name, gs.ended_at
     FROM game_sessions gs
     JOIN players p ON p.id = gs.player_id
     WHERE ${where}
     ORDER BY gs.score DESC
     LIMIT ?`,
    params
  );
  res.json(rows);
}

module.exports = { list };
