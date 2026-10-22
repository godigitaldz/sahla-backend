import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getSupabaseAdmin } from '@/server/supabase/admin';
import { isWebOrderPushOperational } from '@/server/orders/pushFeatureFlag';
import { resolveTrackingLinkByToken } from '@/server/orders/resolveTrackingLinkByToken';
import {
  revokeWebPushSubscription,
  upsertWebPushSubscription,
} from '@/server/orders/pushSubscriptionRepository';
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

const postBodySchema = z.object({
  provider: z.literal('fcm_web'),
  registration_kind: z.enum(['fid', 'legacy_token']),
  registration_value: z.string().min(20).max(512),
  permission_state: z.string().max(32).optional(),
  user_agent_family: z.string().max(64).optional(),
  platform_hint: z.string().max(64).optional(),
});

const deleteBodySchema = z.object({
  registration_value: z.string().min(20).max(512),
});

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

async function validateTokenAccess(request: NextRequest, rawToken: string) {
  if (!isWebOrderPushOperational()) {
    return { ok: false as const, response: genericUnavailable(404, 'unavailable') };
  }

  const token = decodeURIComponent(rawToken ?? '').trim();
  if (!isValidTrackingTokenFormat(token)) {
    return { ok: false as const, response: genericUnavailable(404, 'not_found') };
  }

  const ip = clientIp(request);
  const prefix = trackingTokenPrefix(token);
  const [ipOk, tokenOk] = await Promise.all([
    allowTrackingFetchByIp(ip),
    allowTrackingFetchByTokenPrefix(prefix),
  ]);

  if (!ipOk || !tokenOk) {
    return { ok: false as const, response: genericUnavailable(429, 'rate_limited') };
  }

  const admin = getSupabaseAdmin();
  const resolved = await resolveTrackingLinkByToken(admin, token);
  if (!resolved.ok) {
    if (resolved.reason === 'expired') {
      return { ok: false as const, response: genericUnavailable(410, 'expired') };
    }
    if (resolved.reason === 'revoked') {
      return { ok: false as const, response: genericUnavailable(410, 'unavailable') };
    }
    return { ok: false as const, response: genericUnavailable(404, 'not_found') };
  }

  return { ok: true as const, token, link: resolved.link, admin };
}

export async function POST(request: NextRequest, context: RouteContext) {
  const { token: rawToken } = await context.params;
  const gate = await validateTokenAccess(request, rawToken);
  if (!gate.ok) return gate.response;

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return genericUnavailable(400, 'invalid');
  }

  const parsed = postBodySchema.safeParse(body);
  if (!parsed.success) {
    return genericUnavailable(400, 'invalid');
  }

  try {
    const result = await upsertWebPushSubscription(gate.admin, {
      tracking_link_id: gate.link.tracking_link_id,
      order_id: gate.link.order_id,
      registration_kind: parsed.data.registration_kind,
      registration_value: parsed.data.registration_value,
      permission_state: parsed.data.permission_state,
      user_agent_family: parsed.data.user_agent_family,
      platform_hint: parsed.data.platform_hint,
      click_url: gate.link.click_url,
      expires_at: gate.link.expires_at,
    });

    if (!result.ok) {
      return genericUnavailable(503, 'unavailable');
    }

    return NextResponse.json({ success: true }, { status: 200, headers: NO_STORE });
  } catch {
    return genericUnavailable(503, 'unavailable');
  }
}

export async function DELETE(request: NextRequest, context: RouteContext) {
  const { token: rawToken } = await context.params;
  const gate = await validateTokenAccess(request, rawToken);
  if (!gate.ok) return gate.response;

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return genericUnavailable(400, 'invalid');
  }

  const parsed = deleteBodySchema.safeParse(body);
  if (!parsed.success) {
    return genericUnavailable(400, 'invalid');
  }

  try {
    const result = await revokeWebPushSubscription(gate.admin, {
      tracking_link_id: gate.link.tracking_link_id,
      registration_value: parsed.data.registration_value,
    });

    if (!result.ok) {
      return genericUnavailable(503, 'unavailable');
    }

    return NextResponse.json({ success: true }, { status: 200, headers: NO_STORE });
  } catch {
    return genericUnavailable(503, 'unavailable');
  }
}
