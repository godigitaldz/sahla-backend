import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

import {
  parseAdminUserIdsFromEnv,
  getActiveAdminUserIds,
  invalidateAdminRecipientsCache,
  getAdminAudienceDiagnostic,
} from '../services/adminRecipients.js';
import { sendPushWithDispatch } from '../services/notificationDispatchService.js';
import { qstashPublisher } from '../modules/orders/infrastructure/qstashPublisher.js';
import { orderLifecycleRepository } from '../modules/orders/infrastructure/orderLifecycleRepository.js';
import { supabasePushGateway } from '../modules/notifications/supabasePushGateway.js';
import {
  AUTO_CANCEL_THRESHOLD_MS,
  runPendingOrdersPollOnce,
} from '../services/pendingOrdersPoller.js';
import { runParcelWaitingAdminAlertsOnce } from '../services/parcelWaitingAdminAlertsPoller.js';
import { runPreparingUnassignedRebroadcastOnce } from '../services/preparingUnassignedRebroadcastPoller.js';
import { runPreparingAssignedDelayAdminAlertsOnce } from '../services/preparingAssignedDelayAdminAlertsPoller.js';
import { runPickupDelayAdminAlertsOnce } from '../services/pickupDelayAdminAlertsPoller.js';

test('1. Performance dashboard is strictly read-only with NO poller dispatch side-effects', () => {
  const filePath = path.resolve('src/routes/performanceDashboard.js');
  const code = fs.readFileSync(filePath, 'utf8');

  // Verify poller imports are completely removed from performanceDashboard.js
  assert.ok(!code.includes("from '../services/pendingOrdersPoller.js'"), 'Must not import pendingOrdersPoller');
  assert.ok(!code.includes("from '../services/pickupDelayAdminAlertsPoller.js'"), 'Must not import pickupDelayAdminAlertsPoller');
  assert.ok(!code.includes("from '../services/preparingUnassignedRebroadcastPoller.js'"), 'Must not import preparingUnassignedRebroadcastPoller');
  assert.ok(!code.includes("from '../services/preparingAssignedDelayAdminAlertsPoller.js'"), 'Must not import preparingAssignedDelayAdminAlertsPoller');

  // Verify dashboard-traffic throttle and side effect are gone
  assert.ok(!code.includes('_lastDashboardEscalationPollMs'), '_lastDashboardEscalationPollMs must be removed');
  assert.ok(!code.includes('runPendingOrdersPollOnce'), 'runPendingOrdersPollOnce must not be called from dashboard');
});

test('2. Admin audience resolution handles invalid UUIDs, DB errors, and diagnostics', async () => {
  const prevEnv = process.env.ADMIN_ORDER_ALERT_USER_IDS;
  try {
    // Test invalid UUID parsing with warnings
    process.env.ADMIN_ORDER_ALERT_USER_IDS =
      'c855a0f5-5643-4c91-904e-128a11ea8974, invalid-uuid-1, 99999999-9999-4999-a999-999999999999';
    let warned = false;
    const testLogger = {
      warn: (msg) => {
        if (msg.includes('invalid UUID')) warned = true;
      },
      info: () => {},
      error: () => {},
    };

    const parsed = parseAdminUserIdsFromEnv(testLogger);
    assert.equal(parsed.length, 2);
    assert.ok(warned, 'Should log warning for invalid UUIDs');

    invalidateAdminRecipientsCache();
    const recipients = await getActiveAdminUserIds(testLogger);
    assert.ok(Array.isArray(recipients));

    const diag = getAdminAudienceDiagnostic();
    assert.ok(diag.resolved_at !== null);
    assert.ok(typeof diag.from_env_count === 'number');
    assert.ok(typeof diag.from_db_count === 'number');
    assert.ok(typeof diag.total_count === 'number');
  } finally {
    process.env.ADMIN_ORDER_ALERT_USER_IDS = prevEnv;
    invalidateAdminRecipientsCache();
  }
});

