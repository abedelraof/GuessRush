const test = require('node:test');
const assert = require('node:assert/strict');
const { hashString, rngFromString } = require('../src/utils/seededRandom');

test('hashString is deterministic for the same input', () => {
  assert.equal(hashString('2026-08-23'), hashString('2026-08-23'));
});

test('hashString differs for different inputs (no trivial collisions on adjacent dates)', () => {
  assert.notEqual(hashString('2026-08-23'), hashString('2026-08-24'));
});

test('rngFromString produces the exact same sequence for the same seed string', () => {
  const rngA = rngFromString('2026-08-23');
  const rngB = rngFromString('2026-08-23');
  const sequenceA = Array.from({ length: 10 }, () => rngA());
  const sequenceB = Array.from({ length: 10 }, () => rngB());
  assert.deepEqual(sequenceA, sequenceB);
});

test('rngFromString produces a different sequence for a different seed string', () => {
  const rngA = rngFromString('2026-08-23');
  const rngB = rngFromString('2026-08-24');
  const sequenceA = Array.from({ length: 10 }, () => rngA());
  const sequenceB = Array.from({ length: 10 }, () => rngB());
  assert.notDeepEqual(sequenceA, sequenceB);
});

test('rngFromString always returns numbers in [0, 1)', () => {
  const rng = rngFromString('any-seed');
  for (let i = 0; i < 1000; i++) {
    const value = rng();
    assert.ok(value >= 0 && value < 1, `value ${value} out of range`);
  }
});
