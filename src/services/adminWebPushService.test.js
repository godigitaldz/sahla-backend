import test from 'node:test';
import assert from 'node:assert/strict';
import * as webpush from 'web-push';
import { adminWebPushService, isValidPushSubscription, AdminWebPushService } from './adminWebPushService.js';
import { adminAlertEngine } from '../modules/alerts/adminAlertEngine.js';

test('adminWebPushService: isValidPushSubscription validation rules', () => {
  assert.equal(isValidPushSubscription(null), false);
  assert.equal(isValidPushSubscription({}), false);
  assert.equal(isValidPushSubscription({ endpoint: 'http://insecure.endpoint' }), false);
  assert.equal(isValidPushSubscription({ endpoint: 'https://push.example.com' }), false);
  assert.equal(
    isValidPushSubscription({
      endpoint: 'https://push.example.com',
      keys: { p256dh: 'short', auth: 'short' },
    }),
    false,
  );
  assert.equal(
    isValidPushSubscription({
      endpoint: 'https://fcm.googleapis.com/fcm/send/fake-token',
      keys: {
        p256dh: 'BDZ_ValidKeyLength1234567890abcdefghijklmnopqrstuvwxyz',
        auth: 'ValidAuthKey123',
      },
    }),
    true,
  );
});

test('adminWebPushService: VAPID initialization and dynamic config', () => {
  const generated = webpush.generateVAPIDKeys();
  process.env.ADMIN_VAPID_PUBLIC_KEY = generated.publicKey;
  process.env.ADMIN_VAPID_PRIVATE_KEY = generated.privateKey;
  process.env.ADMIN_VAPID_SUBJECT = 'mailto:test@sahla.dz';

  const service = new AdminWebPushService();
  assert.equal(service.isConfigured(), true);
  const pubKey = service.getVapidPublicKey();
  assert.equal(typeof pubKey, 'string');
  assert.equal(pubKey, generated.publicKey);
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
  // Ensure test VAPID keys are configured so we test the full pipeline
  if (!process.env.ADMIN_VAPID_PUBLIC_KEY) {
    const generated = webpush.generateVAPIDKeys();
    process.env.ADMIN_VAPID_PUBLIC_KEY = generated.publicKey;
    process.env.ADMIN_VAPID_PRIVATE_KEY = generated.privateKey;
  }

  const res = await adminWebPushService.sendWebPushToAllAdmins({
    title: 'Test Notification',
    body: 'Test body message',
    data: { order_id: 'test-order-uuid' },
  });
  assert.ok(res.success !== undefined, 'Result should return execution status');
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
