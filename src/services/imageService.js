import { supabaseAdmin } from '../config/supabase.js';

/**
 * Image Service with aggressive caching for optimal performance
 * Handles batch image loading, single image loading, and restaurant drink images
 */
export class ImageService {
  constructor() {
    // In-memory cache with TTL (Time To Live)
    this.cache = new Map();
    this.cacheTTL = 15 * 60 * 1000; // 15 minutes in milliseconds

    // Cache statistics
    this.stats = {
      hits: 0,
      misses: 0,
      totalRequests: 0,
    };
  }

  /**
   * Get cache key for a request
   */
  _getCacheKey(type, identifier) {
    return `${type}:${identifier}`;
  }

  /**
   * Check if cache entry is valid
   */
  _isCacheValid(entry) {
    if (!entry) return false;
    return Date.now() - entry.timestamp < this.cacheTTL;
  }

  /**
   * Get from cache
   */
  _getFromCache(key) {
    const entry = this.cache.get(key);
    if (this._isCacheValid(entry)) {
      this.stats.hits++;
      return entry.data;
    }
    // Remove expired entry
    if (entry) {
      this.cache.delete(key);
    }
    this.stats.misses++;
    return null;
  }

  /**
   * Set cache entry
   */
  _setCache(key, data) {
    this.cache.set(key, {
      data,
      timestamp: Date.now(),
    });
  }

  /**
   * Batch load images by menu item IDs
   * Returns a map of item ID to image URL
   */
  async loadImagesBatch(itemIds) {
    this.stats.totalRequests++;

    if (!itemIds || itemIds.length === 0) {
      return {};
    }

    // Create cache key from sorted IDs
    const sortedIds = [...itemIds].sort().join(',');
    const cacheKey = this._getCacheKey('batch', sortedIds);

    // Check cache first
    const cached = this._getFromCache(cacheKey);
    if (cached) {
      console.log(`✅ Cache hit for batch images: ${itemIds.length} items`);
      return cached;
    }

    try {
      console.log(`🔄 Loading batch images from database: ${itemIds.length} items`);
      const startTime = Date.now();

      // PERFORMANCE: Single batch query instead of N+1 queries
      // Only select id and image fields to minimize data transfer
      const { data, error } = await supabaseAdmin
        .from('menu_items')
        .select('id, image')
        .in('id', itemIds);

      if (error) {
        console.error('❌ Error loading batch images:', error);
        throw error;
      }

      // Build map from response
      const imageMap = {};
      for (const item of data || []) {
        if (item.id && item.image) {
          imageMap[item.id] = item.image;
        }
      }

      const responseTime = Date.now() - startTime;
      console.log(
        `✅ Batch loaded ${Object.keys(imageMap).length}/${itemIds.length} images in ${responseTime}ms`
      );

      // Cache the result
      this._setCache(cacheKey, imageMap);

      return imageMap;
    } catch (error) {
      console.error('❌ Error in loadImagesBatch:', error);
      throw error;
    }
  }

  /**
   * Load single image by menu item ID
   */
  async loadImageById(itemId) {
    this.stats.totalRequests++;

    if (!itemId) {
      return null;
    }

    const cacheKey = this._getCacheKey('single', itemId);

    // Check cache first
    const cached = this._getFromCache(cacheKey);
    if (cached !== null) {
      console.log(`✅ Cache hit for image: ${itemId}`);
      return cached;
    }

    try {
      console.log(`🔄 Loading image from database: ${itemId}`);
      const startTime = Date.now();

      const { data, error } = await supabaseAdmin
        .from('menu_items')
        .select('image')
        .eq('id', itemId)
        .single();

      if (error) {
        console.error(`❌ Error loading image for ${itemId}:`, error);
        return null;
      }

      const imageUrl = data?.image || null;
      const responseTime = Date.now() - startTime;

      if (imageUrl) {
        console.log(`✅ Loaded image for ${itemId} in ${responseTime}ms`);
        // Cache the result
        this._setCache(cacheKey, imageUrl);
      }

      return imageUrl;
    } catch (error) {
      console.error(`❌ Error in loadImageById for ${itemId}:`, error);
      return null;
    }
  }

