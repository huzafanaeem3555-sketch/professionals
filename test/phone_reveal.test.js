const test = require('node:test');
const assert = require('node:assert/strict');

const { stripPhone } = require('../src/utils/phoneReveal');

test('stripPhone removes sensitive fields and preserves public ones', () => {
  const result = stripPhone({
    displayName: 'Ali Pro',
    phoneNumber: '03001234567',
    fcmToken: 'token_123',
    rating: 4.9,
  });

  assert.deepEqual(result, {
    displayName: 'Ali Pro',
    rating: 4.9,
  });
});
