const bcrypt = require('bcryptjs');
const mysql = require('mysql2/promise');
require('dotenv').config();

const CATEGORIES = [
  { key_slug: 'movies', name: 'Movies', emoji: '🎬', color_hex: '#A24AFF' },
  { key_slug: 'music', name: 'Music', emoji: '🎵', color_hex: '#FB2B9A' },
  { key_slug: 'characters', name: 'Characters', emoji: '🎭', color_hex: '#FF6800' },
  { key_slug: 'general', name: 'General Knowledge', emoji: '🌍', color_hex: '#009DF1' },
  { key_slug: 'sounds', name: 'Funny Sounds', emoji: '😂', color_hex: '#D6B700' },
  { key_slug: 'tv', name: 'TV Shows', emoji: '📺', color_hex: '#376EFF' },
  { key_slug: 'games', name: 'Games', emoji: '🎮', color_hex: '#FF2F64' },
  { key_slug: 'trivia', name: 'Trivia', emoji: '🧠', color_hex: '#00ADB1' },
];

// All ported from the "movies" category — the only one with authored questions today.
const QUESTIONS = [
  {
    category_slug: 'movies',
    type: 'image',
    label: 'LOOK & GUESS 👀',
    prompt: 'Who is this character?',
    media_placeholder: 'character portrait',
    media_duration: null,
    emojis: null,
    options: ['Elsa', 'Moana', 'Anna', 'Rapunzel'],
    correct_index: 0,
    clues: null,
    timer_seconds: 15,
  },
  {
    category_slug: 'movies',
    type: 'audio',
    label: 'LISTEN & GUESS 🎧',
    prompt: 'Who is speaking?',
    media_placeholder: null,
    media_duration: '0:12',
    emojis: null,
    options: ['Genie', 'Olaf', 'Sebastian', 'Timon'],
    correct_index: 1,
    clues: null,
    timer_seconds: 12,
  },
  {
    category_slug: 'movies',
    type: 'video',
    label: 'WATCH & GUESS 🎬',
    prompt: 'Which movie is this from?',
    media_placeholder: null,
    media_duration: '0:08',
    emojis: null,
    options: ['Frozen', 'Moana', 'Encanto', 'Tangled'],
    correct_index: 2,
    clues: null,
    timer_seconds: 15,
  },
  {
    category_slug: 'movies',
    type: 'text',
    label: 'READ & ANSWER 🧠',
    prompt: 'Which movie features a talking snowman named Olaf?',
    media_placeholder: null,
    media_duration: null,
    emojis: null,
    options: ['Frozen', 'Moana', 'Brave', 'Coco'],
    correct_index: 0,
    clues: null,
    timer_seconds: 0,
  },
  {
    category_slug: 'movies',
    type: 'emoji',
    label: 'DECODE & GUESS 🔤',
    prompt: 'Guess the movie',
    media_placeholder: null,
    media_duration: null,
    emojis: '❄️👸⛄🏰',
    options: ['Frozen', 'Tangled', 'Brave', 'Moana'],
    correct_index: 0,
    clues: null,
    timer_seconds: 0,
  },
  {
    category_slug: 'movies',
    type: 'progressive',
    label: 'CLUE BY CLUE 🕵️',
    prompt: 'Guess the character',
    media_placeholder: null,
    media_duration: null,
    emojis: null,
    options: ['Moana', 'Ariel', 'Elsa', 'Pocahontas'],
    correct_index: 0,
    clues: [
      'Lives by the ocean',
      'Sails beyond the reef',
      'Daughter of the village chief',
      'Guided by the ocean itself',
    ],
    timer_seconds: 0,
  },
];

async function seed() {
  const pool = await mysql.createConnection({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
  });

  const categoryIds = {};
  for (const cat of CATEGORIES) {
    await pool.query(
      `INSERT INTO categories (key_slug, name, emoji, color_hex) VALUES (?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE name=VALUES(name), emoji=VALUES(emoji), color_hex=VALUES(color_hex)`,
      [cat.key_slug, cat.name, cat.emoji, cat.color_hex]
    );
    const [rows] = await pool.query('SELECT id FROM categories WHERE key_slug = ?', [cat.key_slug]);
    categoryIds[cat.key_slug] = rows[0].id;
  }
  console.log(`Seeded ${CATEGORIES.length} categories.`);

  const [[{ count }]] = await pool.query(
    `SELECT COUNT(*) AS count FROM questions WHERE category_id = ?`,
    [categoryIds.movies]
  );
  if (count === 0) {
    for (const q of QUESTIONS) {
      await pool.query(
        `INSERT INTO questions
          (category_id, type, label, prompt, media_placeholder, media_duration, emojis, options, correct_index, clues, timer_seconds)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          categoryIds[q.category_slug],
          q.type,
          q.label,
          q.prompt,
          q.media_placeholder,
          q.media_duration,
          q.emojis,
          JSON.stringify(q.options),
          q.correct_index,
          q.clues ? JSON.stringify(q.clues) : null,
          q.timer_seconds,
        ]
      );
    }
    console.log(`Seeded ${QUESTIONS.length} questions.`);
  } else {
    console.log('Questions already seeded, skipping.');
  }

  const adminEmail = process.env.ADMIN_EMAIL;
  const adminPassword = process.env.ADMIN_PASSWORD;
  if (adminEmail && adminPassword) {
    const [existing] = await pool.query('SELECT id FROM players WHERE email = ?', [adminEmail]);
    if (existing.length === 0) {
      const hash = await bcrypt.hash(adminPassword, 10);
      await pool.query(
        `INSERT INTO players (email, password_hash, display_name, role) VALUES (?, ?, ?, 'admin')`,
        [adminEmail, hash, 'Admin']
      );
      console.log(`Seeded admin account: ${adminEmail}`);
    } else {
      console.log('Admin account already exists, skipping.');
    }
  } else {
    console.log('ADMIN_EMAIL/ADMIN_PASSWORD not set — skipping admin account seed.');
  }

  await pool.end();
}

seed().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
