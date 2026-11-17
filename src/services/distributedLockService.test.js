import assert from 'node:assert/strict';
import test from 'node:test';
import { acquireWindowLock, releaseWindowLock } from './distributedLockService.js';

test('distributedLockService: acquires lock and prevents concurrent acquisition within TTL', async () => {
  const lockKey = `test-lock-${Date.now()}`;
  const first = await acquireWindowLock({ key: lockKey, ttlMs: 10_000 });
  assert.equal(first, true, 'First lock acquisition should succeed');

  const second = await acquireWindowLock({ key: lockKey, ttlMs: 10_000 });
  assert.equal(second, false, 'Second lock acquisition within TTL should be rejected');

  await releaseWindowLock(lockKey);
  const third = await acquireWindowLock({ key: lockKey, ttlMs: 10_000 });
  assert.equal(third, true, 'Lock acquisition should succeed after explicit release');

  await releaseWindowLock(lockKey);
});

test('distributedLockService: validates invalid keys gracefully', async () => {
  const empty = await acquireWindowLock({ key: '' });
  assert.equal(empty, false, 'Empty key should return false');

  const nil = await acquireWindowLock({ key: null });
  assert.equal(nil, false, 'Null key should return false');
});
