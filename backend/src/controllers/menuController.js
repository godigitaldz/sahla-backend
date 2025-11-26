import menuService from '../services/menuService.js';
import { paginationMeta, successResponse } from '../utils/response.js';

export const getMenuItems = async (req, res, next) => {
  try {
    const { restaurant_id, category, available_only, limit = 50, offset = 0 } = req.query;

    const { data, count } = await menuService.getMenuItems({
      restaurantId: restaurant_id,
      category,
      availableOnly: available_only,
      limit: parseInt(limit),
      offset: parseInt(offset),
    });

    res.json(successResponse(
      data,
      'Menu items retrieved successfully',
      {
        restaurant_id,
        ...paginationMeta(count, Math.floor(offset / limit) + 1, parseInt(limit))
      }
    ));
  } catch (error) {
    next(error);
  }
};

export const getMenuItemById = async (req, res, next) => {
  try {
    const { id } = req.params;

    const data = await menuService.getMenuItemById(id);

    if (!data) {
      return res.status(404).json({
        success: false,
        error: 'Menu item not found',
      });
    }

    res.json(successResponse(data, 'Menu item retrieved successfully'));
  } catch (error) {
    next(error);
  }
};
