// Central definition of temporary events (Phase 6 — Retention Systems). This is
// deliberately NOT a CMS: events are plain config, same philosophy as
// ACHIEVEMENTS/MISSIONS — add or edit an entry here and redeploy. There's no
// admin CRUD for the same reason there's none for achievements or missions (see
// the Phase 6 final report): these are tuning data, not per-player content.
//
// `type` is what makes this extensible without a rewrite: events.service.js
// only knows how to apply 'xp_multiplier' today (the one concrete effect this
// phase wires into scoring — see playerProgression.service.js), but a future
// event can introduce a new `type` (e.g. 'speed_bonus', 'category_lock')
// without touching how existing events are stored, listed, or expired.
const EVENTS = [
  {
    key: 'double_xp_launch_event',
    name: 'Double XP Event',
    description: 'Every Rush you finish earns double lifetime XP while this is active.',
    type: 'xp_multiplier',
    multiplier: 2,
    startsAt: '2026-08-10T00:00:00Z',
    endsAt: '2026-09-10T00:00:00Z',
  },
];

module.exports = { EVENTS };
