import { NextRequest, NextResponse } from 'next/server';
import { requireStaffSession } from '@/server/staff/auth/staffServerAuth';

export async function GET(request: NextRequest) {
  const auth = await requireStaffSession(request);
  if (!auth.ok) return auth.response;

  const { profile, user, supabaseAdmin } = auth;

  try {
    let query = supabaseAdmin
      .from('restaurants')
      .select('id, name, is_open, public_slug, logo_url, cover_image_url')
      .order('name', { ascending: true });

    if (profile.role !== 'admin' && profile.role !== 'super_admin') {
      if (profile.role === 'owner' || profile.role === 'restaurant_owner') {
        query = query.eq('owner_id', user.id);
      } else {
        const { data: staffMemberships } = await supabaseAdmin
          .from('restaurant_staff_members')
          .select('restaurant_id')
          .eq('user_id', user.id)
          .eq('is_active', true);

        const restIds = (staffMemberships || []).map((m: { restaurant_id: string }) => m.restaurant_id);
        query = query.in('id', restIds.length > 0 ? restIds : ['00000000-0000-0000-0000-000000000000']);
      }
    }

    const { data: restaurants, error } = await query;
    if (error) {
      console.error('[staff-restaurants] DB error:', error);
      return NextResponse.json({ success: false, error: 'تعذر جلب المطاعم' }, { status: 500 });
    }

    return NextResponse.json({
      success: true,
      restaurants: restaurants || [],
    });
  } catch (err: any) {
    console.error('[staff-restaurants] Internal error:', err);
    return NextResponse.json({ success: false, error: 'حدث خطأ في النظام' }, { status: 500 });
  }
}