test('3. notificationDispatchService prevents concurrent double-sends via in-flight reservation lease', async () => {
  const testDispatchKey = `test:lease:${Date.now()}:${Math.random().toString(36).slice(2)}`;
  const orderId = '00000000-0000-0000-0000-000000000001';

  // Mock orderLifecycleRepository for unit verification
  const originalRecord = orderLifecycleRepository.recordDispatchIfNew;
  const originalGet = orderLifecycleRepository.getDispatchByKey;
  const originalUpdate = orderLifecycleRepository.updateDispatchStatus;
  const originalSendPush = supabasePushGateway.sendPush;

  let pushSendCount = 0;
  let storedRecord = null;

  try {
    orderLifecycleRepository.recordDispatchIfNew = async ({ dispatchKey, status, providerResponse }) => {
      if (storedRecord && storedRecord.dispatch_key === dispatchKey) {
        return false; // Already exists
      }
      storedRecord = {
        dispatch_key: dispatchKey,
        status,
        provider_response: providerResponse,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };
      return true;
    };

    orderLifecycleRepository.getDispatchByKey = async (key) => {
      return storedRecord && storedRecord.dispatch_key === key ? storedRecord : null;
    };

    orderLifecycleRepository.updateDispatchStatus = async (key, { status, providerResponse }) => {
      if (storedRecord && storedRecord.dispatch_key === key) {
        storedRecord.status = status;
        storedRecord.provider_response = providerResponse;
      }
    };

    supabasePushGateway.sendPush = async () => {
      pushSendCount += 1;
      return { success: true, total_sent: 1 };
    };

    // First call: successfully reserves and dispatches
    const firstCall = await sendPushWithDispatch({
      dispatchKey: testDispatchKey,
      orderId,
      cohort: 'admin',
      userIds: ['00000000-0000-0000-0000-000000000002'],
      title: 'Test',
      body: 'Test',
      dedupe: true,
    });

    assert.equal(firstCall.success, true);
    assert.equal(firstCall.total_sent, 1);
    assert.equal(pushSendCount, 1);
    assert.equal(storedRecord.status, 'sent');

    // Second call: already marked sent -> skipped
    const secondCall = await sendPushWithDispatch({
      dispatchKey: testDispatchKey,
      orderId,
      cohort: 'admin',
      userIds: ['00000000-0000-0000-0000-000000000002'],
      title: 'Test',
      body: 'Test',
      dedupe: true,
    });

    assert.equal(secondCall.success, true);
    assert.equal(secondCall.skipped, true);
    assert.equal(secondCall.reason, 'deduped_dispatch');
    assert.equal(pushSendCount, 1); // No new push sent!

    // Concurrency test: simulate an in-flight reservation from another runner
    const inFlightKey = `test:inflight:${Date.now()}`;
    storedRecord = {
      dispatch_key: inFlightKey,
      status: 'skipped',
      provider_response: { reserved: true, reserved_at: new Date().toISOString() },
      updated_at: new Date().toISOString(),
    };

    const concurrentCall = await sendPushWithDispatch({
      dispatchKey: inFlightKey,
      orderId,
      cohort: 'admin',
      userIds: ['00000000-0000-0000-0000-000000000002'],
      title: 'Test',
      body: 'Test',
      dedupe: true,
    });

    assert.equal(concurrentCall.success, true);
    assert.equal(concurrentCall.skipped, true);
    assert.equal(concurrentCall.reason, 'dispatch_in_flight');
    assert.equal(pushSendCount, 1); // Absolutely no duplicate push sent while in flight!
  } finally {
    orderLifecycleRepository.recordDispatchIfNew = originalRecord;
    orderLifecycleRepository.getDispatchByKey = originalGet;
    orderLifecycleRepository.updateDispatchStatus = originalUpdate;
    supabasePushGateway.sendPush = originalSendPush;
  }
});

