import type { WebMenuItem } from '@/lib/menuCatalog';
import { filterActiveAppOffers } from '@/lib/appOffers/filterActiveAppOffers';

function belongsToRestaurant(item: WebMenuItem, restaurantId: string): boolean {
  const rid = restaurantId.trim();
  if (!rid) return false;
  const itemRid = item.restaurant_id?.trim();
  if (!itemRid) return false;
  return itemRid === rid;
}

/** Active LTO + non-LTO special packs for one restaurant menu. */
export function filterRestaurantAppOffers(
  items: WebMenuItem[],
  restaurantId: string,
): WebMenuItem[] {
  return filterActiveAppOffers(items).filter((item) =>
    belongsToRestaurant(item, restaurantId),
  );
}
