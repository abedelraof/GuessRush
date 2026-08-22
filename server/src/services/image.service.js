const BASE_URL = 'https://img.expensebeam.store';
const POLL_INTERVAL_MS = 1500;
const MAX_WAIT_MS = 60000;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

class ImageGenError extends Error {}

/**
 * Submits an image generation job and polls until the PNG is ready.
 * Returns the raw PNG bytes as a Buffer. Mirrors tts.service.js's shape —
 * same async job API, no per-request tuning beyond the prompt (defaults for
 * width/height/steps/etc. are fine for this use case).
 */
async function synthesize({ apiKey, prompt }) {
  if (!apiKey) throw new ImageGenError('No Custom AI Key configured.');
  if (!prompt || !prompt.trim()) throw new ImageGenError('No prompt to generate an image from.');

  const submitRes = await fetch(`${BASE_URL}/image`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-API-Key': apiKey },
    body: JSON.stringify({ prompt: prompt.slice(0, 4000) }),
  });

  if (submitRes.status !== 202) {
    throw new ImageGenError(await extractErrorDetail(submitRes));
  }
  const { job_id: jobId } = await submitRes.json();
  if (!jobId) throw new ImageGenError('Image service did not return a job id.');

  const deadline = Date.now() + MAX_WAIT_MS;
  while (Date.now() < deadline) {
    await sleep(POLL_INTERVAL_MS);

    const pollRes = await fetch(`${BASE_URL}/image/${jobId}`, {
      headers: { 'X-API-Key': apiKey },
    });
    const contentType = pollRes.headers.get('content-type') || '';

    if (contentType.startsWith('image/')) {
      const arrayBuffer = await pollRes.arrayBuffer();
      return Buffer.from(arrayBuffer);
    }

    if (!pollRes.ok) {
      throw new ImageGenError(await extractErrorDetail(pollRes));
    }
    // Still pending — JSON body with status, keep polling.
  }

  throw new ImageGenError('Timed out waiting for image generation. Try again.');
}

async function extractErrorDetail(res) {
  try {
    const body = await res.json();
    if (body && body.detail) return `Image service error: ${body.detail}`;
  } catch {
    // fall through
  }
  return `Image service error (${res.status}).`;
}

function friendlyErrorMessage(err) {
  if (err instanceof ImageGenError) return err.message;
  return err.message || 'Failed to generate image.';
}

module.exports = { synthesize, friendlyErrorMessage };