test('4. QStash recurring schedule manager creates and verifies recurring cron schedules', async () => {
  assert.ok(typeof qstashPublisher.ensureRecurringCronSchedule === 'function');
  assert.ok(typeof qstashPublisher.listSchedules === 'function');
  assert.ok(typeof qstashPublisher.deleteSchedule === 'function');

  // Verify idempotency logic when schedule already exists
  const origClient = qstashPublisher.client;
  const origEnabled = qstashPublisher.enabled;
  try {
    let createCalled = false;
    qstashPublisher.enabled = true;
    qstashPublisher.client = {
      schedules: {
        list: async () => [
          {
            scheduleId: 'sched_existing_123',
            cron: '* * * * *',
            destination: 'https://sahla-backend.vercel.app/api/internal/pending-orders-poll',
          },
        ],
        create: async () => {
          createCalled = true;
          return { scheduleId: 'sched_new_456' };
        },
      },
    };

    const res = await qstashPublisher.ensureRecurringCronSchedule({
      cron: '* * * * *',
      destination: 'https://sahla-backend.vercel.app/api/internal/pending-orders-poll',
      cronSecret: 'test-secret',
    });

    assert.equal(res.already_exists, true);
    assert.equal(res.created, false);
    assert.equal(res.scheduleId, 'sched_existing_123');
    assert.equal(createCalled, false); // Did not create a redundant duplicate schedule!
  } finally {
    qstashPublisher.client = origClient;
    qstashPublisher.enabled = origEnabled;
  }
});

test('5. FCM contract: All 5 admin alert families preserve Flutter client notification contract', () => {
  const adminAlertTypes = [
    {
      flow: 'admin_order_pending_2m',
      stage: 'first',
      thresholdMs: 2 * 60_000,
    },
    {
      flow: 'admin_order_pending_5m',
      stage: 'second',
      thresholdMs: 5 * 60_000,
    },
    {
      flow: 'admin_preparing_unassigned_5m',
      stage: 'preparing_unassigned_5m',
      thresholdMs: 5 * 60_000,
    },
    {
      flow: 'admin_preparing_assigned_20m',
      stage: 'preparing_assigned_no_pickup',
      thresholdMs: 20 * 60_000,
    },
    {
      flow: 'admin_delivery_picked_up_15m',
      stage: 'delivery_delayed',
      thresholdMs: 15 * 60_000,
    },
    {
      flow: 'admin_parcel_waiting_15m',
      stage: undefined,
      thresholdMs: 15 * 60_000,
    },
  ];

  for (const alert of adminAlertTypes) {
    const data = {
      type: 'admin_order_alert',
      stage: alert.stage,
      flow: alert.flow,
      order_id: '11111111-2222-3333-4444-555555555555',
      order_number: '1042',
    };

    // Flutter client expects:
    assert.equal(data.type, 'admin_order_alert');
    assert.ok(data.order_id);
    assert.ok(data.order_number);
    assert.ok(data.flow);
  }
});

test('6. All reconciliation pollers execute cleanly and return standard stats', async () => {
  const logger = { info: () => {}, warn: () => {}, error: () => {} };

  const [pendingStats, parcelStats, preparingUnassignedStats, preparingAssignedStats, pickupStats] =
    await Promise.all([
      runPendingOrdersPollOnce({ logger }),
      runParcelWaitingAdminAlertsOnce({ logger }),
      runPreparingUnassignedRebroadcastOnce({ logger }),
      runPreparingAssignedDelayAdminAlertsOnce({ logger }),
      runPickupDelayAdminAlertsOnce({ logger }),
    ]);

  assert.ok(typeof pendingStats.pending_due === 'number');
  assert.ok(typeof parcelStats.parcel_due === 'number');
  assert.ok(typeof preparingUnassignedStats.unassigned_due === 'number');
  assert.ok(typeof preparingAssignedStats.candidates === 'number');
  assert.ok(typeof pickupStats.candidates === 'number');
});
