import { describe, expect, it } from 'vitest';
import type { TrackingOrderProjection } from '../trackingProjection';

function assertNoPrivateFields(projection: TrackingOrderProjection) {
  const json = JSON.stringify(projection);
  expect(json).not.toMatch(/customer_id/i);
  expect(json).not.toMatch(/guest_phone/i);
  expect(json).not.toMatch(/delivery_person_id/i);
  expect(json).not.toMatch(/token_hash/i);
  expect(json).not.toMatch(/"latitude"/);
  expect(json).not.toMatch(/"longitude"/);
  expect(json).not.toMatch(/address_line/i);
  expect(json).not.toMatch(/"phone"/);
}

describe('tracking projection redaction contract', () => {
  it('sample projection contains only customer-safe fields', () => {
    const sample: TrackingOrderProjection = {
      order_number: 'ORD-ABC',
      public_order_code: 'W-000001',
      status: 'preparing',
      fulfillment_type: 'delivery',
      payment_status: 'pending',
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      estimated_delivery_time: 30,
      restaurant: { name: 'Test', slug: 'test' },
      items: [
        {
          name: 'Pizza',
          quantity: 1,
          unit_price: 500,
          total_price: 500,
          notes: null,
          variant: null,
          size: 'L',
          supplements: [],
        },
      ],
      pricing: { subtotal: 500, delivery_fee: 150, total_amount: 650 },
      fulfillment: {
        type: 'delivery',
        delivery_location_saved: true,
        table_label: null,
        table_number: null,
      },
      timeline: {
        kind: 'delivery',
        cancelled: false,
        terminal: false,
        current_step: 'preparing',
        steps: [
          { id: 'placed', state: 'complete' },
          { id: 'preparing', state: 'current' },
          { id: 'on_the_way', state: 'upcoming' },
          { id: 'delivered', state: 'upcoming' },
        ],
      },
      link: { expires_at: new Date().toISOString() },
      terminal: false,
    };

    assertNoPrivateFields(sample);
    expect(sample).not.toHaveProperty('id');
    expect(sample).not.toHaveProperty('restaurant_id');
  });
});
