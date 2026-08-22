const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const IMAGE_DIR = path.join(__dirname, '..', '..', 'public', 'images');
const TMP_DIR = path.join(IMAGE_DIR, 'tmp');

fs.mkdirSync(TMP_DIR, { recursive: true });

/** Writes a freshly-generated image to a temp file, before it's tied to a question/option slot. */
function saveTempImage(buffer) {
  const filename = `${crypto.randomUUID()}.png`;
  const imagePath = `tmp/${filename}`;
  fs.writeFileSync(path.join(IMAGE_DIR, imagePath), buffer);
  return { imagePath, imageUrl: `/public/images/${imagePath}` };
}

/** Writes straight to an option's permanent slot — used when the question id already exists. */
function saveImageForQuestionOption(questionId, optionIndex, buffer) {
  const imagePath = `${questionId}-${optionIndex}.png`;
  fs.writeFileSync(path.join(IMAGE_DIR, imagePath), buffer);
  return `/public/images/${imagePath}`;
}

/** Moves a temp image (from saveTempImage) to its permanent slot once the question is saved. */
function attachTempImage(questionId, optionIndex, tempImagePath) {
  if (!tempImagePath) return null;
  const from = path.join(IMAGE_DIR, tempImagePath);
  if (!fs.existsSync(from)) return null;
  const imagePath = `${questionId}-${optionIndex}.png`;
  fs.renameSync(from, path.join(IMAGE_DIR, imagePath));
  return `/public/images/${imagePath}`;
}

/** Best-effort cleanup of abandoned pre-save images (discarded review cards, never-submitted forms). */
function sweepStaleTempImages(maxAgeMs = 24 * 60 * 60 * 1000) {
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

module.exports = {
  saveTempImage,
  saveImageForQuestionOption,
  attachTempImage,
  sweepStaleTempImages,
};
