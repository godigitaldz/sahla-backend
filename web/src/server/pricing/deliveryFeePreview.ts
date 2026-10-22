import { getSupabaseAdmin } from '../supabase/admin';
import { computeDeliveryTax } from './webOrderTotals';

type PreviewFeeRow = {
  restaurant_id?: string;
  fee_da?: number | null;
};

/** Matches Edge `delivery-fees-preview` → `data.fees[]` (see Flutter DeliveryFeesPreviewService). */
export function parseDeliveryPreviewFee(
  payload: unknown,
  restaurantId: string,
  fallbackBaseFee: number,
): number {
  const root = payload as {
    fees?: unknown;
    data?: { fees?: unknown };
  };

  const rawList = root.data?.fees ?? root.fees;
  if (!Array.isArray(rawList)) {
    return fallbackBaseFee;
  }

  for (const entry of rawList) {
    if (!entry || typeof entry !== 'object') continue;
    const row = entry as PreviewFeeRow;
    if (String(row.restaurant_id ?? '') !== restaurantId) continue;
    const fee = row.fee_da;
    if (fee != null && Number.isFinite(Number(fee))) {
      return Number(fee);
    }
  }

  return fallbackBaseFee;
}

function readConfigNumber(value: unknown): number {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string') {
    const direct = Number(value);
    if (Number.isFinite(direct)) return direct;
    try {
      const parsed = JSON.parse(value) as unknown;
      if (typeof parsed === 'number' && Number.isFinite(parsed)) return parsed;
      if (typeof parsed === 'string') {
        const nested = Number(parsed);
        if (Number.isFinite(nested)) return nested;
      }
    } catch {
      return 0;
    }
  }
  return 0;
}

function roundMoney(value: number): number {
  return Math.round(value * 100) / 100;
}

export function parseBatchDeliveryPreviewFees(
  payload: unknown,
  restaurantIds: string[],
  fallbackById: Record<string, number>,
): Record<string, number> {
  const root = payload as {
    fees?: unknown;
    data?: { fees?: unknown };
  };
  const rawList = root.data?.fees ?? root.fees;
  const out: Record<string, number> = { ...fallbackById };

  if (!Array.isArray(rawList)) {
    return out;
  }

  for (const entry of rawList) {
    if (!entry || typeof entry !== 'object') continue;
    const row = entry as PreviewFeeRow;
    const id = String(row.restaurant_id ?? '').trim();
    if (!id) continue;
    const fee = row.fee_da;
    if (fee != null && Number.isFinite(Number(fee))) {
      out[id] = Number(fee);
    }
  }

  for (const id of restaurantIds) {
    if (out[id] == null && fallbackById[id] != null) {
      out[id] = fallbackById[id];
    }
  }

  return out;
}

export async function fetchBatchDeliveryFeeQuotes(args: {
  customerLatitude: number;
  customerLongitude: number;
  restaurants: Array<{
    id: string;
    latitude: number;
    longitude: number;
    base_fee: number;
  }>;
}): Promise<Record<string, number>> {
  if (args.restaurants.length === 0) return {};

  const url = `${process.env.SUPABASE_URL?.replace(/\/+$/, '')}/functions/v1/delivery-fees-preview`;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceKey) {
    throw new Error('delivery_fee_config_missing');
  }

  const fallbackById = Object.fromEntries(
    args.restaurants.map((r) => [r.id, r.base_fee]),
  );

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${serviceKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      customer_latitude: args.customerLatitude,
      customer_longitude: args.customerLongitude,
      restaurants: args.restaurants.map((r) => ({
        id: r.id,
        latitude: r.latitude,
        longitude: r.longitude,
        base_fee: r.base_fee,
      })),
    }),
  });

  const payload = (await response.json().catch(() => null)) as unknown;
  if (!response.ok) {
    const message =
      payload && typeof payload === 'object' && 'error' in payload
        ? String((payload as { error?: unknown }).error)
        : 'delivery_fee_preview_failed';
    throw new Error(message);
  }

  return parseBatchDeliveryPreviewFees(
    payload,
    args.restaurants.map((r) => r.id),
    fallbackById,
  );
}

export async function fetchDeliveryFeeQuote(args: {
  restaurantId: string;
  restaurantLatitude: number;
  restaurantLongitude: number;
  restaurantBaseFee: number;
  customerLatitude: number;
  customerLongitude: number;
}): Promise<{ originalDeliveryFee: number; deliveryFee: number; deliveryTax: number; netDeliveryAmount: number }> {
  const admin = getSupabaseAdmin();
  const url = `${process.env.SUPABASE_URL?.replace(/\/+$/, '')}/functions/v1/delivery-fees-preview`;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceKey) {
    throw new Error('delivery_fee_config_missing');
  }

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${serviceKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      customer_latitude: args.customerLatitude,
      customer_longitude: args.customerLongitude,
      restaurants: [
        {
          id: args.restaurantId,
          latitude: args.restaurantLatitude,
          longitude: args.restaurantLongitude,
          base_fee: args.restaurantBaseFee,
        },
      ],
    }),
  });

  const payload = (await response.json().catch(() => null)) as unknown;
  if (!response.ok) {
    const message =
      payload && typeof payload === 'object' && 'error' in payload
        ? String((payload as { error?: unknown }).error)
        : 'delivery_fee_preview_failed';
    throw new Error(message);
  }

  const originalDeliveryFee = parseDeliveryPreviewFee(
    payload,
    args.restaurantId,
    args.restaurantBaseFee,
  );
  const deliveryFee = originalDeliveryFee;

  const { data: cfgRows } = await admin
    .from('system_config')
    .select('config_key, config_value')
    .in('config_key', ['delivery_tax', 'delivery_tax_cap_da']);

  const cfg = new Map(
    (cfgRows ?? []).map((r) => [r.config_key, readConfigNumber(r.config_value)]),
  );
  const deliveryTax = computeDeliveryTax(
    deliveryFee,
    cfg.get('delivery_tax') ?? 0.05,
    cfg.get('delivery_tax_cap_da') ?? 35,
  );
  const netDeliveryAmount = Math.max(0, roundMoney(deliveryFee - deliveryTax));

  return {
    originalDeliveryFee: roundMoney(originalDeliveryFee),
    deliveryFee: roundMoney(deliveryFee),
    deliveryTax,
    netDeliveryAmount,
  };
}
