import { isSpecialPack, type WebMenuItem } from '@/lib/menuCatalog';
import { getSupabaseAdmin } from '@/server/supabase/admin';

/** Rail rows often omit variants — hydrate from menu_items for pack naming. */
export async function hydrateSpecialPackVariants(
  items: WebMenuItem[],
): Promise<WebMenuItem[]> {
  const missing = items.filter(
    (item) =>
      isSpecialPack(item) &&
      (!Array.isArray(item.variants) || item.variants.length === 0),
  );
  if (missing.length === 0) return items;

  const admin = getSupabaseAdmin();
  const ids = [...new Set(missing.map((item) => item.id))];
  const { data, error } = await admin
    .from('menu_items')
    .select('id,name,name_ar,name_latin,description,variants')
    .in('id', ids);

  if (error || !data?.length) {
    return items;
  }

  const byId = new Map(data.map((row) => [String(row.id), row]));

  return items.map((item) => {
    const row = byId.get(item.id);
    if (!row) return item;
    const variants = row.variants;
    if (!Array.isArray(variants) || variants.length === 0) return item;
    return {
      ...item,
      name: String(row.name ?? item.name),
      name_ar: (row.name_ar as string | null | undefined) ?? item.name_ar,
      name_latin: (row.name_latin as string | null | undefined) ?? item.name_latin,
      description: (row.description as string | null | undefined) ?? item.description,
      variants,
    };
  });
}
