import { NextRequest, NextResponse } from 'next/server';
import { createServerClient, type CookieOptions } from '@supabase/ssr';
import {
  checkStaffAuthRateLimit,
  recordStaffAuthFailure,
  clearStaffAuthFailures,
} from '@/server/staff/auth/authRateLimiter';
import {
  usernameToInternalAlias,
  isValidUsername,
  normalizeUsername,
} from '@/server/staff/auth/usernameAlias';
import { getStaffCookieName } from '@/lib/staff/staffConfig';
import { type StaffDeviceType } from '@/server/staff/auth/sessionMeta';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json().catch(() => ({}));
    const { username, password, device_type = 'personal' } = body as {
      username?: string;
      password?: string;
      device_type?: StaffDeviceType;
    };

    if (!username || !password) {
      return NextResponse.json(
        { success: false, error: 'اسم المستخدم وكلمة المرور مطلوبان' },
        { status: 400 },
      );
    }

    const check = isValidUsername(username);
    if (!check.valid) {
      return NextResponse.json(
        { success: false, error: 'اسم مستخدم غير صالح' },
        { status: 400 },
      );
    }

    const clientIp =
      request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ||
      request.headers.get('x-real-ip') ||
      '127.0.0.1';

    // 1. Shared rate limiting check via Upstash Redis
    const rateLimit = await checkStaffAuthRateLimit(username, clientIp);
    if (!rateLimit.allowed) {
      return NextResponse.json(
        { success: false, error: rateLimit.message || 'تم تجاوز الحد المسموح من المحاولات' },
        { status: 429 },
      );
    }

    // 2. Resolve internal non-deliverable alias
    const internalAlias = usernameToInternalAlias(username);

    // 3. Prepare response with cookie support
    const response = NextResponse.json({ success: true });

    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL || '';
    const supabaseAnonKey =
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || process.env.SUPABASE_ANON_KEY || '';

    const supabase = createServerClient(supabaseUrl, supabaseAnonKey, {
      cookies: {
        get(name: string) {
          return request.cookies.get(name)?.value;
        },
        set(name: string, value: string, options: CookieOptions) {
          response.cookies.set({ name, value, ...options });
        },
        remove(name: string, options: CookieOptions) {
          response.cookies.set({ name, value: '', ...options });
        },
      },
    });

    // 4. Authenticate via Supabase Auth
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email: internalAlias,
      password,
    });

    if (authError || !authData.user) {
      await recordStaffAuthFailure(username);
      return NextResponse.json(
        { success: false, error: 'اسم المستخدم أو كلمة المرور غير صحيحة' },
        { status: 401 },
      );
    }

    const user = authData.user;
    await clearStaffAuthFailures(username);

    // 5. Verify Staff / Admin Role in user_profiles
    const { data: profile } = await supabase
      .from('user_profiles')
      .select('id, name, role, phone')
      .eq('id', user.id)
      .maybeSingle();

    const role = profile?.role || 'customer';
    const isStaffOrAdmin = role === 'admin' || role === 'super_admin' || role === 'owner' || role === 'manager';

    if (!isStaffOrAdmin) {
      // Sign out unauthorized user immediately
      await supabase.auth.signOut();
      return NextResponse.json(
        { success: false, error: 'هذا الحساب ليس لديه صلاحية الدخول لبوابة الإدارة' },
        { status: 403 },
      );
    }

    // Return authenticated profile info
    return NextResponse.json({
      success: true,
      user: {
        id: user.id,
        username: normalizeUsername(username),
        name: profile?.name || username,
        role: profile?.role,
        phone: profile?.phone,
        device_type,
      },
    });
  } catch (err: any) {
    console.error('[staff-login] Error:', err);
    return NextResponse.json(
      { success: false, error: 'حدث خطأ في النظام. يرجى المحاولة لاحقاً.' },
      { status: 500 },
    );
  }
}
