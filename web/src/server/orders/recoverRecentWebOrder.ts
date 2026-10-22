import type { SupabaseClient } from '@supabase/supabase-js';
import type { CreatedWebOrder } from '@/lib/orders/createdWebOrder';

/** When the 1-minute duplicate guard fires, return the order that was just created. */
export async function recoverRecentWebOrder(
  admin: SupabaseClient,
  params: {
    restaurantId: string;
    guestPhone?: string | null;
    restaurantName: string;
    estimatedDeliveryMinutes?: number | null;
    clientRequestId?: string;
  },
): Promise<CreatedWebOrder | null> {
  const since = new Date(Date.now() - 2 * 60 * 1000).toISOString();

  if (params.clientRequestId) {
    const { data: byRequest } = await admin
      .from('orders')
      .select('id, order_number, public_order_code, total_amount, fulfillment_type')
      .eq('client_request_id', params.clientRequestId)
      .maybeSingle();

    if (byRequest?.order_number) {
      return {
        id: String(byRequest.id),
        order_number: String(byRequest.order_number),
        public_order_code: byRequest.public_order_code
          ? String(byRequest.public_order_code)
          : undefined,
        total_amount: Number(byRequest.total_amount ?? 0),
        fulfillment_type: String(byRequest.fulfillment_type ?? 'delivery'),
        restaurant_name: params.restaurantName,
        estimated_delivery_time: params.estimatedDeliveryMinutes ?? null,
        idempotent: true,
        duplicate_recovered: true,
      };
    }
  }

  const guestPhone = params.guestPhone?.trim();
  if (!guestPhone) {
    return null;
  }

  const { data: recent } = await admin
    .from('orders')
    .select('id, order_number, public_order_code, total_amount, fulfillment_type')
    .eq('restaurant_id', params.restaurantId)
    .eq('guest_phone', guestPhone)
    .eq('source', 'web')
    .gte('created_at', since)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (!recent?.order_number) return null;

  return {
    id: String(recent.id),
    order_number: String(recent.order_number),
    public_order_code: recent.public_order_code ? String(recent.public_order_code) : undefined,
    total_amount: Number(recent.total_amount ?? 0),
    fulfillment_type: String(recent.fulfillment_type ?? 'delivery'),
    restaurant_name: params.restaurantName,
    estimated_delivery_time: params.estimatedDeliveryMinutes ?? null,
    idempotent: true,
    duplicate_recovered: true,
  };
}
