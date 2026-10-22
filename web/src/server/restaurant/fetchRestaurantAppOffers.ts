import { getSupabaseAnon } from '@/server/supabase/admin';
import { fallbackLoadPublicRestaurant } from '@/server/publicRestaurant';
import { enrichMenuCategoryLabels } from '@/server/enrichMenuCategoryLabels';
import { filterRestaurantAppOffers } from '@/lib/appOffers/filterRestaurantAppOffers';
import { mergeAppOffersCarousel } from '@/lib/appOffers/mergeAppOffersCarousel';
import { fetchWilayaAppOffers } from '@/server/restaurant/fetchWilayaAppOffers';
import { hydrateSpecialPackVariants } from '@/server/restaurant/hydrateSpecialPackVariants';
import type { WebMenuItem } from '@/lib/menuCatalog';
import type { SheetMenuItem } from '@/components/menu/MenuItemSheet';

export type RestaurantAppOffersPayload = {
  restaurantId: string;
  wilaya: string | null;
  items: WebMenuItem[];
};

type RestaurantRow = {
  id: string;
  wilaya?: string | null;
};

async function loadRawMenuForSlug(slug: string): Promise<WebMenuItem[]> {
  const anon = getSupabaseAnon();

  const { data: menuPayload, error } = await anon.rpc('get_public_restaurant_menu', {
    p_slug: slug,
    p_limit: 200,
    p_offset: 0,
  });

  if (!error && menuPayload) {
    const rows =
      ((menuPayload as { items?: SheetMenuItem[] })?.items ?? []) as SheetMenuItem[];
    return (await enrichMenuCategoryLabels(anon, rows)) as WebMenuItem[];
  }

  const fallback = await fallbackLoadPublicRestaurant(slug);
  if (!fallback?.catalogItems?.length) {
    return [];
  }

  return fallback.catalogItems as WebMenuItem[];
}

async function resolveRestaurant(slug: string): Promise<RestaurantRow | null> {
  const anon = getSupabaseAnon();
  const { data: rpcRestaurant, error } = await anon.rpc('get_public_restaurant_by_slug', {
    p_slug: slug,
  });

  if (!error && rpcRestaurant) {
    return rpcRestaurant as RestaurantRow;
  }

  const fallback = await fallbackLoadPublicRestaurant(slug);
  if (!fallback) return null;
  return {
    id: String(fallback.restaurant.id),
    wilaya: (fallback.restaurant as { wilaya?: string | null }).wilaya ?? null,
  };
}

export async function fetchRestaurantAppOffers(
  slug: string,
): Promise<RestaurantAppOffersPayload | null> {
  const restaurant = await resolveRestaurant(slug);
  if (!restaurant?.id) return null;

  const restaurantId = String(restaurant.id);
  const wilaya = String(restaurant.wilaya ?? '').trim() || null;

  const rawMenu = await loadRawMenuForSlug(slug);
  const ownItems = filterRestaurantAppOffers(rawMenu, restaurantId);
  const wilayahItems = wilaya ? await fetchWilayaAppOffers(wilaya) : [];
  const merged = mergeAppOffersCarousel(ownItems, wilayahItems, restaurantId);
  const items = await hydrateSpecialPackVariants(merged);

  return { restaurantId, wilaya, items };
}
