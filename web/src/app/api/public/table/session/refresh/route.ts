import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import {
  generateCsrfToken,
  generateSessionToken,
  sha256Buffer,
  sha256Hex,
} from '@/server/table/crypto';
import {
  TABLE_CSRF_COOKIE,
  TABLE_SESSION_COOKIE,
  tableCsrfCookieOptions,
  tableSessionCookieOptions,
} from '@/server/table/cookies';
import { assertAllowedOrigin, assertCsrf } from '@/server/table/csrf';
import { allowVenueAttempt } from '@/server/rateLimit/upstashTableLimiter';
import { getSupabaseAdmin } from '@/server/supabase/admin';
import { tableOrderMaxDistanceMeters } from '@/lib/table/mapTableOrderError';

const bodySchema = z.object({
  table_code: z.string().uuid(),
  latitude: z.number().min(18).max(37.5),
  longitude: z.number().min(-9).max(12),
  device_fingerprint: z.string().max(128).optional(),
});

export async function POST(request: NextRequest) {
  if (!assertAllowedOrigin(request)) {
    return NextResponse.json({ success: false, error: 'forbidden_origin' }, { status: 403 });
  }

  const csrfCookie = request.cookies.get(TABLE_CSRF_COOKIE)?.value;
  if (!assertCsrf(request, csrfCookie)) {
    return NextResponse.json({ success: false, error: 'csrf_invalid' }, { status: 403 });
  }

  const parsed = bodySchema.safeParse(await request.json());
  if (!parsed.success) {
    return NextResponse.json({ success: false, error: 'invalid_body' }, { status: 400 });
  }

  const ip = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? 'unknown';
  const tableHash = sha256Hex(parsed.data.table_code);
  if (!(await allowVenueAttempt(tableHash, ip))) {
    return NextResponse.json({ success: false, error: 'location_locked' }, { status: 429 });
  }

  const sessionToken = generateSessionToken();
  const csrfToken = generateCsrfToken();
  const deviceBinding = parsed.data.device_fingerprint
    ? sha256Buffer(parsed.data.device_fingerprint)
    : null;

  const admin = getSupabaseAdmin();
  const { data, error } = await admin.rpc('exchange_table_presence_by_location', {
    p_table_code: parsed.data.table_code,
    p_customer_latitude: parsed.data.latitude,
    p_customer_longitude: parsed.data.longitude,
    p_session_token_hash: `\\x${sha256Buffer(sessionToken).toString('hex')}`,
    p_device_binding_hash: deviceBinding ? `\\x${deviceBinding.toString('hex')}` : null,
    p_session_ttl_minutes: 30,
    p_max_distance_meters: tableOrderMaxDistanceMeters(),
  });

  if (error) {
    return NextResponse.json({ success: false, error: error.message }, { status: 400 });
  }

  const response = NextResponse.json({
    success: true,
    data: {
      restaurant_slug: data.restaurant_slug,
      expires_at: data.expires_at,
    },
  });

  response.cookies.set(TABLE_SESSION_COOKIE, sessionToken, tableSessionCookieOptions());
  response.cookies.set(TABLE_CSRF_COOKIE, csrfToken, tableCsrfCookieOptions());

  return response;
}
