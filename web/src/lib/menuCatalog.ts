import { catalogNameForLocale } from '@/lib/catalog';

export type RawVariant = {
  id?: string;
  name?: string;
  name_ar?: string;
  name_latin?: string;
  description?: string;
  description_ar?: string;
  description_latin?: string;
  is_available?: boolean;
  is_default?: boolean;
  display_order?: number;
  is_pack?: boolean;
  price?: number;
  variant_price?: number;
  cost?: number;
  amount?: number;
  image?: string;
};

export type RawPricing = {
  id?: string;
  variant_id?: string;
  size?: string;
  size_ar?: string;
  size_latin?: string;
  portion?: string;
  label?: string;
  name?: string;
  description?: string;
  description_ar?: string;
  description_latin?: string;
  price?: number;
  is_default?: boolean;
  is_limited_offer?: boolean;
  offer_start_at?: string | null;
  offer_end_at?: string | null;
  original_price?: number | null;
  offer_types?: string[] | unknown;
  display_order?: number;
};

export type RawSupplement = {
  id?: string;
  name?: string;
  name_ar?: string;
  name_latin?: string;
  price?: number;
  is_available?: boolean;
  available_for_variants?: string[];
};

export type WebMenuItem = {
  id: string;
  restaurant_id?: string;
  name: string;
  name_ar?: string | null;
  name_latin?: string | null;
  description?: string | null;
  description_ar?: string | null;
  description_latin?: string | null;
  image?: string | null;
  images?: unknown;
  price: number;
  category?: string | null;
  category_id?: string | null;
  category_name?: string | null;
  category_name_ar?: string | null;
  category_name_latin?: string | null;
  category_icon?: string | null;
  category_display_order?: number | null;
  is_available?: boolean;
  rating?: number | null;
  review_count?: number | null;
  preparation_time?: number | null;
  is_limited_offer?: boolean;
  is_special_pack_catalog_row?: boolean;
  offer_start_at?: string | null;
  offer_end_at?: string | null;
  original_price?: number | null;
  offer_details?: unknown;
  offer_types?: string[] | unknown;
  variants?: RawVariant[] | unknown;
  pricing_options?: RawPricing[] | unknown;
  supplements?: RawSupplement[] | unknown;
};

/** One list row — base item or a single expanded variant card. */
export type WebDisplayMenuItem = WebMenuItem & {
  list_key: string;
  locked_variant_id?: string | null;
};

function joinLabels(left: string, right: string): string {
  const l = left.trim();
  const r = right.trim();
  if (!r) return l;
  if (!l) return r;
  return `${l} ${r}`;
}

export function categoryGroupKey(item: WebMenuItem): string {
  return item.category?.trim() || 'القائمة';
}

export function categoryDisplayName(item: WebMenuItem, languageCode = 'ar'): string {
  const label = catalogNameForLocale({
    rawName: item.category,
    arabicName: item.category_name_ar,
    latinName: item.category_name_latin,
    languageCode,
  }).trim();
  return label || item.category?.trim() || 'القائمة';
}

export function variantCardDisplayName(
  item: WebMenuItem,
  variant: RawVariant,
  languageCode = 'ar',
): string {
  const variantLabel = resolveVariantLabel(variant, item, languageCode);
  const baseName = itemDisplayName(item, languageCode);
  if (!variantLabel) return baseName;

  const baseAr =
    item.name_ar?.trim() || itemDisplayName(item, 'ar');
  const baseLatin =
    item.name_latin?.trim() || itemDisplayName(item, 'en');

  const suffixAr = variant.name_ar?.trim() || variantLabel;
  const suffixLatin = variant.name_latin?.trim() || variantLabel;

  if (languageCode.startsWith('ar')) {
    return joinLabels(baseAr, suffixAr);
  }
  return joinLabels(baseLatin, suffixLatin);
}

function resolveVariantLabel(
  variant: RawVariant,
  item: WebMenuItem,
  languageCode = 'ar',
): string {
  const fromVariant = catalogNameForLocale({
    rawName: variant.name,
    arabicName: variant.name_ar,
    latinName: variant.name_latin,
    languageCode,
  }).trim();
  if (fromVariant) return fromVariant;

  const variantId = String(variant.id ?? '').trim();
  if (!variantId) return '';

  for (const row of asArray<RawPricing>(item.pricing_options)) {
    if (String(row.variant_id ?? '').trim() !== variantId) continue;
    for (const field of ['size', 'portion', 'label', 'name'] as const) {
      const value = String(row[field] ?? '').trim();
      if (value) return value;
    }
  }
  return '';
}

