const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
require('dotenv').config();

// Columns added after the initial release. schema.sql's CREATE TABLE already
// defines these for fresh installs; this brings pre-existing tables up to date.
// Oracle MySQL has no `ADD COLUMN IF NOT EXISTS` (that's a MariaDB extension),
// so each runs individually and ER_DUP_FIELDNAME (already applied) is ignored.
const COLUMN_MIGRATIONS = [
  'ALTER TABLE questions ADD COLUMN instruct_text VARCHAR(500) NULL AFTER prompt',
  'ALTER TABLE questions ADD COLUMN audio_path VARCHAR(255) NULL AFTER clues',
  'ALTER TABLE questions ADD COLUMN option_image_prompts JSON NULL AFTER options',
  'ALTER TABLE questions ADD COLUMN option_image_paths JSON NULL AFTER option_image_prompts',
  // Rush gameplay (Phase 1): difficulty on questions, progression/timing bookkeeping on
  // game_sessions, and per-answer score breakdown — all backfilled with safe defaults so
  // existing questions, sessions, and answers stay valid and playable.
  "ALTER TABLE questions ADD COLUMN difficulty ENUM('easy','medium','hard','extreme') NOT NULL DEFAULT 'easy' AFTER type",
  'ALTER TABLE game_sessions ADD COLUMN current_index INT NOT NULL DEFAULT 0 AFTER question_ids',
  'ALTER TABLE game_sessions ADD COLUMN question_started_at TIMESTAMP NULL DEFAULT NULL AFTER current_index',
  'ALTER TABLE game_sessions ADD COLUMN question_start_pinged TINYINT(1) NOT NULL DEFAULT 0 AFTER question_started_at',
  'ALTER TABLE answers ADD COLUMN server_elapsed_ms INT NOT NULL DEFAULT 0 AFTER response_time_ms',
  'ALTER TABLE answers ADD COLUMN timed_out BOOLEAN NOT NULL DEFAULT FALSE AFTER server_elapsed_ms',
  "ALTER TABLE answers ADD COLUMN difficulty VARCHAR(16) NOT NULL DEFAULT 'easy' AFTER timed_out",
  'ALTER TABLE answers ADD COLUMN base_score INT NOT NULL DEFAULT 0 AFTER difficulty',
  'ALTER TABLE answers ADD COLUMN speed_multiplier DECIMAL(4,2) NOT NULL DEFAULT 1.00 AFTER base_score',
  'ALTER TABLE answers ADD COLUMN streak_multiplier DECIMAL(4,2) NOT NULL DEFAULT 1.00 AFTER speed_multiplier',
  'ALTER TABLE answers ADD COLUMN streak_after INT NOT NULL DEFAULT 0 AFTER streak_multiplier',
  'ALTER TABLE answers ADD COLUMN score INT NOT NULL DEFAULT 0 AFTER streak_after',
];

async function migrate() {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    multipleStatements: true,
  });

  const schema = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
  await connection.query(schema);
  console.log('Schema applied.');

  for (const statement of COLUMN_MIGRATIONS) {
    try {
      await connection.query(statement);
      console.log(`Applied: ${statement}`);
    } catch (err) {
      if (err.code !== 'ER_DUP_FIELDNAME') throw err;
    }
  }

  await connection.end();
}

migrate().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});
