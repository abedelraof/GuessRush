const crypto = require('crypto');
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
  return {
    id: player.id,
    email: player.email,
    display_name: player.display_name,
    is_guest: !!player.is_guest,
  };
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
  const [rows] = await pool.query(
    'SELECT id, email, display_name, is_guest FROM players WHERE id = ?',
    [req.user.id]
  );
  const player = rows[0];
  if (!player) throw new ApiError(404, 'Player not found');
  res.json(toPublicPlayer(player));
}

// Auto-provisions a real players row with no user-facing credentials, so the
// app can land on the home screen and play solo without ever showing a login
// form. Kept indistinguishable from a real account server-side (same table,
// same JWT shape) — is_guest is purely a client-facing flag for gating
// Play With Friends until the player upgrades this row via /upgrade.
async function guest(req, res) {
  const suffix = crypto.randomBytes(8).toString('hex');
  const email = `guest_${suffix}@guest.guessrush.local`;
  const displayName = `Guest${suffix.slice(0, 4).toUpperCase()}`;
  const hash = await bcrypt.hash(crypto.randomBytes(24).toString('hex'), 10);

  const [result] = await pool.query(
    `INSERT INTO players (email, password_hash, display_name, is_guest) VALUES (?, ?, ?, 1)`,
    [email, hash, displayName]
  );
  const player = {
    id: result.insertId,
    email,
    display_name: displayName,
    role: 'player',
    is_guest: 1,
  };
  res.status(201).json({ token: issueToken(player), player: toPublicPlayer(player) });
}

// Converts the caller's own guest row into a real account in place — same
// player id, so lifetime XP/level/stats/achievements earned as a guest carry
// over. Only valid for a currently-guest session; a real account should use
// /signup (a new player) or /login instead.
async function upgrade(req, res) {
  const { email, password, display_name: displayName } = req.body || {};
  if (!email || !EMAIL_RE.test(email)) throw new ApiError(400, 'Valid email is required');
  if (!password || password.length < 8) throw new ApiError(400, 'Password must be at least 8 characters');
  if (!displayName || !displayName.trim()) throw new ApiError(400, 'Display name is required');

  const [rows] = await pool.query('SELECT id, is_guest FROM players WHERE id = ?', [req.user.id]);
  const current = rows[0];
  if (!current) throw new ApiError(404, 'Player not found');
  if (!current.is_guest) throw new ApiError(409, 'This account already has a login — use /signup for a new account');

  const [existing] = await pool.query('SELECT id FROM players WHERE email = ? AND id != ?', [email, req.user.id]);
  if (existing.length > 0) throw new ApiError(409, 'An account with this email already exists');

  const hash = await bcrypt.hash(password, 10);
  await pool.query(
    `UPDATE players SET email = ?, password_hash = ?, display_name = ?, is_guest = 0 WHERE id = ?`,
    [email, hash, displayName.trim(), req.user.id]
  );
  const player = {
    id: req.user.id,
    email,
    display_name: displayName.trim(),
    role: req.user.role,
    is_guest: 0,
  };
  res.json({ token: issueToken(player), player: toPublicPlayer(player) });
}

module.exports = { signup, login, me, guest, upgrade };
