import { NextResponse } from 'next/server';
import { fetchRestaurantAppOffers } from '@/server/restaurant/fetchRestaurantAppOffers';

export async function GET(
  _request: Request,
  context: { params: Promise<{ slug: string }> },
) {
  try {
    const { slug } = await context.params;
    const payload = await fetchRestaurantAppOffers(slug);
    if (!payload) {
      return NextResponse.json({ success: false, error: 'restaurant_not_found' }, { status: 404 });
    }
    return NextResponse.json({
      success: true,
      data: {
        restaurantId: payload.restaurantId,
        items: payload.items,
      },
    });
  } catch (error) {
    console.warn('[app-offers] failed:', error);
    return NextResponse.json({ success: true, data: { restaurantId: null, items: [] } });
  }
}
