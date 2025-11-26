/**
 * Dashboard Routes
 * Converted from lib/controllers/restaurant_dashboard_controller.dart
 */

import express from 'express';
import {
  getDashboard,
  getKPIs,
  getWeeklySales,
  getCategoryPerformance,
  getRecentActivities,
  getRestaurantStats,
} from '../controllers/dashboardController.js';

const router = express.Router();

// Get complete dashboard data
router.get('/:restaurantId', getDashboard);

// Get today's KPIs
router.get('/:restaurantId/kpis', getKPIs);

// Get weekly sales
router.get('/:restaurantId/weekly-sales', getWeeklySales);

// Get category performance
router.get('/:restaurantId/category-performance', getCategoryPerformance);

// Get recent activities
router.get('/:restaurantId/activities', getRecentActivities);

// Get restaurant statistics
router.get('/:restaurantId/stats', getRestaurantStats);

export default router;
