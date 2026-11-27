import { NextRequest, NextResponse } from 'next/server';
import * as webpush from 'web-push';
import { createClient } from '@supabase/supabase-js';

const VAPID_PUBLIC_KEY =
  process.env.ADMIN_VAPID_PUBLIC_KEY ||
  process.env.NEXT_PUBLIC_ADMIN_VAPID_PUBLIC_KEY ||
  'BCPctlKMTymGl3KJ6qJl22UASeM-nSRSBAmyKrT8xRA9avZMMHMBVk7nQeqRkm_zbSFfjZLyVG1hWN5Q-5dnY3U';
const VAPID_PRIVATE_KEY = process.env.ADMIN_VAPID_PRIVATE_KEY || '';
const VAPID_SUBJECT = process.env.ADMIN_VAPID_SUBJECT || 'mailto:admin@sahla-delivery.com';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json().catch(() => ({}));
    const targetUsername = body.username || 'Hcihem';
    const targetUserId = body.user_id || 'd6863ff7-e462-4463-abef-f9268352ce7d'; // Mr Burger owner

    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL || '';
    const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get active device tokens for target user
    const { data: tokens, error: tokenErr } = await supabase
      .from('user_device_tokens')
      .select('*')
      .eq('user_id', targetUserId)
      .eq('is_active', true);

    if (tokenErr || !tokens || tokens.length === 0) {
      return NextResponse.json({
        success: false,
        error: 'لا يوجد جهاز نشط مسجل لهذا الحساب حالياً. يرجى فتح التطبيق من الشاشة الرئيسية والموافقة على التنبيهات.',
      }, { status: 404 });
    }

    if (VAPID_PRIVATE_KEY) {
      webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY);
    }

    const payload = JSON.stringify({
      title: body.title || 'طلب جديد — Mr Burger',
      body: body.body || '🍔 وصلك طلب تجريبي جديد في مطعم Mr Burger',
      data: {
        url: '/staff/',
        sound: 'new_order_alert',
        type: 'new_order',
      },
    });

    let webSent = 0;
    const errors: string[] = [];

    for (const t of tokens) {
      if (t.platform === 'web') {
        try {
          const sub = typeof t.token === 'string' ? JSON.parse(t.token) : t.token;
          if (sub?.endpoint && sub?.keys) {
            await webpush.sendNotification(sub, payload);
            webSent++;
          }
        } catch (pushErr: any) {
          console.error('[staff-test-push] Web push error:', pushErr.statusCode, pushErr.body || pushErr.message);
          errors.push(pushErr.message || String(pushErr));
        }
      }
    }

    return NextResponse.json({
      success: webSent > 0,
      total_sent: webSent,
      tokens_found: tokens.length,
      errors: errors.length > 0 ? errors : undefined,
    });
  } catch (err: any) {
    console.error('[staff-test-push] Internal error:', err);
    return NextResponse.json({ success: false, error: err.message }, { status: 500 });
  }
}
