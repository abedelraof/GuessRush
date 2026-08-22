const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');
const env = require('../config/env');
const settingsService = require('../services/settings.service');
const claudeService = require('../services/claude.service');
const ttsService = require('../services/tts.service');
const imageService = require('../services/image.service');
const audioStorage = require('../utils/audioStorage');
const imageStorage = require('../utils/imageStorage');

const QUESTION_TYPES = ['image', 'audio', 'video', 'text', 'emoji', 'progressive'];
const MAX_CLUES = 6;
const CLAUDE_KEY_SETTING = 'anthropic_api_key';
const TTS_KEY_SETTING = 'tts_api_key';
const MAX_GENERATE_COUNT = 15;

function parseJsonField(value) {
  return typeof value === 'string' ? JSON.parse(value) : value;
}

function issueAdminCookie(res, admin) {
  const token = jwt.sign(
    { id: admin.id, email: admin.email, role: admin.role },
    env.jwtSecret,
    { expiresIn: env.jwtExpiresIn }
  );
  res.cookie('admin_token', token, {
    httpOnly: true,
    sameSite: 'lax',
    maxAge: 30 * 24 * 60 * 60 * 1000,
  });
}

/** Moves whichever of the 4 options' temp images (pre-save "Generate Image" clicks) exist to
 *  their permanent per-question-per-option slot. Returns the 4-element URL array to persist. */
function attachOptionImages(questionId, tempPaths) {
  return tempPaths.map((tempPath, i) => (tempPath ? imageStorage.attachTempImage(questionId, i, tempPath) : null));
}

// ---- Auth ----

function loginForm(req, res) {
  res.render('admin/login', { error: null });
}

async function login(req, res) {
  const { email, password } = req.body || {};
  const [rows] = await pool.query('SELECT * FROM players WHERE email = ? AND role = "admin"', [email]);
  const admin = rows[0];
  const matches = admin && (await bcrypt.compare(password || '', admin.password_hash));
  if (!matches) {
    return res.status(401).render('admin/login', { error: 'Invalid email or password' });
  }
  issueAdminCookie(res, admin);
  res.redirect('/admin');
}

function logout(req, res) {
  res.clearCookie('admin_token');
  res.redirect('/admin/login');
}

// ---- Dashboard ----

async function dashboard(req, res) {
  const [[categories]] = await pool.query('SELECT COUNT(*) AS n FROM categories');
  const [[questions]] = await pool.query('SELECT COUNT(*) AS n FROM questions');
  const [[players]] = await pool.query('SELECT COUNT(*) AS n FROM players WHERE role = "player"');
  const [[sessions]] = await pool.query('SELECT COUNT(*) AS n FROM game_sessions');
  res.render('admin/dashboard', {
    admin: req.admin,
    counts: { categories: categories.n, questions: questions.n, players: players.n, sessions: sessions.n },
  });
}

// ---- Categories ----

async function listCategories(req, res) {
  const [rows] = await pool.query(
    `SELECT c.*, (SELECT COUNT(*) FROM questions q WHERE q.category_id = c.id) AS question_count
     FROM categories c ORDER BY c.id`
  );
  res.render('admin/categories/list', { admin: req.admin, categories: rows, error: null });
}

function newCategoryForm(req, res) {
  res.render('admin/categories/form', { admin: req.admin, category: null, error: null });
}

async function createCategory(req, res) {
  const { key_slug: keySlug, name, emoji, color_hex: colorHex } = req.body || {};
  if (!keySlug || !name || !emoji || !colorHex) {
    return res.status(400).render('admin/categories/form', {
      admin: req.admin,
      category: req.body,
      error: 'All fields are required',
    });
  }
  await pool.query(
    'INSERT INTO categories (key_slug, name, emoji, color_hex) VALUES (?, ?, ?, ?)',
    [keySlug.trim(), name.trim(), emoji.trim(), colorHex.trim()]
  );
  res.redirect('/admin/categories');
}

async function editCategoryForm(req, res) {
  const [rows] = await pool.query('SELECT * FROM categories WHERE id = ?', [req.params.id]);
  if (!rows[0]) return res.status(404).send('Category not found');
  res.render('admin/categories/form', { admin: req.admin, category: rows[0], error: null });
}

async function updateCategory(req, res) {
  const { key_slug: keySlug, name, emoji, color_hex: colorHex } = req.body || {};
  await pool.query(
    'UPDATE categories SET key_slug=?, name=?, emoji=?, color_hex=? WHERE id=?',
    [keySlug.trim(), name.trim(), emoji.trim(), colorHex.trim(), req.params.id]
  );
  res.redirect('/admin/categories');
}

