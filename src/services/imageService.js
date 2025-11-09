import { supabase } from '../config/supabase.js';

/**
 * Image Service for proxying images from Supabase storage
 * Handles category, menu item, restaurant, and LTO images
 */
export class ImageService {
  /**
   * Get category image from Supabase storage
   * @param {string} categoryName - Category name
   * @param {string} locale - Locale (en, fr, ar)
   * @returns {Promise<Buffer>} Image buffer
   */
  async getCategoryImage(categoryName, locale = 'en') {
    // Normalize category name
    const normalized = this._normalizeCategoryName(categoryName);

    // Determine suffix by locale
    let suffix = '_ang';
    if (locale.startsWith('fr')) {
      suffix = '_fr';
    } else if (locale.startsWith('ar')) {
      suffix = '_ar';
    }

    const fileName = `${normalized}${suffix}.png`;

    // Try localized first, then fallback to universal
    let { data, error } = await supabase.storage
      .from('categories')
      .download(fileName);

    if (error) {
      // Fallback to universal (no suffix)
      const universalFileName = `${normalized}.png`;
      const result = await supabase.storage
        .from('categories')
        .download(universalFileName);
      data = result.data;
      error = result.error;
    }

    if (error || !data) {
      throw new Error(`Category image not found: ${categoryName}`);
    }

    return Buffer.from(await data.arrayBuffer());
  }

  /**
   * Get menu item image from Supabase storage
   * @param {string} imagePath - Image path or URL
   * @returns {Promise<Buffer>} Image buffer
   */
  async getMenuItemImage(imagePath) {
    // If it's already a full URL, try to extract the path first
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      try {
        // Extract path from Supabase URL
        const url = new URL(imagePath);
        const pathParts = url.pathname.split('/').filter(part => part.length > 0);
        
        // Look for bucket name in path
        const bucketNames = ['menu-item-images', 'menu-items', 'menu_item_images'];
        let bucketIndex = -1;
        let bucket = null;
        
        for (const bucketName of bucketNames) {
          bucketIndex = pathParts.findIndex(part => part === bucketName);
          if (bucketIndex !== -1) {
            bucket = bucketName;
            break;
          }
        }

        if (bucketIndex !== -1 && bucket) {
          // Extract file path after bucket name
          const filePath = pathParts.slice(bucketIndex + 1).join('/');
          
          if (filePath) {
            const { data, error } = await supabase.storage
              .from(bucket)
              .download(filePath);

            if (!error && data) {
              return Buffer.from(await data.arrayBuffer());
            }
          }
        }
        
        // If extraction failed, try to proxy the URL directly
        // This handles cases where the URL is from Supabase CDN or external sources
        return await this.getImageFromUrl(imagePath);
      } catch (e) {
        // If URL parsing fails, try to proxy the URL directly
        try {
          return await this.getImageFromUrl(imagePath);
        } catch (proxyError) {
          throw new Error(`Failed to fetch image from URL: ${proxyError.message}`);
        }
      }
    }

    // If it's a storage path (not a full URL), try common bucket names
    const buckets = ['menu-item-images', 'menu-items', 'menu_item_images'];
    for (const bucket of buckets) {
      try {
        const { data, error } = await supabase.storage
          .from(bucket)
          .download(imagePath);

        if (!error && data) {
          return Buffer.from(await data.arrayBuffer());
        }
      } catch (e) {
        // Continue to next bucket
      }
    }

    throw new Error(`Menu item image not found: ${imagePath}`);
  }

  /**
   * Get restaurant logo or cover image
   * @param {string} restaurantId - Restaurant ID
   * @param {string} type - 'logo' or 'cover'
   * @returns {Promise<Buffer>} Image buffer
   */
  async getRestaurantImage(restaurantId, type = 'logo') {
    const buckets = ['restaurants', 'restaurant-images', 'restaurant_images'];
    const fileName = type === 'logo'
      ? `${restaurantId}/logo.png`
      : `${restaurantId}/cover.png`;

    for (const bucket of buckets) {
      try {
        const { data, error } = await supabase.storage
          .from(bucket)
          .download(fileName);

        if (!error && data) {
          return Buffer.from(await data.arrayBuffer());
        }
      } catch (e) {
        // Continue to next bucket
      }
    }

    // Try alternative naming
    const altFileName = type === 'logo'
      ? `logo_${restaurantId}.png`
      : `cover_${restaurantId}.png`;

    for (const bucket of buckets) {
      try {
        const { data, error } = await supabase.storage
          .from(bucket)
          .download(altFileName);

        if (!error && data) {
          return Buffer.from(await data.arrayBuffer());
        }
      } catch (e) {
        // Continue
      }
    }

    throw new Error(`Restaurant ${type} image not found: ${restaurantId}`);
  }

  /**
   * Get image from URL (for menu items that have full URLs)
   * @param {string} imageUrl - Full image URL
   * @returns {Promise<Buffer>} Image buffer
   */
  async getImageFromUrl(imageUrl) {
    try {
      const response = await fetch(imageUrl);
      if (!response.ok) {
        throw new Error(`Failed to fetch image: ${response.statusText}`);
      }
      const arrayBuffer = await response.arrayBuffer();
      return Buffer.from(arrayBuffer);
    } catch (error) {
      throw new Error(`Failed to fetch image from URL: ${error.message}`);
    }
  }

  /**
   * Normalize category name for storage lookup
   * @private
   */
  _normalizeCategoryName(category) {
    // Apply custom character mapping: e=é, é=e, space=_
    return category
      .toLowerCase()
      .replace(/é/g, 'e')
      .replace(/è/g, 'e')
      .replace(/ê/g, 'e')
      .replace(/ë/g, 'e')
      .replace(/à/g, 'a')
      .replace(/á/g, 'a')
      .replace(/â/g, 'a')
      .replace(/ä/g, 'a')
      .replace(/ /g, '_')
      .trim();
  }
}

export default new ImageService();
