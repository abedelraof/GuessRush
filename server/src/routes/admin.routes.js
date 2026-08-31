const express = require('express');
const asyncHandler = require('../utils/asyncHandler');
const { requireAdmin } = require('../middleware/requireAdmin');
const controller = require('../controllers/admin.controller');

const router = express.Router();

router.get('/login', controller.loginForm);
router.post('/login', asyncHandler(controller.login));
router.get('/logout', controller.logout);

router.get('/', requireAdmin, asyncHandler(controller.dashboard));

router.get('/players', requireAdmin, asyncHandler(controller.listPlayers));
router.get('/players/:id', requireAdmin, asyncHandler(controller.playerDetail));

router.get('/categories', requireAdmin, asyncHandler(controller.listCategories));
router.get('/categories/new', requireAdmin, controller.newCategoryForm);
router.post('/categories', requireAdmin, asyncHandler(controller.createCategory));
router.get('/categories/:id/edit', requireAdmin, asyncHandler(controller.editCategoryForm));
router.post('/categories/:id', requireAdmin, asyncHandler(controller.updateCategory));
router.post('/categories/:id/delete', requireAdmin, asyncHandler(controller.deleteCategory));

router.get('/questions', requireAdmin, asyncHandler(controller.listQuestions));
router.get('/questions/new', requireAdmin, asyncHandler(controller.newQuestionForm));
router.post('/questions', requireAdmin, asyncHandler(controller.createQuestion));

// Must come before the generic '/questions/:id' routes below, or e.g.
// POST /questions/generate would match updateQuestion with id="generate".
router.get('/questions/generate', requireAdmin, asyncHandler(controller.generateForm));
router.post('/questions/generate', requireAdmin, asyncHandler(controller.generatePreview));
router.post('/questions/generate/confirm', requireAdmin, asyncHandler(controller.generateConfirm));
router.get('/questions/bulk-ai', requireAdmin, asyncHandler(controller.bulkAiForm));
router.post('/questions/bulk-ai/draft', requireAdmin, asyncHandler(controller.bulkDraftQuestions));
router.post('/questions/ai-fill', requireAdmin, asyncHandler(controller.aiFillQuestion));
router.post('/questions/audio-preview', requireAdmin, asyncHandler(controller.audioPreview));
router.post('/questions/image-preview', requireAdmin, asyncHandler(controller.imagePreview));
router.post('/questions/video-preview', requireAdmin, asyncHandler(controller.videoPreviewStart));
router.get('/questions/video-preview/:jobId', requireAdmin, asyncHandler(controller.videoPreviewStatus));

router.get('/questions/import', requireAdmin, asyncHandler(controller.importForm));
router.post('/questions/import', requireAdmin, asyncHandler(controller.importPreview));
router.post('/questions/import/confirm', requireAdmin, asyncHandler(controller.importConfirm));

router.post('/questions/bulk-delete', requireAdmin, asyncHandler(controller.bulkDeleteQuestions));
router.post('/questions/bulk-edit', requireAdmin, asyncHandler(controller.bulkEditForm));
router.post('/questions/bulk-edit/confirm', requireAdmin, asyncHandler(controller.bulkEditConfirm));

router.get('/questions/:id/edit', requireAdmin, asyncHandler(controller.editQuestionForm));
router.post('/questions/:id', requireAdmin, asyncHandler(controller.updateQuestion));
router.post('/questions/:id/delete', requireAdmin, asyncHandler(controller.deleteQuestion));
router.post('/questions/:id/audio', requireAdmin, asyncHandler(controller.generateAudioForQuestion));
router.post('/questions/:id/image', requireAdmin, asyncHandler(controller.generateImageForQuestionOption));
router.post('/questions/:id/video', requireAdmin, asyncHandler(controller.generateVideoForQuestionStart));
router.get('/questions/:id/video/:jobId', requireAdmin, asyncHandler(controller.generateVideoForQuestionStatus));

router.get('/settings', requireAdmin, asyncHandler(controller.settingsPage));
router.post('/settings/account', requireAdmin, asyncHandler(controller.updateAccount));
router.post('/settings/claude-key', requireAdmin, asyncHandler(controller.updateClaudeKey));
router.post('/settings/claude-key/remove', requireAdmin, asyncHandler(controller.removeClaudeKey));
router.post('/settings/tts-key', requireAdmin, asyncHandler(controller.updateTtsKey));
router.post('/settings/tts-key/remove', requireAdmin, asyncHandler(controller.removeTtsKey));
router.post('/settings/clear-data', requireAdmin, asyncHandler(controller.clearAllData));

module.exports = router;