async function deleteCategory(req, res) {
  try {
    await pool.query('DELETE FROM categories WHERE id = ?', [req.params.id]);
    res.redirect('/admin/categories');
  } catch (err) {
    if (err.code === 'ER_ROW_IS_REFERENCED_2' || err.code === 'ER_ROW_IS_REFERENCED') {
      const [rows] = await pool.query(
        `SELECT c.*, (SELECT COUNT(*) FROM questions q WHERE q.category_id = c.id) AS question_count
         FROM categories c ORDER BY c.id`
      );
      return res.status(409).render('admin/categories/list', {
        admin: req.admin,
        categories: rows,
        error: 'Cannot delete: this category still has questions attached to it.',
      });
    }
    throw err;
  }
}

// ---- Questions ----

async function listQuestions(req, res) {
  const categoryId = req.query.category_id ? Number(req.query.category_id) : null;
  const [categories] = await pool.query('SELECT * FROM categories ORDER BY name');
  const [questions] = await pool.query(
    `SELECT q.*, c.name AS category_name FROM questions q
     JOIN categories c ON c.id = q.category_id
     ${categoryId ? 'WHERE q.category_id = ?' : ''}
     ORDER BY q.id DESC`,
    categoryId ? [categoryId] : []
  );
  res.render('admin/questions/list', {
    admin: req.admin,
    categories,
    questions,
    selectedCategoryId: categoryId,
    error: null,
  });
}

function emptyQuestionForm() {
  return {
    id: null,
    category_id: '',
    type: 'text',
    label: '',
    prompt: '',
    instruct_text: '',
    media_placeholder: '',
    media_duration: '',
    emojis: '',
    options: ['', '', '', ''],
    option_image_prompts: ['', '', '', ''],
    option_image_paths: [null, null, null, null],
    correct_index: 0,
    clues: [],
    audio_path: null,
    timer_seconds: 0,
  };
}

async function newQuestionForm(req, res) {
  const [categories] = await pool.query('SELECT * FROM categories ORDER BY name');
  res.render('admin/questions/form', {
    admin: req.admin,
    categories,
    question: emptyQuestionForm(),
    types: QUESTION_TYPES,
    maxClues: MAX_CLUES,
    error: null,
  });
}

function collectOptionsFromBody(body) {
  return [0, 1, 2, 3].map((i) => (body[`option_${i}`] || '').trim());
}

function collectOptionImagePromptsFromBody(body) {
  return [0, 1, 2, 3].map((i) => (body[`option_image_prompt_${i}`] || '').trim());
}

/** Temp image paths (pre-save flow) stashed per option by the "Generate Image" button, if any. */
function collectOptionImagePathsFromBody(body) {
  return [0, 1, 2, 3].map((i) => body[`option_image_path_${i}`] || null);
}

function collectCluesFromBody(body) {
  const clues = [];
  for (let i = 0; i < MAX_CLUES; i++) {
    const value = (body[`clue_${i}`] || '').trim();
    if (value) clues.push(value);
  }
  return clues;
}

