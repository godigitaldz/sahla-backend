import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { fetchBatchDeliveryFeeQuotes } from '@/server/pricing/deliveryFeePreview';
import { getSupabaseAnon } from '@/server/supabase/admin';

const bodySchema = z.object({
  customer_latitude: z.number(),
  customer_longitude: z.number(),
  restaurant_ids: z.array(z.string().uuid()).max(30),
});

export async function POST(request: NextRequest) {
  try {
    const parsed = bodySchema.safeParse(await request.json());
    if (!parsed.success) {
      return NextResponse.json({ success: false, error: 'invalid_body' }, { status: 400 });
    }

    const ids = [...new Set(parsed.data.restaurant_ids.map((id) => id.trim()).filter(Boolean))];
    if (ids.length === 0) {
      return NextResponse.json({ success: true, data: { feesByRestaurantId: {} } });
    }

    const anon = getSupabaseAnon();
    const { data, error } = await anon
      .from('restaurants')
      .select('id,latitude,longitude,delivery_fee,is_verified,is_public_web_enabled')
      .in('id', ids);

    if (error) {
      return NextResponse.json({ success: false, error: error.message }, { status: 500 });
    }

    const restaurants = (data ?? [])
      .filter(
        (row) =>
          row.is_verified === true &&
          row.is_public_web_enabled === true &&
          Number.isFinite(Number(row.latitude)) &&
          Number.isFinite(Number(row.longitude)),
      )
      .map((row) => ({
        id: String(row.id),
        latitude: Number(row.latitude),
        longitude: Number(row.longitude),
        base_fee: Number(row.delivery_fee ?? 0),
      }));

    const feesByRestaurantId = await fetchBatchDeliveryFeeQuotes({
      customerLatitude: parsed.data.customer_latitude,
      customerLongitude: parsed.data.customer_longitude,
      restaurants,
    });

    return NextResponse.json({ success: true, data: { feesByRestaurantId } });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'unknown_error';
    return NextResponse.json({ success: false, error: message }, { status: 500 });
  }
}
