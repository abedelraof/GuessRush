const express = require('express');
const asyncHandler = require('../utils/asyncHandler');
const { requireAuth } = require('../middleware/auth');
const controller = require('../controllers/dailyRush.controller');

const router = express.Router();

router.get('/today', requireAuth, asyncHandler(controller.today));
router.post('/start', requireAuth, asyncHandler(controller.start));

module.exports = router;
