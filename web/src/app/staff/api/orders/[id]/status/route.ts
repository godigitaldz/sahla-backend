import { NextRequest, NextResponse } from 'next/server';
import { requireStaffSession } from '@/server/staff/auth/staffServerAuth';
import { validateOrderTransition, type OrderStatus } from '@/server/staff/orders/orderTransitions';

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const auth = await requireStaffSession(request);
  if (!auth.ok) return auth.response;

  const { id: orderId } = await params;
  const body = await request.json().catch(() => ({}));
  const { status: targetStatus, reason } = body as {
    status?: OrderStatus;
    reason?: string;
  };

  if (!targetStatus) {
    return NextResponse.json({ success: false, error: 'الحالة المطلوبة مفقودة' }, { status: 400 });
  }

  const { profile, user, supabaseAdmin } = auth;

  try {
    // 1. Fetch current order
    const { data: order, error: orderErr } = await supabaseAdmin
      .from('orders')
      .select('id, status, restaurant_id')
      .eq('id', orderId)
      .maybeSingle();

    if (orderErr || !order) {
      return NextResponse.json({ success: false, error: 'الطلب غير موجود' }, { status: 404 });
    }

    // 2. Build staff context for order transition check
    const isAdmin = profile.role === 'admin' || profile.role === 'super_admin';
    let restaurantIds: string[] = [];

    if (!isAdmin) {
      if (profile.role === 'owner') {
        const { data: owned } = await supabaseAdmin
          .from('restaurants')
          .select('id')
          .eq('owner_id', user.id);
        restaurantIds = (owned || []).map((r: { id: string }) => r.id);
      } else {
        const { data: staffMembers } = await supabaseAdmin
          .from('restaurant_staff_members')
          .select('restaurant_id')
          .eq('user_id', user.id)
          .eq('is_active', true);
        restaurantIds = (staffMembers || []).map((m: { restaurant_id: string }) => m.restaurant_id);
      }
    }

    const transitionResult = validateOrderTransition(
      {
        user_id: user.id,
        username: profile.name,
        roles: [profile.role as any],
        is_admin: isAdmin,
        restaurant_ids: restaurantIds,
        aal_level: 'aal1',
      },
      {
        currentStatus: order.status as OrderStatus,
        targetStatus,
        orderRestaurantId: order.restaurant_id,
        cancelReason: reason,
      },
    );

    if (!transitionResult.allowed) {
      return NextResponse.json(
        { success: false, error: transitionResult.message },
        { status: 400 },
      );
    }

    // 3. Apply state transition in database
    const now = new Date().toISOString();
    const updatePayload: Record<string, any> = {
      status: targetStatus,
      updated_at: now,
    };

    if (targetStatus === 'preparing') {
      updatePayload.accepted_at = now;
      updatePayload.preparing_started_at = now;
    } else if (targetStatus === 'ready_for_pickup') {
      // ready for courier pickup
    } else if (targetStatus === 'cancelled') {
      updatePayload.cancelled_at = now;
      updatePayload.cancel_reason = reason;
    }

    const { error: updateErr } = await supabaseAdmin
      .from('orders')
      .update(updatePayload)
      .eq('id', orderId);

    if (updateErr) {
      console.error('[staff-order-transition] DB update error:', updateErr);
      return NextResponse.json(
        { success: false, error: 'فشل تحديث حالة الطلب في قاعدة البيانات' },
        { status: 500 },
      );
    }

    return NextResponse.json({
      success: true,
      order_id: orderId,
      status: targetStatus,
    });
  } catch (err: any) {
    console.error('[staff-order-transition] Internal error:', err);
    return NextResponse.json({ success: false, error: 'حدث خطأ في النظام' }, { status: 500 });
  }
}
