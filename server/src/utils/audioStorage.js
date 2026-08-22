const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const AUDIO_DIR = path.join(__dirname, '..', '..', 'public', 'audio');
const TMP_DIR = path.join(AUDIO_DIR, 'tmp');

fs.mkdirSync(TMP_DIR, { recursive: true });

/** Writes a freshly-synthesized clip to a temp file, before it's tied to a question id. */
function saveTempAudio(buffer) {
  const filename = `${crypto.randomUUID()}.flac`;
  const audioPath = `tmp/${filename}`;
  fs.writeFileSync(path.join(AUDIO_DIR, audioPath), buffer);
  return { audioPath, audioUrl: `/public/audio/${audioPath}` };
}

/** Writes straight to a question's permanent slot — used when the question id already exists. */
function saveAudioForQuestion(questionId, buffer) {
  const audioPath = `${questionId}.flac`;
  fs.writeFileSync(path.join(AUDIO_DIR, audioPath), buffer);
  return `/public/audio/${audioPath}`;
}

/** Moves a temp clip (from saveTempAudio) to its permanent slot once the question is saved. */
function attachTempAudio(questionId, tempAudioPath) {
  if (!tempAudioPath) return null;
  const from = path.join(AUDIO_DIR, tempAudioPath);
  if (!fs.existsSync(from)) return null;
  const audioPath = `${questionId}.flac`;
  fs.renameSync(from, path.join(AUDIO_DIR, audioPath));
  return `/public/audio/${audioPath}`;
}

/** Best-effort cleanup of abandoned pre-save clips (discarded review cards, never-submitted forms). */
function sweepStaleTempAudio(maxAgeMs = 24 * 60 * 60 * 1000) {
  let entries;
  try {
    entries = fs.readdirSync(TMP_DIR);
  } catch {
    return;
  }
  const now = Date.now();
  for (const name of entries) {
    const filePath = path.join(TMP_DIR, name);
    try {
      const stat = fs.statSync(filePath);
      if (now - stat.mtimeMs > maxAgeMs) fs.unlinkSync(filePath);
    } catch {
      // best-effort — ignore races/permission issues
    }
  }
}

module.exports = { saveTempAudio, saveAudioForQuestion, attachTempAudio, sweepStaleTempAudio };
