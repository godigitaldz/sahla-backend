import { isLimitedOffer, isSpecialPack, pickItemImage, type WebMenuItem } from '@/lib/menuCatalog';
import { isLtoCatalogRowVisible } from '@/lib/appOffers/lto';

/** Active LTO or non-LTO special pack row suitable for app-offer carousel. */
export function isActiveAppOfferRow(item: WebMenuItem): boolean {
  if (item.is_available === false) return false;
  if (!pickItemImage(item)) return false;

  const activeLto = isLtoCatalogRowVisible(item);
  const nonLtoPack = isSpecialPack(item) && !isLimitedOffer(item);
  return activeLto || nonLtoPack;
}

export function filterActiveAppOffers(items: WebMenuItem[]): WebMenuItem[] {
  const seen = new Set<string>();
  const out: WebMenuItem[] = [];

  for (const item of items) {
    if (seen.has(item.id)) continue;
    if (!isActiveAppOfferRow(item)) continue;
    seen.add(item.id);
    out.push(item);
  }

  return out;
}
