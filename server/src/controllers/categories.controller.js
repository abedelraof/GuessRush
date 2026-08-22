const pool = require('../config/db');

async function list(req, res) {
  const [rows] = await pool.query(
    'SELECT id, key_slug, name, emoji, color_hex FROM categories ORDER BY id'
  );
  res.json(rows);
}

module.exports = { list };
