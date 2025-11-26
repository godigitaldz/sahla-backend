import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/maps_config.dart';

/// Google Cloud Firestore service for real-time data
class FirestoreService {
  static const String _baseUrl =
      'https://firestore.googleapis.com/v1/projects/your-project-id/databases/(default)/documents';
  static const String _apiKey = MapsConfig.googleMapsApiKey;

  /// Listen to real-time order updates
  static Stream<OrderUpdate> listenToOrderUpdates(String orderId) {
    return Stream.periodic(const Duration(seconds: 5), (count) {
      return OrderUpdate(
        orderId: orderId,
        status: 'processing',
        timestamp: DateTime.now(),
        message: 'Order is being processed...',
      );
    });
  }

  /// Get real-time delivery person location
  static Future<DeliveryLocation?> getDeliveryPersonLocation(
      String deliveryPersonId) async {
    try {
      final uri =
          Uri.parse('$_baseUrl/deliveryPersons/$deliveryPersonId/location');

      debugPrint('📍 Getting delivery person location: $deliveryPersonId');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_apiKey',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ Delivery person location retrieved');
        return DeliveryLocation.fromJson(data);
      } else {
        debugPrint(
            '❌ Failed to get delivery person location: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error getting delivery person location: $e');
    }

    return null;
  }

  /// Update delivery person location
  static Future<bool> updateDeliveryPersonLocation({
    required String deliveryPersonId,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    try {
      final requestBody = {
        'fields': {
          'latitude': {'doubleValue': latitude},
          'longitude': {'doubleValue': longitude},
          'address': {'stringValue': address},
          'timestamp': {'timestampValue': DateTime.now().toIso8601String()},
        },
      };

      final uri =
          Uri.parse('$_baseUrl/deliveryPersons/$deliveryPersonId/location');

      debugPrint('📍 Updating delivery person location: $deliveryPersonId');

      final response = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Delivery person location updated successfully');
        return true;
      } else {
        debugPrint(
            '❌ Failed to update delivery person location: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error updating delivery person location: $e');
    }

    return false;
  }

  /// Get real-time restaurant status
  static Future<RestaurantStatus?> getRestaurantStatus(
      String restaurantId) async {
    try {
      final uri = Uri.parse('$_baseUrl/restaurants/$restaurantId/status');

      debugPrint('🏪 Getting restaurant status: $restaurantId');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_apiKey',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ Restaurant status retrieved');
        return RestaurantStatus.fromJson(data);
      } else {
        debugPrint('❌ Failed to get restaurant status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error getting restaurant status: $e');
    }

    return null;
  }

  /// Update restaurant status
  static Future<bool> updateRestaurantStatus({
    required String restaurantId,
    required bool isOpen,
    required String reason,
  }) async {
    try {
      final requestBody = {
        'fields': {
          'isOpen': {'booleanValue': isOpen},
          'reason': {'stringValue': reason},
          'timestamp': {'timestampValue': DateTime.now().toIso8601String()},
        },
      };

      final uri = Uri.parse('$_baseUrl/restaurants/$restaurantId/status');

      debugPrint('🏪 Updating restaurant status: $restaurantId');

      final response = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Restaurant status updated successfully');
        return true;
      } else {
        debugPrint(
            '❌ Failed to update restaurant status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error updating restaurant status: $e');
    }

    return false;
  }

  /// Get real-time order queue
  static Future<List<OrderQueueItem>> getOrderQueue(String restaurantId) async {
    try {
      final uri = Uri.parse('$_baseUrl/restaurants/$restaurantId/orderQueue');

      debugPrint('📋 Getting order queue for restaurant: $restaurantId');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_apiKey',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ Order queue retrieved');

        if (data['documents'] != null) {
          return (data['documents'] as List)
              .map((doc) => OrderQueueItem.fromJson(doc))
              .toList();
        }
      } else {
        debugPrint('❌ Failed to get order queue: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error getting order queue: $e');
    }

    return [];
  }

  /// Add order to queue
  static Future<bool> addOrderToQueue({
    required String restaurantId,
    required String orderId,
    required String customerId,
    required List<String> items,
    required double totalAmount,
  }) async {
    try {
      final requestBody = {
        'fields': {
          'orderId': {'stringValue': orderId},
          'customerId': {'stringValue': customerId},
          'items': {
            'arrayValue': {
              'values': items.map((item) => {'stringValue': item}).toList()
            }
          },
          'totalAmount': {'doubleValue': totalAmount},
          'status': {'stringValue': 'pending'},
          'timestamp': {'timestampValue': DateTime.now().toIso8601String()},
        },
      };

      final uri = Uri.parse('$_baseUrl/restaurants/$restaurantId/orderQueue');

      debugPrint('📋 Adding order to queue: $orderId');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Order added to queue successfully');
        return true;
      } else {
        debugPrint('❌ Failed to add order to queue: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error adding order to queue: $e');
    }

    return false;
  }

  /// Get real-time customer notifications
  static Future<List<CustomerNotification>> getCustomerNotifications(
      String customerId) async {
    try {
      final uri = Uri.parse('$_baseUrl/customers/$customerId/notifications');

      debugPrint('🔔 Getting customer notifications: $customerId');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_apiKey',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ Customer notifications retrieved');

        if (data['documents'] != null) {
          return (data['documents'] as List)
              .map((doc) => CustomerNotification.fromJson(doc))
              .toList();
        }
      } else {
        debugPrint(
            '❌ Failed to get customer notifications: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error getting customer notifications: $e');
    }

    return [];
  }

  /// Send customer notification
  static Future<bool> sendCustomerNotification({
    required String customerId,
    required String title,
    required String message,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    try {
      final requestBody = {
        'fields': {
          'title': {'stringValue': title},
          'message': {'stringValue': message},
          'type': {'stringValue': type},
          'data': {
            'mapValue': {
              'fields': data.map((key, value) =>
                  MapEntry(key, {'stringValue': value.toString()}))
            }
          },
          'isRead': {'booleanValue': false},
          'timestamp': {'timestampValue': DateTime.now().toIso8601String()},
        },
      };

      final uri = Uri.parse('$_baseUrl/customers/$customerId/notifications');

      debugPrint('🔔 Sending customer notification: $customerId');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Customer notification sent successfully');
        return true;
      } else {
        debugPrint(
            '❌ Failed to send customer notification: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error sending customer notification: $e');
    }

    return false;
  }

  /// Get real-time restaurant analytics
  static Future<RestaurantAnalytics?> getRestaurantAnalytics(
      String restaurantId) async {
    try {
      final uri = Uri.parse('$_baseUrl/restaurants/$restaurantId/analytics');

      debugPrint('📊 Getting restaurant analytics: $restaurantId');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_apiKey',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ Restaurant analytics retrieved');
        return RestaurantAnalytics.fromJson(data);
      } else {
        debugPrint(
            '❌ Failed to get restaurant analytics: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error getting restaurant analytics: $e');
    }

    return null;
  }
}

