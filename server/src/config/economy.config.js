// Central tuning knob for the coins economy. There is deliberately no
// play-limiting resource (energy) here — Rushes are unlimited; an earlier
// energy-gating mechanic was removed after it proved bad for both onboarding
// and actually playing the game.

// Flat reward per correct answer in a completed Rush. No shop exists yet to
// spend coins on — this is intentionally just the earning side for now.
const COINS_PER_CORRECT_ANSWER = 10;

module.exports = {
  COINS_PER_CORRECT_ANSWER,
};
