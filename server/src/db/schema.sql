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
  category_id INT NOT NULL,
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
  answered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (session_id) REFERENCES game_sessions(id),
  FOREIGN KEY (question_id) REFERENCES questions(id),
  UNIQUE KEY uniq_session_question (session_id, question_id)
) ENGINE=InnoDB;