async function createQuestion(req, res) {
  const body = req.body || {};
  const options = collectOptionsFromBody(body);
  const correctIndex = Number(body.correct_index);
  const [categories] = await pool.query('SELECT * FROM categories ORDER BY name');

  const isValid =
    body.category_id &&
    QUESTION_TYPES.includes(body.type) &&
    body.label &&
    body.prompt &&
    options.every((o) => o.length > 0) &&
    Number.isInteger(correctIndex) &&
    correctIndex >= 0 &&
    correctIndex < 4;

  if (!isValid) {
    return res.status(400).render('admin/questions/form', {
      admin: req.admin,
      categories,
      question: { ...body, options, clues: collectCluesFromBody(body) },
      types: QUESTION_TYPES,
      maxClues: MAX_CLUES,
      error: 'Please fill in all required fields (category, type, label, prompt, all 4 options, correct answer).',
    });
  }

  const clues = body.type === 'progressive' ? collectCluesFromBody(body) : null;
  const optionImagePrompts = collectOptionImagePromptsFromBody(body);

  const [result] = await pool.query(
    `INSERT INTO questions
      (category_id, type, label, prompt, instruct_text, media_placeholder, media_duration, emojis, options, option_image_prompts, correct_index, clues, timer_seconds)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      body.category_id,
      body.type,
      body.label.trim(),
      body.prompt.trim(),
      body.instruct_text ? body.instruct_text.trim() : null,
      body.media_placeholder ? body.media_placeholder.trim() : null,
      body.media_duration ? body.media_duration.trim() : null,
      body.emojis ? body.emojis.trim() : null,
      JSON.stringify(options),
      optionImagePrompts.some((p) => p) ? JSON.stringify(optionImagePrompts) : null,
      correctIndex,
      clues && clues.length ? JSON.stringify(clues) : null,
      Number(body.timer_seconds) || 0,
    ]
  );

  if (body.audio_path) {
    const audioUrl = audioStorage.attachTempAudio(result.insertId, body.audio_path);
    if (audioUrl) {
      await pool.query('UPDATE questions SET audio_path = ? WHERE id = ?', [audioUrl, result.insertId]);
    }
  }

  const optionImagePaths = attachOptionImages(result.insertId, collectOptionImagePathsFromBody(body));
  if (optionImagePaths.some((p) => p)) {
    await pool.query('UPDATE questions SET option_image_paths = ? WHERE id = ?', [
      JSON.stringify(optionImagePaths),
      result.insertId,
    ]);
  }

  res.redirect('/admin/questions');
}

async function editQuestionForm(req, res) {
  const [categories] = await pool.query('SELECT * FROM categories ORDER BY name');
  const [rows] = await pool.query('SELECT * FROM questions WHERE id = ?', [req.params.id]);
  const row = rows[0];
  if (!row) return res.status(404).send('Question not found');
  res.render('admin/questions/form', {
    admin: req.admin,
    categories,
    question: {
      ...row,
      options: parseJsonField(row.options),
      option_image_prompts: row.option_image_prompts ? parseJsonField(row.option_image_prompts) : ['', '', '', ''],
      option_image_paths: row.option_image_paths ? parseJsonField(row.option_image_paths) : [null, null, null, null],
      clues: row.clues ? parseJsonField(row.clues) : [],
    },
    types: QUESTION_TYPES,
    maxClues: MAX_CLUES,
    error: null,
  });
}

async function updateQuestion(req, res) {
  const body = req.body || {};
  const options = collectOptionsFromBody(body);
  const correctIndex = Number(body.correct_index);
  const clues = body.type === 'progressive' ? collectCluesFromBody(body) : null;
  const optionImagePrompts = collectOptionImagePromptsFromBody(body);

  await pool.query(
    `UPDATE questions SET
      category_id=?, type=?, label=?, prompt=?, instruct_text=?, media_placeholder=?, media_duration=?, emojis=?,
      options=?, option_image_prompts=?, correct_index=?, clues=?, timer_seconds=?
     WHERE id=?`,
    [
      body.category_id,
      body.type,
      body.label.trim(),
      body.prompt.trim(),
      body.instruct_text ? body.instruct_text.trim() : null,
      body.media_placeholder ? body.media_placeholder.trim() : null,
      body.media_duration ? body.media_duration.trim() : null,
      body.emojis ? body.emojis.trim() : null,
      JSON.stringify(options),
      optionImagePrompts.some((p) => p) ? JSON.stringify(optionImagePrompts) : null,
      correctIndex,
      clues && clues.length ? JSON.stringify(clues) : null,
      Number(body.timer_seconds) || 0,
      req.params.id,
    ]
  );
  res.redirect('/admin/questions');
}

async function deleteQuestion(req, res) {
  try {
    await pool.query('DELETE FROM questions WHERE id = ?', [req.params.id]);
    res.redirect('/admin/questions');
  } catch (err) {
    if (err.code === 'ER_ROW_IS_REFERENCED_2' || err.code === 'ER_ROW_IS_REFERENCED') {
      const [categories] = await pool.query('SELECT * FROM categories ORDER BY name');
      const [questions] = await pool.query(
        `SELECT q.*, c.name AS category_name FROM questions q JOIN categories c ON c.id = q.category_id ORDER BY q.id DESC`
      );
      return res.status(409).render('admin/questions/list', {
        admin: req.admin,
        categories,
        questions,
        selectedCategoryId: null,
        error: 'Cannot delete: this question already has answers recorded against it.',
      });
    }
    throw err;
  }
}

// ---- AI question generation ----

async function generateForm(req, res) {
  const [categories] = await pool.query('SELECT * FROM categories ORDER BY name');
  res.render('admin/questions/generate', { admin: req.admin, categories, error: null });
}

async function generatePreview(req, res) {
  const body = req.body || {};
  const [categories] = await pool.query('SELECT * FROM categories ORDER BY name');

  const categoryId = Number(body.category_id);
  const count = Number(body.count);
  const category = categories.find((c) => c.id === categoryId);

  if (!category) {
    return res.status(400).render('admin/questions/generate', {
      admin: req.admin,
      categories,
      error: 'Choose a category.',
    });
  }
  if (!Number.isInteger(count) || count < 1 || count > MAX_GENERATE_COUNT) {
    return res.status(400).render('admin/questions/generate', {
      admin: req.admin,
      categories,
      error: `Enter a number of questions between 1 and ${MAX_GENERATE_COUNT}.`,
    });
  }

  const apiKey = await settingsService.getSetting(CLAUDE_KEY_SETTING);
  if (!apiKey) {
    return res.status(400).render('admin/questions/generate', {
      admin: req.admin,
      categories,
      error: 'Add a Claude API key in Settings first.',
    });
  }

  let suggestions;
  try {
    suggestions = await claudeService.generateQuestions({ apiKey, categoryName: category.name, count });
  } catch (err) {
    const message = claudeService.friendlyErrorMessage(err);
    return res.status(502).render('admin/questions/generate', { admin: req.admin, categories, error: message });
  }

  const questions = suggestions.map((q, i) => ({ key: `q${i}`, ...q }));
  res.render('admin/questions/generate_review', {
    admin: req.admin,
    category,
    questions,
    types: QUESTION_TYPES,
    maxClues: MAX_CLUES,
    error: null,
  });
}

async function generateConfirm(req, res) {
  const body = req.body || {};
  const categoryId = Number(body.category_id);
  const rows = Object.values(body.questions || {});

  const [categories] = await pool.query('SELECT * FROM categories ORDER BY name');
  const category = categories.find((c) => c.id === categoryId);
  if (!category) {
    return res.status(400).render('admin/questions/generate', { admin: req.admin, categories, error: 'Category not found.' });
  }
  if (rows.length === 0) {
    return res.redirect('/admin/questions');
  }

  for (const row of rows) {
    const options = collectOptionsFromBody(row);
    const correctIndex = Number(row.correct_index);
    const isValid =
      QUESTION_TYPES.includes(row.type) &&
      row.label &&
      row.prompt &&
      options.every((o) => o.length > 0) &&
      Number.isInteger(correctIndex) &&
      correctIndex >= 0 &&
      correctIndex < 4;
    if (!isValid) continue; // silently skip malformed rows rather than fail the whole batch

    const clues = row.type === 'progressive' ? collectCluesFromBody(row) : null;
    const optionImagePrompts = collectOptionImagePromptsFromBody(row);
    const [result] = await pool.query(
      `INSERT INTO questions
        (category_id, type, label, prompt, instruct_text, media_placeholder, media_duration, emojis, options, option_image_prompts, correct_index, clues, timer_seconds)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        categoryId,
        row.type,
        row.label.trim(),
        row.prompt.trim(),
        row.instruct_text ? row.instruct_text.trim() : null,
        row.media_placeholder ? row.media_placeholder.trim() : null,
        row.media_duration ? row.media_duration.trim() : null,
        row.emojis ? row.emojis.trim() : null,
        JSON.stringify(options),
        optionImagePrompts.some((p) => p) ? JSON.stringify(optionImagePrompts) : null,
        correctIndex,
        clues && clues.length ? JSON.stringify(clues) : null,
        Number(row.timer_seconds) || 0,
      ]
    );

    if (row.audio_path) {
      const audioUrl = audioStorage.attachTempAudio(result.insertId, row.audio_path);
      if (audioUrl) {
        await pool.query('UPDATE questions SET audio_path = ? WHERE id = ?', [audioUrl, result.insertId]);
      }
    }

    const optionImagePaths = attachOptionImages(result.insertId, collectOptionImagePathsFromBody(row));
    if (optionImagePaths.some((p) => p)) {
      await pool.query('UPDATE questions SET option_image_paths = ? WHERE id = ?', [
        JSON.stringify(optionImagePaths),
        result.insertId,
      ]);
    }
  }

  res.redirect('/admin/questions');
}

