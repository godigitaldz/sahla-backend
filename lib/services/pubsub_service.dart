import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/maps_config.dart';

/// Google Cloud Pub/Sub service for reliable messaging
class PubSubService {
  static const String _baseUrl =
      'https://pubsub.googleapis.com/v1/projects/your-project-id';
  static const String _apiKey = MapsConfig.googleMapsApiKey;

  /// Publish order status update
  static Future<bool> publishOrderStatusUpdate({
    required String orderId,
    required String status,
    required String userId,
    required String restaurantId,
    required Map<String, dynamic> data,
  }) async {
    try {
      final message = {
        'orderId': orderId,
        'status': status,
        'userId': userId,
        'restaurantId': restaurantId,
        'timestamp': DateTime.now().toIso8601String(),
        'data': data,
      };

      return await _publishMessage(
        topic: 'order-status-updates',
        message: message,
      );
    } catch (e) {
      debugPrint('❌ Error publishing order status update: $e');
      return false;
    }
  }

  /// Publish delivery location update
  static Future<bool> publishDeliveryLocationUpdate({
    required String deliveryPersonId,
    required double latitude,
    required double longitude,
    required String address,
    required String orderId,
  }) async {
    try {
      final message = {
        'deliveryPersonId': deliveryPersonId,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'orderId': orderId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      return await _publishMessage(
        topic: 'delivery-location-updates',
        message: message,
      );
    } catch (e) {
      debugPrint('❌ Error publishing delivery location update: $e');
      return false;
    }
  }

  /// Publish restaurant status update
  static Future<bool> publishRestaurantStatusUpdate({
    required String restaurantId,
    required bool isOpen,
    required String reason,
  }) async {
    try {
      final message = {
        'restaurantId': restaurantId,
        'isOpen': isOpen,
        'reason': reason,
        'timestamp': DateTime.now().toIso8601String(),
      };

      return await _publishMessage(
        topic: 'restaurant-status-updates',
        message: message,
      );
    } catch (e) {
      debugPrint('❌ Error publishing restaurant status update: $e');
      return false;
    }
  }

  /// Publish customer notification
  static Future<bool> publishCustomerNotification({
    required String customerId,
    required String title,
    required String message,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    try {
      final messageData = {
        'customerId': customerId,
        'title': title,
        'message': message,
        'type': type,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      };

      return await _publishMessage(
        topic: 'customer-notifications',
        message: messageData,
      );
    } catch (e) {
      debugPrint('❌ Error publishing customer notification: $e');
      return false;
    }
  }

  /// Publish promotional campaign
  static Future<bool> publishPromotionalCampaign({
    required String campaignId,
    required String title,
    required String message,
    required String imageUrl,
    required List<String> targetUsers,
    required Map<String, dynamic> data,
  }) async {
    try {
      final messageData = {
        'campaignId': campaignId,
        'title': title,
        'message': message,
        'imageUrl': imageUrl,
        'targetUsers': targetUsers,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      };

      return await _publishMessage(
        topic: 'promotional-campaigns',
        message: messageData,
      );
    } catch (e) {
      debugPrint('❌ Error publishing promotional campaign: $e');
      return false;
    }
  }

  /// Publish restaurant analytics update
  static Future<bool> publishRestaurantAnalyticsUpdate({
    required String restaurantId,
    required Map<String, dynamic> analytics,
  }) async {
    try {
      final message = {
        'restaurantId': restaurantId,
        'analytics': analytics,
        'timestamp': DateTime.now().toIso8601String(),
      };

      return await _publishMessage(
        topic: 'restaurant-analytics-updates',
        message: message,
      );
    } catch (e) {
      debugPrint('❌ Error publishing restaurant analytics update: $e');
      return false;
    }
  }

  /// Publish system health check
  static Future<bool> publishSystemHealthCheck({
    required String serviceName,
    required String status,
    required Map<String, dynamic> metrics,
  }) async {
    try {
      final message = {
        'serviceName': serviceName,
        'status': status,
        'metrics': metrics,
        'timestamp': DateTime.now().toIso8601String(),
      };

      return await _publishMessage(
        topic: 'system-health-checks',
        message: message,
      );
    } catch (e) {
      debugPrint('❌ Error publishing system health check: $e');
      return false;
    }
  }

  /// Publish error report
  static Future<bool> publishErrorReport({
    required String errorType,
    required String errorMessage,
    required String stackTrace,
    required String userId,
    required String deviceInfo,
  }) async {
    try {
      final message = {
        'errorType': errorType,
        'errorMessage': errorMessage,
        'stackTrace': stackTrace,
        'userId': userId,
        'deviceInfo': deviceInfo,
        'timestamp': DateTime.now().toIso8601String(),
      };

      return await _publishMessage(
        topic: 'error-reports',
        message: message,
      );
    } catch (e) {
      debugPrint('❌ Error publishing error report: $e');
      return false;
    }
  }

  /// Publish user activity
  static Future<bool> publishUserActivity({
    required String userId,
    required String activityType,
    required String activityData,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      final message = {
        'userId': userId,
        'activityType': activityType,
        'activityData': activityData,
        'metadata': metadata,
        'timestamp': DateTime.now().toIso8601String(),
      };

      return await _publishMessage(
        topic: 'user-activities',
        message: message,
      );
    } catch (e) {
      debugPrint('❌ Error publishing user activity: $e');
      return false;
    }
  }

  /// Publish delivery route optimization request
  static Future<bool> publishDeliveryRouteOptimizationRequest({
    required List<Map<String, dynamic>> orders,
    required List<Map<String, dynamic>> deliveryPersons,
  }) async {
    try {
      final message = {
        'orders': orders,
        'deliveryPersons': deliveryPersons,
        'timestamp': DateTime.now().toIso8601String(),
      };

      return await _publishMessage(
        topic: 'delivery-route-optimization-requests',
        message: message,
      );
    } catch (e) {
      debugPrint('❌ Error publishing delivery route optimization request: $e');
      return false;
    }
  }

  /// Publish content moderation request
  static Future<bool> publishContentModerationRequest({
    required String contentId,
    required String contentType,
    required String contentUrl,
    required String userId,
  }) async {
    try {
      final message = {
        'contentId': contentId,
        'contentType': contentType,
        'contentUrl': contentUrl,
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      return await _publishMessage(
        topic: 'content-moderation-requests',
        message: message,
      );
    } catch (e) {
      debugPrint('❌ Error publishing content moderation request: $e');
      return false;
    }
  }

  /// Private method to publish message to topic
  static Future<bool> _publishMessage({
    required String topic,
    required Map<String, dynamic> message,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/topics/$topic:publish');

      final requestBody = {
        'messages': [
          {
            'data': base64Encode(utf8.encode(json.encode(message))),
            'attributes': {
              'timestamp': DateTime.now().toIso8601String(),
              'source': 'flutter-app',
            },
          },
        ],
      };

      debugPrint('📤 Publishing message to topic: $topic');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Message published successfully to topic: $topic');
        return true;
      } else {
        debugPrint(
            '❌ Failed to publish message to topic $topic: ${response.statusCode}');
        debugPrint('   Response: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error publishing message to topic $topic: $e');
    }

    return false;
  }

  /// Create subscription for topic
  static Future<bool> createSubscription({
    required String topic,
    required String subscriptionName,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/subscriptions/$subscriptionName');

      final requestBody = {
        'topic': '$_baseUrl/topics/$topic',
        'ackDeadlineSeconds': 60,
        'retainAckedMessages': false,
        'messageRetentionDuration': '604800s', // 7 days
      };

      debugPrint(
          '📋 Creating subscription: $subscriptionName for topic: $topic');

      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Subscription created successfully: $subscriptionName');
        return true;
      } else {
        debugPrint('❌ Failed to create subscription: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error creating subscription: $e');
    }

    return false;
  }

  /// Pull messages from subscription
  static Future<List<PubSubMessage>> pullMessages({
    required String subscriptionName,
    int maxMessages = 10,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/subscriptions/$subscriptionName:pull');

      final requestBody = {
        'maxMessages': maxMessages,
        'returnImmediately': true,
      };

      debugPrint('📥 Pulling messages from subscription: $subscriptionName');

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
        debugPrint(
            '✅ Messages pulled successfully from subscription: $subscriptionName');

        if (data['receivedMessages'] != null) {
          return (data['receivedMessages'] as List)
              .map((msg) => PubSubMessage.fromJson(msg))
              .toList();
        }
      } else {
        debugPrint('❌ Failed to pull messages: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error pulling messages: $e');
    }

    return [];
  }

  /// Acknowledge message
  static Future<bool> acknowledgeMessage({
    required String subscriptionName,
    required String ackId,
  }) async {
    try {
      final uri =
          Uri.parse('$_baseUrl/subscriptions/$subscriptionName:acknowledge');

      final requestBody = {
        'ackIds': [ackId],
      };

      debugPrint('✅ Acknowledging message: $ackId');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Message acknowledged successfully: $ackId');
        return true;
      } else {
        debugPrint('❌ Failed to acknowledge message: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error acknowledging message: $e');
    }

    return false;
  }
}

/// Pub/Sub message model
class PubSubMessage {
  final String ackId;
  final String messageId;
  final String data;
  final Map<String, String> attributes;
  final DateTime publishTime;

  const PubSubMessage({
    required this.ackId,
    required this.messageId,
    required this.data,
    required this.attributes,
    required this.publishTime,
  });

  factory PubSubMessage.fromJson(Map<String, dynamic> json) {
    return PubSubMessage(
      ackId: json['ackId'] ?? '',
      messageId: json['message']['messageId'] ?? '',
      data: utf8.decode(base64Decode(json['message']['data'] ?? '')),
      attributes: Map<String, String>.from(json['message']['attributes'] ?? {}),
      publishTime: DateTime.parse(
          json['message']['publishTime'] ?? DateTime.now().toIso8601String()),
    );
  }

  /// Get decoded message data
  Map<String, dynamic> get decodedData {
    try {
      return json.decode(data);
    } catch (e) {
      return {'raw': data};
    }
  }
}
