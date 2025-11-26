/**
 * Payments Controller
 * Converted from lib/controllers/payments_controller.dart
 */

import paymentsService from '../services/paymentsService.js';
import { successResponse } from '../utils/response.js';

/**
 * Get pending payments for a restaurant
 * GET /api/payments/:restaurantId/pending
 */
export const getPendingPayments = async (req, res, next) => {
  try {
    const { restaurantId } = req.params;

    if (!restaurantId) {
      return res.status(400).json({
        success: false,
        error: 'restaurant_id is required',
      });
    }

    const pendingPayments = await paymentsService.fetchPendingPayments(
      restaurantId
    );

    const pendingCount = pendingPayments.length;
    const pendingTotal = pendingPayments.reduce((sum, order) => {
      return sum + (order.net ?? order.total_amount ?? 0);
    }, 0);

    res.json(
      successResponse(
        {
          pendingPayments,
          pendingCount,
          pendingTotal,
        },
        'Pending payments retrieved successfully'
      )
    );
  } catch (error) {
    next(error);
  }
};

/**
 * Mark payment as collected
 * POST /api/payments/:orderId/collect
 */
export const markAsCollected = async (req, res, next) => {
  try {
    const { orderId } = req.params;

    if (!orderId) {
      return res.status(400).json({
        success: false,
        error: 'order_id is required',
      });
    }

    const success = await paymentsService.markPaymentAsCollected(orderId);

    if (!success) {
      return res.status(500).json({
        success: false,
        error: 'Failed to mark payment as collected',
      });
    }

    res.json(successResponse(null, 'Payment marked as collected successfully'));
  } catch (error) {
    next(error);
  }
};

/**
 * Get pending payments count
 * GET /api/payments/:restaurantId/count
 */
export const getPendingCount = async (req, res, next) => {
  try {
    const { restaurantId } = req.params;

    if (!restaurantId) {
      return res.status(400).json({
        success: false,
        error: 'restaurant_id is required',
      });
    }

    const count = await paymentsService.getPendingPaymentsCount(restaurantId);

    res.json(successResponse({ count }, 'Pending payments count retrieved'));
  } catch (error) {
    next(error);
  }
};

/**
 * Get pending payments total
 * GET /api/payments/:restaurantId/total
 */
export const getPendingTotal = async (req, res, next) => {
  try {
    const { restaurantId } = req.params;

    if (!restaurantId) {
      return res.status(400).json({
        success: false,
        error: 'restaurant_id is required',
      });
    }

    const total = await paymentsService.getPendingPaymentsTotal(restaurantId);

    res.json(successResponse({ total }, 'Pending payments total retrieved'));
  } catch (error) {
    next(error);
  }
};
