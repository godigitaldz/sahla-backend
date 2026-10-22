import { NextRequest, NextResponse } from 'next/server';
import { getSupabaseAdmin } from '@/server/supabase/admin';
import { cancelWebOrderByTrackingToken } from '@/server/orders/cancelWebOrderByToken';
import { isWebOrderTrackingEnabled } from '@/server/orders/trackingFeatureFlag';
import {
  isValidTrackingTokenFormat,
  trackingTokenPrefix,
} from '@/server/orders/trackingToken';
import {
  allowTrackingFetchByIp,
  allowTrackingFetchByTokenPrefix,
} from '@/server/rateLimit/trackingLimiter';

export const dynamic = 'force-dynamic';
export const runtime = 'nodejs';

const NO_STORE = {
  'Cache-Control': 'no-store, no-cache, must-revalidate, private',
  Pragma: 'no-cache',
  'Referrer-Policy': 'no-referrer',
} as const;

function clientIp(request: NextRequest): string {
  const forwarded = request.headers.get('x-forwarded-for');
  if (forwarded) return forwarded.split(',')[0]?.trim() || 'unknown';
  return request.headers.get('x-real-ip')?.trim() || 'unknown';
}

function jsonError(status: number, code: string) {
  return NextResponse.json({ success: false, error: code }, { status, headers: NO_STORE });
}

type RouteContext = { params: Promise<{ token: string }> };

/** Guest cancel while still pending — auth is the tracking bearer token. */
export async function POST(request: NextRequest, context: RouteContext) {
  if (!isWebOrderTrackingEnabled()) {
    return jsonError(404, 'unavailable');
  }

  const { token: rawToken } = await context.params;
  const token = decodeURIComponent(rawToken ?? '').trim();

  if (!isValidTrackingTokenFormat(token)) {
    return jsonError(404, 'not_found');
  }

  const ip = clientIp(request);
  const prefix = trackingTokenPrefix(token);
  const [ipOk, tokenOk] = await Promise.all([
    allowTrackingFetchByIp(ip),
    allowTrackingFetchByTokenPrefix(prefix),
  ]);

  if (!ipOk || !tokenOk) {
    return jsonError(429, 'rate_limited');
  }

  try {
    const admin = getSupabaseAdmin();
    const result = await cancelWebOrderByTrackingToken(admin, token);

    if (!result.ok) {
      if (result.reason === 'expired') return jsonError(410, 'expired');
      if (result.reason === 'revoked') return jsonError(410, 'unavailable');
      if (result.reason === 'not_cancellable') return jsonError(409, 'not_cancellable');
      if (result.reason === 'update_failed') return jsonError(503, 'unavailable');
      return jsonError(404, 'not_found');
    }

    return NextResponse.json(
      { success: true, status: result.status },
      { status: 200, headers: NO_STORE },
    );
  } catch (err) {
    console.error('[web-tracking] cancel failed', {
      message: err instanceof Error ? err.message : 'unknown',
      prefix,
    });
    return jsonError(500, 'unavailable');
  }
}
