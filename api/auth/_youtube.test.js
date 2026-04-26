const test = require('node:test');
const assert = require('node:assert/strict');

const { sanitizeReturnTo, buildReturnUrl } = require('./_youtube');

test('sanitizeReturnTo falls back to default for missing and root values', () => {
  const inputs = [undefined, null, '', '/'];

  for (const input of inputs) {
    assert.equal(sanitizeReturnTo(input), '/#/playlists');
  }
});

test('sanitizeReturnTo keeps already-sanitized hash routes', () => {
  assert.equal(
    sanitizeReturnTo('/#/playlists?tab=recent'),
    '/#/playlists?tab=recent',
  );
});

test('sanitizeReturnTo normalizes hash-only routes', () => {
  assert.equal(sanitizeReturnTo('#/settings'), '/#/settings');
});

test('sanitizeReturnTo converts root-relative routes to hash routes', () => {
  assert.equal(
    sanitizeReturnTo('/playlists/favorites?sort=new'),
    '/#/playlists/favorites?sort=new',
  );
});

test('sanitizeReturnTo extracts hash routes from absolute URLs', () => {
  assert.equal(
    sanitizeReturnTo('https://example.com/somewhere#/studio?view=compact'),
    '/#/studio?view=compact',
  );
});

test('sanitizeReturnTo rejects non-hash absolute URLs', () => {
  assert.equal(
    sanitizeReturnTo('https://example.com/playlists?tab=recent'),
    '/#/playlists',
  );
});

test('sanitizeReturnTo keeps potentially hostile double-slash input internal', () => {
  const value = sanitizeReturnTo('//evil.example.com/path?q=1');
  assert.equal(value, '/#//evil.example.com/path?q=1');
  assert.ok(value.startsWith('/#'));
});

test('buildReturnUrl merges normalized route and extra params', () => {
  const output = buildReturnUrl(
    'https://app.example.com',
    '/#/playlists?tab=recent',
    { youtube_connected: 'true' },
  );

  const url = new URL(output);
  assert.equal(url.origin, 'https://app.example.com');
  assert.equal(url.hash, '#/playlists?tab=recent&youtube_connected=true');
});

test('buildReturnUrl removes stale youtube query parameters', () => {
  const output = buildReturnUrl(
    'https://app.example.com',
    '/#/playlists?youtube_connected=false&youtube_error=denied&keep=1',
  );

  const url = new URL(output);
  assert.equal(url.hash, '#/playlists?keep=1');
});

test('buildReturnUrl allows extra params to delete existing values', () => {
  const output = buildReturnUrl(
    'https://app.example.com',
    '/#/playlists?keep=1&remove_me=1',
    { remove_me: '', keep: 2 },
  );

  const url = new URL(output);
  assert.equal(url.hash, '#/playlists?keep=2');
});

test('buildReturnUrl falls back to default route for invalid return_to', () => {
  const output = buildReturnUrl('https://app.example.com', 'not-a-route', {
    youtube_error: 'state_mismatch',
  });

  const url = new URL(output);
  assert.equal(url.hash, '#/playlists?youtube_error=state_mismatch');
});

test('buildReturnUrl accepts hash-only return_to values via sanitization', () => {
  const output = buildReturnUrl('https://app.example.com', '#/studio');
  const url = new URL(output);
  assert.equal(url.hash, '#/studio');
});
