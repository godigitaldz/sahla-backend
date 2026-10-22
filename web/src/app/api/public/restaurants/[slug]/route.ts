import { NextRequest, NextResponse } from 'next/server';
import { getSupabaseAnon } from '@/server/supabase/admin';
import { enrichMenuCategoryLabels } from '@/server/enrichMenuCategoryLabels';
import { filterWebMenuItems, type WebMenuItem } from '@/lib/menuCatalog';

export async function GET(
  request: NextRequest,
  context: { params: Promise<{ slug: string }> },
) {
  try {
    const { slug } = await context.params;
    const limit = Number(request.nextUrl.searchParams.get('limit') ?? '50');
    const offset = Number(request.nextUrl.searchParams.get('offset') ?? '0');

    const anon = getSupabaseAnon();

    const { data: restaurant, error: restaurantError } = await anon.rpc(
      'get_public_restaurant_by_slug',
      { p_slug: slug },
    );

    if (restaurantError) {
      return NextResponse.json({ success: false, error: restaurantError.message }, { status: 500 });
    }

    if (!restaurant) {
      return NextResponse.json({ success: false, error: 'restaurant_not_found' }, { status: 404 });
    }

    const { data: menuPayload, error: menuError } = await anon.rpc('get_public_restaurant_menu', {
      p_slug: slug,
      p_limit: limit,
      p_offset: offset,
    });

    if (menuError) {
      return NextResponse.json({ success: false, error: menuError.message }, { status: 500 });
    }

    const rawItems = ((menuPayload as { items?: WebMenuItem[] })?.items ?? []) as WebMenuItem[];
    const enrichedItems = await enrichMenuCategoryLabels(anon, rawItems);

    return NextResponse.json({
      success: true,
      data: {
        restaurant,
        menu: {
          ...(typeof menuPayload === 'object' && menuPayload !== null ? menuPayload : {}),
          items: filterWebMenuItems(enrichedItems),
        },
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'unknown_error';
    return NextResponse.json({ success: false, error: message }, { status: 500 });
  }
}
