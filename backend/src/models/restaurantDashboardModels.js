/**
 * Restaurant Dashboard Models
 * Converted from lib/models/restaurant_dashboard_models.dart
 */

/**
 * Activity type enumeration
 */
export const ActivityType = {
  NEW_ORDER: 'newOrder',
  ORDER_DELIVERED: 'orderDelivered',
  ORDER_CANCELLED: 'orderCancelled',
  MENU_ITEM_ADDED: 'menuItemAdded',
  REVIEW_RECEIVED: 'reviewReceived',
  OTHER: 'other',
};

/**
 * Sales data point for charts
 * @typedef {Object} SalesPoint
 * @property {string} label - e.g., "Mon", "Tue", or date
 * @property {number} value - Sales value
 * @property {Date} date - Date of the sales point
 */
export class SalesPoint {
  constructor({ label, value, date }) {
    this.label = label;
    this.value = value;
    this.date = date instanceof Date ? date : new Date(date);
  }

  toJSON() {
    return {
      label: this.label,
      value: this.value,
      date: this.date.toISOString(),
    };
  }
}

/**
 * Category performance data
 * @typedef {Object} CategoryPerformance
 * @property {string} categoryName - Name of the category
 * @property {number} revenue - Revenue from this category
 * @property {number} orderCount - Number of orders in this category
 * @property {string} color - Hex color code (removed Flutter Color dependency)
 */
export class CategoryPerformance {
  constructor({ categoryName, revenue, orderCount, color }) {
    this.categoryName = categoryName;
    this.revenue = revenue;
    this.orderCount = orderCount;
    this.color = color; // Hex string instead of Flutter Color
  }

  toJSON() {
    return {
      categoryName: this.categoryName,
      revenue: this.revenue,
      orderCount: this.orderCount,
      color: this.color,
    };
  }
}

/**
 * Recent activity item
 * @typedef {Object} ActivityItem
 * @property {string} id - Activity ID
 * @property {string} title - Activity title
 * @property {string} subtitle - Activity subtitle
 * @property {string} [trailingText] - Optional trailing text
 * @property {string} icon - Icon name (removed Flutter IconData)
 * @property {string} iconColor - Hex color code
 * @property {Date} timestamp - When the activity occurred
 * @property {string} type - Activity type (from ActivityType enum)
 * @property {string} [orderStatus] - Order status for localization
 */
export class ActivityItem {
  constructor({
    id,
    title,
    subtitle,
    icon,
    iconColor,
    timestamp,
    type,
    trailingText,
    orderStatus,
  }) {
    this.id = id;
    this.title = title;
    this.subtitle = subtitle;
    this.trailingText = trailingText;
    this.icon = icon; // String instead of IconData
    this.iconColor = iconColor; // Hex string instead of Color
    this.timestamp = timestamp instanceof Date ? timestamp : new Date(timestamp);
    this.type = type;
    this.orderStatus = orderStatus;
  }

  toJSON() {
    return {
      id: this.id,
      title: this.title,
      subtitle: this.subtitle,
      trailingText: this.trailingText,
      icon: this.icon,
      iconColor: this.iconColor,
      timestamp: this.timestamp.toISOString(),
      type: this.type,
      orderStatus: this.orderStatus,
    };
  }
}

/**
 * Restaurant statistics
 * @typedef {Object} RestaurantStats
 * @property {number} totalMenuItems - Total menu items
 * @property {number} totalOrders - Total orders
 * @property {number} totalRevenue - Total revenue
 * @property {number} averageRating - Average rating
 * @property {number} totalReviews - Total reviews
 * @property {number} pendingOrders - Pending orders count
 * @property {number} completedOrdersToday - Completed orders today
 */
export class RestaurantStats {
  constructor({
    totalMenuItems = 0,
    totalOrders = 0,
    totalRevenue = 0.0,
    averageRating = 0.0,
    totalReviews = 0,
    pendingOrders = 0,
    completedOrdersToday = 0,
  } = {}) {
    this.totalMenuItems = totalMenuItems;
    this.totalOrders = totalOrders;
    this.totalRevenue = totalRevenue;
    this.averageRating = averageRating;
    this.totalReviews = totalReviews;
    this.pendingOrders = pendingOrders;
    this.completedOrdersToday = completedOrdersToday;
  }

  toJSON() {
    return {
      totalMenuItems: this.totalMenuItems,
      totalOrders: this.totalOrders,
      totalRevenue: this.totalRevenue,
      averageRating: this.averageRating,
      totalReviews: this.totalReviews,
      pendingOrders: this.pendingOrders,
      completedOrdersToday: this.completedOrdersToday,
    };
  }
}

