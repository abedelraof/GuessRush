const express = require('express');
const asyncHandler = require('../utils/asyncHandler');
const { requireAuth } = require('../middleware/auth');
const controller = require('../controllers/leaderboard.controller');

const router = express.Router();

// requireAuth (this endpoint was previously public) — "current player highlight"
// needs to know who the current player is, and every other API route already requires it.
router.get('/', requireAuth, asyncHandler(controller.list));

module.exports = router;
