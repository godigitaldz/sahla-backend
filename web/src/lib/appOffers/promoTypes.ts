export type PromoCodeAppliesTo = 'delivery_fee' | 'subtotal' | string;
export type PromoCodeType =
  | 'percentage'
  | 'fixed_amount'
  | 'free_delivery'
  | 'buy_one_get_one'
  | string;

export type PublicDeliveryPromo = {
  id: string;
  code: string;
  restaurant_id: string | null;
  name: string | null;
  type: PromoCodeType;
  value: number;
  minimum_order_amount: number;
  maximum_discount_amount: number | null;
  start_date: string;
  end_date: string;
  status: string;
  usage_limit: number | null;
  used_count: number | null;
  applicable_categories: string[];
  applicable_menu_items: string[];
  is_public: boolean;
  applies_to: PromoCodeAppliesTo;
};

export function isPromoActive(promo: PublicDeliveryPromo, now = Date.now()): boolean {
  if (promo.status !== 'active') return false;
  if (promo.is_public === false) return false;
  const start = new Date(promo.start_date).getTime();
  const end = new Date(promo.end_date).getTime();
  if (!Number.isFinite(start) || !Number.isFinite(end)) return false;
  if (now < start || now >= end) return false;
  if (
    promo.usage_limit != null &&
    promo.usage_limit > 0 &&
    promo.used_count != null &&
    promo.used_count >= promo.usage_limit
  ) {
    return false;
  }
  return true;
}

export function calculatePromoDiscount(
  promo: PublicDeliveryPromo,
  params: {
    subtotal: number;
    deliveryFee?: number | null;
    minimumReferenceAmount?: number;
  },
): number {
  const targetAmount =
    promo.applies_to === 'delivery_fee'
      ? (params.deliveryFee ?? 0)
      : params.subtotal;
  const amountToCheck = params.minimumReferenceAmount ?? params.subtotal;

  if (!isPromoActive(promo) || amountToCheck < promo.minimum_order_amount) {
    return 0;
  }
  if (targetAmount <= 0) return 0;

  let discount = 0;
  switch (promo.type) {
    case 'percentage':
      discount = targetAmount * (promo.value / 100);
      break;
    case 'fixed_amount':
      discount = promo.value;
      break;
    case 'free_delivery':
      if (promo.applies_to === 'delivery_fee' && params.deliveryFee != null) {
        discount = params.deliveryFee;
      }
      break;
    default:
      discount = 0;
  }

  if (promo.maximum_discount_amount != null && promo.maximum_discount_amount > 0) {
    discount = Math.min(discount, promo.maximum_discount_amount);
  }
  discount = Math.min(discount, targetAmount);
  return Math.max(0, discount);
}
