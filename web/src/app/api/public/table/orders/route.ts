import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { priceCartLines } from '@/server/pricing/menuLinePricing';
import { loadWebCommissionConfig } from '@/server/pricing/webCommissionResolver';
import { computeWebOrderTotals } from '@/server/pricing/webOrderTotals';
import { isValidGuestPhone, normalizePhoneForStorage } from '@/server/phone/normalizePhone';
import { getSupabaseAdmin } from '@/server/supabase/admin';
import { assertRestaurantAcceptingOrders } from '@/server/restaurant/assertRestaurantAcceptingOrders';
import { translateOrderError } from '@/lib/i18n/orderErrors';
import {
  isDuplicateOrderGuardError,
  normalizeCreatedOrder,
} from '@/server/orders/normalizeCreatedOrder';
import { recoverRecentWebOrder } from '@/server/orders/recoverRecentWebOrder';
import { withTrackingLink } from '@/server/orders/issueTrackingLink';
import { verifyReturnedTableOrder } from '@/server/orders/verifyReturnedWebOrder';
import { TABLE_CSRF_COOKIE, TABLE_SESSION_COOKIE } from '@/server/table/cookies';
import { sha256Buffer } from '@/server/table/crypto';
import { assertAllowedOrigin, assertCsrf } from '@/server/table/csrf';
import {
  allowTableOrderByPhone,
  allowTableOrderBySession,
} from '@/server/rateLimit/upstashTableLimiter';

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
  guest_phone: z.string().nullable().optional(),
  guest_name: z.string().nullable().optional(),
  special_instructions: z.string().nullable().optional(),
  payment_method: z.string().optional(),
  items: z.array(cartLineSchema).min(1),
});

