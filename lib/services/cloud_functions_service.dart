import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/maps_config.dart';

/// Google Cloud Functions service for automated tasks
class CloudFunctionsService {
  static const String _baseUrl =
      'https://us-central1-your-project-id.cloudfunctions.net';
  static const String _apiKey = MapsConfig.googleMapsApiKey;

  /// Trigger delivery route optimization
  static Future<RouteOptimizationResult?> optimizeDeliveryRoutes({
    required List<DeliveryOrder> orders,
    required List<DeliveryPerson> deliveryPersons,
  }) async {
    try {
      final requestBody = {
        'orders': orders.map((order) => order.toJson()).toList(),
        'deliveryPersons':
            deliveryPersons.map((person) => person.toJson()).toList(),
        'optimizationType': 'delivery_routes',
      };

      final uri = Uri.parse('$_baseUrl/optimizeDeliveryRoutes');

      debugPrint('🚚 Optimizing delivery routes for ${orders.length} orders');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ Route optimization completed');
        return RouteOptimizationResult.fromJson(data);
      } else {
        debugPrint('❌ Route optimization failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error optimizing delivery routes: $e');
    }

    return null;
  }

  /// Send promotional notifications
  static Future<bool> sendPromotionalNotifications({
    required String campaignId,
    required List<String> targetUsers,
    required String message,
    required String imageUrl,
  }) async {
    try {
      final requestBody = {
        'campaignId': campaignId,
        'targetUsers': targetUsers,
        'message': message,
        'imageUrl': imageUrl,
        'type': 'promotional',
      };

      final uri = Uri.parse('$_baseUrl/sendPromotionalNotifications');

      debugPrint(
          '📢 Sending promotional notifications to ${targetUsers.length} users');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Promotional notifications sent successfully');
        return true;
      } else {
        debugPrint(
            '❌ Failed to send promotional notifications: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error sending promotional notifications: $e');
    }

    return false;
  }

