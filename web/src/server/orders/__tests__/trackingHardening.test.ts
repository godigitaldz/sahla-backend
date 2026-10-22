import { afterEach, describe, expect, it } from 'vitest';
import { isWebOrderTrackingEnabled } from '../trackingFeatureFlag';
import { hasDeliveryLocationSaved } from '../trackingProjection';
import type { TrackingOrderProjection } from '../trackingProjection';
import { resolveCanonicalTrackingPath } from '@/lib/orders/trackingSlug';

afterEach(() => {
  delete process.env.WEB_ORDER_TRACKING_ENABLED;
});

describe('tracking GET flag gate', () => {
  it('blocks reads when WEB_ORDER_TRACKING_ENABLED is false', () => {
    process.env.WEB_ORDER_TRACKING_ENABLED = 'false';
    expect(isWebOrderTrackingEnabled()).toBe(false);
  });

  it('allows reads when enabled', () => {
    process.env.WEB_ORDER_TRACKING_ENABLED = 'true';
    expect(isWebOrderTrackingEnabled()).toBe(true);
  });
});

describe('projection redaction', () => {
  it('does not expose phone, coordinates, or raw address keys', () => {
    const sample: TrackingOrderProjection = {
      order_number: 'ORD-1',
      status: 'pending',
      fulfillment_type: 'delivery',
      payment_status: 'pending',
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      restaurant: { name: 'R', slug: 'r' },
      items: [],
      pricing: { subtotal: 1, delivery_fee: 0, total_amount: 1 },
      fulfillment: { type: 'delivery', delivery_location_saved: true },
      timeline: {
        kind: 'delivery',
        cancelled: false,
        terminal: false,
        current_step: 'placed',
        steps: [],
      },
      link: { expires_at: new Date().toISOString() },
      terminal: false,
    };

    const json = JSON.stringify(sample);
    expect(json).not.toMatch(/phone/i);
    expect(json).not.toMatch(/latitude/i);
    expect(json).not.toMatch(/longitude/i);
    expect(json).not.toMatch(/address_line/i);
    expect(json).not.toMatch(/guest_phone/i);
    expect(json).not.toMatch(/customer_id/i);
    expect(json).not.toMatch(/delivery_person_id/i);
    expect(json).not.toMatch(/token_hash/i);
    expect(sample.restaurant).not.toHaveProperty('phone');
    expect(sample.fulfillment).not.toHaveProperty('address_label');
  });

  it('detects delivery location without exposing contents', () => {
    expect(hasDeliveryLocationSaved({ latitude: 1, longitude: 2 })).toBe(true);
    expect(hasDeliveryLocationSaved({})).toBe(false);
    expect(hasDeliveryLocationSaved(null)).toBe(false);
  });
});

describe('slug canonicalization', () => {
  it('redirects when route slug mismatches projection', () => {
    const result = resolveCanonicalTrackingPath('wrong-slug', 'rb-melty', 'tok123');
    expect(result).toEqual({
      action: 'redirect',
      path: '/restaurants/rb-melty/track/tok123',
    });
  });

  it('returns not_found when projection slug empty', () => {
    expect(resolveCanonicalTrackingPath('x', '', 'tok')).toEqual({ action: 'not_found' });
  });
});