export async function POST(request: NextRequest) {
  try {
    if (!assertAllowedOrigin(request)) {
      return NextResponse.json({ success: false, error: 'forbidden_origin' }, { status: 403 });
    }

    const csrfCookie = request.cookies.get(TABLE_CSRF_COOKIE)?.value;
    if (!assertCsrf(request, csrfCookie)) {
      return NextResponse.json({ success: false, error: 'csrf_invalid' }, { status: 403 });
    }

    const sessionToken = request.cookies.get(TABLE_SESSION_COOKIE)?.value;
    if (!sessionToken) {
      return NextResponse.json(
        {
          success: false,
          error: 'session_expired',
          message: 'يرجى إعادة مسح رمز الطاولة',
        },
        { status: 401 },
      );
    }

    const parsed = bodySchema.safeParse(await request.json());
    if (!parsed.success) {
      return NextResponse.json({ success: false, error: 'invalid_body' }, { status: 400 });
    }

    const guestPhoneRaw = String(parsed.data.guest_phone ?? '').trim();
    let guestPhone: string | null = null;
    if (guestPhoneRaw) {
      if (!isValidGuestPhone(guestPhoneRaw)) {
        return NextResponse.json({ success: false, error: 'invalid_phone' }, { status: 400 });
      }
      guestPhone = normalizePhoneForStorage(guestPhoneRaw);
    }

    const admin = getSupabaseAdmin();
    const sessionHash = `\\x${sha256Buffer(sessionToken).toString('hex')}`;

    const { data: sessionCtx, error: sessionError } = await admin.rpc('get_table_session_context', {
      p_session_token_hash: sessionHash,
    });

    if (sessionError || !sessionCtx || sessionCtx.status !== 'active') {
      return NextResponse.json(
        {
          success: false,
          error: 'session_expired',
          message: 'يرجى إعادة مسح رمز الطاولة',
        },
        { status: 401 },
      );
    }

    if (guestPhone && !(await allowTableOrderByPhone(guestPhone))) {
      return NextResponse.json({ success: false, error: 'rate_limited' }, { status: 429 });
    }

    if (!(await allowTableOrderBySession(String(sessionCtx.session_id)))) {
      return NextResponse.json({ success: false, error: 'rate_limited' }, { status: 429 });
    }

    const { data: restaurant, error: restaurantError } = await admin
      .from('restaurants')
      .select(
        'id,name,public_slug,is_open,opening_hours,closing_hours,vacation_starts_at,vacation_returns_at,is_new,web_order_commission_rate,web_order_commission_cap_da,estimated_delivery_time',
      )
      .eq('id', sessionCtx.restaurant_id)
      .maybeSingle();

    if (restaurantError || !restaurant) {
      return NextResponse.json({ success: false, error: 'restaurant_not_found' }, { status: 404 });
    }

    const restaurantSlug = String(restaurant.public_slug ?? '').trim();

    const availability = assertRestaurantAcceptingOrders({
      is_open: restaurant.is_open,
      opening_hours: restaurant.opening_hours,
      closing_hours: restaurant.closing_hours,
      vacation_starts_at: restaurant.vacation_starts_at,
      vacation_returns_at: restaurant.vacation_returns_at,
    });
    if (!availability.ok) {
      return NextResponse.json(
        { success: false, error: availability.error, message: availability.message },
        { status: 409 },
      );
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
    const totals = computeWebOrderTotals({
      subtotal,
      fulfillmentType: 'table',
      restaurant: {
        is_new: restaurant.is_new === true,
        web_order_commission_rate: restaurant.web_order_commission_rate,
        web_order_commission_cap_da: restaurant.web_order_commission_cap_da,
      },
      systemConfig,
    });

    const pricingSnapshot = {
      source: 'web_table',
      subtotal,
      totals,
      commission: totals.commissionMeta,
      items: pricedLines,
      table_number: sessionCtx.table_number,
    };

    const orderItemsJson = pricedLines.map((line) => ({
      menu_item_id: line.menu_item_id,
      quantity: line.quantity,
      unit_price: line.unit_price,
      total_price: line.total_price,
      special_instructions: line.special_instructions,
      customizations: line.customizations,
    }));

    const { data: created, error: createError } = await admin.rpc('create_public_table_order', {
      p_session_token_hash: sessionHash,
      p_guest_phone: guestPhone,
      p_guest_name: parsed.data.guest_name ?? null,
      p_special_instructions: parsed.data.special_instructions ?? null,
      p_client_request_id: parsed.data.client_request_id,
      p_payment_method: parsed.data.payment_method ?? 'cash',
      p_subtotal: totals.subtotal,
      p_commission_tax: totals.commissionTax,
      p_total_amount: totals.totalAmount,
      p_net: totals.net,
      p_pricing_snapshot: pricingSnapshot,
      p_order_items: orderItemsJson,
    });

    if (createError) {
      if (createError.message?.includes('session_expired')) {
        return NextResponse.json(
          {
            success: false,
            error: 'session_expired',
            message: 'يرجى إعادة مسح رمز الطاولة',
          },
          { status: 401 },
        );
      }

      if (isDuplicateOrderGuardError(createError.message)) {
        const recovered = await recoverRecentWebOrder(admin, {
          restaurantId: String(restaurant.id),
          guestPhone,
          restaurantName: String(restaurant.name ?? ''),
          estimatedDeliveryMinutes: Number(restaurant.estimated_delivery_time ?? 30),
          clientRequestId: parsed.data.client_request_id,
        });
        if (recovered) {
          const verified = await verifyReturnedTableOrder(admin, {
            order: recovered,
            restaurantId: String(restaurant.id),
            clientRequestId: parsed.data.client_request_id,
            guestPhone,
            fulfillmentType: 'table',
            tableSessionId: sessionCtx.session_id,
            tableId: sessionCtx.restaurant_table_id,
            requireRecentWindow: true,
          });
          if (!verified.ok) {
            return NextResponse.json(
              { success: false, error: 'order_conflict', message: translateOrderError('order_conflict') },
              { status: 409 },
            );
          }
          const withTrack = await withTrackingLink(admin, recovered, restaurantSlug);
          return NextResponse.json(
            {
              success: true,
              data: {
                ...withTrack,
                table_number: sessionCtx.table_number,
                table_label: sessionCtx.table_label,
              },
            },
            { status: 201 },
          );
        }
      }

      return NextResponse.json(
        {
          success: false,
          error: createError.message,
          message: translateOrderError(createError.message),
        },
        { status: 400 },
      );
    }

    const order = normalizeCreatedOrder(created);
    if (!order) {
      return NextResponse.json(
        { success: false, error: 'order_response_invalid' },
        { status: 500 },
      );
    }

    const verified = await verifyReturnedTableOrder(admin, {
      order,
      restaurantId: String(restaurant.id),
      clientRequestId: parsed.data.client_request_id,
      guestPhone,
      fulfillmentType: 'table',
      tableSessionId: sessionCtx.session_id,
      tableId: sessionCtx.restaurant_table_id,
      requireRecentWindow: order.idempotent === true || order.duplicate_recovered === true,
    });
    if (!verified.ok) {
      return NextResponse.json(
        { success: false, error: 'order_conflict', message: translateOrderError('order_conflict') },
        { status: 409 },
      );
    }

    const withTrack = await withTrackingLink(admin, order, restaurantSlug);
    return NextResponse.json(
      {
        success: true,
        data: {
          ...withTrack,
          table_number: created?.table_number ?? sessionCtx.table_number,
          table_label: created?.table_label ?? sessionCtx.table_label,
        },
      },
      { status: 201 },
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : 'unknown_error';
    return NextResponse.json({ success: false, error: message }, { status: 500 });
  }
}
