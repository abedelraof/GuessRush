const Anthropic = require('@anthropic-ai/sdk');
const { z } = require('zod');
const { zodOutputFormat } = require('@anthropic-ai/sdk/helpers/zod');

const QUESTION_TYPES = ['image', 'audio', 'video', 'text', 'emoji', 'progressive'];
const DIFFICULTIES = ['easy', 'medium', 'hard', 'extreme'];

const DEFAULT_MODEL = 'claude-opus-5';
// Offered in Settings — highest quality first, fastest last. Admin-configurable
// because a faster/cheaper model can matter a lot for a many-batch bulk run.
const AVAILABLE_MODELS = ['claude-opus-5', 'claude-sonnet-5', 'claude-haiku-4-5-20251001'];

const QuestionSchema = z.object({
  type: z.enum(QUESTION_TYPES),
  difficulty: z
    .enum(DIFFICULTIES)
    .describe(
      'How hard this question is to guess: easy (common knowledge), medium, hard, or extreme ' +
        '(obscure/niche). Judge based on the question and options you write, not the category as a whole.'
    ),
  label: z.string().describe('Short badge text shown on the question screen, include one emoji, e.g. "LOOK & GUESS 👀"'),
  prompt: z.string().describe('The question text shown to the player'),
  instruct_text: z
    .string()
    .max(400)
    .describe(
      'A short text-to-speech style/tone instruction for how this question should be read aloud, ' +
        'tailored to the question — e.g. "Read in an excited, playful game-show host tone" or ' +
        '"Speak slowly and mysteriously" for a suspenseful clue.'
    ),
  media_placeholder: z.string().nullable().describe('For type=image only: a short text description standing in for the (non-existent) image, e.g. "character portrait". Null for other types.'),
  media_duration: z.string().nullable().describe('For type=audio/video only: a fake clip duration like "0:12". Null for other types.'),
  emojis: z.string().nullable().describe('For type=emoji only: a short string of emoji encoding the answer, e.g. "❄️👸⛄🏰". Null for other types.'),
  video_prompt: z
    .string()
    .nullable()
    .describe(
      'For type=video only: a text-to-video generation prompt for a short (5-8s) clip. It must evoke the ' +
        'correct answer WITHOUT literally naming or spelling it out — describe a scene/subject/action a ' +
        'viewer would recognize AS the answer, not the answer itself. One clear subject or action, not a ' +
        'busy multi-element scene. Use cinematic camera/lighting language (e.g. "POV", "shallow depth of ' +
        'field", "golden hour", "slow dolly in"). Explicitly state no on-screen text, no logos, no ' +
        'subtitles, no title cards. Null for other types.'
    ),
  options: z.array(z.string()).length(4).describe('Exactly 4 answer options'),
  option_image_prompts: z
    .array(z.string())
    .length(4)
    .describe(
      'For each of the 4 options, in the same order: a comprehensive, highly descriptive text-to-image ' +
        'generation prompt that depicts that specific answer (the character/movie/thing it names) — ' +
        'describe subject, art style, composition, lighting, and mood in vivid detail, enough to hand ' +
        'directly to an image generation model.'
    ),
  correct_index: z.number().int().min(0).max(3).describe('Index (0-3) of the correct option'),
  clues: z.array(z.string()).min(3).max(5).nullable().describe('For type=progressive only: 3-5 clues revealed one at a time, easiest/vaguest first. Null for other types.'),
  timer_seconds: z.number().int().describe('15 for image/video, 12 for audio, 0 for text/emoji/progressive'),
});

const GenerateResponseSchema = z.object({
  questions: z.array(QuestionSchema),
});

/**
 * Ask Claude for `count` quiz questions themed to `categoryName`, mixing the
 * supported question types. Never caches/reuses a client across calls — the
 * key (and workspace ID) can be replaced or removed from Settings at any time.
 *
 * `workspaceId` is only required for "identity-linked" API keys (the newer
 * per-person key type in the Anthropic Console) — without it, those keys are
 * rejected with "anthropic-workspace-id is required...". A classic
 * workspace-scoped key doesn't need this at all, so it's optional here.
 */
async function generateQuestions({ apiKey, workspaceId, categoryName, count, type, difficulty, model }) {
  const client = new Anthropic({
    apiKey,
    defaultHeaders: workspaceId ? { 'anthropic-workspace-id': workspaceId } : undefined,
  });

  // "Vary across the batch" only makes sense when nothing's pinned — a caller asking
  // for one question of a specific type/difficulty (the New question form's AI-fill
  // button) wants exactly that, not Claude picking something else to "add variety".
  const varietyInstructions = [];
  if (!type) varietyInstructions.push('Vary question types across the batch — do not use the same type for every question.');
  if (!difficulty) {
    varietyInstructions.push(
      'Also vary difficulty across the batch — mix easy, medium, hard, and extreme questions rather than making them all the same difficulty.'
    );
  }

  let userContent = `Category: "${categoryName}". Generate exactly ${count} quiz question(s) for this category.`;
  if (type) userContent += ` Every question must have type "${type}".`;
  if (difficulty) userContent += ` Every question must have difficulty "${difficulty}".`;

  const response = await client.messages.parse({
    model: AVAILABLE_MODELS.includes(model) ? model : DEFAULT_MODEL,
    max_tokens: 16000,
    system:
      'You write trivia quiz questions for a mobile guessing game. Follow the schema exactly. ' +
      varietyInstructions.join(' ') +
      (varietyInstructions.length ? ' ' : '') +
      'This app has no real image/audio media assets: for image/audio questions, media_placeholder/' +
      'media_duration are just short flavor-text stand-ins (e.g. "character portrait", "0:12"), never a ' +
      'real file or URL. For type=video, media_duration is likewise just flavor text, but video_prompt IS ' +
      'used to generate a real clip — follow its schema description\'s rules exactly (evoke the answer, ' +
      'never name it; no on-screen text/logos). ' +
      'Keep prompts and options concise, unambiguous, and appropriate for a general audience. ' +
      'Also write instruct_text for each question — a short tone/style instruction a text-to-speech engine ' +
      'will use to read the question aloud, tailored to that specific question and its type. ' +
      'Also write option_image_prompts — for each of the 4 options, a comprehensive and descriptive ' +
      'text-to-image prompt depicting that specific answer, ready to feed directly to an image model.',
    messages: [
      {
        role: 'user',
        content: userContent,
      },
    ],
    output_config: {
      format: zodOutputFormat(GenerateResponseSchema),
    },
  });

  if (!response.parsed_output) {
    throw new Error('Claude did not return a parseable response. Try again.');
  }

  return response.parsed_output.questions;
}

/** Turns an SDK error into a friendly, non-leaky message for the admin UI. */
function friendlyErrorMessage(err) {
  if (err instanceof Anthropic.AuthenticationError) {
    return 'Claude rejected the API key saved in Settings — check it and try again.';
  }
  if (typeof err.message === 'string' && err.message.includes('anthropic-workspace-id')) {
    return (
      'This is an identity-linked Claude API key, which needs a Workspace ID as well — ' +
      'add it in Settings under the Claude API key, then try again.'
    );
  }
  if (err instanceof Anthropic.RateLimitError) {
    return 'Claude is rate-limited right now — try again shortly.';
  }
  if (err instanceof Anthropic.APIError) {
    return `Claude API error: ${err.message}`;
  }
  return err.message || 'Failed to generate questions.';
}

module.exports = { generateQuestions, friendlyErrorMessage, QUESTION_TYPES, DEFAULT_MODEL, AVAILABLE_MODELS };
