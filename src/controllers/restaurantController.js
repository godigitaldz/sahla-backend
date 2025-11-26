import restaurantService from '../services/restaurantService.js';
import { paginationMeta, successResponse } from '../utils/response.js';

export const getRestaurants = async (req, res, next) => {
  try {
    const { category, cuisine, minRating, isFeatured, limit = 20, offset = 0 } = req.query;

    const { data, count } = await restaurantService.getRestaurants({
      category,
      cuisine,
      minRating,
      isFeatured,
      limit: parseInt(limit),
      offset: parseInt(offset),
    });

    res.json(successResponse(
      data,
      'Restaurants retrieved successfully',
      paginationMeta(count, Math.floor(offset / limit) + 1, parseInt(limit))
    ));
  } catch (error) {
    next(error);
  }
};

export const searchRestaurants = async (req, res, next) => {
  try {
    const { q, query, limit = 20 } = req.query;
    const searchQuery = q || query;

    if (!searchQuery) {
      return res.status(400).json({
        success: false,
        error: 'Search query is required',
      });
    }

    const data = await restaurantService.searchRestaurants({
      query: searchQuery,
      limit: parseInt(limit),
    });

    res.json(successResponse(data, 'Search completed successfully', {
      query: searchQuery,
      count: data.length,
    }));
  } catch (error) {
    next(error);
  }
};

export const getRestaurantById = async (req, res, next) => {
  try {
    const { id } = req.params;

    const data = await restaurantService.getRestaurantById(id);

    if (!data) {
      return res.status(404).json({
        success: false,
        error: 'Restaurant not found',
      });
    }

    res.json(successResponse(data, 'Restaurant retrieved successfully'));
  } catch (error) {
    next(error);
  }
};
