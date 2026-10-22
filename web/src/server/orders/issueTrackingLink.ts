import type { SupabaseClient } from '@supabase/supabase-js';
import type { CreatedWebOrder } from '@/lib/orders/createdWebOrder';
import { isWebOrderTrackingEnabled } from '@/server/orders/trackingFeatureFlag';
import {
  buildTrackingPath,
  buildTrackingUrl,
  generateTrackingToken,
  hashTrackingToken,
  trackingTokenExpiresAt,
  trackingTokenPrefix,
} from '@/server/orders/trackingToken';

export type TrackingIssueResult = {
  tracking_token: string;
  tracking_url: string;
  tracking_path: string;
};

/**
 * Issue a fresh opaque tracking token for an order.
 * On any failure returns null so order creation can still succeed.
 */
export async function issueWebOrderTrackingLink(
  admin: SupabaseClient,
  params: { orderId: string; restaurantSlug: string },
): Promise<TrackingIssueResult | null> {
  if (!isWebOrderTrackingEnabled()) return null;
  if (!params.orderId?.trim() || !params.restaurantSlug?.trim()) return null;

  try {
    const token = generateTrackingToken();
    const tokenHash = hashTrackingToken(token);
    const prefix = trackingTokenPrefix(token);
    const expiresAt = trackingTokenExpiresAt().toISOString();

    const { error } = await admin.from('web_order_tracking_links').insert({
      order_id: params.orderId,
      token_hash: tokenHash,
      token_prefix: prefix,
      expires_at: expiresAt,
    });

    if (error) {
      console.error('[web-tracking] insert failed', {
        code: error.code,
        message: error.message,
        prefix,
      });
      return null;
    }

    return {
      tracking_token: token,
      tracking_url: buildTrackingUrl(params.restaurantSlug, token),
      tracking_path: buildTrackingPath(params.restaurantSlug, token),
    };
  } catch (err) {
    console.error('[web-tracking] issue failed', {
      message: err instanceof Error ? err.message : 'unknown',
    });
    return null;
  }
}

/** Attach tracking_url/path to a created-order DTO when possible. Never throws. */
export async function withTrackingLink(
  admin: SupabaseClient,
  order: CreatedWebOrder,
  restaurantSlug: string,
): Promise<CreatedWebOrder> {
  if (!order.id) return order;
  const issued = await issueWebOrderTrackingLink(admin, {
    orderId: order.id,
    restaurantSlug,
  });
  if (!issued) return order;
  return {
    ...order,
    tracking_url: issued.tracking_url,
    tracking_path: issued.tracking_path,
  };
}
