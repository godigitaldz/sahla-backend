/**
 * Payments Service
 * Converted from lib/services/payments_service.dart
 * Handles payment collections from delivery personnel
 */

import { supabase } from '../config/supabase.js';

export class PaymentsService {
  /**
   * Fetch all delivered orders with cash payment that haven't been collected
   * @param {string} restaurantId - Restaurant ID
   * @returns {Promise<Array>} List of pending payment orders
   */
  async fetchPendingPayments(restaurantId) {
    try {
      console.log(`📦 Fetching pending payments for restaurant: ${restaurantId}`);

      const { data, error } = await supabase
        .from('orders')
        .select(`
          *,
          user_profiles:customer_id (
            id,
            name,
            phone,
            profile_image_url,
            created_at,
            updated_at
          ),
          delivery_personnel:delivery_person_id (
            id,
            user_id,
            vehicle_type,
            user:user_id (
              id,
              name,
              phone,
              profile_image_url,
              created_at,
              updated_at
            )
          ),
          restaurants:restaurant_id (
            id,
            name,
            phone,
            logo_url,
            address_line1,
            city,
            state,
            postal_code,
            latitude,
            longitude,
            created_at,
            updated_at
          ),
          order_items (
            id,
            quantity,
            unit_price,
            total_price,
            menu_item_id,
            special_instructions,
            customizations
          )
        `)
        .eq('restaurant_id', restaurantId)
        .eq('status', 'delivered')
        .eq('collected', false)
        .in('payment_method', ['cash', 'cash_on_delivery'])
        .eq('payment_status', 'pending')
        .order('actual_delivery_time', { ascending: false });

      if (error) throw error;

      console.log(`✅ Fetched ${data?.length || 0} pending payments`);
      return data || [];
    } catch (error) {
      console.error('❌ Error fetching pending payments:', error);
      throw error;
    }
  }

  /**
   * Mark an order payment as collected
   * @param {string} orderId - Order ID
   * @returns {Promise<boolean>} Success status
   */
  async markPaymentAsCollected(orderId) {
    try {
      console.log(`💰 Marking payment as collected for order: ${orderId}`);

      const now = new Date().toISOString();

      const { error } = await supabase
        .from('orders')
        .update({
          collected: true,
          payment_status: 'paid',
          collected_at: now,
          updated_at: now,
        })
        .eq('id', orderId);

      if (error) throw error;

      console.log(`✅ Payment marked as collected for order: ${orderId}`);
      return true;
    } catch (error) {
      console.error('❌ Error marking payment as collected:', error);
      return false;
    }
  }

  /**
   * Get count of pending payment orders for a restaurant
   * @param {string} restaurantId - Restaurant ID
   * @returns {Promise<number>} Count of pending payments
   */
  async getPendingPaymentsCount(restaurantId) {
    try {
      const { data, error } = await supabase
        .from('orders')
        .select('id')
        .eq('restaurant_id', restaurantId)
        .eq('status', 'delivered')
        .eq('collected', false)
        .in('payment_method', ['cash', 'cash_on_delivery'])
        .eq('payment_status', 'pending');

      if (error) throw error;

      return data?.length || 0;
    } catch (error) {
      console.error('❌ Error getting pending payments count:', error);
      return 0;
    }
  }

  /**
   * Get total amount of pending cash collections
   * Uses 'net' column which represents the amount restaurant receives
   * @param {string} restaurantId - Restaurant ID
   * @returns {Promise<number>} Total pending amount
   */
  async getPendingPaymentsTotal(restaurantId) {
    try {
      const { data, error } = await supabase
        .from('orders')
        .select('net, total_amount')
        .eq('restaurant_id', restaurantId)
        .eq('status', 'delivered')
        .eq('collected', false)
        .in('payment_method', ['cash', 'cash_on_delivery'])
        .eq('payment_status', 'pending');

      if (error) throw error;

      let total = 0.0;
      for (const order of data || []) {
        // Use 'net' if available, otherwise fallback to 'total_amount'
        const netAmount = order.net;
        const totalAmount = order.total_amount;
        const amount = netAmount ?? totalAmount ?? 0.0;
        total += amount;
      }

      return total;
    } catch (error) {
      console.error('❌ Error getting pending payments total:', error);
      return 0.0;
    }
  }
}

export default new PaymentsService();
