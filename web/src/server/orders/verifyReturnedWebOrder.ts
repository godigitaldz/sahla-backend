import type { SupabaseClient } from '@supabase/supabase-js';
import type { CreatedWebOrder } from '@/lib/orders/createdWebOrder';

export const IDEMPOTENT_RECOVERY_WINDOW_MS = 10 * 60 * 1000;

export type VerifyWebOrderParams = {
  order: CreatedWebOrder;
  restaurantId: string;
  clientRequestId: string;
  guestPhone: string | null;
  fulfillmentType: string;
  requireRecentWindow: boolean;
};

export type VerifyTableOrderParams = VerifyWebOrderParams & {
  tableSessionId?: string | null;
  tableId?: string | null;
};

export type VerifyResult =
  | { ok: true }
  | { ok: false; reason: 'missing_id' | 'not_found' | 'mismatch' | 'stale' };

export type OrderIdentityRow = {
  id: string;
  client_request_id: string | null;
  restaurant_id: string;
  source: string | null;
  guest_phone: string | null;
  fulfillment_type: string | null;
  created_at: string;
  table_session_id?: string | null;
  table_id?: string | null;
};

export function phonesMatch(a: string | null | undefined, b: string | null | undefined): boolean {
  const left = (a ?? '').trim();
  const right = (b ?? '').trim();
  if (!left && !right) return true;
  return left === right;
}

export function withinRecoveryWindow(createdAt: string, nowMs: number): boolean {
  const created = new Date(createdAt).getTime();
  if (!Number.isFinite(created)) return false;
  return nowMs - created <= IDEMPOTENT_RECOVERY_WINDOW_MS && nowMs - created >= -60_000;
}

export function evaluateWebOrderIdentity(
  row: OrderIdentityRow,
  params: Omit<VerifyWebOrderParams, 'order'> & { orderId: string },
  nowMs: number,
): VerifyResult {
  if (String(row.id) !== params.orderId) return { ok: false, reason: 'mismatch' };
  if (String(row.client_request_id ?? '') !== params.clientRequestId) {
    return { ok: false, reason: 'mismatch' };
  }
  if (String(row.restaurant_id) !== params.restaurantId) {
    return { ok: false, reason: 'mismatch' };
  }
  if (String(row.source ?? '') !== 'web') {
    return { ok: false, reason: 'mismatch' };
  }
  if (String(row.fulfillment_type ?? '') !== params.fulfillmentType) {
    return { ok: false, reason: 'mismatch' };
  }
  if (!phonesMatch(row.guest_phone, params.guestPhone)) {
    return { ok: false, reason: 'mismatch' };
  }
  if (params.requireRecentWindow && !withinRecoveryWindow(row.created_at, nowMs)) {
    return { ok: false, reason: 'stale' };
  }
  return { ok: true };
}

export function evaluateTableOrderIdentity(
  row: OrderIdentityRow,
  params: Omit<VerifyTableOrderParams, 'order'> & { orderId: string },
  nowMs: number,
): VerifyResult {
  if (String(row.id) !== params.orderId) return { ok: false, reason: 'mismatch' };
  if (String(row.client_request_id ?? '') !== params.clientRequestId) {
    return { ok: false, reason: 'mismatch' };
  }
  if (String(row.restaurant_id) !== params.restaurantId) {
    return { ok: false, reason: 'mismatch' };
  }
  if (String(row.source ?? '') !== 'web_table') {
    return { ok: false, reason: 'mismatch' };
  }
  if (String(row.fulfillment_type ?? '') !== 'table') {
    return { ok: false, reason: 'mismatch' };
  }
  if (!phonesMatch(row.guest_phone, params.guestPhone)) {
    return { ok: false, reason: 'mismatch' };
  }

  const sessionOk =
    params.tableSessionId != null &&
    String(row.table_session_id ?? '') === String(params.tableSessionId);
  const tableOk =
    params.tableId != null && String(row.table_id ?? '') === String(params.tableId);
  if (!sessionOk && !tableOk) {
    return { ok: false, reason: 'mismatch' };
  }

  if (params.requireRecentWindow && !withinRecoveryWindow(row.created_at, nowMs)) {
    return { ok: false, reason: 'stale' };
  }
  return { ok: true };
}

async function loadOrderRow(
  admin: SupabaseClient,
  orderId: string,
): Promise<OrderIdentityRow | null> {
  const { data, error } = await admin
    .from('orders')
    .select(
      'id, client_request_id, restaurant_id, source, guest_phone, fulfillment_type, created_at, table_session_id, table_id',
    )
    .eq('id', orderId)
    .maybeSingle();

  if (error || !data) return null;
  return data as OrderIdentityRow;
}

export async function verifyReturnedWebOrder(
  admin: SupabaseClient,
  params: VerifyWebOrderParams,
  nowMs: number = Date.now(),
): Promise<VerifyResult> {
  if (!params.order.id) return { ok: false, reason: 'missing_id' };
  const row = await loadOrderRow(admin, params.order.id);
  if (!row) return { ok: false, reason: 'not_found' };
  return evaluateWebOrderIdentity(
    row,
    {
      orderId: params.order.id,
      restaurantId: params.restaurantId,
      clientRequestId: params.clientRequestId,
      guestPhone: params.guestPhone,
      fulfillmentType: params.fulfillmentType,
      requireRecentWindow: params.requireRecentWindow,
    },
    nowMs,
  );
}

export async function verifyReturnedTableOrder(
  admin: SupabaseClient,
  params: VerifyTableOrderParams,
  nowMs: number = Date.now(),
): Promise<VerifyResult> {
  if (!params.order.id) return { ok: false, reason: 'missing_id' };
  const row = await loadOrderRow(admin, params.order.id);
  if (!row) return { ok: false, reason: 'not_found' };
  return evaluateTableOrderIdentity(
    row,
    {
      orderId: params.order.id,
      restaurantId: params.restaurantId,
      clientRequestId: params.clientRequestId,
      guestPhone: params.guestPhone,
      fulfillmentType: params.fulfillmentType,
      tableSessionId: params.tableSessionId,
      tableId: params.tableId,
      requireRecentWindow: params.requireRecentWindow,
    },
    nowMs,
  );
}
