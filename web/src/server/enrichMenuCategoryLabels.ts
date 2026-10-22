import type { SupabaseClient } from '@supabase/supabase-js';
import type { WebMenuItem } from '@/lib/menuCatalog';

type CategoryRow = {
  name?: string;
  name_ar?: string;
  name_latin?: string;
  icon?: string | null;
  display_order?: number | null;
};

/** Backfill category labels/icons when RPC/menu select has not been migrated yet. */
export async function enrichMenuCategoryLabels(
  anon: SupabaseClient,
  items: WebMenuItem[],
): Promise<WebMenuItem[]> {
  const needsEnrichment = items.some(
    (item) =>
      item.category?.trim() &&
      (!item.category_name_ar?.trim() || !item.category_icon?.trim()),
  );
  if (!needsEnrichment) return items;

  const categoryIds = [
    ...new Set(
      items
        .map((item) => item.category_id?.trim())
        .filter((id): id is string => Boolean(id)),
    ),
  ];
  const categoryNames = [
    ...new Set(
      items
        .map((item) => item.category?.trim())
        .filter((name): name is string => Boolean(name)),
    ),
  ];

  const byId = new Map<string, CategoryRow>();
  const byName = new Map<string, CategoryRow>();

  const ingest = (row: CategoryRow & { id?: string; name?: string }) => {
    if (row.id) byId.set(String(row.id), row);
    if (row.name?.trim()) byName.set(row.name.trim().toLowerCase(), row);
  };

  if (categoryIds.length) {
    const { data } = await anon
      .from('categories')
      .select('id,name,name_ar,name_latin,icon,display_order')
      .in('id', categoryIds);
    for (const row of data ?? []) {
      ingest(row as CategoryRow & { id?: string });
    }
  }

  const missingNames = categoryNames.filter((name) => !byName.has(name.toLowerCase()));
  if (missingNames.length) {
    const { data } = await anon
      .from('categories')
      .select('id,name,name_ar,name_latin,icon,display_order')
      .in('name', missingNames);
    for (const row of data ?? []) {
      ingest(row as CategoryRow & { id?: string });
    }
  }

  return items.map((item) => {
    const categoryId = item.category_id?.trim();
    const category =
      (categoryId ? byId.get(categoryId) : undefined) ??
      (item.category?.trim()
        ? byName.get(item.category.trim().toLowerCase())
        : undefined);
    if (!category) return item;

    return {
      ...item,
      category_name: category.name ?? item.category_name ?? null,
      category_name_ar: category.name_ar ?? item.category_name_ar ?? null,
      category_name_latin: category.name_latin ?? item.category_name_latin ?? null,
      category_icon: category.icon ?? item.category_icon ?? null,
      category_display_order:
        category.display_order ?? item.category_display_order ?? null,
    };
  });
}
