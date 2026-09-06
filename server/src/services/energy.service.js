const ApiError = require('../utils/ApiError');
const { ENERGY_MAX, ENERGY_REGEN_INTERVAL_MS } = require('../config/economy.config');

/**
 * Projects a player's stored energy forward to `now`. Pure function, no DB
 * access — mirrors dailyRush.service.js's secondsUntilNextReset in spirit,
 * but needs its own stored anchor (`energy_updated_at`) rather than a single
 * shared instant: regeneration is per-player and restarts every time energy
 * is spent, not a once-a-day rollover everyone shares.
 */
function projectEnergy(storedEnergy, updatedAt, now = new Date()) {
  if (storedEnergy >= ENERGY_MAX) {
    return { energy: ENERGY_MAX, nextRegenAt: null };
  }
  const elapsedMs = Math.max(0, now.getTime() - new Date(updatedAt).getTime());
  const regenerated = Math.floor(elapsedMs / ENERGY_REGEN_INTERVAL_MS);
  const energy = Math.min(ENERGY_MAX, storedEnergy + regenerated);
  if (energy >= ENERGY_MAX) {
    return { energy: ENERGY_MAX, nextRegenAt: null };
  }
  const msIntoCurrentInterval = elapsedMs % ENERGY_REGEN_INTERVAL_MS;
  const msUntilNext = ENERGY_REGEN_INTERVAL_MS - msIntoCurrentInterval;
  return { energy, nextRegenAt: new Date(now.getTime() + msUntilNext) };
}

/**
 * Spends one energy point for `playerId`, inside the caller's own transaction.
 * Locks the player row FOR UPDATE itself (callers don't need to lock it
 * first) and throws ApiError(409) if there's none available. The write
 * always resets `energy_updated_at` to now, which is what keeps the pure
 * projection above correct: the regen clock restarts from the moment of the
 * last spend, whether or not this particular call actually ticked any
 * regeneration forward first.
 */
async function consumeEnergy(connection, playerId) {
  const [[row]] = await connection.query(
    'SELECT energy, energy_updated_at FROM players WHERE id = ? FOR UPDATE',
    [playerId]
  );
  const now = new Date();
  const { energy: currentEnergy } = projectEnergy(row.energy, row.energy_updated_at, now);
  if (currentEnergy < 1) {
    throw new ApiError(409, 'Out of energy — wait for it to regenerate before starting another Rush.');
  }
  await connection.query('UPDATE players SET energy = ?, energy_updated_at = ? WHERE id = ?', [
    currentEnergy - 1,
    now,
    playerId,
  ]);
}

module.exports = { ENERGY_MAX, ENERGY_REGEN_INTERVAL_MS, projectEnergy, consumeEnergy };
