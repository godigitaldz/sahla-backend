import { NextRequest, NextResponse } from 'next/server';
import { requireStaffSession } from '@/server/staff/auth/staffServerAuth';
import { validateWebPushSubscription, sanitizePushLog } from '@/server/staff/push/webPushSubscription';

export async function POST(request: NextRequest) {
  const auth = await requireStaffSession(request);
  if (!auth.ok) return auth.response;

  const { user, supabaseAdmin } = auth;
  const body = await request.json().catch(() => ({}));
  const userAgent = request.headers.get('user-agent') || '';

  const validation = validateWebPushSubscription(user.id, body.subscription, userAgent);
  if (!validation.valid) {
    return NextResponse.json(
      { success: false, code: validation.code, error: validation.message },
      { status: 400 },
    );
  }

  const sub = validation.subscription;
  const tokenString = JSON.stringify({
    endpoint: sub.endpoint,
    keys: sub.keys,
  });

  const now = new Date().toISOString();

  try {
    // 1. Check if token already exists for user
    const { data: existing } = await supabaseAdmin
      .from('user_device_tokens')
      .select('id')
      .eq('user_id', user.id)
      .eq('platform', 'web')
      .maybeSingle();

    if (existing?.id) {
      await supabaseAdmin
        .from('user_device_tokens')
        .update({
          token: tokenString,
          is_active: true,
          last_seen_at: now,
          updated_at: now,
        })
        .eq('id', existing.id);
    } else {
      await supabaseAdmin.from('user_device_tokens').insert({
        user_id: user.id,
        token: tokenString,
        platform: 'web',
        is_active: true,
        last_seen_at: now,
        created_at: now,
        updated_at: now,
      });
    }

    const logInfo = sanitizePushLog(sub);
    console.log('[staff-push-subscribe] Registered push subscription for:', logInfo);

    return NextResponse.json({
      success: true,
      message: 'تم تفعيل وتخزين اشتراك الإشعارات الفورية بنجاح',
    });
  } catch (err: any) {
    console.error('[staff-push-subscribe] Error:', err);
    return NextResponse.json(
      { success: false, error: 'حدث خطأ أثناء حفظ الاشتراك' },
      { status: 500 },
    );
  }
}
