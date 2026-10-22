import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { isWebOrderPushOperational } from '@/server/orders/pushFeatureFlag';
import { invokeWebOrderPush } from '@/server/notifications/webOrderPushGateway';

export const dynamic = 'force-dynamic';
export const runtime = 'nodejs';

const bodySchema = z.object({
  order_id: z.string().uuid(),
  title: z.string().max(120).optional(),
  body: z.string().max(240).optional(),
});

function unauthorized() {
  return NextResponse.json({ success: false, error: 'unauthorized' }, { status: 401 });
}

function verifyInternalAuth(request: NextRequest): boolean {
  const authHeader = request.headers.get('authorization')?.trim() ?? '';
  const bearer = authHeader.toLowerCase().startsWith('bearer ')
    ? authHeader.slice(7).trim()
    : '';
  const internal = String(process.env.PUSH_NOTIFICATION_INTERNAL_SECRET ?? '').trim();
  const serviceRole = String(process.env.SUPABASE_SERVICE_ROLE_KEY ?? '').trim();
  if (internal && bearer === internal) return true;
  if (serviceRole && bearer === serviceRole) return true;
  return false;
}

/** Internal-only: triggers send-web-order-push Edge Function (no FCM on Vercel). */
export async function POST(request: NextRequest) {
  if (!verifyInternalAuth(request)) {
    return unauthorized();
  }

  if (!isWebOrderPushOperational()) {
    return NextResponse.json({ success: false, error: 'unavailable' }, { status: 404 });
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ success: false, error: 'invalid' }, { status: 400 });
  }

  const parsed = bodySchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ success: false, error: 'invalid' }, { status: 400 });
  }

  try {
    const result = await invokeWebOrderPush({
      order_id: parsed.data.order_id,
      mode: 'test',
      title: parsed.data.title,
      body: parsed.data.body,
    });

    if (!result.success) {
      return NextResponse.json(
        { success: false, error: 'send_failed', total_sent: result.total_sent ?? 0 },
        { status: result.status && result.status >= 400 ? result.status : 502 },
      );
    }

    return NextResponse.json({
      success: true,
      total_sent: result.total_sent ?? 0,
    });
  } catch {
    return NextResponse.json({ success: false, error: 'unavailable' }, { status: 503 });
  }
}
