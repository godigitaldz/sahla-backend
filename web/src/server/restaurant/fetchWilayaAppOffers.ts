import { customerCacheWorkerBaseUrl } from '@/lib/config/customerCache';
import {
  ltoRailRowsToWebMenuItems,
  specialPackRailRowsToWebMenuItems,
} from '@/lib/appOffers/railItemToWebMenuItem';
import { getSupabaseAdmin } from '@/server/supabase/admin';
import type { WebMenuItem } from '@/lib/menuCatalog';

const LTO_SELECT =
  'id,menu_item_id,restaurant_id,restaurant_name,name,name_ar,name_latin,description,image,price,category,is_available,rating,review_count,preparation_time,is_limited_offer,offer_types,offer_start_at,offer_end_at,original_price,offer_details,pricing_options,variants,supplements,images';

const PACK_SELECT =
  'id,menu_item_id,restaurant_id,restaurant_name,name,name_ar,name_latin,description,image,price,original_price,category,is_available,rating,review_count,is_limited_offer,offer_types,offer_start_at,offer_end_at,variants,pricing_options';

async function fetchWilayaRailsFromWorker(wilaya: string): Promise<WebMenuItem[] | null> {
  const base = customerCacheWorkerBaseUrl().replace(/\/+$/, '');
  const url = `${base}/rails?wilaya=${encodeURIComponent(wilaya)}&type=all`;

  try {
    const response = await fetch(url, {
      headers: { 'User-Agent': 'SahlaWeb/1.0' },
      next: { revalidate: 60 },
    });
    if (!response.ok) return null;

    const payload = (await response.json()) as {
      success?: boolean;
      rails?: { lto?: unknown[]; special_packs?: unknown[] };
    };
    if (!payload.success) return null;

    return [
      ...ltoRailRowsToWebMenuItems(payload.rails?.lto ?? []),
      ...specialPackRailRowsToWebMenuItems(payload.rails?.special_packs ?? []),
    ];
  } catch {
    return null;
  }
}

async function fetchWilayaRailsFromDb(wilaya: string): Promise<WebMenuItem[]> {
  const admin = getSupabaseAdmin();

  const [ltoRes, packRes] = await Promise.all([
    admin
      .from('lto_items')
      .select(LTO_SELECT)
      .eq('is_available', true)
      .eq('is_limited_offer', true)
      .eq('lto_wilaya', wilaya)
      .order('is_featured', { ascending: false })
      .order('rating', { ascending: false })
      .limit(24),
    admin
      .from('special_pack_items')
      .select(PACK_SELECT)
      .eq('is_available', true)
      .eq('wilaya', wilaya)
      .order('is_featured', { ascending: false })
      .order('rating', { ascending: false })
      .limit(24),
  ]);

  return [
    ...ltoRailRowsToWebMenuItems(ltoRes.data ?? []),
    ...specialPackRailRowsToWebMenuItems(packRes.data ?? []),
  ];
}

export async function fetchWilayaAppOffers(wilaya: string): Promise<WebMenuItem[]> {
  const normalized = wilaya.trim();
  if (!normalized) return [];

  const fromWorker = await fetchWilayaRailsFromWorker(normalized);
  if (fromWorker != null) return fromWorker;

  try {
    return await fetchWilayaRailsFromDb(normalized);
  } catch (error) {
    console.warn('[fetchWilayaAppOffers] db fallback failed:', error);
    return [];
  }
}
