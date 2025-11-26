import { supabase } from '../config/supabase.js';

export class MenuService {
  /**
   * Get menu items with advanced filtering
   * Converted from lib/features/menu_items/domain/repositories/menu_items_repository.dart
   */
  async getMenuItems({
    restaurantId,
    category,
    availableOnly,
    limit = 50,
    offset = 0,
    cursor,
    query: searchQuery,
    categories,
    cuisines,
    minPrice,
    maxPrice,
  }) {
    if (!restaurantId) {
      throw new Error('restaurant_id is required');
    }

    let queryBuilder = supabase
      .from('menu_items')
      .select(
        `
        id, restaurant_id, restaurant_name, name, description,
        image, price, category, cuisine_type_id, category_id,
        cuisine_types(*), categories(*), is_available, is_featured,
        preparation_time, rating, review_count, variants,
        pricing_options, supplements, created_at, updated_at
      `,
        { count: 'exact' }
      )
      .eq('is_available', true);

    // Server-side text search
    if (searchQuery && searchQuery.trim().length > 0) {
      queryBuilder = queryBuilder.or(
        `name.ilike.%${searchQuery}%,description.ilike.%${searchQuery}%`
      );
    }

    // Server-side category filtering
    if (categories && categories.length > 0) {
      if (categories.length === 1) {
        queryBuilder = queryBuilder.eq('category', categories[0]);
      } else {
        // For multiple categories, use OR condition
        const orConditions = categories.map((cat) => `category.eq.${cat}`).join(',');
        queryBuilder = queryBuilder.or(orConditions);
      }
    } else if (category) {
      queryBuilder = queryBuilder.eq('category', category);
    }

    // Server-side cuisine filtering
    if (cuisines && cuisines.length > 0) {
      // Fetch cuisine IDs first
      const cuisineIds = await this._getCuisineIds(cuisines);
      if (cuisineIds.length > 0) {
        if (cuisineIds.length === 1) {
          queryBuilder = queryBuilder.eq('cuisine_type_id', cuisineIds[0]);
        } else {
          queryBuilder = queryBuilder.in('cuisine_type_id', cuisineIds);
        }
      }
    }

    // Server-side price range filtering
    if (minPrice != null) {
      queryBuilder = queryBuilder.gte('price', minPrice);
    }
    if (maxPrice != null) {
      queryBuilder = queryBuilder.lte('price', maxPrice);
    }

    // Cursor-based pagination
    if (cursor) {
      queryBuilder = queryBuilder.lt('created_at', cursor);
    }

    // Apply ordering and limit
    queryBuilder = queryBuilder
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    const { data, error, count } = await queryBuilder;

    if (error) throw error;

    // Filter out items with empty images
    const filteredData = (data || []).filter((item) => {
      const image = item.image;
      return image && image.trim().length > 0;
    });

    return { data: filteredData, count: count || filteredData.length };
  }

  /**
   * Get cuisine type IDs from names
   * @private
   */
  async _getCuisineIds(cuisineNames) {
    try {
      const { data, error } = await supabase
        .from('cuisine_types')
        .select('id')
        .in('name', cuisineNames);

      if (error) throw error;

      return (data || []).map((item) => item.id);
    } catch (error) {
      console.error('⚠️ Error fetching cuisine IDs:', error);
      return [];
    }
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
