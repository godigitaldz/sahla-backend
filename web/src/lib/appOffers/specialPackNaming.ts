import { catalogNameForLocale } from '@/lib/catalog';
import { isSpecialPack, type RawVariant, type WebMenuItem } from '@/lib/menuCatalog';

function asVariants(value: unknown): RawVariant[] {
  return Array.isArray(value) ? (value as RawVariant[]) : [];
}

function itemBaseDisplayName(item: WebMenuItem, languageCode = 'ar'): string {
  return catalogNameForLocale({
    rawName: item.name,
    arabicName: item.name_ar,
    latinName: item.name_latin,
    languageCode,
  }).trim();
}

function variantLabelName(variant: RawVariant, languageCode = 'ar'): string {
  const raw = String(variant.name ?? '').trim();
  if (!raw) return '';
  return catalogNameForLocale({
    rawName: raw,
    arabicName: variant.name_ar,
    latinName: variant.name_latin,
    languageCode,
  }).trim();
}

/** `qty:2` or `qty:2|options:...` from variant description. */
export function parsePackVariantQuantity(description: unknown): number {
  const text = String(description ?? '').trim();
  if (!text.startsWith('qty:')) return 1;
  try {
    const qtyPart = text.split('|')[0] ?? '';
    const qtyValue = qtyPart.split(':')[1] ?? '';
    const parsed = Number.parseInt(qtyValue, 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : 1;
  } catch {
    return 1;
  }
}

export function packVariantLabels(item: WebMenuItem, languageCode = 'ar'): string[] {
  const labels: string[] = [];
  for (const variant of asVariants(item.variants)) {
    const labelName = variantLabelName(variant, languageCode);
    if (!labelName) continue;
    const quantity = parsePackVariantQuantity(variant.description);
    labels.push(quantity > 1 ? `${quantity} ${labelName}` : labelName);
  }
  return labels;
}

export function joinPackVariantLabelsWithPlus(labels: string[]): string {
  return labels.filter(Boolean).join(' + ');
}

function localizePackListConjunctions(text: string, languageCode = 'ar'): string {
  if (!text) return text;
  if (languageCode.startsWith('ar')) {
    return text.replace(/ et /g, ' و ');
  }
  if (languageCode.startsWith('en')) {
    return text.replace(/ et /g, ' and ');
  }
  return text;
}

function containsAnyVariantName(name: string, variants: RawVariant[]): boolean {
  for (const variant of variants) {
    const itemName = String(variant.name ?? '').trim();
    if (itemName && name.includes(itemName)) return true;
  }
  return false;
}

function formatPackName(item: WebMenuItem, languageCode = 'ar'): string {
  const variants = asVariants(item.variants);
  if (variants.length === 0) {
    return itemBaseDisplayName(item, languageCode);
  }

  const baseName = itemBaseDisplayName(item, languageCode);
  const rawName = item.name.trim();
  const isAlreadyFormatted =
    rawName.includes(' et ') ||
    rawName.includes(')x ') ||
    containsAnyVariantName(rawName, variants);

  if (isAlreadyFormatted) {
    return localizePackListConjunctions(rawName, languageCode);
  }

  const labels = packVariantLabels(item, languageCode);
  if (labels.length === 0) return baseName;

  const joiner = languageCode.startsWith('ar') ? ' و ' : languageCode.startsWith('en') ? ' and ' : ' et ';
  let formatted = labels[0] ?? '';
  for (let i = 1; i < labels.length; i += 1) {
    const label = labels[i] ?? '';
    formatted += i === labels.length - 1 ? `${joiner}${label}` : `, ${label}`;
  }
  return `${baseName} ${formatted}`.trim();
}

/**
 * Home / restaurant strip card title — variant composition only, joined with ` + `
 * (matches Flutter [SpecialPackHelper.formatPackVariantNamesOnly]).
 */
export function formatPackVariantNamesOnly(
  item: WebMenuItem,
  languageCode = 'ar',
): string {
  if (!isSpecialPack(item)) return '';

  const labels = packVariantLabels(item, languageCode);
  if (labels.length > 0) {
    return joinPackVariantLabelsWithPlus(labels);
  }

  const full = formatPackName(item, languageCode);
  const base = itemBaseDisplayName(item, languageCode);
  if (full.length > base.length && full.startsWith(base)) {
    const rest = full.slice(base.length).trim();
    if (rest) {
      const localized = localizePackListConjunctions(rest, languageCode);
      return localized.replace(/ et /g, ' + ').replace(/ و /g, ' + ').replace(/ and /g, ' + ');
    }
  }

  return '';
}

/** Title shown under special-pack offer cards. */
export function specialPackCardTitle(item: WebMenuItem, languageCode = 'ar'): string {
  const variantLine = formatPackVariantNamesOnly(item, languageCode).trim();
  if (variantLine) return variantLine;

  const catalog = itemBaseDisplayName(item, languageCode);
  const raw = localizePackListConjunctions(item.name.trim(), languageCode);
  if (
    catalog &&
    catalog !== raw &&
    (item.name_ar?.trim() || item.name_latin?.trim())
  ) {
    return catalog;
  }
  if (raw.length > catalog.length) return raw;

  const formatted = formatPackName(item, languageCode).trim();
  if (formatted && formatted !== catalog) return formatted;

  return catalog || raw;
}
