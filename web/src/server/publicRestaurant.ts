import { getSupabaseAdmin } from '@/server/supabase/admin';
import { filterWebMenuItems, type WebMenuItem } from '@/lib/menuCatalog';

export async function fallbackLoadPublicRestaurant(slug: string) {
  const admin = getSupabaseAdmin();
  const baseSelect =
    'id,name,name_ar,name_latin,description,logo_url,cover_image_url,phone,address_line1,city,wilaya,latitude,longitude,is_open,is_verified,opening_hours,closing_hours,vacation_starts_at,vacation_returns_at,estimated_delivery_time,minimum_order,delivery_fee,is_new';

  let restaurant: Record<string, unknown> | null = null;

  const withSlug = await admin
    .from('restaurants')
    .select(`${baseSelect},public_slug,is_public_web_enabled,web_order_commission_rate,web_order_commission_cap_da`)
    .eq('public_slug', slug)
    .eq('is_verified', true)
    .eq('is_public_web_enabled', true)
    .maybeSingle();

  if (withSlug.error?.message?.includes('public_slug')) {
    return null;
  }

  restaurant = withSlug.data as Record<string, unknown> | null;

  if (!restaurant) return null;

  const { data: items } = await admin
    .from('menu_items')
    .select(
      'id,restaurant_id,name,name_ar,name_latin,description,description_ar,description_latin,image,images,price,category,category_id,is_available,preparation_time,rating,review_count,variants,pricing_options,supplements,is_limited_offer,offer_start_at,offer_end_at,original_price,offer_details,main_ingredients,ingredients,updated_at,categories(name,name_ar,name_latin,icon,display_order)',
    )
    .eq('restaurant_id', restaurant.id)
    .eq('is_available', true)
    .order('category', { ascending: true })
    .order('name', { ascending: true })
    .limit(100);

  const normalized = normalizeMenuRows((items ?? []) as Record<string, unknown>[]);
  return { restaurant, catalogItems: normalized, items: filterWebMenuItems(normalized) };
}

function normalizeMenuRows(rows: Record<string, unknown>[]): WebMenuItem[] {
  return rows.map((row) => {
    const categories = row.categories as
      | {
          name?: string;
          name_ar?: string;
          name_latin?: string;
          icon?: string | null;
          display_order?: number | null;
        }
      | null
      | undefined;
    const { categories: _drop, ...rest } = row;
    return {
      ...rest,
      category_name: categories?.name ?? rest.category_name ?? null,
      category_name_ar: categories?.name_ar ?? rest.category_name_ar ?? null,
      category_name_latin: categories?.name_latin ?? rest.category_name_latin ?? null,
      category_icon: categories?.icon ?? rest.category_icon ?? null,
      category_display_order:
        categories?.display_order ?? rest.category_display_order ?? null,
    } as WebMenuItem;
  });
}
