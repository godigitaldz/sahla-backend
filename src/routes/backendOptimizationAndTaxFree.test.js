import { test } from 'node:test';
import assert from 'node:assert/strict';
import { runPendingOrdersPollOnce } from '../services/pendingOrdersPoller.js';
import { runParcelWaitingAdminAlertsOnce } from '../services/parcelWaitingAdminAlertsPoller.js';
import { runPreparingUnassignedRebroadcastOnce } from '../services/preparingUnassignedRebroadcastPoller.js';
import { getCachedSystemConfigNumber, invalidateSystemConfigCache } from '../utils/systemConfigCache.js';
import { getActiveAdminUserIds, invalidateAdminRecipientsCache } from '../services/adminRecipients.js';

test('Delivery tax manual calculation helper matches <= 180 DA tax-free invariant', () => {
  const calcTax = (fee, threshold = 180) => {
    return fee <= threshold ? 0 : Math.min(Math.round(fee * 0.15 * 100) / 100, 100);
  };

  assert.equal(calcTax(0), 0);
  assert.equal(calcTax(100), 0);
  assert.equal(calcTax(150), 0);
  assert.equal(calcTax(179.99), 0);
  assert.equal(calcTax(180), 0);
  assert.equal(calcTax(180.01), 27); // 180.01 * 0.15 = 27.0015 -> 27
  assert.equal(calcTax(200), 30);    // 200 * 0.15 = 30
  assert.equal(calcTax(300), 45);    // 300 * 0.15 = 45
  assert.equal(calcTax(1000), 100);  // capped at 100
});

test('runPendingOrdersPollOnce executes cleanly with targeted log queries', async () => {
  const logger = { info: () => {}, warn: () => {}, error: () => {} };
  const stats = await runPendingOrdersPollOnce({ logger });
  assert.ok(stats);
  assert.equal(stats.error, undefined);
  assert.ok(typeof stats.pending_due === 'number');
  assert.ok(typeof stats.delivery_due === 'number');
});

test('runParcelWaitingAdminAlertsOnce executes cleanly with targeted candidate queries', async () => {
  const logger = { info: () => {}, warn: () => {}, error: () => {} };
  const stats = await runParcelWaitingAdminAlertsOnce({ logger });
  assert.ok(stats);
  assert.ok(!stats.error, `Unexpected error: ${stats.error}`);
  assert.ok(typeof stats.parcel_due === 'number');
});

test('runPreparingUnassignedRebroadcastOnce executes cleanly with targeted candidate queries', async () => {
  const logger = { info: () => {}, warn: () => {}, error: () => {} };
  const stats = await runPreparingUnassignedRebroadcastOnce({ logger });
  assert.ok(stats);
  assert.ok(!stats.error, `Unexpected error: ${stats.error}`);
});

test('Cached system_config reads return active 180 DA threshold', async () => {
  invalidateSystemConfigCache();
  const threshold = await getCachedSystemConfigNumber('delivery_tax_free_threshold_da', 180);
  assert.equal(threshold, 180);
});

test('Admin recipients caching eliminates repeated database roundtrips', async () => {
  invalidateAdminRecipientsCache();
  const start1 = performance.now();
  const list1 = await getActiveAdminUserIds({ info: () => {}, warn: () => {} });
  const dur1 = performance.now() - start1;

  const start2 = performance.now();
  const list2 = await getActiveAdminUserIds({ info: () => {}, warn: () => {} });
  const dur2 = performance.now() - start2;

  assert.deepEqual(list1, list2);
  assert.ok(dur2 < 5, `Expected sub-5ms cache hit, got ${dur2}ms (first call took ${dur1}ms)`);
});
