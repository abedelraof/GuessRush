const BASE_URL = 'https://tts.expensebeam.store';
const POLL_INTERVAL_MS = 1500;
const MAX_WAIT_MS = 60000;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

class TtsError extends Error {}

/**
 * Submits a synthesis job and polls until the audio is ready.
 * Returns the raw FLAC bytes as a Buffer.
 */
async function synthesize({ apiKey, text, instructText }) {
  if (!apiKey) throw new TtsError('No Custom AI Key configured.');
  if (!text || !text.trim()) throw new TtsError('No text to synthesize.');

  const submitRes = await fetch(`${BASE_URL}/tts`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-API-Key': apiKey },
    body: JSON.stringify({
      text: text.slice(0, 4000),
      instruct_text: instructText ? instructText.slice(0, 500) : 'speak naturally',
    }),
  });

  if (submitRes.status !== 202) {
    throw new TtsError(await extractErrorDetail(submitRes));
  }
  const { job_id: jobId } = await submitRes.json();
  if (!jobId) throw new TtsError('TTS service did not return a job id.');

  const deadline = Date.now() + MAX_WAIT_MS;
  while (Date.now() < deadline) {
    await sleep(POLL_INTERVAL_MS);

    const pollRes = await fetch(`${BASE_URL}/tts/${jobId}`, {
      headers: { 'X-API-Key': apiKey },
    });
    const contentType = pollRes.headers.get('content-type') || '';

    if (contentType.startsWith('audio/')) {
      const arrayBuffer = await pollRes.arrayBuffer();
      return Buffer.from(arrayBuffer);
    }

    if (!pollRes.ok) {
      throw new TtsError(await extractErrorDetail(pollRes));
    }
    // Still pending — JSON body with status, keep polling.
  }

  throw new TtsError('Timed out waiting for audio synthesis. Try again.');
}

async function extractErrorDetail(res) {
  try {
    const body = await res.json();
    if (body && body.detail) return `TTS service error: ${body.detail}`;
  } catch {
    // fall through
  }
  return `TTS service error (${res.status}).`;
}

function friendlyErrorMessage(err) {
  if (err instanceof TtsError) return err.message;
  return err.message || 'Failed to generate audio.';
}

module.exports = { synthesize, friendlyErrorMessage };
