import assert from 'node:assert/strict';
import test from 'node:test';

import {
  EVENT_DELAYS_SECONDS,
  PENDING_10M_CANCEL_EVENT,
  PENDING_15M_CANCEL_EVENT,
  PENDING_AUTO_CANCEL_SECONDS,
  PENDING_CANCEL_EVENTS,
  PENDING_LIFECYCLE_EVENTS,
} from './application/scheduleOrderLifecycle.js';
import { AUTO_CANCEL_THRESHOLD_MS } from '../../services/pendingOrdersPoller.js';

test('pending auto-cancel delay is 15 minutes (900s)', () => {
  assert.equal(PENDING_AUTO_CANCEL_SECONDS, 900);
  assert.equal(EVENT_DELAYS_SECONDS[PENDING_15M_CANCEL_EVENT], 900);
});

test('new pending lifecycle schedule uses 15m cancel, not 10m', () => {
  assert.ok(PENDING_LIFECYCLE_EVENTS.includes(PENDING_15M_CANCEL_EVENT));
  assert.ok(!PENDING_LIFECYCLE_EVENTS.includes(PENDING_10M_CANCEL_EVENT));
});

test('sibling cancel list includes both 10m and 15m cancel events', () => {
  assert.deepEqual(PENDING_CANCEL_EVENTS, [
    PENDING_10M_CANCEL_EVENT,
    PENDING_15M_CANCEL_EVENT,
  ]);
});

test('poller auto-cancel threshold is 15 minutes', () => {
  assert.equal(AUTO_CANCEL_THRESHOLD_MS, 15 * 60_000);
});

test('poller threshold: age 10m below cancel, age 15m at or above', () => {
  const age10m = 10 * 60_000;
  const age15m = 15 * 60_000;
  assert.ok(age10m < AUTO_CANCEL_THRESHOLD_MS);
  assert.ok(age15m >= AUTO_CANCEL_THRESHOLD_MS);
});

test('legacy 10m delay key still present for residual lookup', () => {
  assert.equal(EVENT_DELAYS_SECONDS[PENDING_10M_CANCEL_EVENT], 600);
});