function priceFromPricingOptions(item: WebMenuItem, variantId: string): number | null {
  const want = variantId.trim();
  if (!want) return null;
  const rows = asArray<RawPricing>(item.pricing_options).filter(
    (p) => String(p.variant_id ?? '').trim() === want,
  );
  if (!rows.length) return null;
  const defaultRow = rows.find((p) => p.is_default) ?? rows[0];
  return Number(defaultRow?.price ?? NaN);
}

function extractVariantPrice(variant: RawVariant, item: WebMenuItem): number {
  const variantId = String(variant.id ?? '').trim();
  const fromOptions = priceFromPricingOptions(item, variantId);
  if (fromOptions != null && Number.isFinite(fromOptions)) return fromOptions;

  for (const field of ['price', 'variant_price', 'cost', 'amount'] as const) {
    const value = variant[field];
    if (typeof value === 'number' && Number.isFinite(value)) return value;
    if (typeof value === 'string') {
      const parsed = Number.parseFloat(value);
      if (Number.isFinite(parsed)) return parsed;
    }
  }
  return Number(item.price ?? 0);
}

export function imageUrlForVariantIndex(item: WebMenuItem, variantIndex: number): string | null {
  const variant = asArray<RawVariant>(item.variants)[variantIndex];
  const variantImage = (variant as { image?: string } | undefined)?.image?.trim();
  if (variantImage) return variantImage;

  const images = asArray<string | { url?: string }>(item.images);
  if (images.length && variantIndex >= 0) {
    const entry = images[variantIndex < images.length ? variantIndex : images.length - 1];
    if (typeof entry === 'string' && entry.trim()) return entry.trim();
    if (entry && typeof entry === 'object' && entry.url?.trim()) return entry.url.trim();
  }
  return pickItemImage(item);
}

function createVariantDisplayItem(
  item: WebMenuItem,
  variant: RawVariant,
  variantIndex: number,
): WebDisplayMenuItem {
  const variantId = String(variant.id ?? '').trim();
  const slug = variantId || `idx_${variantIndex}`;
  return {
    ...item,
    list_key: `${item.id}_variant_${variantIndex}_${slug}`,
    locked_variant_id: variantId || null,
    name: variantCardDisplayName(item, variant, 'en'),
    name_ar: variantCardDisplayName(item, variant, 'ar'),
    name_latin: variantCardDisplayName(item, variant, 'en'),
    price: extractVariantPrice(variant, item),
    image: imageUrlForVariantIndex(item, variantIndex),
    variants: asArray<RawVariant>(item.variants),
  };
}

/** Expand multi-variant food rows into one card per variant (matches Flutter list). */
export function expandVariantsToDisplayItems(items: WebMenuItem[]): WebDisplayMenuItem[] {
  const expanded: WebDisplayMenuItem[] = [];
  for (const item of items) {
    const variants = getAvailableVariants(item);
    if (variants.length <= 1) {
      expanded.push({ ...item, list_key: item.id });
      continue;
    }
    variants.forEach((variant, index) => {
      expanded.push(createVariantDisplayItem(item, variant, index));
    });
  }
  return expanded;
}

export function displayItemImage(item: WebDisplayMenuItem): string | null {
  return item.image?.trim() || pickItemImage(item);
}

function asArray<T>(value: unknown): T[] {
  return Array.isArray(value) ? (value as T[]) : [];
}

export function itemDisplayName(item: WebMenuItem, languageCode = 'ar') {
  return catalogNameForLocale({
    rawName: item.name,
    arabicName: item.name_ar,
    latinName: item.name_latin,
    languageCode,
  });
}

export function itemDisplayDescription(item: WebMenuItem, languageCode = 'ar') {
  const raw = item.description?.trim() ?? '';
  if (!raw) return null;
  return catalogNameForLocale({
    rawName: raw,
    arabicName: item.description_ar,
    latinName: item.description_latin,
    languageCode,
  });
}

