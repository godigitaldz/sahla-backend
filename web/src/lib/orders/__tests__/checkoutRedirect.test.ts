import { describe, expect, it } from 'vitest';
import type { CreatedWebOrder } from '@/lib/orders/createdWebOrder';

function resolvePostCheckoutPath(slug: string, data: CreatedWebOrder): string {
  if (data.tracking_path) return data.tracking_path;
  return (
    `/restaurants/${slug}/success/${encodeURIComponent(data.order_number)}` +
    `?total=${data.total_amount}&type=${data.fulfillment_type}` +
    `&restaurant=${encodeURIComponent(data.restaurant_name)}` +
    `&eta=${data.estimated_delivery_time ?? ''}`
  );
}

describe('checkout redirect preference', () => {
  const base: CreatedWebOrder = {
    id: '11111111-1111-1111-1111-111111111111',
    order_number: 'ORD-TEST',
    total_amount: 900,
    fulfillment_type: 'delivery',
    restaurant_name: 'Test',
    estimated_delivery_time: 30,
  };

  it('prefers tracking_path when present', () => {
    const path = resolvePostCheckoutPath('rb-melty', {
      ...base,
      tracking_path: '/restaurants/rb-melty/track/abcTOKEN',
      tracking_url: 'https://sahla-delivery.com/restaurants/rb-melty/track/abcTOKEN',
    });
    expect(path).toBe('/restaurants/rb-melty/track/abcTOKEN');
    expect(path).not.toContain('/success/');
  });

  it('falls back to legacy success page when tracking fields absent', () => {
    const path = resolvePostCheckoutPath('rb-melty', base);
    expect(path).toContain('/restaurants/rb-melty/success/ORD-TEST');
    expect(path).toContain('total=900');
  });
});
