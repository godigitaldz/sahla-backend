import type { WebMenuItem } from '@/lib/menuCatalog';
import { filterActiveAppOffers } from '@/lib/appOffers/filterActiveAppOffers';

/** Own restaurant offers first, then other wilayah offers in rail order. */
export function mergeAppOffersCarousel(
  ownRestaurantItems: WebMenuItem[],
  wilayahItems: WebMenuItem[],
  restaurantId: string,
): WebMenuItem[] {
  const rid = restaurantId.trim();
  const own = filterActiveAppOffers(ownRestaurantItems);
  const seen = new Set(own.map((item) => item.id));
  const ownFromRails: WebMenuItem[] = [];
  const others: WebMenuItem[] = [];

  for (const item of wilayahItems) {
    if (seen.has(item.id)) continue;
    const itemRid = item.restaurant_id?.trim();
    if (!itemRid) continue;
    seen.add(item.id);

    if (rid && itemRid === rid) {
      ownFromRails.push(item);
    } else {
      others.push(item);
    }
  }

  return [...own, ...filterActiveAppOffers(ownFromRails), ...filterActiveAppOffers(others)];
}
