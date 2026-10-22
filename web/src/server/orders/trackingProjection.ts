import type { SupabaseClient } from '@supabase/supabase-js';
import {
  buildTrackingTimeline,
  isTerminalOrderStatus,
  type TrackingTimeline,
} from '@/lib/orders/trackingTimeline';
import { hashTrackingToken } from '@/server/orders/trackingToken';

export type TrackingItemProjection = {
  name: string;
  quantity: number;
  unit_price: number;
  total_price: number;
  notes?: string | null;
  variant?: string | null;
  size?: string | null;
  supplements?: string[];
};

export type TrackingOrderProjection = {
  order_number: string;
  public_order_code?: string | null;
  status: string;
  fulfillment_type: string;
  payment_status: string;
  created_at: string;
  updated_at: string;
  estimated_delivery_time?: number | null;
  restaurant: {
    name: string;
    slug: string;
  };
  items: TrackingItemProjection[];
  pricing: {
    subtotal: number;
    delivery_fee: number;
    total_amount: number;
  };
  fulfillment: {
    type: string;
    delivery_location_saved?: boolean;
    table_label?: string | null;
    table_number?: string | null;
  };
  timeline: TrackingTimeline;
  link: {
    expires_at: string;
  };
  terminal: boolean;
};

export type TrackingLookupResult =
  | { ok: true; projection: TrackingOrderProjection }
  | { ok: false; reason: 'not_found' | 'expired' | 'revoked' };

function asRecord(value: unknown): Record<string, unknown> | null {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return null;
}

function itemNameFromCustomizations(customizations: unknown): string {
  const c = asRecord(customizations);
  if (!c) return 'عنصر';
  const name = c.menu_item_name ?? c.name;
  return typeof name === 'string' && name.trim() ? name.trim() : 'عنصر';
}

/** True when a delivery address object exists without exposing its contents. */
export function hasDeliveryLocationSaved(deliveryAddress: unknown): boolean {
  const addr = asRecord(deliveryAddress);
  if (!addr) return false;
  return Object.keys(addr).length > 0;
}

function mapItems(rows: unknown[]): TrackingItemProjection[] {
  return rows.map((row) => {
    const r = asRecord(row) ?? {};
    const c = asRecord(r.customizations) ?? {};
    const supplementsRaw = c.supplements;
    const supplements = Array.isArray(supplementsRaw)
      ? supplementsRaw.map((s) => String(s)).filter(Boolean)
      : [];
    return {
      name: itemNameFromCustomizations(r.customizations),
      quantity: Math.max(1, Number(r.quantity ?? 1)),
      unit_price: Number(r.unit_price ?? 0),
      total_price: Number(r.total_price ?? 0),
      notes: typeof r.special_instructions === 'string' ? r.special_instructions : null,
      variant:
        typeof c.variant_name === 'string'
          ? c.variant_name
          : typeof c.variant === 'string'
            ? c.variant
            : null,
      size:
        typeof c.pricing_size === 'string'
          ? c.pricing_size
          : typeof c.size === 'string'
            ? c.size
            : null,
      supplements,
    };
  });
}

export async function loadTrackingProjectionByToken(
  admin: SupabaseClient,
  rawToken: string,
): Promise<TrackingLookupResult> {
  const tokenHash = hashTrackingToken(rawToken);

  const { data: link, error: linkError } = await admin
    .from('web_order_tracking_links')
    .select('id, order_id, expires_at, revoked_at, last_seen_at')
    .eq('token_hash', tokenHash)
    .maybeSingle();

  if (linkError || !link) {
    return { ok: false, reason: 'not_found' };
  }

  if (link.revoked_at) {
    return { ok: false, reason: 'revoked' };
  }

  const expiresAt = new Date(String(link.expires_at)).getTime();
  if (!Number.isFinite(expiresAt) || expiresAt <= Date.now()) {
    return { ok: false, reason: 'expired' };
  }

  const { data: order, error: orderError } = await admin
    .from('orders')
    .select(
      [
        'order_number',
        'public_order_code',
        'status',
        'fulfillment_type',
        'payment_status',
        'created_at',
        'updated_at',
        'estimated_delivery_time',
        'subtotal',
        'delivery_fee',
        'total_amount',
        'delivery_address',
        'pricing_snapshot',
        'restaurants!inner(name, public_slug)',
        'restaurant_tables(table_number, table_label)',
        'order_items(quantity, unit_price, total_price, special_instructions, customizations)',
      ].join(','),
    )
    .eq('id', link.order_id)
    .maybeSingle();

  if (orderError || !order) {
    return { ok: false, reason: 'not_found' };
  }

  const orderRow = order as unknown as Record<string, unknown>;
  const restaurantRaw = Array.isArray(orderRow.restaurants)
    ? orderRow.restaurants[0]
    : orderRow.restaurants;
  const restaurant = asRecord(restaurantRaw) ?? {};
  const tableRaw = Array.isArray(orderRow.restaurant_tables)
    ? orderRow.restaurant_tables[0]
    : orderRow.restaurant_tables;
  const tableRow = asRecord(tableRaw);
  const snapshot = asRecord(orderRow.pricing_snapshot);
  const itemsRaw = Array.isArray(orderRow.order_items) ? orderRow.order_items : [];
  const status = String(orderRow.status ?? 'pending');
  const fulfillmentType = String(orderRow.fulfillment_type ?? 'delivery');
  const timeline = buildTrackingTimeline(status, fulfillmentType);

  const lastSeen = link.last_seen_at ? new Date(String(link.last_seen_at)).getTime() : 0;
  if (!Number.isFinite(lastSeen) || Date.now() - lastSeen > 60_000) {
    void (async () => {
      try {
        await admin
          .from('web_order_tracking_links')
          .update({ last_seen_at: new Date().toISOString() })
          .eq('id', link.id);
      } catch {
        /* non-critical */
      }
    })();
  }

  const tableNumber =
    tableRow?.table_number != null
      ? String(tableRow.table_number)
      : snapshot?.table_number != null
        ? String(snapshot.table_number)
        : null;
  const tableLabel =
    tableRow?.table_label != null
      ? String(tableRow.table_label)
      : snapshot?.table_label != null
        ? String(snapshot.table_label)
        : null;

  const projection: TrackingOrderProjection = {
    order_number: String(orderRow.order_number ?? ''),
    public_order_code: orderRow.public_order_code ? String(orderRow.public_order_code) : null,
    status,
    fulfillment_type: fulfillmentType,
    payment_status: String(orderRow.payment_status ?? 'pending'),
    created_at: String(orderRow.created_at ?? ''),
    updated_at: String(orderRow.updated_at ?? ''),
    estimated_delivery_time:
      orderRow.estimated_delivery_time != null ? Number(orderRow.estimated_delivery_time) : null,
    restaurant: {
      name: String(restaurant.name ?? ''),
      slug: String(restaurant.public_slug ?? ''),
    },
    items: mapItems(itemsRaw),
    pricing: {
      subtotal: Number(orderRow.subtotal ?? 0),
      delivery_fee: Number(orderRow.delivery_fee ?? 0),
      total_amount: Number(orderRow.total_amount ?? 0),
    },
    fulfillment: {
      type: fulfillmentType,
      delivery_location_saved:
        fulfillmentType === 'delivery'
          ? hasDeliveryLocationSaved(orderRow.delivery_address)
          : false,
      table_label: tableLabel,
      table_number: tableNumber,
    },
    timeline,
    link: {
      expires_at: String(link.expires_at),
    },
    terminal: isTerminalOrderStatus(status),
  };

  return { ok: true, projection };
}
