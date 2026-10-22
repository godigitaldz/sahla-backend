import type { RawPricing, WebMenuItem } from '@/lib/menuCatalog';

function asArray<T>(value: unknown): T[] {
  return Array.isArray(value) ? (value as T[]) : [];
}

function parseUtc(value: unknown): Date | null {
  if (value == null || value === '') return null;
  const d = new Date(String(value));
  return Number.isFinite(d.getTime()) ? d : null;
}

function pricingRows(item: WebMenuItem): RawPricing[] {
  return asArray<RawPricing>(item.pricing_options);
}

export function activeLtoPricing(item: WebMenuItem): RawPricing | null {
  const now = Date.now();
  for (const row of pricingRows(item)) {
    if (row.is_limited_offer !== true) continue;
    const start = parseUtc(row.offer_start_at);
    const end = parseUtc(row.offer_end_at);
    const startOk = start == null || now >= start.getTime();
    const endOk = end == null || now < end.getTime();
    if (startOk && endOk) return row;
  }
  return null;
}

export function isOfferActiveInPricing(item: WebMenuItem): boolean {
  return activeLtoPricing(item) != null;
}

export function isLtoCatalogRowVisible(item: WebMenuItem): boolean {
  const image = item.image?.trim() || '';
  if (!image) return false;
  if (isOfferActiveInPricing(item)) return true;
  if (item.is_limited_offer !== true) return false;

  const now = Date.now();
  const start = parseUtc(item.offer_start_at);
  const end = parseUtc(item.offer_end_at);
  if (start != null && now < start.getTime()) return false;
  if (end != null && now >= end.getTime()) return false;
  return true;
}

function offerTypesForItem(item: WebMenuItem): string[] {
  const fromTop = asArray<string>(item.offer_types).map(String);
  const lto = activeLtoPricing(item);
  const fromPricing = lto
    ? asArray<string>((lto as { offer_types?: unknown }).offer_types).map(String)
    : [];
  return [...new Set([...fromTop, ...fromPricing])];
}

export function hasOfferType(item: WebMenuItem, type: string): boolean {
  if (!isLtoCatalogRowVisible(item)) return false;
  return offerTypesForItem(item).includes(type);
}

export function effectiveOfferPrice(item: WebMenuItem): number {
  const lto = activeLtoPricing(item);
  if (!lto) return Number(item.price ?? 0);

  const pricingPrice = Number(lto.price ?? 0);
  const size = String(lto.size ?? lto.portion ?? lto.label ?? '').toLowerCase();
  if (size === 'pack') return pricingPrice;
  return Number(item.price ?? 0);
}

export function originalOfferPrice(item: WebMenuItem): number | null {
  const lto = activeLtoPricing(item);
  if (lto?.original_price != null) {
    const v = Number(lto.original_price);
    if (Number.isFinite(v) && v > 0) return v;
  }
  if (item.original_price != null) {
    const v = Number(item.original_price);
    if (Number.isFinite(v) && v > 0) return v;
  }
  return null;
}

export function discountPercentForItem(item: WebMenuItem): number | null {
  if (!hasOfferType(item, 'special_price')) return null;

  const original = originalOfferPrice(item);
  const discounted = effectiveOfferPrice(item);
  if (original == null || original <= 0 || original <= discounted) return null;
  return Math.round(((original - discounted) / original) * 100);
}

export function offerEndAt(item: WebMenuItem): Date | null {
  const lto = activeLtoPricing(item);
  if (lto?.offer_end_at) return parseUtc(lto.offer_end_at);
  return parseUtc(item.offer_end_at);
}

export function formatOfferTimeRemaining(end: Date | null): string | null {
  if (!end) return null;
  const diffMs = end.getTime() - Date.now();
  if (diffMs <= 0) return null;
  const hours = Math.floor(diffMs / (1000 * 60 * 60));
  if (hours >= 24) {
    const days = Math.floor(hours / 24);
    return `${days} ي`;
  }
  if (hours >= 1) return `${hours} س`;
  const minutes = Math.max(1, Math.floor(diffMs / (1000 * 60)));
  return `${minutes} د`;
}
