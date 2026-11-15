import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  getActiveAdminUserIds,
  invalidateAdminRecipientsCache,
  parseAdminUserIdsFromEnv,
} from './adminRecipients.js';

test('parseAdminUserIdsFromEnv correctly parses UUIDs', () => {
  const prev = process.env.ADMIN_ORDER_ALERT_USER_IDS;
  try {
    process.env.ADMIN_ORDER_ALERT_USER_IDS = '84fe41cf-cf02-4a87-b81f-394f53c8fab2, 11111111-1111-4111-a111-111111111111; invalid-uuid';
    const ids = parseAdminUserIdsFromEnv();
    assert.equal(ids.length, 2);
    assert.equal(ids[0], '84fe41cf-cf02-4a87-b81f-394f53c8fab2');
    assert.equal(ids[1], '11111111-1111-4111-a111-111111111111');
  } finally {
    process.env.ADMIN_ORDER_ALERT_USER_IDS = prev;
  }
});

test('getActiveAdminUserIds caches recipients and serves second call from memory', async () => {
  invalidateAdminRecipientsCache();

  const start1 = performance.now();
  const first = await getActiveAdminUserIds({ info: () => {}, warn: () => {} });
  const duration1 = performance.now() - start1;

  assert.ok(Array.isArray(first));

  const start2 = performance.now();
  const second = await getActiveAdminUserIds({ info: () => {}, warn: () => {} });
  const duration2 = performance.now() - start2;

  assert.deepEqual(first, second);
  assert.ok(duration2 < 10, `Cached call took ${duration2}ms, expected < 10ms (first took ${duration1}ms)`);
});
