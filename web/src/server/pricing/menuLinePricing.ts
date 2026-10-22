export type MenuItemRow = {
  id: string;
  restaurant_id: string;
  name: string;
  price: number;
  category?: string | null;
  is_available?: boolean;
  is_limited_offer?: boolean;
  offer_start_at?: string | null;
  offer_end_at?: string | null;
  pricing_options?: unknown;
  supplements?: unknown;
  variants?: unknown;
  offer_details?: unknown;
};

export type CartLineInput = {
  menu_item_id: string;
  quantity: number;
  pricing_size?: string | null;
  variant_name?: string | null;
  supplement_names?: string[];
  special_instructions?: string | null;
  client_unit_price?: number;
  client_total_price?: number;
};

export type PricedCartLine = {
  menu_item_id: string;
  quantity: number;
  unit_price: number;
  total_price: number;
  special_instructions?: string | null;
  customizations: Record<string, unknown>;
};

const PRICE_TOLERANCE = 0.02;

/** Keys the Flutter app reads for restaurant/customer order line titles. */
export function buildAppCompatibleOrderItemCustomizations(
  line: Pick<CartLineInput, 'pricing_size' | 'variant_name' | 'supplement_names'>,
  item: Pick<MenuItemRow, 'name'>,
  restaurantId: string,
): Record<string, unknown> {
  const pricingSize = line.pricing_size?.trim() || null;
  const variantName = line.variant_name?.trim() || null;
  const supplements = line.supplement_names ?? [];

  return {
    restaurant_id: restaurantId,
    menu_item_name: item.name,
    variant: variantName,
    size: pricingSize,
    portion: null,
    supplements,
    pricing_size: pricingSize,
    variant_name: variantName,
  };
}

function roundMoney(value: number): number {
  return Math.round(value * 100) / 100;
}

function asArray<T = Record<string, unknown>>(value: unknown): T[] {
  return Array.isArray(value) ? (value as T[]) : [];
}

function isSpecialPack(item: MenuItemRow): boolean {
  const category = String(item.category ?? '').toLowerCase();
  if (category.includes('pack') || category.includes('combo') || category.includes('special')) {
    return true;
  }
  const variants = asArray(item.variants);
  return variants.some((v) => {
    const name = String(v.name ?? '').toLowerCase();
    return name.includes('pack') || v.is_pack === true;
  });
}

function isOfferActive(item: MenuItemRow): boolean {
  if (!item.is_limited_offer) return true;
  const now = Date.now();
  const start = item.offer_start_at ? Date.parse(item.offer_start_at) : NaN;
  const end = item.offer_end_at ? Date.parse(item.offer_end_at) : NaN;
  if (Number.isFinite(start) && now < start) return false;
  if (Number.isFinite(end) && now > end) return false;
  return true;
}

function findPricing(item: MenuItemRow, size?: string | null) {
  const options = asArray<{ size?: string; price?: number }>(item.pricing_options);
  if (!options.length) return null;
  if (size) {
    const match = options.find((p) => String(p.size ?? '').trim() === size.trim());
    if (match) return match;
  }
  return options[0];
}

function supplementsTotal(item: MenuItemRow, names: string[] = []): number {
  if (!names.length) return 0;
  const catalog = asArray<{ name?: string; price?: number }>(item.supplements);
  let total = 0;
  for (const name of names) {
    const row = catalog.find((s) => String(s.name ?? '').trim() === name.trim());
    total += Number(row?.price ?? 0);
  }
  return total;
}

function computeUnitPrice(item: MenuItemRow, line: CartLineInput): number {
  if (isSpecialPack(item)) {
    throw new Error('special_pack_web_unsupported');
  }

  if (item.is_limited_offer === true) {
    throw new Error('lto_web_unsupported');
  }

  if (!isOfferActive(item)) {
    throw new Error('menu_item_unavailable');
  }

  const pricing = findPricing(item, line.pricing_size);
  const supplements = supplementsTotal(item, line.supplement_names);

  const sizeMain = Number(pricing?.price ?? item.price ?? 0);
  return roundMoney(sizeMain + supplements);
}

export function priceCartLines(
  menuItems: MenuItemRow[],
  lines: CartLineInput[],
  restaurantId: string,
): { subtotal: number; pricedLines: PricedCartLine[] } {
  const byId = new Map(menuItems.map((m) => [m.id, m]));
  let subtotal = 0;
  const pricedLines: PricedCartLine[] = [];

  for (const line of lines) {
    const item = byId.get(line.menu_item_id);
    if (!item) throw new Error('menu_item_not_found');
    if (item.restaurant_id !== restaurantId) throw new Error('menu_item_not_from_restaurant');
    if (item.is_available === false) throw new Error('menu_item_unavailable');

    const quantity = Math.max(1, Math.floor(line.quantity || 1));
    const unitPrice = computeUnitPrice(item, line);
    const totalPrice = roundMoney(unitPrice * quantity);

    if (
      line.client_unit_price != null &&
      Math.abs(line.client_unit_price - unitPrice) > PRICE_TOLERANCE
    ) {
      throw new Error('price_manipulation_rejected');
    }
    if (
      line.client_total_price != null &&
      Math.abs(line.client_total_price - totalPrice) > PRICE_TOLERANCE
    ) {
      throw new Error('price_manipulation_rejected');
    }

    subtotal += totalPrice;
    pricedLines.push({
      menu_item_id: item.id,
      quantity,
      unit_price: unitPrice,
      total_price: totalPrice,
      special_instructions: line.special_instructions ?? null,
      customizations: buildAppCompatibleOrderItemCustomizations(
        line,
        item,
        restaurantId,
      ),
    });
  }

  return { subtotal: roundMoney(subtotal), pricedLines };
}
