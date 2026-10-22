import { Suspense } from 'react';
import { notFound } from 'next/navigation';
import { getSupabaseAnon } from '@/server/supabase/admin';
import { fallbackLoadPublicRestaurant } from '@/server/publicRestaurant';
import { enrichMenuCategoryLabels } from '@/server/enrichMenuCategoryLabels';
import { RestaurantMenuClient } from '@/components/restaurant/RestaurantMenuClient';
import type { SheetMenuItem } from '@/components/menu/MenuItemSheet';
import { filterWebMenuItems } from '@/lib/menuCatalog';
import type { WebMenuItem } from '@/lib/menuCatalog';

type Props = {
  params: Promise<{ slug: string }>;
};

export default async function RestaurantMenuPage({ params }: Props) {
  const { slug } = await params;
  const anon = getSupabaseAnon();

  let restaurant: Record<string, unknown> | null = null;
  let items: SheetMenuItem[] = [];
  let catalogItems: WebMenuItem[] = [];

  const assignMenu = (raw: SheetMenuItem[]) => {
    catalogItems = raw as WebMenuItem[];
    items = filterWebMenuItems(catalogItems);
  };

  const { data: rpcRestaurant, error } = await anon.rpc('get_public_restaurant_by_slug', {
    p_slug: slug,
  });

  if (error?.message?.includes('function') || error?.code === 'PGRST202') {
    const fallback = await fallbackLoadPublicRestaurant(slug);
    if (!fallback) notFound();
    restaurant = fallback.restaurant as Record<string, unknown>;
    assignMenu((fallback.catalogItems ?? []) as SheetMenuItem[]);
  } else if (error) {
    throw new Error(error.message);
  } else if (!rpcRestaurant) {
    const fallback = await fallbackLoadPublicRestaurant(slug);
    if (!fallback) notFound();
    restaurant = fallback.restaurant as Record<string, unknown>;
    assignMenu((fallback.catalogItems ?? []) as SheetMenuItem[]);
  } else {
    restaurant = rpcRestaurant as Record<string, unknown>;
    const { data: menuPayload } = await anon.rpc('get_public_restaurant_menu', {
      p_slug: slug,
      p_limit: 100,
      p_offset: 0,
    });
    assignMenu(
      await enrichMenuCategoryLabels(
        anon,
        ((menuPayload as { items?: SheetMenuItem[] })?.items ?? []) as SheetMenuItem[],
      ),
    );
  }

  return (
    <Suspense fallback={null}>
      <RestaurantMenuClient
      slug={slug}
      restaurant={{
        id: String(restaurant.id),
        name: String(restaurant.name),
        name_ar: (restaurant.name_ar as string | null) ?? null,
        name_latin: (restaurant.name_latin as string | null) ?? null,
        logo_url: (restaurant.logo_url as string | null) ?? null,
        public_slug: (restaurant.public_slug as string | null) ?? slug,
        is_open: restaurant.is_open as boolean | null | undefined,
        opening_hours: restaurant.opening_hours,
        closing_hours: restaurant.closing_hours,
        vacation_starts_at: (restaurant.vacation_starts_at as string | null) ?? null,
        vacation_returns_at: (restaurant.vacation_returns_at as string | null) ?? null,
        delivery_fee: Number(restaurant.delivery_fee ?? 0),
        minimum_order: Number(restaurant.minimum_order ?? 0),
        estimated_delivery_time: Number(restaurant.estimated_delivery_time ?? 30),
      }}
      items={items}
      />
    </Suspense>
  );
}
