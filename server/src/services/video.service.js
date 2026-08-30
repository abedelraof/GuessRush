const BASE_URL = 'https://video.expensebeam.store';

class VideoGenError extends Error {}

/**
 * Queues a text-to-video generation job. Returns immediately with the job id —
 * unlike image.service.js/tts.service.js this does NOT wait for the result:
 * a video job can take minutes to 20-30 minutes, far too long to hold open a
 * single Express request/reverse-proxy connection. Callers poll `poll()`.
 */
async function submit({ apiKey, prompt, negativePrompt }) {
  if (!apiKey) throw new VideoGenError('No Custom AI Key configured.');
  if (!prompt || !prompt.trim()) throw new VideoGenError('No prompt to generate a video from.');

  const body = {
    prompt: prompt.slice(0, 4000),
    // Vertical, matching the app's phone UI — the API defaults to 16:9 otherwise.
    aspect_ratio: '9:16 (Portrait Widescreen)',
  };
  if (negativePrompt && negativePrompt.trim()) {
    body.negative_prompt = negativePrompt.slice(0, 4000);
  }

  const res = await fetch(`${BASE_URL}/video`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-API-Key': apiKey },
    body: JSON.stringify(body),
  });

  if (res.status !== 202) {
    throw new VideoGenError(await extractErrorDetail(res));
  }
  const { job_id: jobId } = await res.json();
  if (!jobId) throw new VideoGenError('Video service did not return a job id.');
  return jobId;
}

/**
 * One poll of an in-flight job — never waits/blocks, just reports the job's
 * current state so a caller can poll this repeatedly from its own loop.
 * Returns { status: 'queued' | 'running', queuePosition } while pending, or
 * { status: 'done', buffer } once the finished MP4 bytes are available.
 */
async function poll({ apiKey, jobId }) {
  const res = await fetch(`${BASE_URL}/video/${jobId}`, {
    headers: { 'X-API-Key': apiKey },
  });
  const contentType = res.headers.get('content-type') || '';

  if (contentType.startsWith('video/')) {
    if (!res.ok) throw new VideoGenError(await extractErrorDetail(res));
    const arrayBuffer = await res.arrayBuffer();
    return { status: 'done', buffer: Buffer.from(arrayBuffer) };
  }

  const data = await res.json();
  if (!res.ok) {
    throw new VideoGenError(data && data.detail ? `Video service error: ${data.detail}` : `Video service error (${res.status}).`);
  }
  return { status: data.status, queuePosition: data.queue_position ?? null };
}

async function extractErrorDetail(res) {
  try {
    const body = await res.json();
    if (body && body.detail) return `Video service error: ${body.detail}`;
  } catch {
    // fall through
  }
  return `Video service error (${res.status}).`;
}

function friendlyErrorMessage(err) {
  if (err instanceof VideoGenError) return err.message;
  return err.message || 'Failed to generate video.';
}

module.exports = { submit, poll, friendlyErrorMessage };
