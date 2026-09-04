const express = require('express');
const asyncHandler = require('../utils/asyncHandler');
const { requireAuth } = require('../middleware/auth');
const controller = require('../controllers/auth.controller');

const router = express.Router();

router.post('/signup', asyncHandler(controller.signup));
router.post('/login', asyncHandler(controller.login));
router.post('/guest', asyncHandler(controller.guest));
router.post('/upgrade', requireAuth, asyncHandler(controller.upgrade));
router.get('/me', requireAuth, asyncHandler(controller.me));

module.exports = router;
