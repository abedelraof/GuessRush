const express = require('express');
const asyncHandler = require('../utils/asyncHandler');
const { requireAuth } = require('../middleware/auth');
const controller = require('../controllers/shop.controller');

const router = express.Router();

router.get('/', requireAuth, asyncHandler(controller.getShop));
router.post('/energy/buy', requireAuth, asyncHandler(controller.buyEnergyRefill));

module.exports = router;
