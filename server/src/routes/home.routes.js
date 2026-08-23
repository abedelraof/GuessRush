const express = require('express');
const asyncHandler = require('../utils/asyncHandler');
const { requireAuth } = require('../middleware/auth');
const controller = require('../controllers/home.controller');

const router = express.Router();

router.get('/', requireAuth, asyncHandler(controller.getHome));

module.exports = router;
