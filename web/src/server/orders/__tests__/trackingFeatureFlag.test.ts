import { describe, expect, it } from 'vitest';
import { isWebOrderTrackingEnabled } from '../trackingFeatureFlag';

describe('isWebOrderTrackingEnabled', () => {
  it('defaults to false when unset', () => {
    const prev = process.env.WEB_ORDER_TRACKING_ENABLED;
    delete process.env.WEB_ORDER_TRACKING_ENABLED;
    expect(isWebOrderTrackingEnabled()).toBe(false);
    if (prev === undefined) delete process.env.WEB_ORDER_TRACKING_ENABLED;
    else process.env.WEB_ORDER_TRACKING_ENABLED = prev;
  });

  it('accepts true/1/on', () => {
    const prev = process.env.WEB_ORDER_TRACKING_ENABLED;
    process.env.WEB_ORDER_TRACKING_ENABLED = 'true';
    expect(isWebOrderTrackingEnabled()).toBe(true);
    process.env.WEB_ORDER_TRACKING_ENABLED = '1';
    expect(isWebOrderTrackingEnabled()).toBe(true);
    process.env.WEB_ORDER_TRACKING_ENABLED = 'off';
    expect(isWebOrderTrackingEnabled()).toBe(false);
    if (prev === undefined) delete process.env.WEB_ORDER_TRACKING_ENABLED;
    else process.env.WEB_ORDER_TRACKING_ENABLED = prev;
  });
});
