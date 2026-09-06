const pool = require('../config/db');
const rewardsService = require('../services/rewards.service');

async function getRewards(req, res) {
  const rewards = await rewardsService.listRewardsForPlayer(pool, req.user.id);
  res.json({ rewards });
}

async function claimReward(req, res) {
  const rewardKey = req.params.key;

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const result = await rewardsService.claimReward(connection, req.user.id, rewardKey);
    await connection.commit();
    res.json({ key: result.key, coins_awarded: result.coinsAwarded, coins_total: result.coinsTotal });
  } catch (err) {
    await connection.rollback();
    throw err;
  } finally {
    connection.release();
  }
}

module.exports = { getRewards, claimReward };
