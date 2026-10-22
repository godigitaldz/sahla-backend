import { customerCacheWorkerBaseUrl } from '@/lib/config/customerCache';
import { isPromoActive, type PublicDeliveryPromo } from '@/lib/appOffers/promoTypes';
import { getSupabaseAnon } from '@/server/supabase/admin';

const PROMO_SELECT =
  'id,code,restaurant_id,name,type,value,minimum_order_amount,maximum_discount_amount,start_date,end_date,status,usage_limit,used_count,applicable_categories,applicable_menu_items,is_public,applies_to';

function parsePromo(row: Record<string, unknown>): PublicDeliveryPromo | null {
  try {
    return {
      id: String(row.id),
      code: String(row.code ?? ''),
      restaurant_id: row.restaurant_id ? String(row.restaurant_id) : null,
      name: row.name != null ? String(row.name) : null,
      type: String(row.type ?? 'percentage'),
      value: Number(row.value ?? 0),
      minimum_order_amount: Number(row.minimum_order_amount ?? 0),
      maximum_discount_amount:
        row.maximum_discount_amount != null
          ? Number(row.maximum_discount_amount)
          : null,
      start_date: String(row.start_date),
      end_date: String(row.end_date),
      status: String(row.status ?? 'inactive'),
      usage_limit: row.usage_limit != null ? Number(row.usage_limit) : null,
      used_count: row.used_count != null ? Number(row.used_count) : null,
      applicable_categories: Array.isArray(row.applicable_categories)
        ? row.applicable_categories.map(String)
        : [],
      applicable_menu_items: Array.isArray(row.applicable_menu_items)
        ? row.applicable_menu_items.map(String)
        : [],
      is_public: row.is_public !== false,
      applies_to: String(row.applies_to ?? 'subtotal'),
    };
  } catch {
    return null;
  }
}

async function fetchPromosFromWorker(wilaya: string): Promise<PublicDeliveryPromo[] | null> {
  const base = customerCacheWorkerBaseUrl().replace(/\/+$/, '');
  try {
    const response = await fetch(
      `${base}/rails?wilaya=${encodeURIComponent(wilaya)}&type=promos`,
      { headers: { 'User-Agent': 'SahlaWeb/1.0' }, next: { revalidate: 60 } },
    );
    if (!response.ok) return null;
    const payload = (await response.json()) as {
      success?: boolean;
      rails?: { promos?: unknown[] };
    };
    if (!payload.success) return null;
    return ((payload.rails?.promos ?? []) as Record<string, unknown>[])
      .map(parsePromo)
      .filter(
        (promo): promo is PublicDeliveryPromo =>
          promo != null &&
          isPromoActive(promo) &&
          promo.applies_to === 'delivery_fee',
      );
  } catch {
    return null;
  }
}

async function fetchPromosFromDb(): Promise<PublicDeliveryPromo[]> {
  const anon = getSupabaseAnon();
  const { data, error } = await anon
    .from('promo_codes')
    .select(PROMO_SELECT)
    .eq('applies_to', 'delivery_fee')
    .eq('is_public', true)
    .eq('status', 'active')
    .order('created_at', { ascending: false })
    .limit(100);

  if (error) {
    console.warn('[fetchPublicDeliveryPromos] db read failed:', error.message);
    return [];
  }

  return ((data ?? []) as Record<string, unknown>[])
    .map(parsePromo)
    .filter((promo): promo is PublicDeliveryPromo => promo != null && isPromoActive(promo));
}

/** All active public delivery-fee promos (wilaya rail first, DB fallback). */
export async function fetchPublicDeliveryPromos(
  wilaya?: string | null,
): Promise<PublicDeliveryPromo[]> {
  const normalized = wilaya?.trim();
  if (normalized) {
    const fromWorker = await fetchPromosFromWorker(normalized);
    if (fromWorker != null) return fromWorker;
  }
  return fetchPromosFromDb();
}
