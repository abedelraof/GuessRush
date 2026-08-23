const { EVENTS } = require('../config/events.config');

/** Events whose [startsAt, endsAt) window contains `now`. Pure — no DB, easy to unit test. */
function activeEventsAt(now = new Date()) {
  const ts = now.getTime();
  return EVENTS.filter((e) => ts >= Date.parse(e.startsAt) && ts < Date.parse(e.endsAt));
}

/**
 * The combined XP multiplier from every currently-active 'xp_multiplier' event.
 * Multiple overlapping events take the highest one rather than stacking
 * multiplicatively — simple and avoids a config mistake silently producing a
 * runaway multiplier.
 */
function xpMultiplierAt(now = new Date()) {
  const multipliers = activeEventsAt(now)
    .filter((e) => e.type === 'xp_multiplier')
    .map((e) => e.multiplier);
  return multipliers.length > 0 ? Math.max(...multipliers) : 1;
}

module.exports = { activeEventsAt, xpMultiplierAt };