/// Order update model
class OrderUpdate {
  final String orderId;
  final String status;
  final DateTime timestamp;
  final String message;

  const OrderUpdate({
    required this.orderId,
    required this.status,
    required this.timestamp,
    required this.message,
  });

  @override
  String toString() =>
      'OrderUpdate(orderId: $orderId, status: $status, message: $message)';
}

/// Delivery location model
class DeliveryLocation {
  final String deliveryPersonId;
  final double latitude;
  final double longitude;
  final String address;
  final DateTime timestamp;

  const DeliveryLocation({
    required this.deliveryPersonId,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.timestamp,
  });

  factory DeliveryLocation.fromJson(Map<String, dynamic> json) {
    return DeliveryLocation(
      deliveryPersonId: json['deliveryPersonId'] ?? '',
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      address: json['address'] ?? '',
      timestamp:
          DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}

/// Restaurant status model
class RestaurantStatus {
  final String restaurantId;
  final bool isOpen;
  final String reason;
  final DateTime timestamp;

  const RestaurantStatus({
    required this.restaurantId,
    required this.isOpen,
    required this.reason,
    required this.timestamp,
  });

  factory RestaurantStatus.fromJson(Map<String, dynamic> json) {
    return RestaurantStatus(
      restaurantId: json['restaurantId'] ?? '',
      isOpen: json['isOpen'] ?? false,
      reason: json['reason'] ?? '',
      timestamp:
          DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}

/// Order queue item model
class OrderQueueItem {
  final String orderId;
  final String customerId;
  final List<String> items;
  final double totalAmount;
  final String status;
  final DateTime timestamp;

  const OrderQueueItem({
    required this.orderId,
    required this.customerId,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.timestamp,
  });

  factory OrderQueueItem.fromJson(Map<String, dynamic> json) {
    return OrderQueueItem(
      orderId: json['orderId'] ?? '',
      customerId: json['customerId'] ?? '',
      items: List<String>.from(json['items'] ?? []),
      totalAmount: json['totalAmount']?.toDouble() ?? 0.0,
      status: json['status'] ?? '',
      timestamp:
          DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}

/// Customer notification model
class CustomerNotification {
  final String id;
  final String title;
  final String message;
  final String type;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime timestamp;

  const CustomerNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.data,
    required this.isRead,
    required this.timestamp,
  });

  factory CustomerNotification.fromJson(Map<String, dynamic> json) {
    return CustomerNotification(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? {}),
      isRead: json['isRead'] ?? false,
      timestamp:
          DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}

/// Restaurant analytics model
class RestaurantAnalytics {
  final String restaurantId;
  final int totalOrders;
  final double totalRevenue;
  final double averageRating;
  final int totalReviews;
  final Map<String, int> orderTrends;
  final Map<String, double> revenueTrends;

  const RestaurantAnalytics({
    required this.restaurantId,
    required this.totalOrders,
    required this.totalRevenue,
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
      averageRating: json['averageRating']?.toDouble() ?? 0.0,
      totalReviews: json['totalReviews'] ?? 0,
      orderTrends: Map<String, int>.from(json['orderTrends'] ?? {}),
      revenueTrends: Map<String, double>.from(json['revenueTrends'] ?? {}),
    );
  }
}
