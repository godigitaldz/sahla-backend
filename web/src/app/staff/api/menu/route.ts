import { NextRequest, NextResponse } from 'next/server';
import { requireStaffSession } from '@/server/staff/auth/staffServerAuth';

export async function GET(request: NextRequest) {
  const auth = await requireStaffSession(request);
  if (!auth.ok) return auth.response;

  const { supabaseAdmin } = auth;
  const searchParams = request.nextUrl.searchParams;
  let restaurantId = searchParams.get('restaurant_id');

  try {
    if (!restaurantId || restaurantId === 'all') {
      // Pick first active restaurant if not specified
      const { data: firstRest } = await supabaseAdmin
        .from('restaurants')
        .select('id')
        .order('name', { ascending: true })
        .limit(1)
        .maybeSingle();
      restaurantId = firstRest?.id || null;
    }

    if (!restaurantId) {
      return NextResponse.json({ success: true, items: [] });
    }

    const { data: rawItems, error } = await supabaseAdmin
      .from('menu_items')
      .select(`
        id,
        name,
        price,
        is_available,
        preparation_time,
        restaurant_id,
        category_id,
        variants,
        supplements,
        categories (
          name
        )
      `)
      .eq('restaurant_id', restaurantId)
      .order('name', { ascending: true });

    if (error) {
      console.error('[staff-menu] DB error:', error);
      return NextResponse.json({ success: false, error: 'تعذر جلب قائمة الطعام' }, { status: 500 });
    }

    const items = (rawItems || []).map((item: any) => {
      const categoryName = Array.isArray(item.categories)
        ? item.categories[0]?.name
        : item.categories?.name;

      const hasVariants = Boolean(item.variants && Array.isArray(item.variants) && item.variants.length > 0);
      const hasSupplements = Boolean(item.supplements && Array.isArray(item.supplements) && item.supplements.length > 0);

      return {
        id: item.id,
        name: item.name,
        category: categoryName || 'عام',
        price: item.price || 0,
        preparation_time: item.preparation_time || 20,
        is_available: item.is_available ?? true,
        has_complex_variants: hasVariants || hasSupplements,
      };
    });

    return NextResponse.json({
      success: true,
      items,
    });
  } catch (err: any) {
    console.error('[staff-menu] Internal error:', err);
    return NextResponse.json({ success: false, error: 'حدث خطأ في النظام' }, { status: 500 });
  }
}
