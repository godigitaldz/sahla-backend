import { supabaseAdmin } from '../config/supabase.js';
import { getActiveAdminUserIds } from './adminRecipients.js';

const ALLOWED_ORDER_STATUSES = new Set([
  'pending',
  'confirmed',
  'preparing',
  'ready',
  'picked_up',
  'delivered',
  'cancelled',
]);

function httpError(statusCode, message) {
  const err = new Error(message);
  err.statusCode = statusCode;
  return err;
}

export class OrderService {
  async getOrders({ userId, status, limit = 50, offset = 0 }) {
    let query = supabaseAdmin
      .from('orders')
      .select(`
        *,
        restaurant:restaurants(id, name, image_url),
        order_items(*)
      `, { count: 'exact' })
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (status) {
      query = query.eq('status', status);
    }

    const { data, error, count } = await query;

    if (error) throw error;

    return { data, count };
  }

  async createOrder(orderData) {
    const {
      userId,
      restaurantId,
      items,
      deliveryAddress,
      promoCode,
      notes,
    } = orderData;

    if (!restaurantId || !Array.isArray(items) || items.length === 0) {
      throw httpError(400, 'restaurantId and at least one order item are required');
    }

    const { data: restaurant, error: restaurantError } = await supabaseAdmin
      .from('restaurants')
      .select('id, delivery_fee, is_open')
      .eq('id', restaurantId)
      .maybeSingle();

    if (restaurantError) throw restaurantError;
    if (!restaurant) {
      throw httpError(404, 'Restaurant not found');
    }

    const menuItemIds = [...new Set(items.map((item) => item?.menu_item_id).filter(Boolean))];
    if (menuItemIds.length === 0) {
      throw httpError(400, 'Valid menu_item_id is required for each item');
    }

    const { data: menuRows, error: menuError } = await supabaseAdmin
      .from('menu_items')
      .select('id, restaurant_id, price, is_available')
      .in('id', menuItemIds);

    if (menuError) throw menuError;

    const menuById = new Map((menuRows || []).map((row) => [row.id, row]));
    let serverSubtotal = 0;
    const normalizedItems = [];

    for (const item of items) {
      const qty = Number(item?.quantity);
      if (!Number.isInteger(qty) || qty <= 0 || qty > 100) {
        throw httpError(400, 'Each item quantity must be a positive integer (1-100)');
      }
      const dbItem = menuById.get(item.menu_item_id);
      if (!dbItem || dbItem.restaurant_id !== restaurantId) {
        throw httpError(400, `Menu item ${item?.menu_item_id} does not belong to restaurant`);
      }
      if (dbItem.is_available === false) {
        throw httpError(400, `Menu item ${item?.menu_item_id} is currently unavailable`);
      }
      const unitPrice = Number(dbItem.price) || 0;
      const lineSubtotal = Math.round(unitPrice * qty * 100) / 100;
      serverSubtotal += lineSubtotal;
      normalizedItems.push({
        menu_item_id: dbItem.id,
        quantity: qty,
        price: unitPrice,
        subtotal: lineSubtotal,
        customizations: item.customizations || null,
      });
    }

    const serverDeliveryFee = Number(restaurant.delivery_fee) || 0;
    const serverTotal = Math.round((serverSubtotal + serverDeliveryFee) * 100) / 100;

    // Create order using server-verified prices and totals (cash on delivery)
    const { data: order, error: orderError } = await supabaseAdmin
      .from('orders')
      .insert({
        user_id: userId,
        restaurant_id: restaurantId,
        delivery_address: deliveryAddress,
        delivery_fee: serverDeliveryFee,
        subtotal: serverSubtotal,
        total: serverTotal,
        payment_method: 'cash',
        promo_code: promoCode || null,
        notes: notes || null,
        status: 'pending',
      })
      .select()
      .single();

    if (orderError) throw orderError;

    const orderItems = normalizedItems.map((item) => ({
      order_id: order.id,
      ...item,
    }));

    const { error: itemsError } = await supabaseAdmin
      .from('order_items')
      .insert(orderItems);

    if (itemsError) throw itemsError;

    return order;
  }

  async getOrderById(orderId, userId) {
    const { data, error } = await supabaseAdmin
      .from('orders')
      .select(`
        *,
        restaurant:restaurants(*),
        order_items(*)
      `)
      .eq('id', orderId)
      .eq('user_id', userId)
      .single();

    if (error) throw error;

    return data;
  }

  async updateOrderStatus(orderId, status, actorUserId) {
    if (!ALLOWED_ORDER_STATUSES.has(status)) {
      throw httpError(400, `Invalid status value: ${status}`);
    }

    const { data: existing, error: fetchError } = await supabaseAdmin
      .from('orders')
      .select('id, user_id, restaurant_id, delivery_person_id, status')
      .eq('id', orderId)
      .maybeSingle();

    if (fetchError) throw fetchError;
    if (!existing) {
      throw httpError(404, 'Order not found');
    }

    const adminIds = await getActiveAdminUserIds();
    const isAdmin = adminIds.includes(actorUserId);

    let isRestaurantOwner = false;
    if (!isAdmin && existing.restaurant_id) {
      const { data: rest } = await supabaseAdmin
        .from('restaurants')
        .select('owner_id')
        .eq('id', existing.restaurant_id)
        .maybeSingle();
      isRestaurantOwner = Boolean(rest && rest.owner_id === actorUserId);
    }

    const isAssignedCourier = Boolean(
      existing.delivery_person_id && existing.delivery_person_id === actorUserId
    );
    const isCustomerCancellingPending =
      existing.user_id === actorUserId &&
      existing.status === 'pending' &&
      status === 'cancelled';

    if (!isAdmin && !isRestaurantOwner && !isAssignedCourier && !isCustomerCancellingPending) {
      throw httpError(403, 'Forbidden: not authorized to update this order status');
    }

    const { data, error } = await supabaseAdmin
      .from('orders')
      .update({ status, updated_at: new Date().toISOString() })
      .eq('id', orderId)
      .select()
      .single();

    if (error) throw error;

    return data;
  }
}

export default new OrderService();
