import imageService from '../services/imageService.js';
import { successResponse } from '../utils/response.js';

/**
 * Batch load images by menu item IDs
 * POST /api/images/batch
 * Body: { itemIds: string[] }
 */
export const loadImagesBatch = async (req, res, next) => {
  try {
    const { itemIds } = req.body;

    if (!itemIds || !Array.isArray(itemIds) || itemIds.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'itemIds array is required and must not be empty',
      });
    }

    // Limit batch size for performance
    if (itemIds.length > 100) {
      return res.status(400).json({
        success: false,
        error: 'Maximum 100 item IDs allowed per batch request',
      });
    }

    const imageMap = await imageService.loadImagesBatch(itemIds);

    res.json(successResponse(imageMap, 'Images loaded successfully', {
      count: Object.keys(imageMap).length,
      requested: itemIds.length,
    }));
  } catch (error) {
    next(error);
  }
};

/**
 * Load single image by menu item ID
 * GET /api/images/:id
 */
export const loadImageById = async (req, res, next) => {
  try {
    const { id } = req.params;

    if (!id) {
      return res.status(400).json({
        success: false,
        error: 'Menu item ID is required',
      });
    }

    const imageUrl = await imageService.loadImageById(id);

    if (!imageUrl) {
      return res.status(404).json({
        success: false,
        error: 'Image not found for this menu item',
      });
    }

    res.json(successResponse({ id, image: imageUrl }, 'Image loaded successfully'));
  } catch (error) {
    next(error);
  }
};

/**
 * Load drink images for a restaurant
 * GET /api/images/drinks/:restaurantId
 */
export const loadDrinkImagesByRestaurant = async (req, res, next) => {
  try {
    const { restaurantId } = req.params;

    if (!restaurantId) {
      return res.status(400).json({
        success: false,
        error: 'Restaurant ID is required',
      });
    }

    const imageMap = await imageService.loadDrinkImagesByRestaurant(restaurantId);

    res.json(successResponse(imageMap, 'Drink images loaded successfully', {
      count: Object.keys(imageMap).length,
    }));
  } catch (error) {
    next(error);
  }
};

/**
 * Load all menu item images for a restaurant
 * GET /api/images/restaurant/:restaurantId
 * Query params: availableOnly (boolean), limit (number), offset (number)
 */
export const loadRestaurantMenuImages = async (req, res, next) => {
  try {
    const { restaurantId } = req.params;
    const { availableOnly = 'true', limit = '50', offset = '0' } = req.query;

    if (!restaurantId) {
      return res.status(400).json({
        success: false,
        error: 'Restaurant ID is required',
      });
    }

    const options = {
      availableOnly: availableOnly === 'true',
      limit: parseInt(limit, 10),
      offset: parseInt(offset, 10),
    };

    const imageMap = await imageService.loadRestaurantMenuImages(restaurantId, options);

    res.json(successResponse(imageMap, 'Restaurant menu images loaded successfully', {
      count: Object.keys(imageMap).length,
      ...options,
    }));
  } catch (error) {
    next(error);
  }
};

/**
 * Get cache statistics
 * GET /api/images/stats
 */
export const getImageStats = async (req, res, next) => {
  try {
    const stats = imageService.getStats();
    res.json(successResponse(stats, 'Image service statistics retrieved successfully'));
  } catch (error) {
    next(error);
  }
};

/**
 * Clear image cache
 * DELETE /api/images/cache
 */
export const clearImageCache = async (req, res, next) => {
  try {
    imageService.clearCache();
    res.json(successResponse(null, 'Image cache cleared successfully'));
  } catch (error) {
    next(error);
  }
};
