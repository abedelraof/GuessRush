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