/**
 * Dashboard state containing all KPIs, charts, and activity data
 * @typedef {Object} DashboardState
 * @property {number} ordersToday - Orders today
 * @property {number} totalRevenue - Total revenue
 * @property {number} avgOrderValue - Average order value
 * @property {number} activeDeliveries - Active deliveries count
 * @property {SalesPoint[]} weeklySales - Weekly sales data
 * @property {CategoryPerformance[]} categoryStats - Category performance stats
 * @property {ActivityItem[]} recentActivities - Recent activities
 * @property {RestaurantStats} [restaurantStats] - Restaurant statistics
 * @property {boolean} isLoading - Is loading
 * @property {boolean} isLoadingKPIs - Is loading KPIs
 * @property {boolean} isLoadingActivities - Is loading activities
 * @property {boolean} hasError - Has error
 * @property {string} [errorMessage] - Error message
 * @property {Date} lastUpdated - Last updated timestamp
 */
export class DashboardState {
  constructor({
    ordersToday = 0,
    totalRevenue = 0.0,
    avgOrderValue = 0.0,
    activeDeliveries = 0,
    weeklySales = [],
    categoryStats = [],
    recentActivities = [],
    restaurantStats = null,
    isLoading = false,
    isLoadingKPIs = false,
    isLoadingActivities = false,
    hasError = false,
    errorMessage = null,
    lastUpdated = null,
  } = {}) {
    this.ordersToday = ordersToday;
    this.totalRevenue = totalRevenue;
    this.avgOrderValue = avgOrderValue;
    this.activeDeliveries = activeDeliveries;
    this.weeklySales = weeklySales.map((s) =>
      s instanceof SalesPoint ? s : new SalesPoint(s)
    );
    this.categoryStats = categoryStats.map((c) =>
      c instanceof CategoryPerformance ? c : new CategoryPerformance(c)
    );
    this.recentActivities = recentActivities.map((a) =>
      a instanceof ActivityItem ? a : new ActivityItem(a)
    );
    this.restaurantStats =
      restaurantStats instanceof RestaurantStats
        ? restaurantStats
        : restaurantStats
        ? new RestaurantStats(restaurantStats)
        : null;
    this.isLoading = isLoading;
    this.isLoadingKPIs = isLoadingKPIs;
    this.isLoadingActivities = isLoadingActivities;
    this.hasError = hasError;
    this.errorMessage = errorMessage;
    this.lastUpdated = lastUpdated
      ? lastUpdated instanceof Date
        ? lastUpdated
        : new Date(lastUpdated)
      : new Date();
  }

  /**
   * Create a copy with updated fields (similar to Dart's copyWith)
   */
  copyWith(updates = {}) {
    return new DashboardState({
      ordersToday: updates.ordersToday ?? this.ordersToday,
      totalRevenue: updates.totalRevenue ?? this.totalRevenue,
      avgOrderValue: updates.avgOrderValue ?? this.avgOrderValue,
      activeDeliveries: updates.activeDeliveries ?? this.activeDeliveries,
      weeklySales: updates.weeklySales ?? this.weeklySales,
      categoryStats: updates.categoryStats ?? this.categoryStats,
      recentActivities: updates.recentActivities ?? this.recentActivities,
      restaurantStats: updates.restaurantStats ?? this.restaurantStats,
      isLoading: updates.isLoading ?? this.isLoading,
      isLoadingKPIs: updates.isLoadingKPIs ?? this.isLoadingKPIs,
      isLoadingActivities:
        updates.isLoadingActivities ?? this.isLoadingActivities,
      hasError: updates.hasError ?? this.hasError,
      errorMessage: updates.errorMessage ?? this.errorMessage,
      lastUpdated: updates.lastUpdated ?? this.lastUpdated,
    });
  }

  toJSON() {
    return {
      ordersToday: this.ordersToday,
      totalRevenue: this.totalRevenue,
      avgOrderValue: this.avgOrderValue,
      activeDeliveries: this.activeDeliveries,
      weeklySales: this.weeklySales.map((s) => s.toJSON()),
      categoryStats: this.categoryStats.map((c) => c.toJSON()),
      recentActivities: this.recentActivities.map((a) => a.toJSON()),
      restaurantStats: this.restaurantStats?.toJSON(),
      isLoading: this.isLoading,
      isLoadingKPIs: this.isLoadingKPIs,
      isLoadingActivities: this.isLoadingActivities,
      hasError: this.hasError,
      errorMessage: this.errorMessage,
      lastUpdated: this.lastUpdated.toISOString(),
    };
  }
}
