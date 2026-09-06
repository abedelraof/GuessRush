const pool = require('../config/db');
const { ENERGY_REFILL_COST_COINS } = require('../config/economy.config');
const energyService = require('../services/energy.service');

/** Static catalog — a single client-visible price, kept server-side so it can never drift from what /buy actually charges. */
function getShop(req, res) {
  res.json({ energy_refill_cost_coins: ENERGY_REFILL_COST_COINS });
}

async function buyEnergyRefill(req, res) {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const result = await energyService.buyEnergy(connection, req.user.id);
    await connection.commit();
    res.json({
      energy: result.energy,
      energy_max: energyService.ENERGY_MAX,
      energy_regen_seconds: result.nextRegenAt
        ? Math.max(0, Math.round((result.nextRegenAt.getTime() - Date.now()) / 1000))
        : null,
      coins: result.coins,
    });
  } catch (err) {
    await connection.rollback();
    throw err;
  } finally {
    connection.release();
  }
}

module.exports = { getShop, buyEnergyRefill };
