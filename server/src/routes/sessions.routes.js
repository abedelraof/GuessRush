const express = require('express');
const asyncHandler = require('../utils/asyncHandler');
const { requireAuth } = require('../middleware/auth');
const controller = require('../controllers/sessions.controller');

const router = express.Router();

router.post('/', requireAuth, asyncHandler(controller.create));
router.post('/:id/answers', requireAuth, asyncHandler(controller.submitAnswer));
router.post('/:id/finish', requireAuth, asyncHandler(controller.finish));

module.exports = router;
