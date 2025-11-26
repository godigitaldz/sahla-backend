import cuisineService from '../services/cuisineService.js';
import { successResponse } from '../utils/response.js';

export const getCuisines = async (req, res, next) => {
  try {
    const data = await cuisineService.getCuisines();

    res.json(successResponse(data, 'Cuisines retrieved successfully', {
      count: data.length,
    }));
  } catch (error) {
    next(error);
  }
};

export const getCuisineById = async (req, res, next) => {
  try {
    const { id } = req.params;

    const data = await cuisineService.getCuisineById(id);

    if (!data) {
      return res.status(404).json({
        success: false,
        error: 'Cuisine not found',
      });
    }

    res.json(successResponse(data, 'Cuisine retrieved successfully'));
  } catch (error) {
    next(error);
  }
};
