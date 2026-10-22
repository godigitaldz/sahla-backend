import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { priceCartLines } from '@/server/pricing/menuLinePricing';
import { fetchDeliveryFeeQuote } from '@/server/pricing/deliveryFeePreview';
import { loadWebCommissionConfig } from '@/server/pricing/webCommissionResolver';
import { computeWebOrderTotals } from '@/server/pricing/webOrderTotals';
import { isValidGuestPhone, normalizePhoneForStorage } from '@/server/phone/normalizePhone';
import { allowPublicOrderRequest } from '@/server/rateLimit/publicOrderLimiter';
import { getSupabaseAdmin, getSupabaseAnon } from '@/server/supabase/admin';
import { fallbackLoadPublicRestaurant } from '@/server/publicRestaurant';
import { assertRestaurantAcceptingOrders } from '@/server/restaurant/assertRestaurantAcceptingOrders';
import { translateOrderError } from '@/lib/i18n/orderErrors';
import {
  isDuplicateOrderGuardError,
  normalizeCreatedOrder,
} from '@/server/orders/normalizeCreatedOrder';
import { recoverRecentWebOrder } from '@/server/orders/recoverRecentWebOrder';
import { withTrackingLink } from '@/server/orders/issueTrackingLink';
import { verifyReturnedWebOrder } from '@/server/orders/verifyReturnedWebOrder';

const cartLineSchema = z.object({
  menu_item_id: z.string().uuid(),
  quantity: z.number().int().min(1).max(50),
  pricing_size: z.string().nullable().optional(),
  variant_name: z.string().nullable().optional(),
  supplement_names: z.array(z.string()).optional(),
  special_instructions: z.string().nullable().optional(),
  client_unit_price: z.number().optional(),
  client_total_price: z.number().optional(),
});

