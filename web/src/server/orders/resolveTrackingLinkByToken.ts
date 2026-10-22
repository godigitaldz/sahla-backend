import type { SupabaseClient } from '@supabase/supabase-js';
import { buildTrackingUrl } from '@/server/orders/trackingToken';
import { hashTrackingToken } from '@/server/orders/trackingToken';

export type ResolvedTrackingLink = {
  tracking_link_id: string;
  order_id: string;
  expires_at: string;
  revoked_at: string | null;
  restaurant_slug: string;
  /** Server-only secure URL — never log or return to browser. */
  click_url: string;
};

export type ResolveTrackingLinkResult =
  | { ok: true; link: ResolvedTrackingLink }
  | { ok: false; reason: 'not_found' | 'expired' | 'revoked' };

/**
 * Resolve a tracking link by raw bearer token.
 * Private ids and click_url are server-only.
 */
export async function resolveTrackingLinkByToken(
  admin: SupabaseClient,
  rawToken: string,
): Promise<ResolveTrackingLinkResult> {
  const tokenHash = hashTrackingToken(rawToken);

  const { data: link, error: linkError } = await admin
    .from('web_order_tracking_links')
    .select('id, order_id, expires_at, revoked_at')
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
    .select('restaurants!inner(public_slug)')
    .eq('id', link.order_id)
    .maybeSingle();

  if (orderError || !order) {
    return { ok: false, reason: 'not_found' };
  }

  const orderRow = order as unknown as Record<string, unknown>;
  const restaurantRaw = Array.isArray(orderRow.restaurants)
    ? orderRow.restaurants[0]
    : orderRow.restaurants;
  const restaurant = (restaurantRaw ?? {}) as Record<string, unknown>;
  const slug = String(restaurant.public_slug ?? '').trim();
  if (!slug) {
    return { ok: false, reason: 'not_found' };
  }

  return {
    ok: true,
    link: {
      tracking_link_id: String(link.id),
      order_id: String(link.order_id),
      expires_at: String(link.expires_at),
      revoked_at: link.revoked_at ? String(link.revoked_at) : null,
      restaurant_slug: slug,
      click_url: buildTrackingUrl(slug, rawToken),
    },
  };
}
