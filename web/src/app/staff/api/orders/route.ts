import { NextRequest, NextResponse } from 'next/server';
import { requireStaffSession } from '@/server/staff/auth/staffServerAuth';

export async function GET(request: NextRequest) {
  const auth = await requireStaffSession(request);
  if (!auth.ok) return auth.response;

  const { profile, user, supabaseAdmin } = auth;
  const searchParams = request.nextUrl.searchParams;
  const restaurantId = searchParams.get('restaurant_id');
  const statusFilter = searchParams.get('status');

  try {
    let query = supabaseAdmin
      .from('orders')
      .select(`
        id,
        order_number,
        status,
        total_amount,
        cash_payable_amount,
        created_at,
        cancel_reason,
        special_instructions,
        restaurant_id,
        customer_id,
        guest_name,
        guest_phone,
        restaurants (
          id,
          name
        ),
        user_profiles:customer_id (
          name,
          phone
        ),
        order_items (
          id,
          quantity,
          price,
          unit_price,
          menu_items (
            name
          )
        )
      `)
      .order('created_at', { ascending: false })
      .limit(50);

    // Filter by restaurant if specified or required
    if (restaurantId && restaurantId !== 'all') {
      query = query.eq('restaurant_id', restaurantId);
    } else if (profile.role !== 'admin' && profile.role !== 'super_admin') {
      if (profile.role === 'owner') {
        const { data: owned } = await supabaseAdmin
          .from('restaurants')
          .select('id')
          .eq('owner_id', user.id);
        const restIds = (owned || []).map((r: { id: string }) => r.id);
        query = query.in('restaurant_id', restIds.length > 0 ? restIds : ['00000000-0000-0000-0000-000000000000']);
      } else {
        const { data: staffMemberships } = await supabaseAdmin
          .from('restaurant_staff_members')
          .select('restaurant_id')
          .eq('user_id', user.id)
          .eq('is_active', true);
        const restIds = (staffMemberships || []).map((m: { restaurant_id: string }) => m.restaurant_id);
        query = query.in('restaurant_id', restIds.length > 0 ? restIds : ['00000000-0000-0000-0000-000000000000']);
      }
    }

    if (statusFilter && statusFilter !== 'all') {
      query = query.eq('status', statusFilter);
    }

    const { data: rawOrders, error } = await query;
    if (error) {
      console.error('[staff-orders] DB error:', error);
      return NextResponse.json({ success: false, error: 'تعذر جلب الطلبات' }, { status: 500 });
    }

    const formattedOrders = (rawOrders || []).map((ord: any) => {
      const customerProfile = Array.isArray(ord.user_profiles)
        ? ord.user_profiles[0]
        : ord.user_profiles;

      const items = (ord.order_items || []).map((item: any) => {
        const menuItem = Array.isArray(item.menu_items) ? item.menu_items[0] : item.menu_items;
        return {
          id: item.id,
          name: menuItem?.name || 'وجبة ساهلة',
          quantity: item.quantity || 1,
          price: item.unit_price || item.price || 0,
        };
      });

      return {
        id: ord.id,
        order_number: ord.order_number,
        restaurant_name: ord.restaurants?.name || 'مطعم ساهلة',
        restaurant_id: ord.restaurant_id,
        status: ord.status,
        total_price: ord.cash_payable_amount || ord.total_amount || 0,
        created_at: ord.created_at,
        customer_name: customerProfile?.name || ord.guest_name || 'زبون ساهلة',
        customer_phone: customerProfile?.phone || ord.guest_phone || '',
        items,
        cancel_reason: ord.cancel_reason,
      };
    });

    return NextResponse.json({
      success: true,
      orders: formattedOrders,
    });
  } catch (err: any) {
    console.error('[staff-orders] Internal error:', err);
    return NextResponse.json({ success: false, error: 'حدث خطأ في جلب الطلبات' }, { status: 500 });
  }
}