export function isSpecialPack(item: WebMenuItem): boolean {
  if (item.is_special_pack_catalog_row) return true;

  const categoryTokens = [
    item.category,
    item.category_name,
    item.category_name_ar,
    item.category_name_latin,
  ]
    .map((v) => String(v ?? '').toLowerCase())
    .filter(Boolean);

  const categoryLooksLikePack = categoryTokens.some(
    (c) =>
      c.includes('pack') ||
      c.includes('combo') ||
      c.includes('special pack') ||
      c.includes('عرض خاص') ||
      c.includes('باك'),
  );
  if (categoryLooksLikePack) return true;

  return asArray<RawVariant>(item.variants).some((v) => v.is_pack === true);
}

export function isLimitedOffer(item: WebMenuItem): boolean {
  return item.is_limited_offer === true;
}

export function isWebMenuEligible(item: WebMenuItem): boolean {
  if (item.is_available === false) return false;
  if (isLimitedOffer(item)) return false;
  if (isSpecialPack(item)) return false;
  return true;
}

export function filterWebMenuItems(items: WebMenuItem[]): WebMenuItem[] {
  return items.filter(isWebMenuEligible);
}

export function isDrinkCategory(value: string): boolean {
  const lower = value.toLowerCase();
  return (
    lower.includes('drink') ||
    lower.includes('beverage') ||
    lower.includes('boissons') ||
    lower.includes('boisson') ||
    lower.includes('مشروب')
  );
}

export function isDrinkItem(item: WebMenuItem): boolean {
  if (isDrinkCategory(String(item.category ?? ''))) return true;
  const nameLower = `${item.name} ${item.name_ar ?? ''}`.toLowerCase();
  return (
    nameLower.includes('drink') ||
    nameLower.includes('juice') ||
    nameLower.includes('soda') ||
    nameLower.includes('coffee') ||
    nameLower.includes('tea') ||
    nameLower.includes('water') ||
    nameLower.includes('coca') ||
    nameLower.includes('pepsi') ||
    nameLower.includes('gazouz') ||
    nameLower.includes('hamoud')
  );
}

export function partitionWebMenuItems(items: WebMenuItem[]) {
  const eligible = filterWebMenuItems(items);
  const drinks: WebMenuItem[] = [];
  const food: WebMenuItem[] = [];
  for (const item of eligible) {
    if (isDrinkItem(item)) drinks.push(item);
    else food.push(item);
  }
  return { food, drinks };
}

export function drinkSizeLabel(item: WebMenuItem, languageCode = 'ar'): string | null {
  const first = asArray<RawPricing>(item.pricing_options)[0];
  if (!first) return null;
  const label = pricingSizeLabel(first, languageCode);
  return label || null;
}

export function pickItemImage(item: WebMenuItem): string | null {
  const direct = item.image?.trim();
  if (direct) return direct;
  const images = asArray<string | { url?: string }>(item.images);
  for (const entry of images) {
    if (typeof entry === 'string' && entry.trim()) return entry.trim();
    if (entry && typeof entry === 'object' && entry.url?.trim()) return entry.url.trim();
  }
  return null;
}

export function isFixedPriceLtoFakeVariant(variant: RawVariant): boolean {
  const id = String(variant.id ?? '').trim();
  const name = String(variant.name ?? '').trim();
  const nameLower = name.toLowerCase();
  const fakeIds = new Set(['confirm_offer', 'standard', 'default', 'confirm']);
  if (fakeIds.has(id)) return true;
  const needles = ['اضغط هنا لتأكيد العرض', 'tap to confirm', 'confirm offer', 'confirmation'];
  if (needles.some((n) => name.includes(n) || nameLower.includes(n.toLowerCase()))) return true;
  // Blank-name placeholder rows are LTO-only; regular items keep them (see RegularItemHelper).
  return false;
}

/** @deprecated Use [isFixedPriceLtoFakeVariant] — not applied in [getAvailableVariants]. */
export function isFakeConfirmVariant(variant: RawVariant): boolean {
  return isFixedPriceLtoFakeVariant(variant);
}

export function getAvailableVariants(item: WebMenuItem): RawVariant[] {
  return asArray<RawVariant>(item.variants)
    .filter((v) => v.is_available !== false)
    .sort((a, b) => Number(a.display_order ?? 0) - Number(b.display_order ?? 0));
}

