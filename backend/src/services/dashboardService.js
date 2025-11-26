/**
 * Restaurant Dashboard Service
 * Converted from lib/controllers/restaurant_dashboard_controller.dart
 * Handles all dashboard data fetching and processing
 */

import { supabase } from '../config/supabase.js';
import {
  DashboardState,
  SalesPoint,
  CategoryPerformance,
  ActivityItem,
  RestaurantStats,
  ActivityType,
} from '../models/restaurantDashboardModels.js';

export class DashboardService {
  /**
   * Fetch today's KPIs
   * @param {string} restaurantId - Restaurant ID
   * @returns {Promise<Object>} KPIs object
   */
  async fetchTodayKPIs(restaurantId) {
    try {
      const now = new Date();
      const startOfDay = new Date(
        now.getFullYear(),
        now.getMonth(),
        now.getDate()
      );
      const endOfDay = new Date(startOfDay);
      endOfDay.setDate(endOfDay.getDate() + 1);

      // Fetch pending orders count
      const { data: pendingOrders, error: pendingError } = await supabase
        .from('orders')
        .select('id, status')
        .eq('restaurant_id', restaurantId)
        .eq('status', 'pending');

      if (pendingError) throw pendingError;

      const availableOrders = pendingOrders?.length || 0;

      // Fetch today's orders for revenue calculation
      const { data: orders, error: ordersError } = await supabase
        .from('orders')
        .select(
          'id, net, total_amount, delivery_fee, service_fee, tax_amount, status, created_at'
        )
        .eq('restaurant_id', restaurantId)
        .gte('created_at', startOfDay.toISOString())
        .lt('created_at', endOfDay.toISOString());

      if (ordersError) throw ordersError;

      const ordersList = orders || [];

      // Calculate KPIs
      const ordersToday = ordersList.length;

      // Calculate revenue using net amount
      const totalRevenue = ordersList.reduce((sum, order) => {
        const net = order.net;
        if (net != null) {
          return sum + (typeof net === 'number' ? net : 0);
        }

        // Calculate net if not available
        const totalAmount = order.total_amount || 0;
        const deliveryFee = order.delivery_fee || 0;
        const serviceFee = order.service_fee || 0;
        const taxAmount = order.tax_amount || 0;

        return sum + (totalAmount - deliveryFee - serviceFee - taxAmount);
      }, 0);

      const avgOrderValue = ordersToday > 0 ? totalRevenue / ordersToday : 0;

      // Count active deliveries
      const { data: activeDeliveriesData, error: activeError } = await supabase
        .from('orders')
        .select('id, status')
        .eq('restaurant_id', restaurantId)
        .in('status', ['confirmed', 'preparing', 'ready', 'picked_up']);

      if (activeError) throw activeError;

      const activeDeliveries = activeDeliveriesData?.length || 0;

      return {
        ordersToday: availableOrders,
        totalRevenue,
        avgOrderValue,
        activeDeliveries,
      };
    } catch (error) {
      console.error('❌ Error fetching today KPIs:', error);
      return {
        ordersToday: 0,
        totalRevenue: 0.0,
        avgOrderValue: 0.0,
        activeDeliveries: 0,
      };
    }
  }

  /**
   * Fetch weekly sales data for chart
   * @param {string} restaurantId - Restaurant ID
   * @returns {Promise<SalesPoint[]>} Weekly sales points
   */
  async fetchWeeklySales(restaurantId) {
    try {
      const now = new Date();
      const weekAgo = new Date(now);
      weekAgo.setDate(weekAgo.getDate() - 7);

      const { data: orders, error } = await supabase
        .from('orders')
        .select(
          'net, total_amount, delivery_fee, service_fee, tax_amount, created_at, status, collected'
        )
        .eq('restaurant_id', restaurantId)
        .eq('status', 'delivered')
        .gte('created_at', weekAgo.toISOString())
        .order('created_at', { ascending: true });

      if (error) throw error;

      const ordersList = orders || [];

      if (ordersList.length === 0) {
        return [];
      }

      // Group by day
      const dailySales = {};
      const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

      // Initialize all days to 0
      for (let i = 0; i < 7; i++) {
        const date = new Date(weekAgo);
        date.setDate(date.getDate() + i);
        const dayIndex = (date.getDay() + 6) % 7; // Convert to Mon-Sun (0-6)
        dailySales[dayLabels[dayIndex]] = 0.0;
      }

      // Sum sales by day using net amount
      for (const order of ordersList) {
        try {
          const status = order.status;
          if (status !== 'delivered') {
            continue;
          }

          const createdAt = new Date(order.created_at);
          const dayIndex = (createdAt.getDay() + 6) % 7; // Convert to Mon-Sun
          const dayLabel = dayLabels[dayIndex];

          // Use net amount
          let netAmount = 0.0;
          const net = order.net;
          if (net != null) {
            netAmount = typeof net === 'number' ? net : 0;
          } else {
            // Calculate net if not available
            const totalAmount = order.total_amount || 0;
            const deliveryFee = order.delivery_fee || 0;
            const serviceFee = order.service_fee || 0;
            const taxAmount = order.tax_amount || 0;

            netAmount = totalAmount - deliveryFee - serviceFee - taxAmount;
          }

          dailySales[dayLabel] = (dailySales[dayLabel] || 0) + netAmount;
        } catch (e) {
          console.error('Error parsing order date:', e);
        }
      }

      // Convert to SalesPoint list
      const salesPoints = Object.entries(dailySales).map(([label, value]) => {
        const dayIndex = dayLabels.indexOf(label);
        const date = new Date(weekAgo);
        date.setDate(date.getDate() + dayIndex);
        return new SalesPoint({ label, value, date });
      });

      // Sort by date
      salesPoints.sort((a, b) => a.date - b.date);

      return salesPoints;
    } catch (error) {
      console.error('❌ Error fetching weekly sales:', error);
      return [];
    }
  }

