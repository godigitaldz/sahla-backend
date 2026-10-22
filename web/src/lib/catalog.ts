const ARABIC = /[\u0600-\u06FF]/;
const LATIN = /[A-Za-z]/;
const SPLIT = /\s*(?:\||\/|•|·|-|—|–)\s*/;

export function catalogNameForLocale(input: {
  rawName?: string | null;
  arabicName?: string | null;
  latinName?: string | null;
  languageCode?: string;
}): string {
  const languageCode = (input.languageCode ?? 'ar').toLowerCase();
  const isArabic = languageCode.startsWith('ar');
  const explicitArabic = input.arabicName?.trim();
  const explicitLatin = input.latinName?.trim();

  if (isArabic && explicitArabic) return explicitArabic;
  if (!isArabic && explicitLatin) return explicitLatin;

  const trimmed = (input.rawName ?? '').trim();
  if (!trimmed) return input.rawName ?? '';

  const parts = trimmed
    .split(SPLIT)
    .map((p) => p.trim())
    .filter(Boolean);

  if (parts.length < 2) return trimmed;

  if (isArabic) {
    return parts.find((p) => ARABIC.test(p)) ?? trimmed;
  }
  return parts.find((p) => LATIN.test(p)) ?? trimmed;
}
