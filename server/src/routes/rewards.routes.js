const express = require('express');
const asyncHandler = require('../utils/asyncHandler');
const { requireAuth } = require('../middleware/auth');
const controller = require('../controllers/rewards.controller');

const router = express.Router();

router.get('/', requireAuth, asyncHandler(controller.getRewards));
router.post('/:key/claim', requireAuth, asyncHandler(controller.claimReward));

module.exports = router;
