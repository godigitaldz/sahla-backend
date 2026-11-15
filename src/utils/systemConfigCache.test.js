import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  getCachedSystemConfigNumber,
  getCachedSystemConfigValue,
  invalidateSystemConfigCache,
} from './systemConfigCache.js';

test('getCachedSystemConfigNumber returns valid config and caches response', async () => {
  invalidateSystemConfigCache();

  // Test reading threshold (which was just seeded in DB)
  const threshold = await getCachedSystemConfigNumber('delivery_tax_free_threshold_da', 180);
  assert.equal(threshold, 180);

  // Subsequent call should be served from memory instantly
  const start = performance.now();
  const cachedVal = await getCachedSystemConfigNumber('delivery_tax_free_threshold_da', 180);
  const duration = performance.now() - start;
  assert.equal(cachedVal, 180);
  assert.ok(duration < 10, `Cached call took ${duration}ms, expected < 10ms`);
});

test('getCachedSystemConfigNumber handles fallback gracefully for unknown keys', async () => {
  const missing = await getCachedSystemConfigNumber('non_existent_key_xyz_123', 999);
  assert.equal(missing, 999);
});

test('invalidateSystemConfigCache clears entry and forces re-fetch', async () => {
  await getCachedSystemConfigNumber('delivery_tax_free_threshold_da', 180);
  invalidateSystemConfigCache('delivery_tax_free_threshold_da');
  const fresh = await getCachedSystemConfigNumber('delivery_tax_free_threshold_da', 180);
  assert.equal(fresh, 180);
});
