import type { WebMenuItem } from '@/lib/menuCatalog';

type RailRow = Record<string, unknown>;

function railMenuItemId(row: RailRow): string {
  const menuItemId = String(row.menu_item_id ?? '').trim();
  if (menuItemId) return menuItemId;
  return String(row.id ?? '').trim();
}

function baseFromRail(row: RailRow, packRow: boolean): WebMenuItem | null {
  const id = railMenuItemId(row);
  if (!id) return null;

  const restaurantId = String(row.restaurant_id ?? '').trim();
  if (!restaurantId) return null;

  const image = String(row.image ?? '').trim();
  if (!image) return null;

  return {
    id,
    restaurant_id: restaurantId,
    name: String(row.name ?? '').trim() || 'عرض',
    name_ar: (row.name_ar as string | null | undefined) ?? null,
    name_latin: (row.name_latin as string | null | undefined) ?? null,
    description: (row.description as string | null | undefined) ?? null,
    image,
    images: row.images,
    price: Number(row.price ?? 0),
    category: (row.category as string | null | undefined) ?? null,
    is_available: row.is_available !== false,
    rating: row.rating != null ? Number(row.rating) : null,
    review_count: row.review_count != null ? Number(row.review_count) : null,
    preparation_time:
      row.preparation_time != null ? Number(row.preparation_time) : null,
    is_limited_offer: Boolean(row.is_limited_offer),
    is_special_pack_catalog_row: packRow,
    offer_start_at: (row.offer_start_at as string | null | undefined) ?? null,
    offer_end_at: (row.offer_end_at as string | null | undefined) ?? null,
    original_price: row.original_price != null ? Number(row.original_price) : null,
    offer_details: row.offer_details,
    offer_types: row.offer_types,
    variants: row.variants,
    pricing_options: row.pricing_options,
    supplements: row.supplements,
    restaurant_name: String(row.restaurant_name ?? '').trim() || undefined,
  } as WebMenuItem & { restaurant_name?: string };
}

export function ltoRailRowsToWebMenuItems(rows: unknown[]): WebMenuItem[] {
  if (!Array.isArray(rows)) return [];
  const out: WebMenuItem[] = [];
  for (const row of rows) {
    if (!row || typeof row !== 'object') continue;
    const item = baseFromRail(row as RailRow, false);
    if (item) out.push(item);
  }
  return out;
}

export function specialPackRailRowsToWebMenuItems(rows: unknown[]): WebMenuItem[] {
  if (!Array.isArray(rows)) return [];
  const out: WebMenuItem[] = [];
  for (const row of rows) {
    if (!row || typeof row !== 'object') continue;
    const item = baseFromRail(row as RailRow, true);
    if (item) out.push(item);
  }
  return out;
}