// ---- AI audio generation ----

/** Pre-save: synthesizes to a temp file. Caller (review card / new-question form) stashes
 *  the returned audio_path in a hidden field, attached to the real row once it's inserted. */
async function audioPreview(req, res) {
  const { text, instruct_text: instructText } = req.body || {};
  const apiKey = await settingsService.getSetting(TTS_KEY_SETTING);
  if (!apiKey) {
    return res.status(400).json({ error: 'Add a Custom AI Key in Settings first.' });
  }
  try {
    const buffer = await ttsService.synthesize({ apiKey, text, instructText });
    const { audioPath, audioUrl } = audioStorage.saveTempAudio(buffer);
    res.json({ audio_url: audioUrl, audio_path: audioPath });
  } catch (err) {
    res.status(502).json({ error: ttsService.friendlyErrorMessage(err) });
  }
}

/** Post-save: question already has an id, so this writes straight to its permanent slot. */
async function generateAudioForQuestion(req, res) {
  const { text, instruct_text: instructText } = req.body || {};
  const questionId = Number(req.params.id);
  const apiKey = await settingsService.getSetting(TTS_KEY_SETTING);
  if (!apiKey) {
    return res.status(400).json({ error: 'Add a Custom AI Key in Settings first.' });
  }
  try {
    const buffer = await ttsService.synthesize({ apiKey, text, instructText });
    const audioUrl = audioStorage.saveAudioForQuestion(questionId, buffer);
    await pool.query('UPDATE questions SET audio_path = ? WHERE id = ?', [audioUrl, questionId]);
    res.json({ audio_url: audioUrl });
  } catch (err) {
    res.status(502).json({ error: ttsService.friendlyErrorMessage(err) });
  }
}

