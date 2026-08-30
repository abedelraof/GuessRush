const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const VIDEO_DIR = path.join(__dirname, '..', '..', 'public', 'video');
const TMP_DIR = path.join(VIDEO_DIR, 'tmp');

fs.mkdirSync(TMP_DIR, { recursive: true });

/** Writes a freshly-generated clip to a temp file, before it's tied to a question id. */
function saveTempVideo(buffer) {
  const filename = `${crypto.randomUUID()}.mp4`;
  const videoPath = `tmp/${filename}`;
  fs.writeFileSync(path.join(VIDEO_DIR, videoPath), buffer);
  return { videoPath, videoUrl: `/public/video/${videoPath}` };
}

/** Writes straight to a question's permanent slot — used when the question id already exists. */
function saveVideoForQuestion(questionId, buffer) {
  const videoPath = `${questionId}.mp4`;
  fs.writeFileSync(path.join(VIDEO_DIR, videoPath), buffer);
  return `/public/video/${videoPath}`;
}

/** Moves a temp clip (from saveTempVideo) to its permanent slot once the question is saved. */
function attachTempVideo(questionId, tempVideoPath) {
  if (!tempVideoPath) return null;
  const from = path.join(VIDEO_DIR, tempVideoPath);
  if (!fs.existsSync(from)) return null;
  const videoPath = `${questionId}.mp4`;
  fs.renameSync(from, path.join(VIDEO_DIR, videoPath));
  return `/public/video/${videoPath}`;
}

/** Best-effort cleanup of abandoned pre-save clips (discarded review cards, never-submitted forms). */
function sweepStaleTempVideo(maxAgeMs = 24 * 60 * 60 * 1000) {
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

module.exports = { saveTempVideo, saveVideoForQuestion, attachTempVideo, sweepStaleTempVideo };
