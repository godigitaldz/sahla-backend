import test from 'node:test';
import assert from 'node:assert/strict';
import { adminWebPushService } from './adminWebPushService.js';
import { adminAlertEngine } from '../modules/alerts/adminAlertEngine.js';

test('adminWebPushService: VAPID initialization and public key retrieval', () => {
  const pubKey = adminWebPushService.getVapidPublicKey();
  assert.ok(typeof pubKey === 'string' && pubKey.length > 20, 'Public key should be a non-empty string');
  assert.match(pubKey, /^[A-Za-z0-9_-]+$/, 'Public key should be valid URL-safe base64');
});

test('adminWebPushService: registerSubscription validation', async () => {
  const missingDev = await adminWebPushService.registerSubscription({
    userId: 'test-user',
    token: 'test-token',
  });
  assert.equal(missingDev.success, false);
  assert.equal(missingDev.error, 'device_id_required');
});

test('adminWebPushService: sendWebPushToAllAdmins gracefully executes with zero active devices', async () => {
  // Should not throw or crash when called with a valid payload
  const res = await adminWebPushService.sendWebPushToAllAdmins({
    title: 'Test Notification',
    body: 'Test body message',
    data: { order_id: 'test-order-uuid' },
  });
  assert.ok(res.success, 'Result should succeed without throwing');
});

test('adminAlertEngine: acknowledgeAlert persists across lookup', async () => {
  const testOrderId = 'c0ffee00-1111-2222-3333-444455556666';
  const ackRes = await adminAlertEngine.acknowledgeAlert({
    alertId: testOrderId,
    operatorName: 'SuperAdmin',
  });
  assert.equal(ackRes.success, true);
  assert.equal(ackRes.alert.status, 'acknowledged');

  // Verify getActiveAlerts includes this acknowledged order
  const alerts = await adminAlertEngine.getActiveAlerts();
  const matched = alerts.find((a) => a.order_id === testOrderId);
  assert.ok(matched, 'Acknowledged order should be present in getActiveAlerts list');
  assert.equal(matched.status, 'acknowledged');
});