// ---- AI image generation (per answer option) ----

/** Pre-save: generates to a temp file. Caller stashes the returned image_path in that
 *  option's hidden field, attached to the real row once it's inserted. */
async function imagePreview(req, res) {
  const { prompt } = req.body || {};
  const apiKey = await settingsService.getSetting(TTS_KEY_SETTING);
  if (!apiKey) {
    return res.status(400).json({ error: 'Add a Custom AI Key in Settings first.' });
  }
  try {
    const buffer = await imageService.synthesize({ apiKey, prompt });
    const { imagePath, imageUrl } = imageStorage.saveTempImage(buffer);
    res.json({ image_url: imageUrl, image_path: imagePath });
  } catch (err) {
    res.status(502).json({ error: imageService.friendlyErrorMessage(err) });
  }
}

/** Post-save: question already has an id, so this writes straight to the given option's
 *  permanent slot and read-modify-writes that one index of option_image_paths. */
async function generateImageForQuestionOption(req, res) {
  const { prompt, option_index: optionIndexRaw } = req.body || {};
  const questionId = Number(req.params.id);
  const optionIndex = Number(optionIndexRaw);
  if (!Number.isInteger(optionIndex) || optionIndex < 0 || optionIndex > 3) {
    return res.status(400).json({ error: 'Invalid option index.' });
  }
  const apiKey = await settingsService.getSetting(TTS_KEY_SETTING);
  if (!apiKey) {
    return res.status(400).json({ error: 'Add a Custom AI Key in Settings first.' });
  }
  try {
    const buffer = await imageService.synthesize({ apiKey, prompt });
    const imageUrl = imageStorage.saveImageForQuestionOption(questionId, optionIndex, buffer);

    const [rows] = await pool.query('SELECT option_image_paths FROM questions WHERE id = ?', [questionId]);
    const current =
      rows[0] && rows[0].option_image_paths ? parseJsonField(rows[0].option_image_paths) : [null, null, null, null];
    current[optionIndex] = imageUrl;
    await pool.query('UPDATE questions SET option_image_paths = ? WHERE id = ?', [JSON.stringify(current), questionId]);

    res.json({ image_url: imageUrl });
  } catch (err) {
    res.status(502).json({ error: imageService.friendlyErrorMessage(err) });
  }
}

// ---- Settings ----

async function settingsPage(req, res) {
  const [rows] = await pool.query('SELECT email, display_name FROM players WHERE id = ?', [req.admin.id]);
  const account = rows[0];
  const [claudeKey, ttsKey] = await Promise.all([
    settingsService.getSetting(CLAUDE_KEY_SETTING),
    settingsService.getSetting(TTS_KEY_SETTING),
  ]);
  res.render('admin/settings', {
    admin: req.admin,
    account,
    maskedClaudeKey: settingsService.maskKey(claudeKey),
    maskedTtsKey: settingsService.maskKey(ttsKey),
    accountError: null,
    accountSuccess: null,
    claudeKeyError: null,
    claudeKeySuccess: null,
    ttsKeyError: null,
    ttsKeySuccess: null,
  });
}

