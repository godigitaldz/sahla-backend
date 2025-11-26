import 'dart:math';

import '../models/delivery_man_request.dart';
import '../models/restaurant_request.dart';

class AdminAnalyticsService {
  /// Calculate comprehensive statistics for admin dashboard
  static Map<String, dynamic> calculateStatistics({
    required List<RestaurantRequest> restaurantRequests,
    required List<DeliveryManRequest> deliveryManRequests,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    return {
      // Restaurant statistics
      'restaurant_total': restaurantRequests.length,
      'restaurant_pending': restaurantRequests.where((r) => r.isPending).length,
      'restaurant_approved':
          restaurantRequests.where((r) => r.isApproved).length,
      'restaurant_rejected':
          restaurantRequests.where((r) => r.isRejected).length,

      // Delivery man statistics
      'delivery_total': deliveryManRequests.length,
      'delivery_pending': deliveryManRequests.where((r) => r.isPending).length,
      'delivery_approved':
          deliveryManRequests.where((r) => r.isApproved).length,
      'delivery_rejected':
          deliveryManRequests.where((r) => r.isRejected).length,

      // Time-based statistics
      'requests_today':
          _countRequestsToday(restaurantRequests, deliveryManRequests, today),
      'requests_this_week': _countRequestsThisWeek(
          restaurantRequests, deliveryManRequests, weekStart),
      'requests_this_month': _countRequestsThisMonth(
          restaurantRequests, deliveryManRequests, monthStart),

      // Performance metrics
      'avg_processing_time': _calculateAverageProcessingTime(
          restaurantRequests, deliveryManRequests),
      'approval_rate':
          _calculateApprovalRate(restaurantRequests, deliveryManRequests),
      'rejection_rate':
          _calculateRejectionRate(restaurantRequests, deliveryManRequests),

      // Geographic distribution
      'wilaya_distribution': _calculateWilayaDistribution(restaurantRequests),
      'top_wilayas': _getTopWilayas(restaurantRequests),

      // Trend analysis
      'daily_trends':
          _calculateDailyTrends(restaurantRequests, deliveryManRequests),
      'weekly_trends':
          _calculateWeeklyTrends(restaurantRequests, deliveryManRequests),

      // Processing efficiency
      'pending_duration': _calculateAveragePendingDuration(
          restaurantRequests, deliveryManRequests),
      'peak_hours':
          _calculatePeakHours(restaurantRequests, deliveryManRequests),
    };
  }

  /// Calculate approval rate percentage
  static double _calculateApprovalRate(
      List<RestaurantRequest> restaurantRequests,
      List<DeliveryManRequest> deliveryManRequests) {
    final totalProcessed =
        restaurantRequests.where((r) => !r.isPending).length +
            deliveryManRequests.where((r) => !r.isPending).length;

    if (totalProcessed == 0) return 0.0;

    final approved = restaurantRequests.where((r) => r.isApproved).length +
        deliveryManRequests.where((r) => r.isApproved).length;

    return (approved / totalProcessed) * 100;
  }

  /// Calculate rejection rate percentage
  static double _calculateRejectionRate(
      List<RestaurantRequest> restaurantRequests,
      List<DeliveryManRequest> deliveryManRequests) {
    final totalProcessed =
        restaurantRequests.where((r) => !r.isPending).length +
            deliveryManRequests.where((r) => !r.isPending).length;

    if (totalProcessed == 0) return 0.0;

    final rejected = restaurantRequests.where((r) => r.isRejected).length +
        deliveryManRequests.where((r) => r.isRejected).length;

    return (rejected / totalProcessed) * 100;
  }

  /// Calculate average processing time
  static String _calculateAverageProcessingTime(
      List<RestaurantRequest> restaurantRequests,
      List<DeliveryManRequest> deliveryManRequests) {
    final processedRequests = <Map<String, dynamic>>[];

    // Add restaurant requests
    for (final request in restaurantRequests.where((r) => !r.isPending)) {
      if (request.reviewedAt != null) {
        final processingTime =
            request.reviewedAt!.difference(request.createdAt);
        processedRequests.add({
          'processing_time': processingTime,
          'type': 'restaurant',
        });
      }
    }

    // Add delivery man requests
    for (final request in deliveryManRequests.where((r) => !r.isPending)) {
      if (request.reviewedAt != null) {
        final processingTime =
            request.reviewedAt!.difference(request.createdAt);
        processedRequests.add({
          'processing_time': processingTime,
          'type': 'delivery',
        });
      }
    }

    if (processedRequests.isEmpty) return 'N/A';

    final totalMinutes = processedRequests.fold<int>(
        0, (sum, req) => sum + (req['processing_time'] as Duration).inMinutes);
    final avgMinutes = totalMinutes / processedRequests.length;

    if (avgMinutes < 60) {
      return '${avgMinutes.round()} minutes';
    } else if (avgMinutes < 1440) {
      // 24 hours
      return '${(avgMinutes / 60).toStringAsFixed(1)} hours';
    } else {
      return '${(avgMinutes / 1440).toStringAsFixed(1)} days';
    }
  }

  /// Count requests created today
  static int _countRequestsToday(List<RestaurantRequest> restaurantRequests,
      List<DeliveryManRequest> deliveryManRequests, DateTime today) {
    final todayEnd = today.add(const Duration(days: 1));

    final restaurantToday = restaurantRequests
        .where(
            (r) => r.createdAt.isAfter(today) && r.createdAt.isBefore(todayEnd))
        .length;

    final deliveryToday = deliveryManRequests
        .where(
            (r) => r.createdAt.isAfter(today) && r.createdAt.isBefore(todayEnd))
        .length;

    return restaurantToday + deliveryToday;
  }

  /// Count requests created this week
  static int _countRequestsThisWeek(List<RestaurantRequest> restaurantRequests,
      List<DeliveryManRequest> deliveryManRequests, DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 7));

