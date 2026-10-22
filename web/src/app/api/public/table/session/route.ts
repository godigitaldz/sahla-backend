import { NextRequest, NextResponse } from 'next/server';
import { TABLE_SESSION_COOKIE } from '@/server/table/cookies';
import { sha256Buffer } from '@/server/table/crypto';
import { getSupabaseAdmin } from '@/server/supabase/admin';

export async function GET(request: NextRequest) {
  try {
    const sessionToken = request.cookies.get(TABLE_SESSION_COOKIE)?.value;
    if (!sessionToken) {
      return NextResponse.json({ success: true, data: { status: 'missing' } });
    }

    const admin = getSupabaseAdmin();
    const { data, error } = await admin.rpc('get_table_session_context', {
      p_session_token_hash: `\\x${sha256Buffer(sessionToken).toString('hex')}`,
    });

    if (error) {
      return NextResponse.json({ success: false, error: error.message }, { status: 500 });
    }

    if (!data || data.status === 'expired') {
      return NextResponse.json({
        success: true,
        data: { status: 'expired', message: 'يرجى إعادة مسح رمز الطاولة' },
      });
    }

    return NextResponse.json({ success: true, data });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'unknown_error';
    return NextResponse.json({ success: false, error: message }, { status: 500 });
  }
}