  /**
   * Fetch category performance data
   * @param {string} restaurantId - Restaurant ID
   * @returns {Promise<CategoryPerformance[]>} Category performance list
   */
  async fetchCategoryPerformance(restaurantId) {
    try {
      const { data: items, error } = await supabase
        .from('order_items')
        .select(
          `
          quantity,
          price,
          menu_items!inner(
            category,
            restaurant_id
          )
        `
        )
        .eq('menu_items.restaurant_id', restaurantId)
        .limit(1000);

      if (error) throw error;

      const itemsList = items || [];

      // Group by category
      const categoryData = {};

      for (const item of itemsList) {
        try {
          const menuItem = item.menu_items;
          if (!menuItem) continue;

          const category = menuItem.category || 'Other';
          const price = item.price || 0;
          const quantity = item.quantity || 1;
          const revenue = price * quantity;

          if (!categoryData[category]) {
            categoryData[category] = {
              revenue: 0.0,
              orderCount: 0,
            };
          }

          categoryData[category].revenue += revenue;
          categoryData[category].orderCount += 1;
        } catch (e) {
          console.error('Error processing order item:', e);
        }
      }

      // Convert to CategoryPerformance list
      const colors = [
        '#FB8C00', // Orange
        '#1976D2', // Blue
        '#388E3C', // Green
        '#7B1FA2', // Purple
        '#D32F2F', // Red
        '#00796B', // Teal
      ];

      let colorIndex = 0;
      const performances = Object.entries(categoryData).map(([key, value]) => {
        const color = colors[colorIndex % colors.length];
        colorIndex++;

        return new CategoryPerformance({
          categoryName: key,
          revenue: value.revenue,
          orderCount: value.orderCount,
          color: color,
        });
      });

      // Sort by revenue descending
      performances.sort((a, b) => b.revenue - a.revenue);

      // Return top 6 categories
      return performances.slice(0, 6);
    } catch (error) {
      console.error('❌ Error fetching category performance:', error);
      return [];
    }
  }

  /**
   * Fetch recent activities
   * @param {string} restaurantId - Restaurant ID
   * @param {number} limit - Limit of activities
   * @returns {Promise<ActivityItem[]>} Recent activities
   */
  async fetchRecentActivities(restaurantId, limit = 10) {
    try {
      const { data: orders, error } = await supabase
        .from('orders')
        .select('*')
        .eq('restaurant_id', restaurantId)
        .order('created_at', { ascending: false })
        .limit(limit);

      if (error) throw error;

      const ordersList = orders || [];
      const activities = [];

      for (const order of ordersList) {
        const status = order.status;
        let icon, iconColor, type, title, subtitle;

        switch (status) {
          case 'pending':
            icon = 'receipt_long';
            iconColor = '#FB8C00';
            type = ActivityType.NEW_ORDER;
            title = `New Order #${order.order_number || order.id.slice(0, 8)}`;
            subtitle = 'Waiting for confirmation';
            break;
          case 'delivered':
            icon = 'check_circle';
            iconColor = '#388E3C';
            type = ActivityType.ORDER_DELIVERED;
            title = `Order #${order.order_number || order.id.slice(0, 8)} Delivered`;
            subtitle = 'Completed successfully';
            break;
          case 'collected':
            icon = 'account_balance_wallet';
            iconColor = '#2E7D32';
            type = ActivityType.ORDER_DELIVERED;
            title = `Order #${order.order_number || order.id.slice(0, 8)} Payment Collected`;
            subtitle = 'Payment confirmed and recorded';
            break;
          case 'cancelled':
            icon = 'cancel';
            iconColor = '#D32F2F';
            type = ActivityType.ORDER_CANCELLED;
            title = `Order #${order.order_number || order.id.slice(0, 8)} Cancelled`;
            subtitle = 'Order was cancelled';
            break;
          case 'confirmed':
          case 'preparing':
          case 'ready':
          case 'picked_up':
            icon = 'info';
            iconColor = '#1976D2';
            type = ActivityType.OTHER;
            title = `Order #${order.order_number || order.id.slice(0, 8)}`;
            subtitle = status;
            break;
          default:
            icon = 'info';
            iconColor = '#757575';
            type = ActivityType.OTHER;
            title = `Order #${order.order_number || order.id.slice(0, 8)}`;
            subtitle = status || 'Unknown';
        }

        activities.push(
          new ActivityItem({
            id: order.id,
            title,
            subtitle,
            trailingText: `${(order.total_amount || 0).toFixed(0)} Da`,
            icon,
            iconColor,
            timestamp: new Date(order.created_at),
            type,
            orderStatus: status,
          })
        );
      }

      return activities;
    } catch (error) {
      console.error('❌ Error fetching recent activities:', error);
      return [];
    }
  }

