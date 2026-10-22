import { NextResponse } from 'next/server';
import { fetchPublicDeliveryPromos } from '@/server/restaurant/fetchPublicDeliveryPromos';
import { getSupabaseAnon } from '@/server/supabase/admin';
import { fallbackLoadPublicRestaurant } from '@/server/publicRestaurant';

export async function GET(
  _request: Request,
  context: { params: Promise<{ slug: string }> },
) {
  try {
    const { slug } = await context.params;
    const anon = getSupabaseAnon();
    let wilaya: string | null = null;

    const { data: rpcRestaurant, error } = await anon.rpc('get_public_restaurant_by_slug', {
      p_slug: slug,
    });

    if (!error && rpcRestaurant) {
      wilaya = String((rpcRestaurant as { wilaya?: string }).wilaya ?? '').trim() || null;
    } else {
      const fallback = await fallbackLoadPublicRestaurant(slug);
      wilaya =
        String((fallback?.restaurant as { wilaya?: string } | undefined)?.wilaya ?? '').trim() ||
        null;
    }

    const promos = await fetchPublicDeliveryPromos(wilaya);
    return NextResponse.json({ success: true, data: promos });
  } catch (error) {
    console.warn('[app-promos] unexpected error:', error);
    return NextResponse.json({ success: true, data: [] });
  }
}