async function renderSettingsWithError(req, res, status, overrides) {
  const [rows] = await pool.query('SELECT email, display_name FROM players WHERE id = ?', [req.admin.id]);
  const [claudeKey, ttsKey] = await Promise.all([
    settingsService.getSetting(CLAUDE_KEY_SETTING),
    settingsService.getSetting(TTS_KEY_SETTING),
  ]);
  res.status(status).render('admin/settings', {
    admin: req.admin,
    account: rows[0],
    maskedClaudeKey: settingsService.maskKey(claudeKey),
    maskedTtsKey: settingsService.maskKey(ttsKey),
    accountError: null,
    accountSuccess: null,
    claudeKeyError: null,
    claudeKeySuccess: null,
    ttsKeyError: null,
    ttsKeySuccess: null,
    ...overrides,
  });
}

async function updateAccount(req, res) {
  const { email, current_password: currentPassword, new_password: newPassword, confirm_password: confirmPassword } =
    req.body || {};

  const [rows] = await pool.query('SELECT * FROM players WHERE id = ?', [req.admin.id]);
  const account = rows[0];

  const matches = account && (await bcrypt.compare(currentPassword || '', account.password_hash));
  if (!matches) {
    return renderSettingsWithError(req, res, 401, { accountError: 'Current password is incorrect.' });
  }

  if (newPassword && newPassword !== confirmPassword) {
    return renderSettingsWithError(req, res, 400, { accountError: 'New password and confirmation do not match.' });
  }
  if (newPassword && newPassword.length < 8) {
    return renderSettingsWithError(req, res, 400, { accountError: 'New password must be at least 8 characters.' });
  }

  if (email && email !== account.email) {
    const [existing] = await pool.query('SELECT id FROM players WHERE email = ? AND id != ?', [email, account.id]);
    if (existing.length > 0) {
      return renderSettingsWithError(req, res, 409, { accountError: 'That email is already in use.' });
    }
  }

  const nextEmail = email || account.email;
  if (newPassword) {
    const hash = await bcrypt.hash(newPassword, 10);
    await pool.query('UPDATE players SET email = ?, password_hash = ? WHERE id = ?', [nextEmail, hash, account.id]);
  } else {
    await pool.query('UPDATE players SET email = ? WHERE id = ?', [nextEmail, account.id]);
  }

  // Email may have changed — the JWT cookie carries it, so re-issue.
  issueAdminCookie(res, { id: account.id, email: nextEmail, role: account.role });
  await renderSettingsWithError(req, res, 200, { accountSuccess: 'Account updated.' });
}

async function updateClaudeKey(req, res) {
  const { api_key: apiKey } = req.body || {};
  if (!apiKey || !apiKey.trim()) {
    return renderSettingsWithError(req, res, 400, { claudeKeyError: 'Enter a key to save.' });
  }
  await settingsService.setSetting(CLAUDE_KEY_SETTING, apiKey.trim());
  await renderSettingsWithError(req, res, 200, { claudeKeySuccess: 'Claude API key saved.' });
}

async function removeClaudeKey(req, res) {
  await settingsService.deleteSetting(CLAUDE_KEY_SETTING);
  await renderSettingsWithError(req, res, 200, { claudeKeySuccess: 'Claude API key removed.' });
}

async function updateTtsKey(req, res) {
  const { api_key: apiKey } = req.body || {};
  if (!apiKey || !apiKey.trim()) {
    return renderSettingsWithError(req, res, 400, { ttsKeyError: 'Enter a key to save.' });
  }
  await settingsService.setSetting(TTS_KEY_SETTING, apiKey.trim());
  await renderSettingsWithError(req, res, 200, { ttsKeySuccess: 'Custom AI key saved.' });
}

async function removeTtsKey(req, res) {
  await settingsService.deleteSetting(TTS_KEY_SETTING);
  await renderSettingsWithError(req, res, 200, { ttsKeySuccess: 'Custom AI key removed.' });
}

module.exports = {
  loginForm,
  login,
  logout,
  dashboard,
  listCategories,
  newCategoryForm,
  createCategory,
  editCategoryForm,
  updateCategory,
  deleteCategory,
  listQuestions,
  newQuestionForm,
  createQuestion,
  editQuestionForm,
  updateQuestion,
  deleteQuestion,
  generateForm,
  generatePreview,
  generateConfirm,
  audioPreview,
  generateAudioForQuestion,
  imagePreview,
  generateImageForQuestionOption,
  settingsPage,
  updateAccount,
  updateClaudeKey,
  removeClaudeKey,
  updateTtsKey,
  removeTtsKey,
};