  /**
   * Fetch restaurant statistics
   * @param {string} restaurantId - Restaurant ID
   * @param {number} totalRevenue - Total revenue (from KPIs)
   * @param {number} ordersToday - Orders today (from KPIs)
   * @returns {Promise<RestaurantStats>} Restaurant statistics
   */
  async fetchRestaurantStats(restaurantId, totalRevenue = 0, ordersToday = 0) {
    try {
      // Fetch menu items count
      const { count: totalMenuItems, error: menuError } = await supabase
        .from('menu_items')
        .select('id', { count: 'exact', head: true })
        .eq('restaurant_id', restaurantId);

      if (menuError) throw menuError;

      // Fetch restaurant details for rating
      const { data: restaurant, error: restaurantError } = await supabase
        .from('restaurants')
        .select('rating, review_count')
        .eq('id', restaurantId)
        .single();

      if (restaurantError) throw restaurantError;

      // Fetch total orders
      const { data: orders, error: ordersError } = await supabase
        .from('orders')
        .select('id, status')
        .eq('restaurant_id', restaurantId);

      if (ordersError) throw ordersError;

      const ordersList = orders || [];
      const totalOrders = ordersList.length;

      // Count pending orders
      const pendingOrders = ordersList.filter((order) => {
        const status = order.status;
        return (
          status === 'pending' ||
          status === 'confirmed' ||
          status === 'preparing'
        );
      }).length;

      return new RestaurantStats({
        totalMenuItems: totalMenuItems || 0,
        totalOrders,
        totalRevenue,
        averageRating: restaurant?.rating || 0.0,
        totalReviews: restaurant?.review_count || 0,
        pendingOrders,
        completedOrdersToday: ordersToday,
      });
    } catch (error) {
      console.error('❌ Error fetching restaurant stats:', error);
      return new RestaurantStats();
    }
  }

  /**
   * Get complete dashboard data
   * @param {string} restaurantId - Restaurant ID
   * @returns {Promise<DashboardState>} Complete dashboard state
   */
  async getDashboardData(restaurantId) {
    try {
      // Load KPIs first
      const kpis = await this.fetchTodayKPIs(restaurantId);
      const weeklySales = await this.fetchWeeklySales(restaurantId);
      const categoryStats = await this.fetchCategoryPerformance(restaurantId);
      const restaurantStats = await this.fetchRestaurantStats(
        restaurantId,
        kpis.totalRevenue,
        kpis.ordersToday
      );

      // Load activities
      const recentActivities = await this.fetchRecentActivities(restaurantId);

      return new DashboardState({
        ordersToday: kpis.ordersToday,
        totalRevenue: kpis.totalRevenue,
        avgOrderValue: kpis.avgOrderValue,
        activeDeliveries: kpis.activeDeliveries,
        weeklySales,
        categoryStats,
        recentActivities,
        restaurantStats,
        isLoading: false,
        isLoadingKPIs: false,
        isLoadingActivities: false,
        hasError: false,
        lastUpdated: new Date(),
      });
    } catch (error) {
      console.error('❌ Error getting dashboard data:', error);
      return new DashboardState({
        hasError: true,
        errorMessage: error.message,
        isLoading: false,
        isLoadingKPIs: false,
        isLoadingActivities: false,
      });
    }
  }
}

export default new DashboardService();
