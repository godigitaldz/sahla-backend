import { describe, it } from 'node:test';
import assert from 'node:assert';
import { buildDedupeKey, AdminAlertEngine } from './adminAlertEngine.js';

describe('AdminAlertEngine & Deduplication', () => {
  it('generates consistent dedupe keys', () => {
    const key1 = buildDedupeKey('1042', 'stale_pending', '2026-11-16T06:00:00.000Z');
    const key2 = buildDedupeKey('1042', 'stale_pending', '2026-11-16T06:00:00.000Z');
    const key3 = buildDedupeKey('1042', 'pickup_delay', '2026-11-16T06:00:00.000Z');

    assert.strictEqual(key1, key2);
    assert.strictEqual(key1, 'order:1042:stale_pending:2026-11-16T06:00:00.000Z');
    assert.notStrictEqual(key1, key3);
  });

  it('correctly handles ephemeral lifecycle: raise -> acknowledge -> resolve', async () => {
    const mockLogger = { info: () => {}, warn: () => {}, error: () => {} };
    const engine = new AdminAlertEngine(mockLogger);

    // 1. Raise alert
    const raised = await engine.raiseAlert({
      orderId: 'dummy-order-uuid-1',
      alertType: 'stale_pending',
      severity: 'critical',
      title: 'Order Delayed',
      message: 'Pending for 6 min',
      episodeTimestamp: '2026-11-16T06:10:00.000Z',
    });

    assert.ok(raised);
    assert.ok(raised.alert);
    assert.strictEqual(raised.isNew, true);
    assert.strictEqual(raised.alert.status, 'active');

    // 2. Duplicate raise must return isNew = false
    const duplicate = await engine.raiseAlert({
      orderId: 'dummy-order-uuid-1',
      alertType: 'stale_pending',
      severity: 'critical',
      title: 'Order Delayed',
      message: 'Pending for 6 min',
      episodeTimestamp: '2026-11-16T06:10:00.000Z',
    });
    assert.strictEqual(duplicate.isNew, false);

    // 3. Acknowledge alert by orderId
    const ack = await engine.acknowledgeAlert({
      alertId: 'dummy-order-uuid-1',
      operatorName: 'Amine',
    });
    assert.strictEqual(ack.success, true);
    assert.strictEqual(ack.alert.status, 'acknowledged');
    assert.strictEqual(ack.alert.acknowledged_by, 'Amine');

    // 4. Resolve alert
    const res = await engine.resolveOrderAlerts('dummy-order-uuid-1', 'courier_picked_up', 'Amine');
    assert.strictEqual(res.resolved_count, 1);
  });
});
