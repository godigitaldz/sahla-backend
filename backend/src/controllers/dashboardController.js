/**
 * Restaurant Dashboard Controller
 * Converted from lib/controllers/restaurant_dashboard_controller.dart
 */

import dashboardService from '../services/dashboardService.js';
import { successResponse } from '../utils/response.js';

/**
 * Get dashboard data for a restaurant
 * GET /api/dashboard/:restaurantId
 */
export const getDashboard = async (req, res, next) => {
  try {
    const { restaurantId } = req.params;

    if (!restaurantId) {
      return res.status(400).json({
        success: false,
        error: 'restaurant_id is required',
      });
    }

    const dashboardData = await dashboardService.getDashboardData(restaurantId);

    res.json(
      successResponse(dashboardData.toJSON(), 'Dashboard data retrieved successfully')
    );
  } catch (error) {
    next(error);
  }
};

/**
 * Get today's KPIs
 * GET /api/dashboard/:restaurantId/kpis
 */
export const getKPIs = async (req, res, next) => {
  try {
    const { restaurantId } = req.params;

    if (!restaurantId) {
      return res.status(400).json({
        success: false,
        error: 'restaurant_id is required',
      });
    }

    const kpis = await dashboardService.fetchTodayKPIs(restaurantId);

    res.json(successResponse(kpis, 'KPIs retrieved successfully'));
  } catch (error) {
    next(error);
  }
};

/**
 * Get weekly sales
 * GET /api/dashboard/:restaurantId/weekly-sales
 */
export const getWeeklySales = async (req, res, next) => {
  try {
    const { restaurantId } = req.params;

    if (!restaurantId) {
      return res.status(400).json({
        success: false,
        error: 'restaurant_id is required',
      });
    }

    const weeklySales = await dashboardService.fetchWeeklySales(restaurantId);

    res.json(
      successResponse(
        weeklySales.map((s) => s.toJSON()),
        'Weekly sales retrieved successfully'
      )
    );
  } catch (error) {
    next(error);
  }
};

/**
 * Get category performance
 * GET /api/dashboard/:restaurantId/category-performance
 */
export const getCategoryPerformance = async (req, res, next) => {
  try {
    const { restaurantId } = req.params;

    if (!restaurantId) {
      return res.status(400).json({
        success: false,
        error: 'restaurant_id is required',
      });
    }

    const categoryStats = await dashboardService.fetchCategoryPerformance(
      restaurantId
    );

    res.json(
      successResponse(
        categoryStats.map((c) => c.toJSON()),
        'Category performance retrieved successfully'
      )
    );
  } catch (error) {
    next(error);
  }
};

/**
 * Get recent activities
 * GET /api/dashboard/:restaurantId/activities
 */
export const getRecentActivities = async (req, res, next) => {
  try {
    const { restaurantId } = req.params;
    const limit = parseInt(req.query.limit) || 10;

    if (!restaurantId) {
      return res.status(400).json({
        success: false,
        error: 'restaurant_id is required',
      });
    }

    const activities = await dashboardService.fetchRecentActivities(
      restaurantId,
      limit
    );

    res.json(
      successResponse(
        activities.map((a) => a.toJSON()),
        'Recent activities retrieved successfully'
      )
    );
  } catch (error) {
    next(error);
  }
};

/**
 * Get restaurant statistics
 * GET /api/dashboard/:restaurantId/stats
 */
export const getRestaurantStats = async (req, res, next) => {
  try {
    const { restaurantId } = req.params;

    if (!restaurantId) {
      return res.status(400).json({
        success: false,
        error: 'restaurant_id is required',
      });
    }

    const stats = await dashboardService.fetchRestaurantStats(restaurantId);

    res.json(successResponse(stats.toJSON(), 'Restaurant stats retrieved successfully'));
  } catch (error) {
    next(error);
  }
};
