import { NextRequest, NextResponse } from 'next/server';
import { getSupabaseAdmin } from '@/server/supabase/admin';
import { loadTrackingProjectionByToken } from '@/server/orders/trackingProjection';
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

function genericUnavailable(status: number, code: string) {
  return NextResponse.json(
    { success: false, error: code },
    { status, headers: NO_STORE },
  );
}

type RouteContext = { params: Promise<{ token: string }> };

export async function GET(request: NextRequest, context: RouteContext) {
  // Rollback: flag off blocks reads as well as new token issuance.
  if (!isWebOrderTrackingEnabled()) {
    return genericUnavailable(404, 'unavailable');
  }

  const { token: rawToken } = await context.params;
  const token = decodeURIComponent(rawToken ?? '').trim();

  if (!isValidTrackingTokenFormat(token)) {
    return genericUnavailable(404, 'not_found');
  }

  const ip = clientIp(request);
  const prefix = trackingTokenPrefix(token);

  const [ipOk, tokenOk] = await Promise.all([
    allowTrackingFetchByIp(ip),
    allowTrackingFetchByTokenPrefix(prefix),
  ]);

  if (!ipOk || !tokenOk) {
    return genericUnavailable(429, 'rate_limited');
  }

  try {
    const admin = getSupabaseAdmin();
    const result = await loadTrackingProjectionByToken(admin, token);

    if (!result.ok) {
      if (result.reason === 'expired') {
        return genericUnavailable(410, 'expired');
      }
      if (result.reason === 'revoked') {
        return genericUnavailable(410, 'unavailable');
      }
      return genericUnavailable(404, 'not_found');
    }

    return NextResponse.json(
      { success: true, data: result.projection },
      { status: 200, headers: NO_STORE },
    );
  } catch (err) {
    console.error('[web-tracking] lookup failed', {
      message: err instanceof Error ? err.message : 'unknown',
      prefix,
    });
    return genericUnavailable(500, 'unavailable');
  }
}
