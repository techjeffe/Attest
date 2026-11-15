import test from 'node:test';
import assert from 'node:assert/strict';
import { haptic, STYLES } from '../public/app/haptic.js';

test('haptic is a no-op outside the iPhone app', () => {
  delete globalThis.window;
  globalThis.window = globalThis;
  assert.equal(haptic('success'), false);
});

test('haptic posts a styled message to the native shell', () => {
  const sent = [];
  globalThis.window = { webkit: { messageHandlers: { attest: { postMessage: (m) => sent.push(m) } } } };
  assert.equal(haptic('success'), true);
  assert.equal(haptic(), true);
  assert.deepEqual(sent, [{ action: 'haptic', style: 'success' }, { action: 'haptic', style: 'light' }]);
});

test('haptic ignores unknown styles and a throwing bridge', () => {
  globalThis.window = { webkit: { messageHandlers: { attest: { postMessage() { throw new Error('x'); } } } } };
  assert.equal(haptic('bogus'), false);
  assert.equal(haptic('error'), false);
  assert.ok(STYLES.includes('selection'));
});
