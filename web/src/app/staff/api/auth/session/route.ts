import { NextRequest, NextResponse } from 'next/server';
import { createServerClient, type CookieOptions } from '@supabase/ssr';

export async function GET(request: NextRequest) {
  try {
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL || '';
    const supabaseAnonKey =
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || process.env.SUPABASE_ANON_KEY || '';

    const response = NextResponse.json({ authenticated: false });
    const PERMANENT_COOKIE_MAX_AGE = 365 * 24 * 60 * 60;

    const supabase = createServerClient(supabaseUrl, supabaseAnonKey, {
      cookies: {
        get(name: string) {
          return request.cookies.get(name)?.value;
        },
        set(name: string, value: string, options: CookieOptions) {
          response.cookies.set({
            name,
            value,
            ...options,
            maxAge: PERMANENT_COOKIE_MAX_AGE,
            sameSite: 'lax',
            path: '/',
          });
        },
        remove(name: string, options: CookieOptions) {
          response.cookies.set({ name, value: '', ...options, path: '/' });
        },
      },
    });

    const { data: authData } = await supabase.auth.getUser();
    if (!authData?.user) {
      return NextResponse.json({ authenticated: false }, { status: 401 });
    }

    const { data: profile } = await supabase
      .from('user_profiles')
      .select('id, name, role, phone')
      .eq('id', authData.user.id)
      .maybeSingle();

    const finalResponse = NextResponse.json({
      authenticated: true,
      user: {
        id: authData.user.id,
        email: authData.user.email,
        name: profile?.name || 'Staff User',
        role: profile?.role || 'staff',
        phone: profile?.phone,
      },
    });

    response.cookies.getAll().forEach((cookie) => {
      finalResponse.cookies.set({
        ...cookie,
        maxAge: PERMANENT_COOKIE_MAX_AGE,
        sameSite: 'lax',
        path: '/',
      });
    });

    return finalResponse;
  } catch (err: any) {
    return NextResponse.json({ authenticated: false, error: err.message }, { status: 500 });
  }
}

export async function DELETE(request: NextRequest) {
  try {
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL || '';
    const supabaseAnonKey =
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || process.env.SUPABASE_ANON_KEY || '';

    const response = NextResponse.json({ success: true });

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

    await supabase.auth.signOut();
    return response;
  } catch (err: any) {
    return NextResponse.json({ success: false, error: err.message }, { status: 500 });
  }
}
