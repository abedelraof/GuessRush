const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');
const env = require('../config/env');
const settingsService = require('../services/settings.service');
const claudeService = require('../services/claude.service');
const ttsService = require('../services/tts.service');
const imageService = require('../services/image.service');
const videoService = require('../services/video.service');
const audioStorage = require('../utils/audioStorage');
const imageStorage = require('../utils/imageStorage');
const videoStorage = require('../utils/videoStorage');
const { levelForXp } = require('../services/progression.service');
const { ACHIEVEMENTS } = require('../config/progression.config');
const missionsService = require('../services/missions.service');
const eventsService = require('../services/events.service');

const QUESTION_TYPES = ['image', 'audio', 'video', 'text', 'emoji', 'progressive'];
const DIFFICULTIES = ['easy', 'medium', 'hard', 'extreme'];
const MAX_CLUES = 6;
const CLAUDE_KEY_SETTING = 'anthropic_api_key';
// Only needed for "identity-linked" Claude API keys — see claude.service.js.
const CLAUDE_WORKSPACE_SETTING = 'anthropic_workspace_id';
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
  const [[activeStreaks]] = await pool.query(
    'SELECT COUNT(*) AS n FROM players WHERE role = "player" AND daily_streak_current > 0'
  );
  const activeEvents = eventsService.activeEventsAt(new Date());
  res.render('admin/dashboard', {
    admin: req.admin,
    counts: { categories: categories.n, questions: questions.n, players: players.n, sessions: sessions.n },
    activeStreaks: activeStreaks.n,
    activeEvents,
  });
}

// ---- Players (progression visibility — read-only; achievements are configuration-driven,
// defined in progression.config.js, so there's no editor here, just a view). ----

async function listPlayers(req, res) {
  const [players] = await pool.query(
    `SELECT p.*, (SELECT COUNT(*) FROM player_achievements pa WHERE pa.player_id = p.id) AS achievements_unlocked
     FROM players p WHERE p.role = 'player' ORDER BY p.lifetime_xp DESC`
  );
  res.render('admin/players/list', {
    admin: req.admin,
    players: players.map((p) => ({ ...p, level: levelForXp(p.lifetime_xp).level })),
    totalAchievements: ACHIEVEMENTS.length,
  });
}