const bodySchema = z.object({
  client_request_id: z.string().uuid(),
  fulfillment_type: z.enum(['delivery', 'pickup']),
  guest_phone: z.string().min(6),
  guest_name: z.string().nullable().optional(),
  special_instructions: z.string().nullable().optional(),
  payment_method: z.string().optional(),
  delivery_address: z.record(z.unknown()).nullable().optional(),
  items: z.array(cartLineSchema).min(1),
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

    const guestPhone = normalizePhoneForStorage(parsed.data.guest_phone);
    if (!isValidGuestPhone(parsed.data.guest_phone)) {
      return NextResponse.json({ success: false, error: 'invalid_phone' }, { status: 400 });
    }

    const ip = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? 'unknown';
    const anon = getSupabaseAnon();
    const admin = getSupabaseAdmin();

    let restaurant = null as Record<string, unknown> | null;
    const { data: rpcRestaurant, error: rpcError } = await anon.rpc(
      'get_public_restaurant_by_slug',
      { p_slug: slug },
    );

    if (rpcError?.message?.includes('function') || rpcError?.code === 'PGRST202') {
      const fallback = await fallbackLoadPublicRestaurant(slug);
      restaurant = (fallback?.restaurant as Record<string, unknown>) ?? null;
    } else if (rpcError) {
      return NextResponse.json({ success: false, error: rpcError.message }, { status: 500 });
    } else {
      restaurant = rpcRestaurant as Record<string, unknown> | null;
    }

    if (!restaurant) {
      return NextResponse.json({ success: false, error: 'restaurant_not_found' }, { status: 404 });
    }

    const availability = assertRestaurantAcceptingOrders({
      is_open: restaurant.is_open as boolean | null | undefined,
      opening_hours: restaurant.opening_hours,
      closing_hours: restaurant.closing_hours,
      vacation_starts_at: restaurant.vacation_starts_at as string | null | undefined,
      vacation_returns_at: restaurant.vacation_returns_at as string | null | undefined,
    });
    if (!availability.ok) {
      return NextResponse.json(
        { success: false, error: availability.error, message: availability.message },
        { status: 409 },
      );
    }

    if (!allowPublicOrderRequest(ip, guestPhone, parsed.data.client_request_id)) {
      return NextResponse.json({ success: false, error: 'rate_limited' }, { status: 429 });
    }

    const menuItemIds = parsed.data.items.map((i) => i.menu_item_id);
    const { data: menuItems, error: menuError } = await admin
      .from('menu_items')
      .select(
        'id,restaurant_id,name,price,is_available,is_limited_offer,offer_start_at,offer_end_at,pricing_options,supplements,variants,offer_details',
      )
      .in('id', menuItemIds);

    if (menuError) {
      return NextResponse.json({ success: false, error: menuError.message }, { status: 500 });
    }

    const { subtotal, pricedLines } = priceCartLines(
      (menuItems ?? []) as never[],
      parsed.data.items,
      String(restaurant.id),
    );

    const systemConfig = await loadWebCommissionConfig(admin);

    let deliveryQuote;
    if (parsed.data.fulfillment_type === 'delivery') {
      const address = parsed.data.delivery_address ?? {};
      const lat = Number((address as Record<string, unknown>).latitude);
      const lon = Number((address as Record<string, unknown>).longitude);
      if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
        return NextResponse.json({ success: false, error: 'delivery_address_required' }, { status: 400 });
      }
      deliveryQuote = await fetchDeliveryFeeQuote({
        restaurantId: String(restaurant.id),
        restaurantLatitude: Number(restaurant.latitude),
        restaurantLongitude: Number(restaurant.longitude),
        restaurantBaseFee: Number(restaurant.delivery_fee ?? 0),
        customerLatitude: lat,
        customerLongitude: lon,
      });
    }

    const totals = computeWebOrderTotals({
      subtotal,
      fulfillmentType: parsed.data.fulfillment_type,
      deliveryQuote,
      restaurant: {
        is_new: restaurant.is_new === true,
        web_order_commission_rate: restaurant.web_order_commission_rate as number | null,
        web_order_commission_cap_da: restaurant.web_order_commission_cap_da as number | null,
      },
      systemConfig,
    });

    const pickupAddress =
      parsed.data.fulfillment_type === 'pickup'
        ? {
            fullAddress: [restaurant.address_line1, restaurant.city, restaurant.wilaya]
              .filter(Boolean)
              .join(', '),
            latitude: restaurant.latitude,
            longitude: restaurant.longitude,
          }
        : null;

    const pricingSnapshot = {
      source: 'web',
      subtotal,
      totals,
      commission: totals.commissionMeta,
      items: pricedLines,
    };

    const orderItemsJson = pricedLines.map((line) => ({
      menu_item_id: line.menu_item_id,
      quantity: line.quantity,
      unit_price: line.unit_price,
      total_price: line.total_price,
      special_instructions: line.special_instructions,
      customizations: line.customizations,
    }));

    const { data: created, error: createError } = await admin.rpc('create_public_web_order', {
      p_restaurant_slug: slug,
      p_fulfillment_type: parsed.data.fulfillment_type,
      p_guest_phone: guestPhone,
      p_guest_name: parsed.data.guest_name ?? null,
      p_delivery_address: parsed.data.fulfillment_type === 'delivery' ? parsed.data.delivery_address : {},
      p_pickup_address: pickupAddress,
      p_special_instructions: parsed.data.special_instructions ?? null,
      p_client_request_id: parsed.data.client_request_id,
      p_payment_method: parsed.data.payment_method ?? 'cash',
      p_subtotal: totals.subtotal,
      p_original_delivery_fee: totals.originalDeliveryFee,
      p_delivery_fee: totals.deliveryFee,
      p_delivery_tax: totals.deliveryTax,
      p_net_delivery_amount: totals.netDeliveryAmount,
      p_commission_tax: totals.commissionTax,
      p_total_amount: totals.totalAmount,
      p_net: totals.net,
      p_pricing_snapshot: pricingSnapshot,
      p_order_items: orderItemsJson,
    });

    if (createError) {
      if (isDuplicateOrderGuardError(createError.message)) {
        const recovered = await recoverRecentWebOrder(admin, {
          restaurantId: String(restaurant.id),
          guestPhone,
          restaurantName: String(restaurant.name ?? ''),
          estimatedDeliveryMinutes: Number(restaurant.estimated_delivery_time ?? 30),
          clientRequestId: parsed.data.client_request_id,
        });
        if (recovered) {
          const verified = await verifyReturnedWebOrder(admin, {
            order: recovered,
            restaurantId: String(restaurant.id),
            clientRequestId: parsed.data.client_request_id,
            guestPhone,
            fulfillmentType: parsed.data.fulfillment_type,
            requireRecentWindow: true,
          });
          if (!verified.ok) {
            return NextResponse.json(
              { success: false, error: 'order_conflict', message: translateOrderError('order_conflict') },
              { status: 409 },
            );
          }
          const withTrack = await withTrackingLink(admin, recovered, slug);
          return NextResponse.json({ success: true, data: withTrack }, { status: 201 });
        }
      }

      return NextResponse.json(
        {
          success: false,
          error: createError.message,
          message: isDuplicateOrderGuardError(createError.message)
            ? createError.message
            : translateOrderError(createError.message),
        },
        { status: 400 },
      );
    }

    const order = normalizeCreatedOrder(created);
    if (!order) {
      return NextResponse.json(
        { success: false, error: 'order_response_invalid', message: translateOrderError('order_response_invalid') },
        { status: 500 },
      );
    }

    const verified = await verifyReturnedWebOrder(admin, {
      order,
      restaurantId: String(restaurant.id),
      clientRequestId: parsed.data.client_request_id,
      guestPhone,
      fulfillmentType: parsed.data.fulfillment_type,
      requireRecentWindow: order.idempotent === true || order.duplicate_recovered === true,
    });
    if (!verified.ok) {
      return NextResponse.json(
        { success: false, error: 'order_conflict', message: translateOrderError('order_conflict') },
        { status: 409 },
      );
    }

    const withTrack = await withTrackingLink(admin, order, slug);
    return NextResponse.json({ success: true, data: withTrack }, { status: 201 });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'unknown_error';
    const status = message.includes('manipulation') ? 400 : 500;
    return NextResponse.json({ success: false, error: message }, { status });
  }
}
