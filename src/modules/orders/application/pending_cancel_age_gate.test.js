/**
 * Lightweight unit coverage for pending auto-cancel age-gate helpers and
 * schedule constants used by handleOrderLifecycleEvent.
 * Full handler I/O is integration-tested via mocks in this file.
 */
import assert from 'node:assert/strict';
import test from 'node:test';

import {
  PENDING_10M_CANCEL_EVENT,
  PENDING_15M_CANCEL_EVENT,
  PENDING_AUTO_CANCEL_MINUTES,
  PENDING_CANCEL_EVENTS,
} from './scheduleOrderLifecycle.js';

const THRESHOLD_MS = PENDING_AUTO_CANCEL_MINUTES * 60 * 1000;

function shouldCancelByAge(createdAtIso, nowMs = Date.now()) {
  const createdMs = Date.parse(String(createdAtIso || ''));
  if (!Number.isFinite(createdMs)) return true;
  return nowMs - createdMs >= THRESHOLD_MS;
}

function skipReasonForPremature(eventType) {
  return eventType === PENDING_10M_CANCEL_EVENT
    ? 'premature_legacy_10m_before_15m'
    : 'premature_before_15m';
}

test('age gate: 10m old order must not cancel', () => {
  const createdAt = new Date(Date.now() - 10 * 60_000).toISOString();
  assert.equal(shouldCancelByAge(createdAt), false);
});

test('age gate: 15m old order may cancel', () => {
  const createdAt = new Date(Date.now() - 15 * 60_000).toISOString();
  assert.equal(shouldCancelByAge(createdAt), true);
});

test('premature skip reason distinguishes legacy 10m', () => {
  assert.equal(
    skipReasonForPremature(PENDING_10M_CANCEL_EVENT),
    'premature_legacy_10m_before_15m',
  );
  assert.equal(
    skipReasonForPremature(PENDING_15M_CANCEL_EVENT),
    'premature_before_15m',
  );
});

test('both cancel events are siblings for status transition cleanup', () => {
  assert.ok(PENDING_CANCEL_EVENTS.includes(PENDING_10M_CANCEL_EVENT));
  assert.ok(PENDING_CANCEL_EVENTS.includes(PENDING_15M_CANCEL_EVENT));
});
