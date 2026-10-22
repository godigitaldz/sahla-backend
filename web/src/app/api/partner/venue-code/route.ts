import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';
import { getVenueCodeForStaff } from '@/server/table/venueCode';
import { getSupabaseAdmin } from '@/server/supabase/admin';

async function verifyRestaurantStaff(request: NextRequest, restaurantId: string) {
  const authHeader = request.headers.get('authorization');
  const token = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : null;
  if (!token) return false;

  const url = process.env.SUPABASE_URL;
  const anonKey = process.env.SUPABASE_ANON_KEY;
  if (!url || !anonKey) return false;

  const client = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });

  const { data: userData } = await client.auth.getUser(token);
  if (!userData.user) return false;

  const { data: staff } = await client
    .from('restaurant_staff_members')
    .select('id')
    .eq('restaurant_id', restaurantId)
    .eq('user_id', userData.user.id)
    .eq('status', 'active')
    .maybeSingle();

  return Boolean(staff);
}

export async function GET(request: NextRequest) {
  const restaurantId = request.nextUrl.searchParams.get('restaurant_id');
  if (!restaurantId) {
    return NextResponse.json({ success: false, error: 'restaurant_id_required' }, { status: 400 });
  }

  const isStaff = await verifyRestaurantStaff(request, restaurantId);
  if (!isStaff) {
    return NextResponse.json({ success: false, error: 'unauthorized' }, { status: 401 });
  }

  const admin = getSupabaseAdmin();
  const { data: restaurant } = await admin
    .from('restaurants')
    .select('table_ordering_enabled')
    .eq('id', restaurantId)
    .maybeSingle();

  if (!restaurant?.table_ordering_enabled) {
    return NextResponse.json({ success: false, error: 'table_ordering_disabled' }, { status: 404 });
  }

  const venue = await getVenueCodeForStaff(restaurantId);
  return NextResponse.json({ success: true, data: venue });
}
