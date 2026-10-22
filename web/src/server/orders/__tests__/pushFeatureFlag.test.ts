import { afterEach, describe, expect, it } from 'vitest';
import {
  isWebOrderPushEnabled,
  isWebOrderPushOperational,
  webOrderPushProvider,
} from '../pushFeatureFlag';

afterEach(() => {
  delete process.env.WEB_ORDER_PUSH_ENABLED;
  delete process.env.WEB_ORDER_TRACKING_ENABLED;
  delete process.env.WEB_ORDER_PUSH_PROVIDER;
});

describe('pushFeatureFlag', () => {
  it('is off by default', () => {
    expect(isWebOrderPushEnabled()).toBe(false);
  });

  it('enables with true/1', () => {
    process.env.WEB_ORDER_PUSH_ENABLED = 'true';
    expect(isWebOrderPushEnabled()).toBe(true);
  });

  it('requires tracking enabled for operational', () => {
    process.env.WEB_ORDER_PUSH_ENABLED = 'true';
    process.env.WEB_ORDER_TRACKING_ENABLED = 'false';
    expect(isWebOrderPushOperational()).toBe(false);
    process.env.WEB_ORDER_TRACKING_ENABLED = 'true';
    expect(isWebOrderPushOperational()).toBe(true);
  });

  it('defaults provider to fcm_web', () => {
    expect(webOrderPushProvider()).toBe('fcm_web');
  });
});
