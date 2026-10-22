import { itemDisplayName, isSpecialPack, pickItemImage, type WebMenuItem } from '@/lib/menuCatalog';
import { specialPackCardTitle } from '@/lib/appOffers/specialPackNaming';
import {
  discountPercentForItem,
  effectiveOfferPrice,
  formatOfferTimeRemaining,
  isLtoCatalogRowVisible,
  offerEndAt,
  originalOfferPrice,
} from '@/lib/appOffers/lto';
import {
  bestDeliveryPromoForItem,
  deliveryPromoBadgeText,
} from '@/lib/appOffers/promoEligibility';
import type { PublicDeliveryPromo } from '@/lib/appOffers/promoTypes';

export type AppOfferKind = 'lto' | 'special_pack';

export type AppOfferPreview = {
  id: string;
  kind: AppOfferKind;
  title: string;
  imageUrl: string;
  price: number;
  originalPrice: number | null;
  discountPercent: number | null;
  timeRemaining: string | null;
  preparationMinutes: number | null;
  promoBadge: string | null;
  restaurantName: string | null;
  isOwnRestaurant: boolean;
  subtitleLabel: string | null;
  sourceItem: WebMenuItem;
};

type PreviewOptions = {
  pageRestaurantId: string;
  promos: PublicDeliveryPromo[];
  feesByRestaurantId: Record<string, number>;
  locationReady: boolean;
};

function readRestaurantName(item: WebMenuItem): string | null {
  const embedded = (item as WebMenuItem & { restaurant_name?: string }).restaurant_name;
  const name = String(embedded ?? '').trim();
  return name || null;
}

function deliveryFeeForItem(
  item: WebMenuItem,
  options: PreviewOptions,
): number | null {
  if (!options.locationReady) return null;
  const itemRestaurantId = String(item.restaurant_id ?? '').trim();
  if (!itemRestaurantId) return null;
  const fee = options.feesByRestaurantId[itemRestaurantId];
  return fee != null && Number.isFinite(fee) ? fee : null;
}

function specialPackPromoBadge(
  item: WebMenuItem,
  itemRestaurantId: string,
  deliveryFee: number | null,
  promos: PublicDeliveryPromo[],
): string | null {
  if (deliveryFee != null && deliveryFee <= 0) {
    return 'توصيل مجاني';
  }
  if (deliveryFee == null || deliveryFee <= 0) return null;

  const promo = bestDeliveryPromoForItem(promos, item, itemRestaurantId, deliveryFee);
  if (!promo) return null;
  return deliveryPromoBadgeText(promo, item, deliveryFee) || null;
}

function offerTitle(item: WebMenuItem, kind: AppOfferKind): string {
  if (kind === 'special_pack' || isSpecialPack(item)) {
    return specialPackCardTitle(item, 'ar');
  }
  return itemDisplayName(item);
}

export function toAppOfferPreview(item: WebMenuItem, options: PreviewOptions): AppOfferPreview {
  const isLto = isLtoCatalogRowVisible(item);
  const kind: AppOfferKind = isLto ? 'lto' : 'special_pack';
  const itemRestaurantId = String(item.restaurant_id ?? options.pageRestaurantId).trim();
  const isOwnRestaurant = itemRestaurantId === options.pageRestaurantId.trim();
  const deliveryFee = deliveryFeeForItem(item, options);

  const price = isLto ? effectiveOfferPrice(item) : Number(item.price ?? 0);
  const originalPrice = isLto ? originalOfferPrice(item) : null;
  const discountPercent = isLto ? discountPercentForItem(item) : null;
  const end = isLto ? offerEndAt(item) : null;

  const promoBadge =
    kind === 'special_pack' || isSpecialPack(item)
      ? specialPackPromoBadge(item, itemRestaurantId, deliveryFee, options.promos)
      : null;

  return {
    id: item.id,
    kind,
    title: offerTitle(item, kind),
    imageUrl: pickItemImage(item) ?? '',
    price,
    originalPrice,
    discountPercent,
    timeRemaining: formatOfferTimeRemaining(end),
    preparationMinutes: item.preparation_time ?? null,
    promoBadge,
    restaurantName: readRestaurantName(item),
    isOwnRestaurant,
    subtitleLabel: !isOwnRestaurant ? readRestaurantName(item) : null,
    sourceItem: item,
  };
}

export function buildAppOfferPreviews(
  items: WebMenuItem[],
  options: PreviewOptions,
): AppOfferPreview[] {
  return items.map((item) => toAppOfferPreview(item, options));
}
