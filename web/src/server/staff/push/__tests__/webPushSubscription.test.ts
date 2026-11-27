import { describe, expect, it } from 'vitest';
import {
  sanitizePushLog,
  validateWebPushSubscription,
} from '../webPushSubscription';

describe('Staff Web Push Subscription & Ledger Validator', () => {
  const validSubscription = {
    endpoint: 'https://fcm.googleapis.com/fcm/send/sample-subscription-token-12345',
    keys: {
      p256dh: 'BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QT9P_sample_long_key_string_xyz',
      auth: 'sample_auth_token_secret',
    },
  };

  it('validates and parses conforming push subscriptions', () => {
    const res = validateWebPushSubscription('u1', validSubscription, 'Mozilla/5.0');
    expect(res.valid).toBe(true);
    if (res.valid) {
      expect(res.subscription.user_id).toBe('u1');
      expect(res.subscription.endpoint).toBe(validSubscription.endpoint);
      expect(res.subscription.keys.p256dh).toBe(validSubscription.keys.p256dh);
    }
  });

  it('rejects non-HTTPS endpoints', () => {
    const invalidSub = {
      ...validSubscription,
      endpoint: 'http://insecure.endpoint.com/push',
    };
    const res = validateWebPushSubscription('u1', invalidSub);
    expect(res.valid).toBe(false);
    if (!res.valid) expect(res.code).toBe('invalid_endpoint');
  });

  it('rejects missing or truncated encryption keys', () => {
    const missingKeys = {
      endpoint: validSubscription.endpoint,
      keys: { p256dh: 'too_short', auth: '' },
    };
    const res = validateWebPushSubscription('u1', missingKeys);
    expect(res.valid).toBe(false);
    if (!res.valid) expect(res.code).toBe('invalid_keys');
  });

  it('sanitizes push subscriptions for audit logs without leaking secrets', () => {
    const parseRes = validateWebPushSubscription('u1', validSubscription);
    expect(parseRes.valid).toBe(true);
    if (parseRes.valid) {
      const sanitized = sanitizePushLog(parseRes.subscription);
      expect(sanitized.user_id).toBe('u1');
      expect(sanitized.endpoint_domain).toBe('fcm.googleapis.com');
      expect(sanitized.keys_present).toBe(true);
      // Ensure no raw keys or sensitive tokens appear in the sanitized output
      expect((sanitized as any).endpoint).toBeUndefined();
      expect((sanitized as any).keys).toBeUndefined();
    }
  });
});