    final restaurantWeek = restaurantRequests
        .where((r) =>
            r.createdAt.isAfter(weekStart) && r.createdAt.isBefore(weekEnd))
        .length;

    final deliveryWeek = deliveryManRequests
        .where((r) =>
            r.createdAt.isAfter(weekStart) && r.createdAt.isBefore(weekEnd))
        .length;

    return restaurantWeek + deliveryWeek;
  }

  /// Count requests created this month
  static int _countRequestsThisMonth(List<RestaurantRequest> restaurantRequests,
      List<DeliveryManRequest> deliveryManRequests, DateTime monthStart) {
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);

    final restaurantMonth = restaurantRequests
        .where((r) =>
            r.createdAt.isAfter(monthStart) && r.createdAt.isBefore(monthEnd))
        .length;

    final deliveryMonth = deliveryManRequests
        .where((r) =>
            r.createdAt.isAfter(monthStart) && r.createdAt.isBefore(monthEnd))
        .length;

    return restaurantMonth + deliveryMonth;
  }

  /// Calculate wilaya distribution
  static Map<String, int> _calculateWilayaDistribution(
      List<RestaurantRequest> restaurantRequests) {
    final distribution = <String, int>{};

    for (final request in restaurantRequests) {
      final wilaya = request.wilaya ?? 'Unknown';
      distribution[wilaya] = (distribution[wilaya] ?? 0) + 1;
    }

    return distribution;
  }

  /// Get top wilayas by request count
  static List<Map<String, dynamic>> _getTopWilayas(
      List<RestaurantRequest> restaurantRequests) {
    final distribution = _calculateWilayaDistribution(restaurantRequests);

    return distribution.entries
        .map((entry) => {'wilaya': entry.key, 'count': entry.value})
        .toList()
      ..sort((a, b) => ((b['count'] ?? 0) as num)
          .toDouble()
          .compareTo(((a['count'] ?? 0) as num).toDouble()))
      ..take(10);
  }

  /// Calculate daily trends for the last 7 days
  static List<Map<String, dynamic>> _calculateDailyTrends(
      List<RestaurantRequest> restaurantRequests,
      List<DeliveryManRequest> deliveryManRequests) {
    final trends = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      final nextDate = date.add(const Duration(days: 1));

      final restaurantCount = restaurantRequests
          .where((r) =>
              r.createdAt.isAfter(date) && r.createdAt.isBefore(nextDate))
          .length;

      final deliveryCount = deliveryManRequests
          .where((r) =>
              r.createdAt.isAfter(date) && r.createdAt.isBefore(nextDate))
          .length;

      trends.add({
        'date': '${date.day}/${date.month}',
        'restaurant_requests': restaurantCount,
        'delivery_requests': deliveryCount,
        'total': restaurantCount + deliveryCount,
      });
    }

    return trends;
  }

  /// Calculate weekly trends for the last 4 weeks
  static List<Map<String, dynamic>> _calculateWeeklyTrends(
      List<RestaurantRequest> restaurantRequests,
      List<DeliveryManRequest> deliveryManRequests) {
    final trends = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (int i = 3; i >= 0; i--) {
      final weekStart =
          DateTime(now.year, now.month, now.day - (now.weekday - 1) - (i * 7));
      final weekEnd = weekStart.add(const Duration(days: 7));

      final restaurantCount = restaurantRequests
          .where((r) =>
              r.createdAt.isAfter(weekStart) && r.createdAt.isBefore(weekEnd))
          .length;

      final deliveryCount = deliveryManRequests
          .where((r) =>
              r.createdAt.isAfter(weekStart) && r.createdAt.isBefore(weekEnd))
          .length;

      trends.add({
        'week': 'Week ${4 - i}',
        'restaurant_requests': restaurantCount,
        'delivery_requests': deliveryCount,
        'total': restaurantCount + deliveryCount,
      });
    }

    return trends;
  }

  /// Calculate average pending duration
  static String _calculateAveragePendingDuration(
      List<RestaurantRequest> restaurantRequests,
      List<DeliveryManRequest> deliveryManRequests) {
    final pendingRequests = <Duration>[];

    // Add restaurant pending requests
    for (final request in restaurantRequests.where((r) => r.isPending)) {
      pendingRequests.add(DateTime.now().difference(request.createdAt));
    }

    // Add delivery man pending requests
    for (final request in deliveryManRequests.where((r) => r.isPending)) {
      pendingRequests.add(DateTime.now().difference(request.createdAt));
    }

    if (pendingRequests.isEmpty) return 'No pending requests';

    final avgMinutes = pendingRequests.fold<int>(
            0, (sum, duration) => sum + duration.inMinutes) /
        pendingRequests.length;

    if (avgMinutes < 60) {
      return '${avgMinutes.round()} minutes';
    } else if (avgMinutes < 1440) {
      // 24 hours
      return '${(avgMinutes / 60).toStringAsFixed(1)} hours';
    } else {
      return '${(avgMinutes / 1440).toStringAsFixed(1)} days';
    }
  }

  /// Calculate peak hours for requests
  static List<Map<String, dynamic>> _calculatePeakHours(
      List<RestaurantRequest> restaurantRequests,
      List<DeliveryManRequest> deliveryManRequests) {
    final hourCounts = <int, int>{};

    // Count requests by hour
    for (final request in restaurantRequests) {
      final hour = request.createdAt.hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }

    for (final request in deliveryManRequests) {
      final hour = request.createdAt.hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }

    // Convert to list and sort by count
    return hourCounts.entries
        .map((entry) => {'hour': entry.key, 'count': entry.value})
        .toList()
      ..sort((a, b) => ((b['count'] ?? 0) as num)
          .toDouble()
          .compareTo(((a['count'] ?? 0) as num).toDouble()))
      ..take(5);
  }

  /// Generate insights and recommendations
  static List<String> generateInsights(Map<String, dynamic> stats) {
    final insights = <String>[];

    // Approval rate insights
    final approvalRate = stats['approval_rate'] as double;
    if (approvalRate > 80) {
      insights.add(
          'High approval rate (${approvalRate.toStringAsFixed(1)}%) indicates good application quality');
    } else if (approvalRate < 50) {
      insights.add(
          'Low approval rate (${approvalRate.toStringAsFixed(1)}%) - consider reviewing application requirements');
    }

    // Processing time insights
    final avgProcessingTime = stats['avg_processing_time'] as String;
    if (avgProcessingTime.contains('days') &&
        double.parse(avgProcessingTime.split(' ')[0]) > 3) {
      insights.add(
          'Average processing time is high - consider increasing admin capacity');
    }

    // Pending duration insights
    final pendingDuration = stats['pending_duration'] as String;
    if (pendingDuration.contains('days') &&
        double.parse(pendingDuration.split(' ')[0]) > 2) {
      insights.add(
          'Some requests have been pending for several days - prioritize review');
    }

    // Geographic insights
    final topWilayas = stats['top_wilayas'] as List<Map<String, dynamic>>;
    if (topWilayas.isNotEmpty) {
      final topWilaya = topWilayas.first;
      insights.add(
          '${topWilaya['wilaya']} has the most requests (${topWilaya['count']})');
    }

    // Trend insights
    final dailyTrends = stats['daily_trends'] as List<Map<String, dynamic>>;
    if (dailyTrends.length >= 2) {
      final today = dailyTrends.last['total'] as int;
      final yesterday = dailyTrends[dailyTrends.length - 2]['total'] as int;

      if (today > yesterday * 1.5) {
        insights.add('Request volume increased significantly today');
      } else if (today < yesterday * 0.5) {
        insights.add('Request volume decreased significantly today');
      }
    }

    return insights;
  }

  /// Get performance score (0-100)
  static int calculatePerformanceScore(Map<String, dynamic> stats) {
    int score = 0;

    // Approval rate score (40 points)
    final approvalRate = stats['approval_rate'] as double;
    score += (approvalRate / 100 * 40).round();

    // Processing time score (30 points)
    final avgProcessingTime = stats['avg_processing_time'] as String;
    if (avgProcessingTime.contains('minutes')) {
      score += 30; // Excellent
    } else if (avgProcessingTime.contains('hours')) {
      final hours = double.parse(avgProcessingTime.split(' ')[0]);
      if (hours <= 24) {
        score += 25; // Good
      } else {
        score += 15; // Fair
      }
    } else {
      score += 10; // Poor
    }

    // Pending duration score (20 points)
    final pendingDuration = stats['pending_duration'] as String;
    if (pendingDuration.contains('minutes')) {
      score += 20; // Excellent
    } else if (pendingDuration.contains('hours')) {
      score += 15; // Good
    } else {
      score += 5; // Poor
    }

    // Volume consistency score (10 points)
    final dailyTrends = stats['daily_trends'] as List<Map<String, dynamic>>;
    if (dailyTrends.length >= 3) {
      final totals = dailyTrends.map((d) => d['total'] as int).toList();
      final avg = totals.reduce((a, b) => a + b) / totals.length;
      final variance =
          totals.map((t) => (t - avg).abs()).reduce((a, b) => a + b) /
              totals.length;

      if (variance < avg * 0.2) {
        score += 10; // Consistent
      } else if (variance < avg * 0.5) {
        score += 5; // Somewhat consistent
      }
    }

    return min(100, score);
  }
}