async function playerDetail(req, res) {
  const [[player]] = await pool.query('SELECT * FROM players WHERE id = ? AND role = "player"', [req.params.id]);
  if (!player) return res.status(404).send('Player not found');

  const [unlockedRows] = await pool.query(
    'SELECT achievement_key, unlocked_at FROM player_achievements WHERE player_id = ?',
    [req.params.id]
  );
  const unlockedByKey = new Map(unlockedRows.map((r) => [r.achievement_key, r.unlocked_at]));
  const missions = await missionsService.getMissionsStatus(player.id);

  res.render('admin/players/detail', {
    admin: req.admin,
    player: { ...player, ...levelForXp(player.lifetime_xp) },
    achievements: ACHIEVEMENTS.map((a) => ({
      ...a,
      unlocked: unlockedByKey.has(a.key),
      unlockedAt: unlockedByKey.get(a.key) || null,
    })),
    missions,
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

/** Shared by listQuestions and the bulk-delete error path (partial failure). */
async function fetchQuestionsListData(categoryId) {
  const [categories] = await pool.query('SELECT * FROM categories ORDER BY name');
  const [questions] = await pool.query(
    `SELECT q.*, c.name AS category_name FROM questions q
     JOIN categories c ON c.id = q.category_id
     ${categoryId ? 'WHERE q.category_id = ?' : ''}
     ORDER BY q.id DESC`,
    categoryId ? [categoryId] : []
  );
  return { categories, questions };
}

async function listQuestions(req, res) {
  const categoryId = req.query.category_id ? Number(req.query.category_id) : null;
  const importedCount = req.query.imported != null ? Number(req.query.imported) : null;
  const bulkDeletedCount = req.query.bulk_deleted != null ? Number(req.query.bulk_deleted) : null;
  const bulkUpdatedCount = req.query.bulk_updated != null ? Number(req.query.bulk_updated) : null;
  const { categories, questions } = await fetchQuestionsListData(categoryId);
  res.render('admin/questions/list', {
    admin: req.admin,
    categories,
    questions,
    selectedCategoryId: categoryId,
    error: null,
    importedCount: Number.isInteger(importedCount) ? importedCount : null,
    bulkDeletedCount: Number.isInteger(bulkDeletedCount) ? bulkDeletedCount : null,
    bulkUpdatedCount: Number.isInteger(bulkUpdatedCount) ? bulkUpdatedCount : null,
  });
}

/** Normalizes the `ids` field from a bulk-action form (checkboxes) into positive integer ids. */
function collectBulkIds(body) {
  const raw = body && body.ids;
  if (!raw) return [];
  const arr = Array.isArray(raw) ? raw : [raw];
  return arr.map(Number).filter((n) => Number.isInteger(n) && n > 0);
}

function emptyQuestionForm() {
  return {
    id: null,
    category_id: '',
    type: 'text',
    difficulty: 'easy',
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
    difficulties: DIFFICULTIES,
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
  const difficulty = DIFFICULTIES.includes(body.difficulty) ? body.difficulty : 'easy';
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
      question: { ...body, options, difficulty, clues: collectCluesFromBody(body) },
      types: QUESTION_TYPES,
      difficulties: DIFFICULTIES,
      maxClues: MAX_CLUES,
      error: 'Please fill in all required fields (category, type, label, prompt, all 4 options, correct answer).',
    });
  }

  const clues = body.type === 'progressive' ? collectCluesFromBody(body) : null;
  const optionImagePrompts = collectOptionImagePromptsFromBody(body);

  const [result] = await pool.query(
    `INSERT INTO questions
      (category_id, type, difficulty, label, prompt, instruct_text, media_placeholder, media_duration, emojis, options, option_image_prompts, correct_index, clues, timer_seconds, video_prompt)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      body.category_id,
      body.type,
      difficulty,
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
      body.video_prompt ? body.video_prompt.trim() : null,
    ]
  );

  if (body.audio_path) {
    const audioUrl = audioStorage.attachTempAudio(result.insertId, body.audio_path);
    if (audioUrl) {
      await pool.query('UPDATE questions SET audio_path = ? WHERE id = ?', [audioUrl, result.insertId]);
    }
  }

  if (body.video_path) {
    const videoUrl = videoStorage.attachTempVideo(result.insertId, body.video_path);
    if (videoUrl) {
      await pool.query('UPDATE questions SET video_path = ? WHERE id = ?', [videoUrl, result.insertId]);
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
    difficulties: DIFFICULTIES,
    maxClues: MAX_CLUES,
    error: null,
  });
}

async function updateQuestion(req, res) {
  const body = req.body || {};
  const options = collectOptionsFromBody(body);
  const correctIndex = Number(body.correct_index);
  const difficulty = DIFFICULTIES.includes(body.difficulty) ? body.difficulty : 'easy';
  const clues = body.type === 'progressive' ? collectCluesFromBody(body) : null;
  const optionImagePrompts = collectOptionImagePromptsFromBody(body);

  await pool.query(
    `UPDATE questions SET
      category_id=?, type=?, difficulty=?, label=?, prompt=?, instruct_text=?, media_placeholder=?, media_duration=?, emojis=?,
      options=?, option_image_prompts=?, correct_index=?, clues=?, timer_seconds=?, video_prompt=?
     WHERE id=?`,
    [
      body.category_id,
      body.type,
      difficulty,
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
      body.video_prompt ? body.video_prompt.trim() : null,
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
      const { categories, questions } = await fetchQuestionsListData(null);
      return res.status(409).render('admin/questions/list', {
        admin: req.admin,
        categories,
        questions,
        selectedCategoryId: null,
        error: 'Cannot delete: this question already has answers recorded against it.',
        importedCount: null,
        bulkDeletedCount: null,
        bulkUpdatedCount: null,
      });
    }
    throw err;
  }
}

/**
 * Deletes every selected question, tolerating the same FK-referenced case as the
 * single-delete path (a question with recorded answers can't be deleted) — rather
 * than failing the whole batch, it deletes everything else and reports which ids
 * were blocked.
 */
async function bulkDeleteQuestions(req, res) {
  const ids = collectBulkIds(req.body);
  if (ids.length === 0) return res.redirect('/admin/questions');

  let deletedCount = 0;
  const blockedIds = [];
  for (const id of ids) {
    try {
      const [result] = await pool.query('DELETE FROM questions WHERE id = ?', [id]);
      if (result.affectedRows > 0) deletedCount += 1;
    } catch (err) {
      if (err.code === 'ER_ROW_IS_REFERENCED_2' || err.code === 'ER_ROW_IS_REFERENCED') {
        blockedIds.push(id);
        continue;
      }
      throw err;
    }
  }

  if (blockedIds.length === 0) {
    return res.redirect(`/admin/questions?bulk_deleted=${deletedCount}`);
  }

  const { categories, questions } = await fetchQuestionsListData(null);
  res.status(409).render('admin/questions/list', {
    admin: req.admin,
    categories,
    questions,
    selectedCategoryId: null,
    error:
      `Deleted ${deletedCount} of ${ids.length} selected question(s). ${blockedIds.length} couldn't be ` +
      `deleted because they already have answers recorded (IDs: ${blockedIds.join(', ')}).`,
    importedCount: null,
    bulkDeletedCount: null,
    bulkUpdatedCount: null,
  });
}