/** Resolve variant id for sheet/cart when DB uses a blank-name default row. */
export function resolvePrimaryVariantId(item: WebMenuItem, lockedVariantId?: string | null): string | null {
  const locked = lockedVariantId?.trim();
  if (locked) return locked;

  const variants = getAvailableVariants(item);
  if (variants.length === 1) {
    return String(variants[0].id ?? '').trim() || null;
  }
  if (variants.length > 1) return null;

  const pricingRows = asArray<RawPricing>(item.pricing_options);
  const fromPricing = String(pricingRows[0]?.variant_id ?? '').trim();
  if (fromPricing) return fromPricing;

  return null;
}

export function defaultPricingForVariant(item: WebMenuItem, variantId: string): RawPricing | null {
  const rows = getVariantPricingForDisplay(item, variantId);
  if (!rows.length) return null;
  return rows.find((p) => p.is_default) ?? rows[0] ?? null;
}

export function getVariantPricing(item: WebMenuItem, variantId: string): RawPricing[] {
  const want = variantId.trim();
  return asArray<RawPricing>(item.pricing_options)
    .filter((p) => String(p.variant_id ?? '').trim() === want)
    .sort((a, b) => Number(a.display_order ?? 0) - Number(b.display_order ?? 0));
}

export function getVariantPricingForDisplay(item: WebMenuItem, variantId: string): RawPricing[] {
  return getVariantPricing(item, variantId);
}

export function everyVariantHasSinglePricingOption(item: WebMenuItem, variants: RawVariant[]): boolean {
  if (!variants.length) return false;
  return variants.every((v) => getVariantPricingForDisplay(item, String(v.id ?? '')).length === 1);
}

export function variantDisplayLabel(item: WebMenuItem, variant: RawVariant, languageCode = 'ar') {
  const localized = catalogNameForLocale({
    rawName: variant.name,
    arabicName: variant.name_ar,
    latinName: variant.name_latin,
    languageCode,
  }).trim();
  if (localized) return localized;
  return itemDisplayName(item, languageCode);
}

export function pricingSizeLabel(pricing: RawPricing, languageCode = 'ar') {
  return catalogNameForLocale({
    rawName: pricing.size,
    arabicName: pricing.size_ar,
    latinName: pricing.size_latin,
    languageCode,
  }).trim();
}

export function pricingDescriptionLine(pricing: RawPricing, languageCode = 'ar') {
  const raw = pricing.description?.trim() ?? '';
  if (!raw) return null;
  return catalogNameForLocale({
    rawName: raw,
    arabicName: pricing.description_ar,
    latinName: pricing.description_latin,
    languageCode,
  });
}

export function variantDescriptionLine(variant: RawVariant, languageCode = 'ar') {
  const raw = variant.description?.trim() ?? '';
  if (!raw) return null;
  return catalogNameForLocale({
    rawName: raw,
    arabicName: variant.description_ar,
    latinName: variant.description_latin,
    languageCode,
  });
}

export function getVariantSupplements(item: WebMenuItem, variantId: string): RawSupplement[] {
  const want = variantId.trim();
  return asArray<RawSupplement>(item.supplements).filter((supp) => {
    if (supp.is_available === false) return false;
    const allowed = asArray<string>(supp.available_for_variants).map(String);
    if (!allowed.length) return true;
    return allowed.includes(want);
  });
}

export function supplementDisplayName(supp: RawSupplement, languageCode = 'ar') {
  return catalogNameForLocale({
    rawName: supp.name,
    arabicName: supp.name_ar,
    latinName: supp.name_latin,
    languageCode,
  });
}

export function computeRegularUnitPrice(
  item: WebMenuItem,
  selectedPricing: RawPricing | null,
  supplementNames: string[],
): number {
  const supplements = asArray<RawSupplement>(item.supplements);
  const suppTotal = supplementNames.reduce((sum, name) => {
    const row = supplements.find((s) => String(s.name ?? '').trim() === name.trim());
    return sum + Number(row?.price ?? 0);
  }, 0);

  const variants = getAvailableVariants(item);
  const pricingRows = asArray<RawPricing>(item.pricing_options);

  if (pricingRows.length > 0) {
    const sizeMain = Number(
      selectedPricing?.price ??
        defaultPricingForVariant(item, resolvePrimaryVariantId(item) ?? '')?.price ??
        item.price ??
        0,
    );
    return Math.round((sizeMain + suppTotal) * 100) / 100;
  }

  return Math.round((Number(item.price ?? 0) + suppTotal) * 100) / 100;
}
