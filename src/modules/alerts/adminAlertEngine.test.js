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

  it('different alert types for the same order are independent (stale_pending does not suppress pickup_delay)', async () => {
    const mockLogger = { info: () => {}, warn: () => {}, error: () => {} };
    const engine = new AdminAlertEngine(mockLogger);
    const orderId = 'order-multi-incident-123';

    // 1. Raise and acknowledge stale_pending
    const raisedPending = await engine.raiseAlert({
      orderId,
      alertType: 'stale_pending',
      severity: 'critical',
      title: 'Stale Pending Order',
      message: 'Order unaccepted > 5 min',
      episodeTimestamp: '2026-11-16T07:00:00.000Z',
    });
    assert.strictEqual(raisedPending.isNew, true);

    await engine.acknowledgeAlert({
      alertId: orderId,
      alertType: 'stale_pending',
      operatorName: 'AdminAmine',
    });

    // 2. Order later suffers a pickup delay incident
    const raisedPickup = await engine.raiseAlert({
      orderId,
      alertType: 'pickup_delay',
      severity: 'critical',
      title: 'Pickup Delay',
      message: 'Order not picked up > 20 min',
      episodeTimestamp: '2026-11-16T07:30:00.000Z',
    });

    // Must NOT be suppressed by the prior acknowledged stale_pending alert
    assert.strictEqual(raisedPickup.isNew, true, 'Distinct alert type for the same order must create a new alert');
    assert.strictEqual(raisedPickup.alert.alert_type, 'pickup_delay');
    assert.strictEqual(raisedPickup.alert.status, 'active');
  });

  it('acknowledgement survives across separate engine instances', async () => {
    const mockLogger = { info: () => {}, warn: () => {}, error: () => {} };
    const engine1 = new AdminAlertEngine(mockLogger);
    const orderId = 'order-cross-instance-456';

    await engine1.raiseAlert({
      orderId,
      alertType: 'prep_unassigned',
      severity: 'critical',
      title: 'Preparing without Courier',
      message: 'Preparing > 5 min without courier',
      episodeTimestamp: '2026-11-16T08:00:00.000Z',
    });

    await engine1.acknowledgeAlert({
      alertId: orderId,
      alertType: 'prep_unassigned',
      operatorName: 'Dispatcher',
    });

    // Simulate subsequent serverless invocation with a fresh engine instance
    const engine2 = new AdminAlertEngine(mockLogger);
    const activeAlerts = await engine2.getActiveAlerts();
    const found = activeAlerts.find((a) => a.order_id === orderId && a.alert_type === 'prep_unassigned');

    assert.ok(found, 'Alert should be accessible from the second engine instance');
    assert.strictEqual(found.status, 'acknowledged');
    assert.strictEqual(found.acknowledged_by, 'Dispatcher');
  });

  it('resolution of an incident permits a new distinct episode alert for the same order', async () => {
    const mockLogger = { info: () => {}, warn: () => {}, error: () => {} };
    const engine = new AdminAlertEngine(mockLogger);
    const orderId = 'order-cycle-episode-789';

    // Episode 1
    const ep1 = await engine.raiseAlert({
      orderId,
      alertType: 'delivery_delay',
      severity: 'critical',
      title: 'Delivery Delay',
      message: 'Transit > 15 min',
      episodeTimestamp: '2026-11-16T09:00:00.000Z',
    });
    assert.strictEqual(ep1.isNew, true);

    // Resolve episode 1
    await engine.resolveOrderAlerts(orderId, 'order_delivered', 'System');

    // Duplicate raise for Episode 1 returns isNew = false
    const ep1Repeat = await engine.raiseAlert({
      orderId,
      alertType: 'delivery_delay',
      severity: 'critical',
      title: 'Delivery Delay',
      message: 'Transit > 15 min',
      episodeTimestamp: '2026-11-16T09:00:00.000Z',
    });
    assert.strictEqual(ep1Repeat.isNew, false);

    // Episode 2: a new distinct timestamp for a subsequent incident
    const ep2 = await engine.raiseAlert({
      orderId,
      alertType: 'delivery_delay',
      severity: 'critical',
      title: 'Delivery Delay Re-opened',
      message: 'Re-delivery transit > 15 min',
      episodeTimestamp: '2026-11-16T10:00:00.000Z',
    });
    assert.strictEqual(ep2.isNew, true, 'New episode timestamp must create a new active alert');
  });

  it('database error visibility: requires alertId for acknowledge and resolve', async () => {
    const mockLogger = { info: () => {}, warn: () => {}, error: () => {} };
    const engine = new AdminAlertEngine(mockLogger);

    const ackMissing = await engine.acknowledgeAlert({});
    assert.strictEqual(ackMissing.success, false);
    assert.strictEqual(ackMissing.error, 'alert_id_required');

    const resolveMissing = await engine.resolveAlert({});
    assert.strictEqual(resolveMissing.success, false);
    assert.strictEqual(resolveMissing.error, 'alert_id_required');
  });
});
