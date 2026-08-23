// Small, dependency-free deterministic PRNG so Daily Rush can shuffle/select
// "randomly" while still producing the exact same result for every player on
// the same server day. Not cryptographic — just needs to be reproducible.

/** 32-bit string hash (djb2-ish), used to turn a date string into a numeric seed. */
function hashString(str) {
  let h = 0;
  for (let i = 0; i < str.length; i++) {
    h = (Math.imul(31, h) + str.charCodeAt(i)) | 0;
  }
  return h;
}

/** mulberry32: fast, tiny, good-enough distribution for shuffling. Returns a `() => number in [0,1)` generator. */
function mulberry32(seed) {
  let a = seed | 0;
  return function rng() {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Deterministic RNG generator seeded from an arbitrary string (e.g. "2026-08-23"). */
function rngFromString(str) {
  return mulberry32(hashString(str));
}

module.exports = { hashString, mulberry32, rngFromString };
