import promoCodeService from '../services/promoCodeService.js';
import { paginationMeta, successResponse } from '../utils/response.js';

export const getPromoCodes = async (req, res, next) => {
  try {
    const { restaurant_id, limit = 20, offset = 0 } = req.query;

    const { data, count } = await promoCodeService.getPromoCodes({
      restaurantId: restaurant_id,
      limit: parseInt(limit),
      offset: parseInt(offset),
    });

    res.json(successResponse(
      data,
      'Promo codes retrieved successfully',
      paginationMeta(count, Math.floor(offset / limit) + 1, parseInt(limit))
    ));
  } catch (error) {
    next(error);
  }
};

export const validatePromoCode = async (req, res, next) => {
  try {
    const { code, restaurant_id } = req.body;

    if (!code) {
      return res.status(400).json({
        success: false,
        error: 'Promo code is required',
      });
    }

    const data = await promoCodeService.validatePromoCode(code, restaurant_id);

    res.json(successResponse(data, 'Promo code is valid'));
  } catch (error) {
    next(error);
  }
};
