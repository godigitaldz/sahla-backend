import { NextRequest, NextResponse } from 'next/server';
import { requireStaffSession } from '@/server/staff/auth/staffServerAuth';
import { validateMenuItemUpdate } from '@/server/staff/menu/menuValidation';

export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const auth = await requireStaffSession(request);
  if (!auth.ok) return auth.response;

  const { id: itemId } = await params;
  const body = await request.json().catch(() => ({}));
  const { profile, user, supabaseAdmin } = auth;

  try {
    // 1. Fetch current menu item snapshot
    const { data: item, error: itemErr } = await supabaseAdmin
      .from('menu_items')
      .select('*')
      .eq('id', itemId)
      .maybeSingle();

    if (itemErr || !item) {
      return NextResponse.json({ success: false, error: 'الطبق غير موجود' }, { status: 404 });
    }

    // 2. Validate tenant access
    const isAdmin = profile.role === 'admin' || profile.role === 'super_admin';
    if (!isAdmin) {
      if (profile.role === 'owner') {
        const { data: rest } = await supabaseAdmin
          .from('restaurants')
          .select('id')
          .eq('id', item.restaurant_id)
          .eq('owner_id', user.id)
          .maybeSingle();
        if (!rest) {
          return NextResponse.json({ success: false, error: 'غير مصرح لك بتعديل هذا الصنف' }, { status: 403 });
        }
      } else {
        const { data: staffMember } = await supabaseAdmin
          .from('restaurant_staff_members')
          .select('restaurant_id')
          .eq('restaurant_id', item.restaurant_id)
          .eq('user_id', user.id)
          .eq('is_active', true)
          .maybeSingle();
        if (!staffMember) {
          return NextResponse.json({ success: false, error: 'غير مصرح لك بتعديل هذا الصنف' }, { status: 403 });
        }
      }
    }

    // 3. Validate patch with Corruption Guard
    const validation = validateMenuItemUpdate(item, body);
    if (!validation.valid) {
      return NextResponse.json(
        { success: false, code: validation.code, error: validation.message },
        { status: 400 },
      );
    }

    // 4. Apply sanitized patch
    const patch = validation.sanitizedPatch;
    const { data: updatedItem, error: updateErr } = await supabaseAdmin
      .from('menu_items')
      .update(patch)
      .eq('id', itemId)
      .select('id, name, price, is_available, preparation_time')
      .single();

    if (updateErr) {
      console.error('[staff-menu-patch] DB update error:', updateErr);
      return NextResponse.json(
        { success: false, error: 'فشل تحديث الصنف في قاعدة البيانات' },
        { status: 500 },
      );
    }

    return NextResponse.json({
      success: true,
      item: updatedItem,
    });
  } catch (err: any) {
    console.error('[staff-menu-patch] Internal error:', err);
    return NextResponse.json({ success: false, error: 'حدث خطأ في النظام' }, { status: 500 });
  }
}
