import { supabase } from '../config/supabase.js';

export class OrderService {
  async getOrders({ userId, status, limit = 50, offset = 0 }) {
    let query = supabase
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
      deliveryFee,
      subtotal,
      total,
      paymentMethod,
      promoCode,
      notes,
    } = orderData;

    // Create order
    const { data: order, error: orderError } = await supabase
      .from('orders')
      .insert({
        user_id: userId,
        restaurant_id: restaurantId,
        delivery_address: deliveryAddress,
        delivery_fee: deliveryFee || 0,
        subtotal: subtotal || 0,
        total: total || 0,
        payment_method: paymentMethod || 'cash',
        promo_code: promoCode,
        notes,
        status: 'pending',
      })
      .select()
      .single();

    if (orderError) throw orderError;

    // Create order items
    const orderItems = items.map(item => ({
      order_id: order.id,
      menu_item_id: item.menu_item_id,
      quantity: item.quantity,
      price: item.price,
      subtotal: item.quantity * item.price,
      customizations: item.customizations || null,
    }));

    const { error: itemsError } = await supabase
      .from('order_items')
      .insert(orderItems);

    if (itemsError) throw itemsError;

    return order;
  }

  async getOrderById(orderId, userId) {
    const { data, error } = await supabase
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

  async updateOrderStatus(orderId, status) {
    const { data, error } = await supabase
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
