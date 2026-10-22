import type { SupabaseClient } from '@supabase/supabase-js';
import { resolveTrackingLinkByToken } from '@/server/orders/resolveTrackingLinkByToken';

export type CancelWebOrderResult =
  | { ok: true; order_id: string; status: 'cancelled' }
  | {
      ok: false;
      reason: 'not_found' | 'expired' | 'revoked' | 'not_cancellable' | 'update_failed';
    };

/** Pending guest web orders only — mirrors Flutter tracking cancel gate. */
export function isWebOrderCancellable(status: string, source: string | null | undefined): boolean {
  const normalizedStatus = String(status ?? '').trim().toLowerCase();
  const normalizedSource = String(source ?? '').trim().toLowerCase();
  if (normalizedStatus !== 'pending') return false;
  return normalizedSource === 'web' || normalizedSource === 'web_table';
}

/**
 * Cancel a guest web order via tracking bearer token.
 * Atomic: only updates rows still in `pending`.
 */
export async function cancelWebOrderByTrackingToken(
  admin: SupabaseClient,
  rawToken: string,
): Promise<CancelWebOrderResult> {
  const resolved = await resolveTrackingLinkByToken(admin, rawToken);
  if (!resolved.ok) {
    return { ok: false, reason: resolved.reason };
  }

  const orderId = resolved.link.order_id;

  const { data: order, error: orderError } = await admin
    .from('orders')
    .select('id, status, source')
    .eq('id', orderId)
    .maybeSingle();

  if (orderError || !order) {
    return { ok: false, reason: 'not_found' };
  }

  if (!isWebOrderCancellable(String(order.status ?? ''), order.source as string | null)) {
    return { ok: false, reason: 'not_cancellable' };
  }

  const now = new Date().toISOString();
  const { data: updated, error: updateError } = await admin
    .from('orders')
    .update({
      status: 'cancelled',
      updated_at: now,
    })
    .eq('id', orderId)
    .eq('status', 'pending')
    .select('id, status')
    .maybeSingle();

  if (updateError) {
    return { ok: false, reason: 'update_failed' };
  }

  if (!updated || String(updated.status) !== 'cancelled') {
    // Race: restaurant accepted (or already cancelled) between read and update.
    return { ok: false, reason: 'not_cancellable' };
  }

  return { ok: true, order_id: String(updated.id), status: 'cancelled' };
}
