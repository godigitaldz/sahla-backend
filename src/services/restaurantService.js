import { supabase } from '../config/supabase.js';

export class RestaurantService {
  async getRestaurants({ category, cuisine, minRating, isFeatured, limit = 20, offset = 0 }) {
    let query = supabase
      .from('restaurants')
      .select('*', { count: 'exact' })
      .order('rating', { ascending: false })
      .range(offset, offset + limit - 1);

    if (category) {
      query = query.eq('category', category);
    }
    if (cuisine) {
      query = query.eq('cuisine_type', cuisine);
    }
    if (minRating) {
      query = query.gte('rating', parseFloat(minRating));
    }
    if (isFeatured !== undefined) {
      query = query.eq('is_featured', isFeatured === 'true');
    }

    const { data, error, count } = await query;

    if (error) throw error;

    return { data, count };
  }

  async searchRestaurants({ query, limit = 20 }) {
    const { data, error } = await supabase
      .from('restaurants')
      .select('*')
      .or(`name.ilike.%${query}%,description.ilike.%${query}%`)
      .order('rating', { ascending: false })
      .limit(limit);

    if (error) throw error;

    return data;
  }

  async getRestaurantById(id) {
    const { data, error } = await supabase
      .from('restaurants')
      .select('*')
      .eq('id', id)
      .single();

    if (error) throw error;

    return data;
  }
}

export default new RestaurantService();
