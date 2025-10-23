import { supabase } from '../config/supabase.js';

export class MenuService {
  async getMenuItems({ restaurantId, category, availableOnly, limit = 50, offset = 0 }) {
    if (!restaurantId) {
      throw new Error('restaurant_id is required');
    }

    let query = supabase
      .from('menu_items')
      .select(`
        *,
        cuisine_types(*),
        categories(*)
      `, { count: 'exact' })
      .eq('restaurant_id', restaurantId)
      .order('category')
      .order('name')
      .range(offset, offset + limit - 1);

    if (category) {
      query = query.eq('category', category);
    }
    if (availableOnly === 'true' || availableOnly === true) {
      query = query.eq('is_available', true);
    }

    const { data, error, count } = await query;

    if (error) throw error;

    return { data, count };
  }

  async getMenuItemById(id) {
    const { data, error } = await supabase
      .from('menu_items')
      .select(`
        *,
        cuisine_types(*),
        categories(*),
        restaurant:restaurants(*)
      `)
      .eq('id', id)
      .single();

    if (error) throw error;

    return data;
  }
}

export default new MenuService();
