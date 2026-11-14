import { NextResponse } from 'next/server';
import { getSupabaseAdmin, getSupabaseAnon } from '@/server/supabase/admin';
import { isAcceptingOrdersNow } from '@/lib/restaurant/restaurantAvailability';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    if (!process.env.SUPABASE_URL) {
      return NextResponse.json({ restaurants: [], cuisines: [], total: 0 });
    }

    let client;
    try {
      client = getSupabaseAdmin();
    } catch {
      client = getSupabaseAnon();
    }

    // Fetch pinned cuisine categories for the top filter row
    const { data: rawCuisines } = await client
      .from('cuisine_types')
      .select('id, name, name_ar, icon, home_category_row_sort_order')
      .eq('pinned_to_home_category_row', true)
      .order('home_category_row_sort_order', { ascending: true });

    const cuisines = (rawCuisines || []).map((c) => ({
      id: c.id,
      name: c.name,
      nameAr: c.name_ar,
      icon: c.icon,
      sortOrder: c.home_category_row_sort_order || 0,
    }));

    // Fetch verified and open restaurants ONLY
    const { data: rawRests, error } = await client
      .from('restaurants')
      .select(
        'id,name,name_ar,name_latin,description,image,cover_image_url,logo_url,rating,review_count,minimum_order,delivery_fee,estimated_delivery_time,is_open,is_featured,is_verified,is_new,public_slug,is_public_web_enabled,opening_hours,closing_hours,vacation_starts_at,vacation_returns_at'
      )
      .eq('is_verified', true)
      .eq('is_open', true)
      .order('is_featured', { ascending: false })
      .order('rating', { ascending: false });

    if (error) {
      console.error('[api/public/restaurants] Supabase error:', error);
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    // Double-defense: enforce real working hours check against local Algerian time
    const rests = (rawRests || []).filter((r) => isAcceptingOrdersNow(r as any));

    const restIds = (rests || []).map((r) => r.id);

    // Fetch menu items to associate cuisines and category tags
    const { data: items } = await client
      .from('menu_items')
      .select('restaurant_id,category,cuisine_type_id,categories(name,name_ar,name_latin)')
      .in('restaurant_id', restIds)
      .eq('is_available', true);

    const catMap: Record<
      string,
      { ar: Set<string>; fr: Set<string>; en: Set<string> }
    > = {};
    const restCuisineMap: Record<string, Set<string>> = {};

    const skipKeywords = ['drink', 'boisson', 'مشروب', 'limited time offer', 'عرض محدود الوقت'];

    for (const it of items || []) {
      const restId = (it as any).restaurant_id;
      if (!catMap[restId]) {
        catMap[restId] = { ar: new Set(), fr: new Set(), en: new Set() };
      }
      if (!restCuisineMap[restId]) {
        restCuisineMap[restId] = new Set();
      }

      if ((it as any).cuisine_type_id) {
        restCuisineMap[restId].add((it as any).cuisine_type_id);
      }

      const catsObj = (it as any).categories;
      const arName = (catsObj?.name_ar || it.category || '').trim();
      const frName = (catsObj?.name_latin || catsObj?.name || it.category || '').trim();
      const enName = (catsObj?.name || catsObj?.name_latin || it.category || '').trim();

      if (arName && !skipKeywords.some((k) => arName.toLowerCase().includes(k))) {
        catMap[restId].ar.add(arName);
      }
      if (frName && !skipKeywords.some((k) => frName.toLowerCase().includes(k))) {
        catMap[restId].fr.add(frName);
      }
      if (enName && !skipKeywords.some((k) => enName.toLowerCase().includes(k))) {
        catMap[restId].en.add(enName);
      }
    }

    const restaurants = (rests || []).map((r) => {
      const catsAr = Array.from(catMap[r.id]?.ar || []).slice(0, 3);
      const catsFr = Array.from(catMap[r.id]?.fr || []).slice(0, 3);
      const catsEn = Array.from(catMap[r.id]?.en || []).slice(0, 3);
      const dt = r.estimated_delivery_time || 30;

      const fallbackDescAr = r.description || 'أشهى المأكولات والوجبات السريعة';
      const fallbackDescFr = r.description || 'Plats savoureux & Fast-food';
      const fallbackDescEn = r.description || 'Delicious Food & Fast Delivery';

      return {
        id: r.id,
        name: r.name,
        nameAr: r.name_ar || r.name,
        nameLatin: r.name_latin || r.name,
        tagAr: catsAr.length > 0 ? catsAr.join(' • ') : fallbackDescAr,
        tagFr: catsFr.length > 0 ? catsFr.join(' • ') : fallbackDescFr,
        tagEn: catsEn.length > 0 ? catsEn.join(' • ') : fallbackDescEn,
        rating: Number(r.rating) || 5.0,
        reviewCount: Number(r.review_count) || 0,
        minimumOrder: Number(r.minimum_order) || 150,
        deliveryFee: Number(r.delivery_fee) || 150,
        deliveryTime: `${dt}-${dt + 10} دقيقة`,
        deliveryTimeEn: `${dt}-${dt + 10} min`,
        logo:
          r.logo_url ||
          r.image ||
          'https://pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev/default_logo.png',
        cover:
          r.cover_image_url ||
          r.image ||
          r.logo_url ||
          'https://pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev/default_cover.jpg',
        slug: r.public_slug,
        isOpen: true,
        isFeatured: r.is_featured ?? false,
        isNew: r.is_new ?? false,
        cuisineTypeIds: Array.from(restCuisineMap[r.id] || []),
      };
    });

    return NextResponse.json(
      { restaurants, cuisines, total: restaurants.length },
      {
        headers: {
          'Cache-Control': 'public, s-maxage=30, stale-while-revalidate=60',
        },
      }
    );
  } catch (err: any) {
    console.error('[api/public/restaurants] Unexpected error:', err);
    return NextResponse.json(
      { error: err?.message || 'Internal Server Error' },
      { status: 500 }
    );
  }
}
