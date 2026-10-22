import type { WebMenuItem } from '@/lib/menuCatalog';
import {
  calculatePromoDiscount,
  isPromoActive,
  type PublicDeliveryPromo,
} from '@/lib/appOffers/promoTypes';

export function isDeliveryPromoEligibleForItem(
  promo: PublicDeliveryPromo,
  item: WebMenuItem,
  restaurantId: string,
): boolean {
  if (!isPromoActive(promo) || promo.applies_to !== 'delivery_fee') return false;

  const promoRestaurantId = promo.restaurant_id?.trim();
  if (
    promoRestaurantId &&
    promoRestaurantId.length > 0 &&
    promoRestaurantId !== restaurantId
  ) {
    return false;
  }

  if (
    promo.applicable_menu_items.length > 0 &&
    !promo.applicable_menu_items.includes(item.id)
  ) {
    return false;
  }

  if (promo.applicable_categories.length > 0) {
    const tokens = new Set(
      [item.category, item.category_id, item.category_name]
        .map((v) => String(v ?? '').trim())
        .filter(Boolean),
    );
    if (!promo.applicable_categories.some((c) => tokens.has(c.trim()))) {
      return false;
    }
  }

  return Number(item.price ?? 0) >= promo.minimum_order_amount;
}

export function bestDeliveryPromoForItem(
  promos: PublicDeliveryPromo[],
  item: WebMenuItem,
  restaurantId: string,
  deliveryFee: number | null,
): PublicDeliveryPromo | null {
  if (deliveryFee == null || deliveryFee <= 0) return null;

  let best: PublicDeliveryPromo | null = null;
  let bestDiscount = 0;

  for (const promo of promos) {
    if (!isDeliveryPromoEligibleForItem(promo, item, restaurantId)) continue;
    const discount = calculatePromoDiscount(promo, {
      subtotal: Number(item.price ?? 0),
      deliveryFee,
      minimumReferenceAmount: Number(item.price ?? 0),
    });
    if (discount > bestDiscount) {
      best = promo;
      bestDiscount = discount;
    }
  }

  return bestDiscount > 0 ? best : null;
}

export function deliveryPromoBadgeText(
  promo: PublicDeliveryPromo,
  item: WebMenuItem,
  deliveryFee: number,
): string {
  const discount = calculatePromoDiscount(promo, {
    subtotal: Number(item.price ?? 0),
    deliveryFee,
    minimumReferenceAmount: Number(item.price ?? 0),
  });
  if (discount <= 0) return '';
  if (discount >= deliveryFee) return 'توصيل مجاني';
  if (promo.type === 'percentage') return `-${Math.round(promo.value)}%`;
  if (promo.type === 'free_delivery') return 'توصيل مجاني';
  return 'عرض توصيل';
}
