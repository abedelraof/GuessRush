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
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS game_sessions (
  id INT PRIMARY KEY AUTO_INCREMENT,
  player_id INT NOT NULL,
  category_id INT NOT NULL,
  status ENUM('in_progress','completed') NOT NULL DEFAULT 'in_progress',
  question_ids JSON NOT NULL,
  score INT NOT NULL DEFAULT 0,
  streak INT NOT NULL DEFAULT 0,
  best_streak INT NOT NULL DEFAULT 0,
  correct_count INT NOT NULL DEFAULT 0,
  wrong_count INT NOT NULL DEFAULT 0,
  started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  ended_at TIMESTAMP NULL,
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
  response_time_ms INT NOT NULL,
  answered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (session_id) REFERENCES game_sessions(id),
  FOREIGN KEY (question_id) REFERENCES questions(id),
  UNIQUE KEY uniq_session_question (session_id, question_id)
) ENGINE=InnoDB;
