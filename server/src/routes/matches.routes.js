const express = require('express');
const asyncHandler = require('../utils/asyncHandler');
const { requireAuth } = require('../middleware/auth');
const controller = require('../controllers/matches.controller');

const router = express.Router();

router.post('/queue', requireAuth, asyncHandler(controller.joinQueue));
router.delete('/queue', requireAuth, asyncHandler(controller.leaveQueue));
router.post('/friend', requireAuth, asyncHandler(controller.createFriendMatch));
router.post('/friend/:code/join', requireAuth, asyncHandler(controller.joinFriendMatch));
router.get('/:id', requireAuth, asyncHandler(controller.getMatch));

module.exports = router;
