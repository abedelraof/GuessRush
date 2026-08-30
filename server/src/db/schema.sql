CREATE TABLE IF NOT EXISTS categories (
  id INT PRIMARY KEY AUTO_INCREMENT,
  key_slug VARCHAR(32) NOT NULL UNIQUE,
  name VARCHAR(64) NOT NULL,
  emoji VARCHAR(8) NOT NULL,
  color_hex CHAR(7) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS questions (
  id INT PRIMARY KEY AUTO_INCREMENT,
  category_id INT NOT NULL,
  type ENUM('image','audio','video','text','emoji','progressive') NOT NULL,
  difficulty ENUM('easy','medium','hard','extreme') NOT NULL DEFAULT 'easy',
  label VARCHAR(64) NOT NULL,
  prompt VARCHAR(255) NOT NULL,
  instruct_text VARCHAR(500) NULL,
  media_placeholder VARCHAR(255) NULL,
  media_duration VARCHAR(16) NULL,
  emojis VARCHAR(32) NULL,
  options JSON NOT NULL,
  option_image_prompts JSON NULL,
  option_image_paths JSON NULL,
  correct_index TINYINT NOT NULL,
  clues JSON NULL,
  audio_path VARCHAR(255) NULL,
  video_prompt VARCHAR(2000) NULL,
  video_path VARCHAR(255) NULL,
  timer_seconds SMALLINT NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (category_id) REFERENCES categories(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS players (
  id INT PRIMARY KEY AUTO_INCREMENT,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  display_name VARCHAR(64) NOT NULL,
  role ENUM('player','admin') NOT NULL DEFAULT 'player',
  -- Persistent progression (Phase 3) — server-authoritative, updated only by
  -- applyRushProgression() inside the /finish transaction. level is a cached
  -- projection of lifetime_xp (see progression.service.js's XP curve),
  -- kept in sync on every award so simple reads don't need to recompute it.
  level INT NOT NULL DEFAULT 1,
  lifetime_xp INT NOT NULL DEFAULT 0,
  rushes_completed INT NOT NULL DEFAULT 0,
  questions_answered INT NOT NULL DEFAULT 0,
  questions_correct INT NOT NULL DEFAULT 0,
  total_response_time_ms BIGINT NOT NULL DEFAULT 0,
  best_rush_score INT NOT NULL DEFAULT 0,
  best_streak INT NOT NULL DEFAULT 0,
  best_accuracy_pct INT NOT NULL DEFAULT 0,
  fastest_avg_response_time_ms INT NULL DEFAULT NULL,
  perfect_rush_count INT NOT NULL DEFAULT 0,
  -- Daily play streak (Phase 6) — deliberately separate from best_streak above,
  -- which is the in-game answer streak. Updated only by dailyStreak.service's
  -- applyDailyStreak(), on completing the official Daily Rush for the day.
  daily_streak_current INT NOT NULL DEFAULT 0,
  daily_streak_longest INT NOT NULL DEFAULT 0,
  daily_streak_last_date DATE NULL DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- One row per unlocked achievement per player. The unique constraint is what
-- makes awarding idempotent — INSERT IGNORE against it is a no-op for an
-- achievement the player already has, never a duplicate row or an error.
CREATE TABLE IF NOT EXISTS player_achievements (
  id INT PRIMARY KEY AUTO_INCREMENT,
  player_id INT NOT NULL,
  achievement_key VARCHAR(64) NOT NULL,
  unlocked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (player_id) REFERENCES players(id),
  UNIQUE KEY uniq_player_achievement (player_id, achievement_key)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS game_sessions (
  id INT PRIMARY KEY AUTO_INCREMENT,
  player_id INT NOT NULL,
  -- NULL for a Pick Your Rush session (quick/chaos/streak/chill) — those pull across every
  -- category, so there's no single category to record. Still NOT NULL-equivalent in practice
  -- for the legacy single-category flow (`mode` = 'single_category').
  category_id INT NULL,
  -- 'single_category' is the original "pick a category" Rush (createSession). The rest are
  -- Pick Your Rush's game modes (see questionSelection.service.js's selectVariedRushQuestions).
  mode ENUM('single_category','quick_rush','chaos_rush','streak_rush','chill_rush') NOT NULL DEFAULT 'single_category',
  status ENUM('in_progress','completed') NOT NULL DEFAULT 'in_progress',
  question_ids JSON NOT NULL,
  current_index INT NOT NULL DEFAULT 0,
  question_started_at TIMESTAMP NULL DEFAULT NULL,
  question_start_pinged TINYINT(1) NOT NULL DEFAULT 0,
  score INT NOT NULL DEFAULT 0,
  streak INT NOT NULL DEFAULT 0,
  best_streak INT NOT NULL DEFAULT 0,
  correct_count INT NOT NULL DEFAULT 0,
  wrong_count INT NOT NULL DEFAULT 0,
  started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  ended_at TIMESTAMP NULL,
  -- Set once, by applyRushProgression on the in_progress -> completed transition — lets a
  -- repeat /finish call report what was already granted instead of re-awarding (idempotency).
  xp_awarded INT NOT NULL DEFAULT 0,
  progression_applied TINYINT(1) NOT NULL DEFAULT 0,
  -- Strategic mechanics (Phase 5) — all server-authoritative, mirroring the
  -- question_started_at/question_start_pinged pattern above: state for the
  -- CURRENT question, read and reset by submitAnswer as current_index advances.
  current_clue_count INT NOT NULL DEFAULT 1,
  remove_one_uses_remaining INT NOT NULL DEFAULT 1,
  remove_one_used_at_index INT NULL DEFAULT NULL,
  removed_option_index INT NULL DEFAULT NULL,
  double_down_offered_at_index INT NULL DEFAULT NULL,
  double_down_choice_index INT NULL DEFAULT NULL,
  double_down_choice ENUM('safe','risky') NULL DEFAULT NULL,
  FOREIGN KEY (player_id) REFERENCES players(id),
  FOREIGN KEY (category_id) REFERENCES categories(id),
  INDEX idx_leaderboard (score DESC)
) ENGINE=InnoDB;

-- Generic encrypted key/value store for admin-configurable settings
-- (e.g. the Anthropic API key). `value` holds an AES-256-GCM blob, never plaintext.
CREATE TABLE IF NOT EXISTS app_settings (
  setting_key VARCHAR(64) PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- One row per player per calendar day (server/UTC date, never client-supplied) —
-- this is what "one official Daily Rush attempt per day" actually enforces: the
-- UNIQUE constraint makes a second /daily-rush/start for the same day either
-- resume the existing session (if unfinished) or just report today's result,
-- never create a second attempt, even under concurrent requests.
CREATE TABLE IF NOT EXISTS daily_rush_attempts (
  id INT PRIMARY KEY AUTO_INCREMENT,
  player_id INT NOT NULL,
  daily_date DATE NOT NULL,
  session_id INT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (player_id) REFERENCES players(id),
  FOREIGN KEY (session_id) REFERENCES game_sessions(id),
  UNIQUE KEY uniq_player_daily (player_id, daily_date)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS answers (
  id INT PRIMARY KEY AUTO_INCREMENT,
  session_id INT NOT NULL,
  question_id INT NOT NULL,
  selected_index TINYINT NOT NULL,
  is_correct BOOLEAN NOT NULL,
  -- Client-reported elapsed time, kept for analytics only — never trusted for scoring.
  response_time_ms INT NOT NULL,
  -- Server-authoritative elapsed time (from question_started_at to submission), used for scoring/timeout.
  server_elapsed_ms INT NOT NULL DEFAULT 0,
  timed_out BOOLEAN NOT NULL DEFAULT FALSE,
  difficulty VARCHAR(16) NOT NULL DEFAULT 'easy',
  base_score INT NOT NULL DEFAULT 0,
  speed_multiplier DECIMAL(4,2) NOT NULL DEFAULT 1.00,
  streak_multiplier DECIMAL(4,2) NOT NULL DEFAULT 1.00,
  streak_after INT NOT NULL DEFAULT 0,
  score INT NOT NULL DEFAULT 0,
  -- Strategic mechanics (Phase 5) breakdown, recorded per answer for the same
  -- "explain how a score was produced" reason as base_score/speed_multiplier above.
  clues_revealed INT NOT NULL DEFAULT 1,
  clue_multiplier DECIMAL(4,2) NOT NULL DEFAULT 1.00,
  remove_one_used BOOLEAN NOT NULL DEFAULT FALSE,
  double_down_choice ENUM('none','safe','risky') NOT NULL DEFAULT 'none',
  double_down_multiplier DECIMAL(4,2) NOT NULL DEFAULT 1.00,
  answered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (session_id) REFERENCES game_sessions(id),
  FOREIGN KEY (question_id) REFERENCES questions(id),
  UNIQUE KEY uniq_session_question (session_id, question_id)
) ENGINE=InnoDB;

-- One row per player per mission per period (period_key is a date string for a
-- 'daily' mission, e.g. "2026-08-24" — see missions.service.js's periodKeyFor).
-- The UNIQUE constraint is what makes accumulating progress across multiple
-- Rushes in the same period safe under concurrent /finish calls: INSERT IGNORE
-- to ensure the row exists, then SELECT ... FOR UPDATE to serialize the update.
CREATE TABLE IF NOT EXISTS player_mission_progress (
  id INT PRIMARY KEY AUTO_INCREMENT,
  player_id INT NOT NULL,
  mission_key VARCHAR(64) NOT NULL,
  period_key VARCHAR(16) NOT NULL,
  progress INT NOT NULL DEFAULT 0,
  completed_at TIMESTAMP NULL DEFAULT NULL,
  FOREIGN KEY (player_id) REFERENCES players(id),
  UNIQUE KEY uniq_player_mission_period (player_id, mission_key, period_key)
) ENGINE=InnoDB;

-- Play With Friends: one row per 1v1 match (random matchmaking or a friend
-- invite code). Capped at exactly two players by design — player_b_id/
-- session_b_id stay NULL until someone joins. The two game_sessions this
-- points at are ordinary Rush sessions (mode='quick_rush') that happen to
-- share the same question_ids — nothing about scoring/gameplay itself is
-- match-aware; see matchProgress.service.js for how presence/results are
-- layered on top without touching sessions.controller.js's core logic.
CREATE TABLE IF NOT EXISTS matches (
  id INT PRIMARY KEY AUTO_INCREMENT,
  mode ENUM('random','friend') NOT NULL,
  status ENUM('waiting','in_progress','completed','cancelled') NOT NULL DEFAULT 'waiting',
  invite_code VARCHAR(8) NULL UNIQUE,
  question_ids JSON NULL,
  player_a_id INT NOT NULL,
  player_b_id INT NULL,
  session_a_id INT NULL,
  session_b_id INT NULL,
  winner_player_id INT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  started_at TIMESTAMP NULL DEFAULT NULL,
  ended_at TIMESTAMP NULL DEFAULT NULL,
  FOREIGN KEY (player_a_id) REFERENCES players(id),
  FOREIGN KEY (player_b_id) REFERENCES players(id),
  FOREIGN KEY (session_a_id) REFERENCES game_sessions(id),
  FOREIGN KEY (session_b_id) REFERENCES game_sessions(id),
  FOREIGN KEY (winner_player_id) REFERENCES players(id)
) ENGINE=InnoDB;
