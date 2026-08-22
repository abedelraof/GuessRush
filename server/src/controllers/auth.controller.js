const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');
const env = require('../config/env');
const ApiError = require('../utils/ApiError');

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function issueToken(player) {
  return jwt.sign(
    { id: player.id, email: player.email, role: player.role },
    env.jwtSecret,
    { expiresIn: env.jwtExpiresIn }
  );
}

function toPublicPlayer(player) {
  return { id: player.id, email: player.email, display_name: player.display_name };
}

async function signup(req, res) {
  const { email, password, display_name: displayName } = req.body || {};
  if (!email || !EMAIL_RE.test(email)) throw new ApiError(400, 'Valid email is required');
  if (!password || password.length < 8) throw new ApiError(400, 'Password must be at least 8 characters');
  if (!displayName || !displayName.trim()) throw new ApiError(400, 'Display name is required');

  const [existing] = await pool.query('SELECT id FROM players WHERE email = ?', [email]);
  if (existing.length > 0) throw new ApiError(409, 'An account with this email already exists');

  const hash = await bcrypt.hash(password, 10);
  const [result] = await pool.query(
    `INSERT INTO players (email, password_hash, display_name) VALUES (?, ?, ?)`,
    [email, hash, displayName.trim()]
  );
  const player = { id: result.insertId, email, display_name: displayName.trim(), role: 'player' };
  res.status(201).json({ token: issueToken(player), player: toPublicPlayer(player) });
}

async function login(req, res) {
  const { email, password } = req.body || {};
  if (!email || !password) throw new ApiError(400, 'Email and password are required');

  const [rows] = await pool.query('SELECT * FROM players WHERE email = ?', [email]);
  const player = rows[0];
  if (!player) throw new ApiError(401, 'Invalid email or password');

  const matches = await bcrypt.compare(password, player.password_hash);
  if (!matches) throw new ApiError(401, 'Invalid email or password');

  res.json({ token: issueToken(player), player: toPublicPlayer(player) });
}

async function me(req, res) {
  const [rows] = await pool.query('SELECT id, email, display_name FROM players WHERE id = ?', [req.user.id]);
  const player = rows[0];
  if (!player) throw new ApiError(404, 'Player not found');
  res.json(player);
}

module.exports = { signup, login, me };