/** Shows the bulk-edit form for the selected questions. */
async function bulkEditForm(req, res) {
  const ids = collectBulkIds(req.body);
  if (ids.length === 0) return res.redirect('/admin/questions');

  const [categories] = await pool.query('SELECT * FROM categories ORDER BY name');
  const [questions] = await pool.query(
    `SELECT q.*, c.name AS category_name FROM questions q
     JOIN categories c ON c.id = q.category_id
     WHERE q.id IN (?)
     ORDER BY q.id DESC`,
    [ids]
  );
  res.render('admin/questions/bulk_edit', {
    admin: req.admin,
    categories,
    questions,
    ids,
    difficulties: DIFFICULTIES,
    error: null,
  });
}

/**
 * Applies bulk-edit changes to every selected question in one UPDATE — only the
 * fields the admin actually filled in are changed (an empty field means "leave
 * this alone"), unlike the single-question edit form which always rewrites every
 * column. Only category/difficulty/timer are offered: everything else (prompt,
 * options, media, clues, ...) is inherently per-question content.
 */
async function bulkEditConfirm(req, res) {
  const body = req.body || {};
  const ids = collectBulkIds(body);
  if (ids.length === 0) return res.redirect('/admin/questions');

  const setClauses = [];
  const params = [];
  if (body.category_id) {
    setClauses.push('category_id = ?');
    params.push(Number(body.category_id));
  }
  if (DIFFICULTIES.includes(body.difficulty)) {
    setClauses.push('difficulty = ?');
    params.push(body.difficulty);
  }
  if (body.timer_seconds !== undefined && body.timer_seconds !== '') {
    const timerSeconds = Number(body.timer_seconds);
    if (Number.isInteger(timerSeconds) && timerSeconds >= 0) {
      setClauses.push('timer_seconds = ?');
      params.push(timerSeconds);
    }
  }

  if (setClauses.length === 0) {
    const [categories] = await pool.query('SELECT * FROM categories ORDER BY name');
    const [questions] = await pool.query(
      `SELECT q.*, c.name AS category_name FROM questions q
       JOIN categories c ON c.id = q.category_id
       WHERE q.id IN (?)
       ORDER BY q.id DESC`,
      [ids]
    );
    return res.status(400).render('admin/questions/bulk_edit', {
      admin: req.admin,
      categories,
      questions,
      ids,
      difficulties: DIFFICULTIES,
      error: 'Choose at least one field to change.',
    });
  }

  params.push(ids);
  await pool.query(`UPDATE questions SET ${setClauses.join(', ')} WHERE id IN (?)`, params);
  res.redirect(`/admin/questions?bulk_updated=${ids.length}`);
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

  const [apiKey, workspaceId] = await Promise.all([
    settingsService.getSetting(CLAUDE_KEY_SETTING),
    settingsService.getSetting(CLAUDE_WORKSPACE_SETTING),
  ]);
  if (!apiKey) {
    return res.status(400).render('admin/questions/generate', {
      admin: req.admin,
      categories,
      error: 'Add a Claude API key in Settings first.',
    });
  }

  let suggestions;
  try {
    suggestions = await claudeService.generateQuestions({ apiKey, workspaceId, categoryName: category.name, count });
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
    difficulties: DIFFICULTIES,
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
    const difficulty = DIFFICULTIES.includes(row.difficulty) ? row.difficulty : 'easy';
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
        (category_id, type, difficulty, label, prompt, instruct_text, media_placeholder, media_duration, emojis, options, option_image_prompts, correct_index, clues, timer_seconds, video_prompt)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        categoryId,
        row.type,
        difficulty,
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
        row.video_prompt ? row.video_prompt.trim() : null,
      ]
    );

    if (row.audio_path) {
      const audioUrl = audioStorage.attachTempAudio(result.insertId, row.audio_path);
      if (audioUrl) {
        await pool.query('UPDATE questions SET audio_path = ? WHERE id = ?', [audioUrl, result.insertId]);
      }
    }

    if (row.video_path) {
      const videoUrl = videoStorage.attachTempVideo(result.insertId, row.video_path);
      if (videoUrl) {
        await pool.query('UPDATE questions SET video_path = ? WHERE id = ?', [videoUrl, result.insertId]);
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

// ---- Bulk JSON import ----

async function importForm(req, res) {
  const [categories] = await pool.query('SELECT * FROM categories ORDER BY name');
  res.render('admin/questions/import', { admin: req.admin, categories, error: null });
}

async function importPreview(req, res) {
  const body = req.body || {};
  const [categories] = await pool.query('SELECT * FROM categories ORDER BY name');

  let parsed;
  try {
    parsed = JSON.parse(body.payload || '');
  } catch (err) {
    return res.status(400).render('admin/questions/import', {
      admin: req.admin,
      categories,
      error: 'That file is not valid JSON.',
    });
  }

  const rawQuestions = Array.isArray(parsed)
    ? parsed
    : parsed && Array.isArray(parsed.questions)
    ? parsed.questions
    : null;

  if (!rawQuestions || rawQuestions.length === 0) {
    return res.status(400).render('admin/questions/import', {
      admin: req.admin,
      categories,
      error: 'Expected a JSON object with a "questions" array containing at least one question.',
    });
  }

  const categoryBySlug = new Map(categories.map((c) => [c.key_slug.toLowerCase(), c.id]));
  const categoryIds = new Set(categories.map((c) => c.id));

  const questions = rawQuestions.map((raw, idx) => {
    const q = raw && typeof raw === 'object' ? raw : {};
    let categoryId = '';
    if (q.category != null) {
      categoryId = categoryBySlug.get(String(q.category).trim().toLowerCase()) || '';
    }
    if (!categoryId && q.category_id != null && categoryIds.has(Number(q.category_id))) {
      categoryId = Number(q.category_id);
    }
    return {
      key: `q${idx}`,
      category_id: categoryId,
      type: QUESTION_TYPES.includes(q.type) ? q.type : 'text',
      difficulty: DIFFICULTIES.includes(q.difficulty) ? q.difficulty : 'easy',
      label: q.label || '',
      prompt: q.prompt || '',
      instruct_text: q.instruct_text || '',
      media_placeholder: q.media_placeholder || '',
      media_duration: q.media_duration || '',
      emojis: q.emojis || '',
      options: Array.isArray(q.options) ? q.options : ['', '', '', ''],
      correct_index: q.correct_index,
      clues: Array.isArray(q.clues) ? q.clues : [],
      timer_seconds: q.timer_seconds || 0,
    };
  });

  res.render('admin/questions/import_review', {
    admin: req.admin,
    categories,
    questions,
    types: QUESTION_TYPES,
    difficulties: DIFFICULTIES,
    maxClues: MAX_CLUES,
    error: null,
  });
}

async function importConfirm(req, res) {
  const body = req.body || {};
  const rows = Object.values(body.questions || {});
  if (rows.length === 0) {
    return res.redirect('/admin/questions');
  }

  const [categories] = await pool.query('SELECT id FROM categories');
  const validCategoryIds = new Set(categories.map((c) => c.id));

  let insertedCount = 0;
  for (const row of rows) {
    const options = collectOptionsFromBody(row);
    const correctIndex = Number(row.correct_index);
    const difficulty = DIFFICULTIES.includes(row.difficulty) ? row.difficulty : 'easy';
    const categoryId = Number(row.category_id);
    const isValid =
      validCategoryIds.has(categoryId) &&
      QUESTION_TYPES.includes(row.type) &&
      row.label &&
      row.prompt &&
      options.every((o) => o.length > 0) &&
      Number.isInteger(correctIndex) &&
      correctIndex >= 0 &&
      correctIndex < 4;
    if (!isValid) continue; // silently skip malformed rows rather than fail the whole batch

    const clues = row.type === 'progressive' ? collectCluesFromBody(row) : null;

    await pool.query(
      `INSERT INTO questions
        (category_id, type, difficulty, label, prompt, instruct_text, media_placeholder, media_duration, emojis, options, correct_index, clues, timer_seconds)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        categoryId,
        row.type,
        difficulty,
        row.label.trim(),
        row.prompt.trim(),
        row.instruct_text ? row.instruct_text.trim() : null,
        row.media_placeholder ? row.media_placeholder.trim() : null,
        row.media_duration ? row.media_duration.trim() : null,
        row.emojis ? row.emojis.trim() : null,
        JSON.stringify(options),
        correctIndex,
        clues && clues.length ? JSON.stringify(clues) : null,
        Number(row.timer_seconds) || 0,
      ]
    );
    insertedCount++;
  }

  res.redirect(`/admin/questions?imported=${insertedCount}`);
}

// ---- AI single-question fill (New question form) ----

/** Drafts one full question for the given category via Claude — same call the
 *  bulk "Generate with AI" flow uses (generateQuestions with count: 1), just
 *  handed straight back as JSON to fill the New question form's fields in
 *  place instead of going through the separate draft-then-review screen. */
async function aiFillQuestion(req, res) {
  const categoryId = Number((req.body || {}).category_id);
  const [categories] = await pool.query('SELECT * FROM categories ORDER BY name');
  const category = categories.find((c) => c.id === categoryId);
  if (!category) {
    return res.status(400).json({ error: 'Choose a category first.' });
  }

  const [apiKey, workspaceId] = await Promise.all([
    settingsService.getSetting(CLAUDE_KEY_SETTING),
    settingsService.getSetting(CLAUDE_WORKSPACE_SETTING),
  ]);
  if (!apiKey) {
    return res.status(400).json({ error: 'Add a Claude API key in Settings first.' });
  }

  try {
    const [question] = await claudeService.generateQuestions({
      apiKey,
      workspaceId,
      categoryName: category.name,
      count: 1,
    });
    if (!question) throw new Error('Claude did not return a question. Try again.');
    res.json({ question });
  } catch (err) {
    res.status(502).json({ error: claudeService.friendlyErrorMessage(err) });
  }
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

// ---- AI video generation ----
//
// Unlike audio/image, this is a two-step submit-then-poll flow, not a single
// request-blocks-until-done call — a video job can take minutes to 20-30
// minutes (see video.service.js), far too long to hold one Express request
// open. The browser (admin.js) submits once, then polls the status endpoint
// on its own timer until it reports 'done' or 'failed'.

/** Pre-save: queues a job, not tied to a question id yet. */
async function videoPreviewStart(req, res) {
  const { prompt } = req.body || {};
  const apiKey = await settingsService.getSetting(TTS_KEY_SETTING);
  if (!apiKey) {
    return res.status(400).json({ error: 'Add a Custom AI Key in Settings first.' });
  }
  try {
    const jobId = await videoService.submit({ apiKey, prompt });
    res.json({ job_id: jobId });
  } catch (err) {
    res.status(502).json({ error: videoService.friendlyErrorMessage(err) });
  }
}

/** Pre-save: one poll. On completion, saves to a temp file — caller stashes the
 *  returned video_path in a hidden field, attached to the real row once it's inserted. */
async function videoPreviewStatus(req, res) {
  const apiKey = await settingsService.getSetting(TTS_KEY_SETTING);
  if (!apiKey) {
    return res.status(400).json({ error: 'Add a Custom AI Key in Settings first.' });
  }
  try {
    const result = await videoService.poll({ apiKey, jobId: req.params.jobId });
    if (result.status === 'done') {
      const { videoPath, videoUrl } = videoStorage.saveTempVideo(result.buffer);
      return res.json({ status: 'done', video_url: videoUrl, video_path: videoPath });
    }
    res.json({ status: result.status, queue_position: result.queuePosition });
  } catch (err) {
    res.status(502).json({ error: videoService.friendlyErrorMessage(err) });
  }
}

/** Post-save: question already has an id — queues a job for it. */
async function generateVideoForQuestionStart(req, res) {
  const { prompt } = req.body || {};
  const apiKey = await settingsService.getSetting(TTS_KEY_SETTING);
  if (!apiKey) {
    return res.status(400).json({ error: 'Add a Custom AI Key in Settings first.' });
  }
  try {
    const jobId = await videoService.submit({ apiKey, prompt });
    res.json({ job_id: jobId });
  } catch (err) {
    res.status(502).json({ error: videoService.friendlyErrorMessage(err) });
  }
}

/** Post-save: one poll. On completion, writes straight to the question's permanent slot. */
async function generateVideoForQuestionStatus(req, res) {
  const questionId = Number(req.params.id);
  const apiKey = await settingsService.getSetting(TTS_KEY_SETTING);
  if (!apiKey) {
    return res.status(400).json({ error: 'Add a Custom AI Key in Settings first.' });
  }
  try {
    const result = await videoService.poll({ apiKey, jobId: req.params.jobId });
    if (result.status === 'done') {
      const videoUrl = videoStorage.saveVideoForQuestion(questionId, result.buffer);
      await pool.query('UPDATE questions SET video_path = ? WHERE id = ?', [videoUrl, questionId]);
      return res.json({ status: 'done', video_url: videoUrl });
    }
    res.json({ status: result.status, queue_position: result.queuePosition });
  } catch (err) {
    res.status(502).json({ error: videoService.friendlyErrorMessage(err) });
  }
}

// ---- Settings ----

async function settingsPage(req, res) {
  const [rows] = await pool.query('SELECT email, display_name FROM players WHERE id = ?', [req.admin.id]);
  const account = rows[0];
  const [claudeKey, workspaceId, ttsKey] = await Promise.all([
    settingsService.getSetting(CLAUDE_KEY_SETTING),
    settingsService.getSetting(CLAUDE_WORKSPACE_SETTING),
    settingsService.getSetting(TTS_KEY_SETTING),
  ]);
  res.render('admin/settings', {
    admin: req.admin,
    account,
    maskedClaudeKey: settingsService.maskKey(claudeKey),
    workspaceId,
    maskedTtsKey: settingsService.maskKey(ttsKey),
    accountError: null,
    accountSuccess: null,
    claudeKeyError: null,
    claudeKeySuccess: null,
    ttsKeyError: null,
    ttsKeySuccess: null,
    dangerZoneError: null,
    dangerZoneSuccess: null,
  });
}

async function renderSettingsWithError(req, res, status, overrides) {
  const [rows] = await pool.query('SELECT email, display_name FROM players WHERE id = ?', [req.admin.id]);
  const [claudeKey, workspaceId, ttsKey] = await Promise.all([
    settingsService.getSetting(CLAUDE_KEY_SETTING),
    settingsService.getSetting(CLAUDE_WORKSPACE_SETTING),
    settingsService.getSetting(TTS_KEY_SETTING),
  ]);
  res.status(status).render('admin/settings', {
    admin: req.admin,
    account: rows[0],
    maskedClaudeKey: settingsService.maskKey(claudeKey),
    workspaceId,
    maskedTtsKey: settingsService.maskKey(ttsKey),
    accountError: null,
    accountSuccess: null,
    claudeKeyError: null,
    claudeKeySuccess: null,
    ttsKeyError: null,
    ttsKeySuccess: null,
    dangerZoneError: null,
    dangerZoneSuccess: null,
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
  const { api_key: apiKey, workspace_id: workspaceId } = req.body || {};
  const hasExistingKey = Boolean(await settingsService.getSetting(CLAUDE_KEY_SETTING));
  // The key field is required the first time, but a saved key is never shown again
  // (by design), so a blank submission afterward just means "leave it as-is" — e.g.
  // saving the Workspace ID alone without having to re-paste the key too.
  if (!hasExistingKey && (!apiKey || !apiKey.trim())) {
    return renderSettingsWithError(req, res, 400, { claudeKeyError: 'Enter a key to save.' });
  }
  if (apiKey && apiKey.trim()) {
    await settingsService.setSetting(CLAUDE_KEY_SETTING, apiKey.trim());
  }
  // Optional — only "identity-linked" keys need it (see claude.service.js). An
  // empty submission clears it rather than leaving a stale value behind.
  if (workspaceId && workspaceId.trim()) {
    await settingsService.setSetting(CLAUDE_WORKSPACE_SETTING, workspaceId.trim());
  } else {
    await settingsService.deleteSetting(CLAUDE_WORKSPACE_SETTING);
  }
  await renderSettingsWithError(req, res, 200, { claudeKeySuccess: 'Claude API key saved.' });
}

async function removeClaudeKey(req, res) {
  await settingsService.deleteSetting(CLAUDE_KEY_SETTING);
  await settingsService.deleteSetting(CLAUDE_WORKSPACE_SETTING);
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

const CLEAR_DATA_CONFIRM_PHRASE = 'DELETE ALL DATA';

/**
 * Full reset: deletes every player (except admin accounts), question, game
 * session, answer, achievement, mission-progress record, and daily-rush
 * record. Categories and app_settings (API keys) are deliberately kept —
 * this clears out player/game data, not the app's own configuration.
 *
 * Gated the same way updateAccount gates a password change (current password
 * required) PLUS a typed confirmation phrase, since this is irreversible and
 * far more consequential than anything else in Settings.
 */
async function clearAllData(req, res) {
  const { current_password: currentPassword, confirm_phrase: confirmPhrase } = req.body || {};

  const [rows] = await pool.query('SELECT * FROM players WHERE id = ?', [req.admin.id]);
  const account = rows[0];
  const passwordMatches = account && (await bcrypt.compare(currentPassword || '', account.password_hash));
  if (!passwordMatches) {
    return renderSettingsWithError(req, res, 401, { dangerZoneError: 'Current password is incorrect.' });
  }
  if (confirmPhrase !== CLEAR_DATA_CONFIRM_PHRASE) {
    return renderSettingsWithError(req, res, 400, {
      dangerZoneError: `Type "${CLEAR_DATA_CONFIRM_PHRASE}" exactly to confirm.`,
    });
  }

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    // Deletion order respects FK dependencies: each table here is deleted only
    // once every table that references it has already been fully cleared.
    const [answersResult] = await connection.query('DELETE FROM answers');
    const [dailyResult] = await connection.query('DELETE FROM daily_rush_attempts');
    const [achievementsResult] = await connection.query('DELETE FROM player_achievements');
    const [missionsResult] = await connection.query('DELETE FROM player_mission_progress');
    const [sessionsResult] = await connection.query('DELETE FROM game_sessions');
    const [questionsResult] = await connection.query('DELETE FROM questions');
    const [playersResult] = await connection.query("DELETE FROM players WHERE role != 'admin'");
    await connection.commit();

    await renderSettingsWithError(req, res, 200, {
      dangerZoneSuccess:
        `Cleared all data — ${playersResult.affectedRows} player(s), ${questionsResult.affectedRows} question(s), ` +
        `${sessionsResult.affectedRows} session(s), ${answersResult.affectedRows} answer(s), ` +
        `${achievementsResult.affectedRows} achievement(s), ${missionsResult.affectedRows} mission record(s), ` +
        `${dailyResult.affectedRows} daily-rush record(s). Categories and admin accounts were kept.`,
    });
  } catch (err) {
    await connection.rollback();
    throw err;
  } finally {
    connection.release();
  }
}

module.exports = {
  loginForm,
  login,
  logout,
  dashboard,
  listPlayers,
  playerDetail,
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
  bulkDeleteQuestions,
  bulkEditForm,
  bulkEditConfirm,
  generateForm,
  generatePreview,
  generateConfirm,
  importForm,
  importPreview,
  importConfirm,
  aiFillQuestion,
  audioPreview,
  generateAudioForQuestion,
  imagePreview,
  generateImageForQuestionOption,
  videoPreviewStart,
  videoPreviewStatus,
  generateVideoForQuestionStart,
  generateVideoForQuestionStatus,
  settingsPage,
  updateAccount,
  updateClaudeKey,
  removeClaudeKey,
  updateTtsKey,
  removeTtsKey,
  clearAllData,
};
