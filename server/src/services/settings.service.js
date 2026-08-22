const pool = require('../config/db');
const { encrypt, decrypt } = require('../utils/crypto');

async function getSetting(key) {
  const [rows] = await pool.query('SELECT value FROM app_settings WHERE setting_key = ?', [key]);
  if (rows.length === 0) return null;
  return decrypt(rows[0].value);
}

async function setSetting(key, plaintextValue) {
  const encrypted = encrypt(plaintextValue);
  await pool.query(
    `INSERT INTO app_settings (setting_key, value) VALUES (?, ?)
     ON DUPLICATE KEY UPDATE value = VALUES(value)`,
    [key, encrypted]
  );
}

async function deleteSetting(key) {
  await pool.query('DELETE FROM app_settings WHERE setting_key = ?', [key]);
}

/**
 * Shows only the last 4 characters behind a fixed-width mask, e.g. "••••••••••••wxyz".
 * Fixed-length regardless of key length so the UI never has to render a mask as long
 * as the real (often 100+ char) key. Never returns the real key.
 */
function maskKey(key) {
  if (!key) return null;
  if (key.length <= 4) return '••••';
  return `${'•'.repeat(12)}${key.slice(-4)}`;
}

module.exports = { getSetting, setSetting, deleteSetting, maskKey };