  /**
   * Load drink images for a restaurant
   * Returns a map of item ID to image URL for drinks only
   */
  async loadDrinkImagesByRestaurant(restaurantId) {
    this.stats.totalRequests++;

    if (!restaurantId) {
      return {};
    }

    const cacheKey = this._getCacheKey('drinks', restaurantId);

    // Check cache first
    const cached = this._getFromCache(cacheKey);
    if (cached) {
      console.log(`✅ Cache hit for restaurant drinks: ${restaurantId}`);
      return cached;
    }

    try {
      console.log(`🔄 Loading drink images for restaurant: ${restaurantId}`);
      const startTime = Date.now();

      // Query drinks with optimized select fields
      const { data, error } = await supabaseAdmin
        .from('menu_items')
        .select('id, image, category')
        .eq('restaurant_id', restaurantId)
        .eq('is_available', true)
        .or('category.ilike.%drink%,category.ilike.%beverage%,category.ilike.%boisson%');

      if (error) {
        console.error(`❌ Error loading drink images for restaurant ${restaurantId}:`, error);
        throw error;
      }

      // Build map from response (only items with valid images)
      const imageMap = {};
      for (const item of data || []) {
        if (item.id && item.image) {
          imageMap[item.id] = item.image;
        }
      }

      const responseTime = Date.now() - startTime;
      console.log(
        `✅ Loaded ${Object.keys(imageMap).length} drink images for restaurant ${restaurantId} in ${responseTime}ms`
      );

      // Cache the result
      this._setCache(cacheKey, imageMap);

      return imageMap;
    } catch (error) {
      console.error(`❌ Error in loadDrinkImagesByRestaurant for ${restaurantId}:`, error);
      throw error;
    }
  }

  /**
   * Load all menu item images for a restaurant
   * Returns a map of item ID to image URL
   */
  async loadRestaurantMenuImages(restaurantId, options = {}) {
    this.stats.totalRequests++;

    if (!restaurantId) {
      return {};
    }

    const { availableOnly = true, limit = 50, offset = 0 } = options;
    const cacheKey = this._getCacheKey('restaurant', `${restaurantId}:${availableOnly}:${limit}:${offset}`);

    // Check cache first
    const cached = this._getFromCache(cacheKey);
    if (cached) {
      console.log(`✅ Cache hit for restaurant menu images: ${restaurantId}`);
      return cached;
    }

    try {
      console.log(`🔄 Loading menu images for restaurant: ${restaurantId}`);
      const startTime = Date.now();

      let query = supabaseAdmin
        .from('menu_items')
        .select('id, image')
        .eq('restaurant_id', restaurantId)
        .range(offset, offset + limit - 1);

      if (availableOnly) {
        query = query.eq('is_available', true);
      }

      const { data, error } = await query;

      if (error) {
        console.error(`❌ Error loading menu images for restaurant ${restaurantId}:`, error);
        throw error;
      }

      // Build map from response (only items with valid images)
      const imageMap = {};
      for (const item of data || []) {
        if (item.id && item.image) {
          imageMap[item.id] = item.image;
        }
      }

      const responseTime = Date.now() - startTime;
      console.log(
        `✅ Loaded ${Object.keys(imageMap).length} menu images for restaurant ${restaurantId} in ${responseTime}ms`
      );

      // Cache the result
      this._setCache(cacheKey, imageMap);

      return imageMap;
    } catch (error) {
      console.error(`❌ Error in loadRestaurantMenuImages for ${restaurantId}:`, error);
      throw error;
    }
  }

  /**
   * Clear cache (useful for testing or forced refresh)
   */
  clearCache() {
    this.cache.clear();
    console.log('🧹 Image cache cleared');
  }

  /**
   * Get cache statistics
   */
  getStats() {
    const hitRate = this.stats.totalRequests > 0
      ? ((this.stats.hits / this.stats.totalRequests) * 100).toFixed(2)
      : 0;

    return {
      ...this.stats,
      hitRate: `${hitRate}%`,
      cacheSize: this.cache.size,
    };
  }
}

// Export singleton instance
export default new ImageService();
