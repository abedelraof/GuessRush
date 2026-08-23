const express = require('express');
const asyncHandler = require('../utils/asyncHandler');
const { requireAuth } = require('../middleware/auth');
const controller = require('../controllers/sessions.controller');

const router = express.Router();

router.post('/', requireAuth, asyncHandler(controller.create));
router.post('/:id/start', requireAuth, asyncHandler(controller.startQuestion));
router.post('/:id/answers', requireAuth, asyncHandler(controller.submitAnswer));
router.post('/:id/finish', requireAuth, asyncHandler(controller.finish));
router.post('/:id/reveal-clue', requireAuth, asyncHandler(controller.revealClue));
router.post('/:id/power-ups/remove-one', requireAuth, asyncHandler(controller.useRemoveOne));
router.post('/:id/double-down', requireAuth, asyncHandler(controller.chooseDoubleDown));

module.exports = router;
