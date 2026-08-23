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
  // Persistent player progression (Phase 3): lifetime XP/level and lifetime stats/records on
  // players, achievement unlocks in their own table, and a per-session record of what a
  // completed Rush actually granted so /finish stays idempotent on repeat calls.
  'ALTER TABLE players ADD COLUMN level INT NOT NULL DEFAULT 1 AFTER role',
  'ALTER TABLE players ADD COLUMN lifetime_xp INT NOT NULL DEFAULT 0 AFTER level',
  'ALTER TABLE players ADD COLUMN rushes_completed INT NOT NULL DEFAULT 0 AFTER lifetime_xp',
  'ALTER TABLE players ADD COLUMN questions_answered INT NOT NULL DEFAULT 0 AFTER rushes_completed',
  'ALTER TABLE players ADD COLUMN questions_correct INT NOT NULL DEFAULT 0 AFTER questions_answered',
  'ALTER TABLE players ADD COLUMN total_response_time_ms BIGINT NOT NULL DEFAULT 0 AFTER questions_correct',
  'ALTER TABLE players ADD COLUMN best_rush_score INT NOT NULL DEFAULT 0 AFTER total_response_time_ms',
  'ALTER TABLE players ADD COLUMN best_streak INT NOT NULL DEFAULT 0 AFTER best_rush_score',
  'ALTER TABLE players ADD COLUMN best_accuracy_pct INT NOT NULL DEFAULT 0 AFTER best_streak',
  'ALTER TABLE players ADD COLUMN fastest_avg_response_time_ms INT NULL DEFAULT NULL AFTER best_accuracy_pct',
  'ALTER TABLE players ADD COLUMN perfect_rush_count INT NOT NULL DEFAULT 0 AFTER fastest_avg_response_time_ms',
  'ALTER TABLE game_sessions ADD COLUMN xp_awarded INT NOT NULL DEFAULT 0 AFTER ended_at',
  'ALTER TABLE game_sessions ADD COLUMN progression_applied TINYINT(1) NOT NULL DEFAULT 0 AFTER xp_awarded',
];

// Backfills players' lifetime stats/records from their existing completed game_sessions/answers
// history, for databases that had Rush data before Phase 3 added persistent progression. Safe
// to run repeatedly — recomputes from source data rather than incrementing, so it can't double-count.
// New rows going forward are handled incrementally by applyRushProgression() instead.
const BACKFILL_PLAYER_STATS_SQL = `
  UPDATE players p
  LEFT JOIN (
    SELECT
      gs.player_id,
      COUNT(*) AS rushes_completed,
      COALESCE(SUM(gs.correct_count + gs.wrong_count), 0) AS questions_answered,
      COALESCE(SUM(gs.correct_count), 0) AS questions_correct,
      COALESCE(MAX(gs.score), 0) AS best_rush_score,
      COALESCE(MAX(gs.best_streak), 0) AS best_streak,
      COALESCE(SUM(gs.correct_count + gs.wrong_count > 0 AND gs.wrong_count = 0), 0) AS perfect_rush_count,
      COALESCE(MAX(ROUND(gs.correct_count / NULLIF(gs.correct_count + gs.wrong_count, 0) * 100)), 0) AS best_accuracy_pct
    FROM game_sessions gs
    WHERE gs.status = 'completed'
    GROUP BY gs.player_id
  ) agg ON agg.player_id = p.id
  LEFT JOIN (
    SELECT gs.player_id, COALESCE(SUM(a.server_elapsed_ms), 0) AS total_response_time_ms
    FROM answers a JOIN game_sessions gs ON gs.id = a.session_id
    GROUP BY gs.player_id
  ) rt ON rt.player_id = p.id
  SET
    p.rushes_completed = COALESCE(agg.rushes_completed, 0),
    p.questions_answered = COALESCE(agg.questions_answered, 0),
    p.questions_correct = COALESCE(agg.questions_correct, 0),
    p.best_rush_score = COALESCE(agg.best_rush_score, 0),
    p.best_streak = COALESCE(agg.best_streak, 0),
    p.perfect_rush_count = COALESCE(agg.perfect_rush_count, 0),
    p.best_accuracy_pct = COALESCE(agg.best_accuracy_pct, 0),
    p.total_response_time_ms = COALESCE(rt.total_response_time_ms, 0)
  WHERE p.rushes_completed = 0 AND agg.rushes_completed > 0
`;

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

  // Existing players' lifetime XP/level start fresh under the new progression system (XP is a
  // new mechanic, not retroactively computable the same way stats are) — but their historical
  // stats/records ARE recomputed here so a profile screen doesn't show a misleading "0" for a
  // player who's actually completed Rushes before this migration existed.
  const [backfillResult] = await connection.query(BACKFILL_PLAYER_STATS_SQL);
  if (backfillResult.affectedRows > 0) {
    console.log(`Backfilled lifetime stats for ${backfillResult.affectedRows} existing player(s).`);
  }

  await connection.end();
}

migrate().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});
