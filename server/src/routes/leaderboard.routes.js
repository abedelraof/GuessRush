const express = require('express');
const asyncHandler = require('../utils/asyncHandler');
const controller = require('../controllers/leaderboard.controller');

const router = express.Router();

router.get('/', asyncHandler(controller.list));

module.exports = router;
