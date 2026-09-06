// Central tuning knobs for the energy (play-limiting resource) and coins
// (lifetime currency) economy — kept separate from mechanics.config.js, which
// scopes itself to Phase 5's per-Rush strategic mechanics specifically.

// ---- Energy ----
// Full tank. Costs 1 per Rush started (see energy.service.js's consumeEnergy) —
// Daily Rush is deliberately exempt (it's the one guaranteed free daily
// activity, already gated to once/day on its own terms).
const ENERGY_MAX = 5;
// How long a single point takes to regenerate once below ENERGY_MAX.
const ENERGY_REGEN_INTERVAL_MS = 20 * 60 * 1000;

// ---- Coins ----
// Flat reward per correct answer in a completed Rush. No shop exists yet to
// spend them on — this is intentionally just the earning side for now.
const COINS_PER_CORRECT_ANSWER = 10;

module.exports = {
  ENERGY_MAX,
  ENERGY_REGEN_INTERVAL_MS,
  COINS_PER_CORRECT_ANSWER,
};
