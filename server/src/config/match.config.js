// Central tuning knobs for Play With Friends (1v1 matches) — mirrors how
// rush.config.js centralizes Rush's own tuning.

// How long a player waits in the random matchmaking queue before being
// evicted and told to try again.
const QUEUE_TIMEOUT_MS = 45 * 1000;

// How long a friend-invite code stays valid if never joined.
const FRIEND_CODE_EXPIRY_MS = 15 * 60 * 1000;

// Grace period after a websocket disconnect before a mid-match drop is
// resolved as a forfeit (or voided, if neither side had answered yet).
const DISCONNECT_GRACE_MS = 75 * 1000;

const INVITE_CODE_LENGTH = 6;
// Excludes visually-ambiguous characters (0/O, 1/I) since this is read aloud/typed by hand.
const INVITE_CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

module.exports = {
  QUEUE_TIMEOUT_MS,
  FRIEND_CODE_EXPIRY_MS,
  DISCONNECT_GRACE_MS,
  INVITE_CODE_LENGTH,
  INVITE_CODE_ALPHABET,
};