  /// Update restaurant availability
  static Future<bool> updateRestaurantAvailability({
    required String restaurantId,
    required bool isOpen,
    required String reason,
  }) async {
    try {
      final requestBody = {
        'restaurantId': restaurantId,
        'isOpen': isOpen,
        'reason': reason,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final uri = Uri.parse('$_baseUrl/updateRestaurantAvailability');

      debugPrint('🏪 Updating restaurant availability: $restaurantId');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Restaurant availability updated successfully');
        return true;
      } else {
        debugPrint(
            '❌ Failed to update restaurant availability: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error updating restaurant availability: $e');
    }

    return false;
  }

  /// Process order status updates
  static Future<bool> processOrderStatusUpdate({
    required String orderId,
    required String status,
    required String userId,
    required String restaurantId,
  }) async {
    try {
      final requestBody = {
        'orderId': orderId,
        'status': status,
        'userId': userId,
        'restaurantId': restaurantId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final uri = Uri.parse('$_baseUrl/processOrderStatusUpdate');

      debugPrint('📦 Processing order status update: $orderId -> $status');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Order status update processed successfully');
        return true;
      } else {
        debugPrint(
            '❌ Failed to process order status update: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error processing order status update: $e');
    }

    return false;
  }

  /// Generate restaurant analytics
  static Future<RestaurantAnalytics?> generateRestaurantAnalytics({
    required String restaurantId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final requestBody = {
        'restaurantId': restaurantId,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'metrics': [
          'orders',
          'revenue',
          'popular_items',
          'customer_satisfaction'
        ],
      };

      final uri = Uri.parse('$_baseUrl/generateRestaurantAnalytics');

      debugPrint('📊 Generating analytics for restaurant: $restaurantId');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ Restaurant analytics generated successfully');
        return RestaurantAnalytics.fromJson(data);
      } else {
        debugPrint(
            '❌ Failed to generate restaurant analytics: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error generating restaurant analytics: $e');
    }

    return null;
  }

  /// Clean up expired data
  static Future<bool> cleanupExpiredData({
    required String dataType,
    required int daysOld,
  }) async {
    try {
      final requestBody = {
        'dataType': dataType,
        'daysOld': daysOld,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final uri = Uri.parse('$_baseUrl/cleanupExpiredData');

      debugPrint(
          '🧹 Cleaning up expired $dataType data older than $daysOld days');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Data cleanup completed successfully');
        return true;
      } else {
        debugPrint('❌ Failed to cleanup expired data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error cleaning up expired data: $e');
    }

    return false;
  }
}

/// Delivery order model
class DeliveryOrder {
  final String id;
  final String restaurantId;
  final String customerId;
  final double latitude;
  final double longitude;
  final String address;
  final DateTime orderTime;
  final double totalAmount;
  final List<String> items;

  const DeliveryOrder({
    required this.id,
    required this.restaurantId,
    required this.customerId,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.orderTime,
    required this.totalAmount,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'restaurantId': restaurantId,
        'customerId': customerId,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'orderTime': orderTime.toIso8601String(),
        'totalAmount': totalAmount,
        'items': items,
      };
}

/// Delivery person model
class DeliveryPerson {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final bool isAvailable;
  final int currentOrders;
  final int maxOrders;

  const DeliveryPerson({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.isAvailable,
    required this.currentOrders,
    required this.maxOrders,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'isAvailable': isAvailable,
        'currentOrders': currentOrders,
        'maxOrders': maxOrders,
      };
}

/// Route optimization result
class RouteOptimizationResult {
  final List<OptimizedRoute> routes;
  final double totalDistance;
  final int totalTime;
  final double totalCost;

  const RouteOptimizationResult({
    required this.routes,
    required this.totalDistance,
    required this.totalTime,
    required this.totalCost,
  });

  factory RouteOptimizationResult.fromJson(Map<String, dynamic> json) {
    return RouteOptimizationResult(
      routes: (json['routes'] as List)
          .map((route) => OptimizedRoute.fromJson(route))
          .toList(),
      totalDistance: json['totalDistance']?.toDouble() ?? 0.0,
      totalTime: json['totalTime'] ?? 0,
      totalCost: json['totalCost']?.toDouble() ?? 0.0,
    );
  }
}

/// Optimized route
class OptimizedRoute {
  final String deliveryPersonId;
  final List<String> orderIds;
  final List<RouteStep> steps;
  final double distance;
  final int estimatedTime;

  const OptimizedRoute({
    required this.deliveryPersonId,
    required this.orderIds,
    required this.steps,
    required this.distance,
    required this.estimatedTime,
  });

  factory OptimizedRoute.fromJson(Map<String, dynamic> json) {
    return OptimizedRoute(
      deliveryPersonId: json['deliveryPersonId'] ?? '',
      orderIds: List<String>.from(json['orderIds'] ?? []),
      steps: (json['steps'] as List)
          .map((step) => RouteStep.fromJson(step))
          .toList(),
      distance: json['distance']?.toDouble() ?? 0.0,
      estimatedTime: json['estimatedTime'] ?? 0,
    );
  }
}

/// Route step
class RouteStep {
  final String type; // 'pickup', 'delivery', 'restaurant'
  final String locationId;
  final double latitude;
  final double longitude;
  final String address;
  final int estimatedTime;

  const RouteStep({
    required this.type,
    required this.locationId,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.estimatedTime,
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    return RouteStep(
      type: json['type'] ?? '',
      locationId: json['locationId'] ?? '',
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      address: json['address'] ?? '',
      estimatedTime: json['estimatedTime'] ?? 0,
    );
  }
}

/// Restaurant analytics
class RestaurantAnalytics {
  final String restaurantId;
  final int totalOrders;
  final double totalRevenue;
  final List<PopularItem> popularItems;
  final double averageRating;
  final int totalReviews;
  final Map<String, int> orderTrends;
  final Map<String, double> revenueTrends;

  const RestaurantAnalytics({
    required this.restaurantId,
    required this.totalOrders,
    required this.totalRevenue,
    required this.popularItems,
    required this.averageRating,
    required this.totalReviews,
    required this.orderTrends,
    required this.revenueTrends,
  });

  factory RestaurantAnalytics.fromJson(Map<String, dynamic> json) {
    return RestaurantAnalytics(
      restaurantId: json['restaurantId'] ?? '',
      totalOrders: json['totalOrders'] ?? 0,
      totalRevenue: json['totalRevenue']?.toDouble() ?? 0.0,
      popularItems: (json['popularItems'] as List)
          .map((item) => PopularItem.fromJson(item))
          .toList(),
      averageRating: json['averageRating']?.toDouble() ?? 0.0,
      totalReviews: json['totalReviews'] ?? 0,
      orderTrends: Map<String, int>.from(json['orderTrends'] ?? {}),
      revenueTrends: Map<String, double>.from(json['revenueTrends'] ?? {}),
    );
  }
}

/// Popular item
class PopularItem {
  final String name;
  final int orderCount;
  final double revenue;
  final double averageRating;

  const PopularItem({
    required this.name,
    required this.orderCount,
    required this.revenue,
    required this.averageRating,
  });

  factory PopularItem.fromJson(Map<String, dynamic> json) {
    return PopularItem(
      name: json['name'] ?? '',
      orderCount: json['orderCount'] ?? 0,
      revenue: json['revenue']?.toDouble() ?? 0.0,
      averageRating: json['averageRating']?.toDouble() ?? 0.0,
    );
  }
}
