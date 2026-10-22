import type { CreatedWebOrder } from '@/lib/orders/createdWebOrder';

export type { CreatedWebOrder } from '@/lib/orders/createdWebOrder';

export function normalizeCreatedOrder(raw: unknown): CreatedWebOrder | null {
  if (!raw) return null;

  let value: unknown = raw;
  if (typeof value === 'string') {
    try {
      value = JSON.parse(value);
    } catch {
      return null;
    }
  }

  if (typeof value !== 'object' || value === null) return null;
  const row = value as Record<string, unknown>;
  const orderNumber = row.order_number;
  if (typeof orderNumber !== 'string' || !orderNumber.trim()) return null;

  const publicCode =
    typeof row.public_order_code === 'string' ? row.public_order_code.trim() : undefined;

  return {
    id: typeof row.id === 'string' ? row.id : undefined,
    order_number: orderNumber.trim(),
    public_order_code: publicCode,
    total_amount: Number(row.total_amount ?? 0),
    fulfillment_type: String(row.fulfillment_type ?? 'delivery'),
    restaurant_name: String(row.restaurant_name ?? ''),
    estimated_delivery_time:
      row.estimated_delivery_time != null ? Number(row.estimated_delivery_time) : null,
    idempotent: row.idempotent === true,
    duplicate_recovered: row.duplicate_recovered === true,
  };
}

export function isDuplicateOrderGuardError(message: string | null | undefined): boolean {
  return Boolean(message?.includes('منع الطلب المكرر'));
}
