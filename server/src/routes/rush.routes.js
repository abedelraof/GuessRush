const express = require('express');
const asyncHandler = require('../utils/asyncHandler');
const { requireAuth } = require('../middleware/auth');
const controller = require('../controllers/rush.controller');

const router = express.Router();

router.post('/start', requireAuth, asyncHandler(controller.start));

module.exports = router;
