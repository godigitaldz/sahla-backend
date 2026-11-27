import { NextRequest, NextResponse } from 'next/server';
import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';

export interface StaffUserProfile {
  id: string;
  name: string;
  role: string;
  phone?: string;
}

export type StaffAuthCheck =
  | {
      ok: true;
      user: { id: string; email?: string };
      profile: StaffUserProfile;
      supabaseAdmin: SupabaseClient;
    }
  | {
      ok: false;
      response: NextResponse;
    };

export async function requireStaffSession(request: NextRequest): Promise<StaffAuthCheck> {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL || '';
  const supabaseAnonKey =
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || process.env.SUPABASE_ANON_KEY || '';
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || supabaseAnonKey;

  const dummyRes = NextResponse.next();
  const supabase = createServerClient(supabaseUrl, supabaseAnonKey, {
    cookies: {
      get(name: string) {
        return request.cookies.get(name)?.value;
      },
      set(name: string, value: string, options: CookieOptions) {
        dummyRes.cookies.set({ name, value, ...options });
      },
      remove(name: string, options: CookieOptions) {
        dummyRes.cookies.set({ name, value: '', ...options });
      },
    },
  });

  const { data: authData, error: authErr } = await supabase.auth.getUser();
  if (authErr || !authData?.user) {
    return {
      ok: false,
      response: NextResponse.json(
        { success: false, error: 'يجب تسجيل الدخول أولاً' },
        { status: 401 },
      ),
    };
  }

  const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: profile } = await supabaseAdmin
    .from('user_profiles')
    .select('id, name, role, phone')
    .eq('id', authData.user.id)
    .maybeSingle();

  const role = profile?.role || 'customer';
  const isStaff = ['admin', 'super_admin', 'owner', 'manager'].includes(role);

  if (!isStaff) {
    return {
      ok: false,
      response: NextResponse.json(
        { success: false, error: 'غير مصرح لك بالوصول لبوابة الإدارة' },
        { status: 403 },
      ),
    };
  }

  return {
    ok: true,
    user: { id: authData.user.id, email: authData.user.email },
    profile: {
      id: authData.user.id,
      name: profile?.name || 'Staff User',
      role,
      phone: profile?.phone,
    },
    supabaseAdmin,
  };
}
