import {
  categoryDisplayName,
  categoryGroupKey,
  pickItemImage,
  type WebMenuItem,
} from '@/lib/menuCatalog';
import { categoryIconPublicUrl } from '@/lib/supabasePublic';

export type MenuCategoryEntry = {
  key: string;
  label: string;
  iconUrl: string | null;
  displayOrder: number;
};

export function buildMenuCategoryEntries(items: WebMenuItem[]): MenuCategoryEntry[] {
  const map = new Map<
    string,
    MenuCategoryEntry & { sampleItem?: WebMenuItem }
  >();

  for (const item of items) {
    const key = categoryGroupKey(item);
    const existing = map.get(key);
    if (!existing) {
      map.set(key, {
        key,
        label: categoryDisplayName(item),
        iconUrl: categoryIconPublicUrl(item.category_icon),
        displayOrder: Number(item.category_display_order ?? 9999),
        sampleItem: item,
      });
      continue;
    }
    if (!existing.iconUrl && item.category_icon) {
      existing.iconUrl = categoryIconPublicUrl(item.category_icon);
    }
    if (Number(item.category_display_order ?? 9999) < existing.displayOrder) {
      existing.displayOrder = Number(item.category_display_order ?? 9999);
    }
  }

  return [...map.values()]
    .map((entry) => ({
      key: entry.key,
      label: entry.label,
      displayOrder: entry.displayOrder,
      iconUrl: entry.iconUrl ?? pickItemImage(entry.sampleItem!),
    }))
    .sort(
      (a, b) =>
        a.displayOrder - b.displayOrder ||
        a.label.localeCompare(b.label, 'ar'),
    );
}
