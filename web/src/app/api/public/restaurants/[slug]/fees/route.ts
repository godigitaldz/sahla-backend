import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { fetchDeliveryFeeQuote } from '@/server/pricing/deliveryFeePreview';
import { getSupabaseAnon } from '@/server/supabase/admin';
import { fallbackLoadPublicRestaurant } from '@/server/publicRestaurant';

const bodySchema = z.object({
  customer_latitude: z.number(),
  customer_longitude: z.number(),
});

export async function POST(
  request: NextRequest,
  context: { params: Promise<{ slug: string }> },
) {
  try {
    const { slug } = await context.params;
    const parsed = bodySchema.safeParse(await request.json());
    if (!parsed.success) {
      return NextResponse.json({ success: false, error: 'invalid_body' }, { status: 400 });
    }

    const anon = getSupabaseAnon();
    let restaurant = null as Record<string, unknown> | null;

    const { data: rpcRestaurant, error } = await anon.rpc('get_public_restaurant_by_slug', {
      p_slug: slug,
    });

    if (error?.message?.includes('function') || error?.code === 'PGRST202') {
      const fallback = await fallbackLoadPublicRestaurant(slug);
      restaurant = fallback?.restaurant ?? null;
    } else if (error) {
      return NextResponse.json({ success: false, error: error.message }, { status: 500 });
    } else {
      restaurant = rpcRestaurant as Record<string, unknown> | null;
    }

    if (!restaurant) {
      return NextResponse.json({ success: false, error: 'restaurant_not_found' }, { status: 404 });
    }

    const quote = await fetchDeliveryFeeQuote({
      restaurantId: String(restaurant.id),
      restaurantLatitude: Number(restaurant.latitude),
      restaurantLongitude: Number(restaurant.longitude),
      restaurantBaseFee: Number(restaurant.delivery_fee ?? 0),
      customerLatitude: parsed.data.customer_latitude,
      customerLongitude: parsed.data.customer_longitude,
    });

    return NextResponse.json({ success: true, data: quote });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'unknown_error';
    return NextResponse.json({ success: false, error: message }, { status: 500 });
  }
}
