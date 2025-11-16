import { supabase, supabaseAdmin } from '../config/supabase.js';

/**
 * Service for fetching data for Socket.IO real-time updates
 * Provides methods to get categories, special packs, LTO, restaurants, menu items, and tasks
 */
export class SocketDataService {
  /**
   * Get all categories
   */
  async getCategories() {
    try {
      const { data, error } = await supabase
        .from('categories')
        .select('*')
        .eq('is_active', true)
        .order('display_order')
        .order('name');

      if (error) throw error;
      return data || [];
    } catch (error) {
      console.error('Error fetching categories:', error);
      return [];
    }
  }

  /**
   * Get special pack menu items
   * Special packs are items that are not LTO but have special pricing or bundles
   */
  async getSpecialPacks({ limit = 50, offset = 0 } = {}) {
    try {
      const { data, error } = await supabase
        .from('menu_items')
        .select(`
          *,
          cuisine_types(*),
          categories(*),
          restaurant:restaurants(id, name, image_url)
        `)
        .eq('is_available', true)
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1);

      if (error) throw error;

      // Filter for special packs (items with special pricing, bundles, or marked as special)
      // Exclude LTO items
      const specialPacks = (data || []).filter(item => {
        // Check if item has special pack indicators
        const hasSpecialPricing = item.pricing_options &&
          Object.keys(item.pricing_options).length > 0;
        const isBundle = item.variants && item.variants.some(v => v.type === 'bundle');
        const isMarkedSpecial = item.is_featured === true;

        // Exclude LTO items (items with active offers)
        const hasActiveOffer = item.pricing_options?.offer_end_date &&
          new Date(item.pricing_options.offer_end_date) > new Date();

        return (hasSpecialPricing || isBundle || isMarkedSpecial) && !hasActiveOffer;
      });

      return specialPacks;
    } catch (error) {
      console.error('Error fetching special packs:', error);
      return [];
    }
  }

  /**
   * Get Limited Time Offer (LTO) items
   * Items with active time-limited offers
   */
  async getLTOItems({ restaurantId, limit = 100, offset = 0 } = {}) {
    try {
      let query = supabase
        .from('menu_items')
        .select(`
          *,
          cuisine_types(*),
          categories(*),
          restaurant:restaurants(id, name, image_url)
        `)
        .eq('is_available', true)
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1);

      if (restaurantId) {
        query = query.eq('restaurant_id', restaurantId);
      }

      const { data, error } = await query;

      if (error) throw error;

      // Filter for LTO items (items with active offers that haven't expired)
      const now = new Date();
      const ltoItems = (data || []).filter(item => {
        // Check if item has active offer
        if (item.pricing_options?.offer_end_date) {
          const offerEndDate = new Date(item.pricing_options.offer_end_date);
          return offerEndDate > now;
        }

        // Check if item has discount or special offer
        if (item.pricing_options?.discount_percent ||
            item.pricing_options?.original_price) {
          return true;
        }

        return false;
      });

      return ltoItems;
    } catch (error) {
      console.error('Error fetching LTO items:', error);
      return [];
    }
  }

  /**
   * Get restaurants
   */
  async getRestaurants({ limit = 50, offset = 0, isOpen } = {}) {
    try {
      let query = supabase
        .from('restaurants')
        .select('*')
        .order('rating', { ascending: false })
        .order('name')
        .range(offset, offset + limit - 1);

      if (isOpen !== undefined) {
        query = query.eq('is_open', isOpen);
      }

      const { data, error } = await query;

      if (error) throw error;
      return data || [];
    } catch (error) {
      console.error('Error fetching restaurants:', error);
      return [];
    }
  }

  /**
   * Get menu items
   */
  async getMenuItems({ restaurantId, category, limit = 100, offset = 0 } = {}) {
    try {
      let query = supabase
        .from('menu_items')
        .select(`
          *,
          cuisine_types(*),
          categories(*),
          restaurant:restaurants(id, name, image_url)
        `)
        .eq('is_available', true)
        .order('category')
        .order('name')
        .range(offset, offset + limit - 1);

      if (restaurantId) {
        query = query.eq('restaurant_id', restaurantId);
      }

      if (category) {
        query = query.eq('category', category);
      }

      const { data, error } = await query;

      if (error) throw error;
      return data || [];
    } catch (error) {
      console.error('Error fetching menu items:', error);
      return [];
    }
  }

  /**
   * Get tasks for delivery personnel
   */
  async getTasks({ deliveryPersonId, status, limit = 50, offset = 0 } = {}) {
    try {
      // Try tasks table first
      let query = supabase
        .from('tasks')
        .select(`
          *,
          order:orders(*),
          delivery_person:delivery_personnel(*)
        `)
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1);

      if (deliveryPersonId) {
        query = query.eq('delivery_man_id', deliveryPersonId);
      }

      if (status) {
        query = query.eq('status', status);
      }

      const { data, error } = await query;

      if (error) {
        // If tasks table doesn't exist, try delivery_tasks or return empty
        if (error.code === 'PGRST116' || error.message?.includes('does not exist')) {
          console.log('Tasks table not found, returning empty array');
          return [];
        }
        throw error;
      }
      return data || [];
    } catch (error) {
      console.error('Error fetching tasks:', error);
      return [];
    }
  }

  /**
   * Get single order by ID
   */
  async getOrderById(orderId) {
    try {
      const { data, error } = await supabase
        .from('orders')
        .select(`
          *,
          restaurant:restaurants(*),
          order_items(*)
        `)
        .eq('id', orderId)
        .single();

      if (error) throw error;
      return data;
    } catch (error) {
      console.error('Error fetching order:', error);
      return null;
    }
  }

  /**
   * Create notification in database
   */
  async createNotification({ userId, title, message, type = 'info', data = {} }) {
    try {
      const { data: notification, error } = await supabase
        .from('notifications')
        .insert({
          user_id: userId,
          title,
          message,
          type,
          data,
          is_read: false,
        })
        .select()
        .single();

      if (error) throw error;
      return notification;
    } catch (error) {
      console.error('Error creating notification:', error);
      return null;
    }
  }

  /**
   * Update order status
   */
  async updateOrderStatus(orderId, status, previousStatus = null) {
    try {
      const { data, error } = await supabase
        .from('orders')
        .update({
          status,
          updated_at: new Date().toISOString(),
        })
        .eq('id', orderId)
        .select()
        .single();

      if (error) throw error;
      return { ...data, previousStatus };
    } catch (error) {
      console.error('Error updating order status:', error);
      return null;
    }
  }

  /**
   * Update delivery location
   */
  async updateDeliveryLocation(orderId, latitude, longitude) {
    try {
      // Store in delivery_tracking table if it exists
      const { data, error } = await supabase
        .from('delivery_tracking')
        .upsert({
          order_id: orderId,
          latitude,
          longitude,
          updated_at: new Date().toISOString(),
        })
        .select()
        .single();

      if (error && error.code !== 'PGRST116') {
        // PGRST116 = table doesn't exist, which is okay
        throw error;
      }

      return data;
    } catch (error) {
      // If table doesn't exist, just return success (location is sent via Socket only)
      console.log('Delivery tracking table not found, using Socket only');
      return { orderId, latitude, longitude };
    }
  }
}

export default new SocketDataService();
