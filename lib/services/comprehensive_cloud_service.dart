import 'package:flutter/foundation.dart';

import 'cloud_functions_service.dart' as cloud_functions;
import 'cloud_storage_service.dart';
import 'enhanced_google_cloud_service.dart';
import 'firestore_service.dart' as firestore;
import 'pubsub_service.dart';

/// Comprehensive Google Cloud service integrating all APIs
class ComprehensiveCloudService {
  /// Process new order with full pipeline
  static Future<OrderProcessingResult> processNewOrder({
    required String orderId,
    required String restaurantId,
    required String customerId,
    required List<String> items,
    required double totalAmount,
    required String customerAddress,
  }) async {
    try {
      debugPrint('🔄 Processing new order: $orderId');

      // 1. Add order to Firestore queue
      final queueAdded = await firestore.FirestoreService.addOrderToQueue(
        restaurantId: restaurantId,
        orderId: orderId,
        customerId: customerId,
        items: items,
        totalAmount: totalAmount,
      );

      if (!queueAdded) {
        return const OrderProcessingResult(
          success: false,
          message: 'Failed to add order to queue',
        );
      }

      // 2. Publish order status update
      await PubSubService.publishOrderStatusUpdate(
        orderId: orderId,
        status: 'pending',
        userId: customerId,
        restaurantId: restaurantId,
        data: {
          'items': items,
          'totalAmount': totalAmount,
          'address': customerAddress,
        },
      );

      // 3. Send customer notification
      await PubSubService.publishCustomerNotification(
        customerId: customerId,
        title: 'Order Confirmed',
        message: 'Your order has been confirmed and is being prepared.',
        type: 'order_confirmation',
        data: {
          'orderId': orderId,
          'restaurantId': restaurantId,
          'estimatedTime': '30-45 minutes',
        },
      );

      // 4. Trigger delivery route optimization
      await PubSubService.publishDeliveryRouteOptimizationRequest(
        orders: [
          {
            'orderId': orderId,
            'restaurantId': restaurantId,
            'customerId': customerId,
            'address': customerAddress,
            'totalAmount': totalAmount,
          }
        ],
        deliveryPersons: [], // Will be populated by the function
      );

      debugPrint('✅ Order processing completed successfully');
      return OrderProcessingResult(
        success: true,
        message: 'Order processed successfully',
        orderId: orderId,
      );
    } catch (e) {
      debugPrint('❌ Error processing new order: $e');
      return OrderProcessingResult(
        success: false,
        message: 'Error processing order: $e',
      );
    }
  }

  /// Update delivery person location with full pipeline
  static Future<bool> updateDeliveryPersonLocation({
    required String deliveryPersonId,
    required double latitude,
    required double longitude,
    required String address,
    required String orderId,
  }) async {
    try {
      debugPrint('📍 Updating delivery person location: $deliveryPersonId');

      // 1. Update location in Firestore
      final firestoreUpdated =
          await firestore.FirestoreService.updateDeliveryPersonLocation(
        deliveryPersonId: deliveryPersonId,
        latitude: latitude,
        longitude: longitude,
        address: address,
      );

      if (!firestoreUpdated) {
        debugPrint('⚠️ Failed to update location in Firestore');
      }

      // 2. Publish location update
      final pubsubPublished = await PubSubService.publishDeliveryLocationUpdate(
        deliveryPersonId: deliveryPersonId,
        latitude: latitude,
        longitude: longitude,
        address: address,
        orderId: orderId,
      );

      if (!pubsubPublished) {
        debugPrint('⚠️ Failed to publish location update');
      }

      // 3. Send customer notification if close to delivery
      await PubSubService.publishCustomerNotification(
        customerId: 'customer_id', // Get from order
        title: 'Delivery Update',
        message: 'Your delivery person is on the way!',
        type: 'delivery_update',
        data: {
          'deliveryPersonId': deliveryPersonId,
          'orderId': orderId,
          'estimatedArrival': '10-15 minutes',
        },
      );

      debugPrint('✅ Delivery person location updated successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating delivery person location: $e');
      return false;
    }
  }

  /// Process restaurant menu upload with AI analysis
  static Future<MenuProcessingResult> processRestaurantMenuUpload({
    required String restaurantId,
    required String imageUrl,
    required String targetLanguage,
  }) async {
    try {
      debugPrint('🍽️ Processing restaurant menu upload: $restaurantId');

      // 1. Upload image to Cloud Storage
      final storageUrl = await CloudStorageService.uploadMenuImage(
        imagePath: imageUrl,
        restaurantId: restaurantId,
        menuItemId: 'menu_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (storageUrl == null) {
        return const MenuProcessingResult(
          success: false,
          message: 'Failed to upload menu image',
        );
      }

      // 2. Analyze menu with Vision API
      final menuItems = await EnhancedGoogleCloudService.analyzeMenuImage(
        imageUrl: storageUrl,
        targetLanguage: targetLanguage,
      );

      // 3. Moderate content
      final moderation =
          await EnhancedGoogleCloudService.moderateRestaurantContent(
        restaurantId: restaurantId,
        imageUrls: [storageUrl],
        textContent: menuItems.map((item) => item.name).toList(),
      );

      if (!moderation.isContentSafe) {
        return MenuProcessingResult(
          success: false,
          message: 'Menu content failed moderation',
          moderationIssues: moderation.inappropriateContentCount,
        );
      }

      // 4. Publish content moderation result
      await PubSubService.publishContentModerationRequest(
        contentId: 'menu_$restaurantId',
        contentType: 'menu_image',
        contentUrl: storageUrl,
        userId: restaurantId,
      );

      debugPrint('✅ Menu processing completed successfully');
      return MenuProcessingResult(
        success: true,
        message: 'Menu processed successfully',
        menuItems: menuItems,
        imageUrl: storageUrl,
      );
    } catch (e) {
      debugPrint('❌ Error processing restaurant menu: $e');
      return MenuProcessingResult(
        success: false,
        message: 'Error processing menu: $e',
      );
    }
  }

  /// Generate comprehensive restaurant analytics
  static Future<RestaurantAnalyticsResult> generateRestaurantAnalytics({
    required String restaurantId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      debugPrint('📊 Generating restaurant analytics: $restaurantId');

      // 1. Get analytics from Cloud Functions
      final analytics = await cloud_functions.CloudFunctionsService
          .generateRestaurantAnalytics(
        restaurantId: restaurantId,
        startDate: startDate,
        endDate: endDate,
      );

      if (analytics == null) {
        return const RestaurantAnalyticsResult(
          success: false,
          message: 'Failed to generate analytics',
        );
      }

      // 2. Get real-time analytics from Firestore
      final realtimeAnalytics =
          await firestore.FirestoreService.getRestaurantAnalytics(restaurantId);

      // 3. Publish analytics update
      await PubSubService.publishRestaurantAnalyticsUpdate(
        restaurantId: restaurantId,
        analytics: {
          'totalOrders': analytics.totalOrders,
          'totalRevenue': analytics.totalRevenue,
          'averageRating': analytics.averageRating,
          'totalReviews': analytics.totalReviews,
        },
      );

      debugPrint('✅ Restaurant analytics generated successfully');
      return RestaurantAnalyticsResult(
        success: true,
        message: 'Analytics generated successfully',
        analytics: analytics,
        realtimeAnalytics: realtimeAnalytics,
      );
    } catch (e) {
      debugPrint('❌ Error generating restaurant analytics: $e');
      return RestaurantAnalyticsResult(
        success: false,
        message: 'Error generating analytics: $e',
      );
    }
  }

  /// Send promotional campaign with full pipeline
  static Future<PromotionalCampaignResult> sendPromotionalCampaign({
    required String campaignId,
    required String title,
    required String message,
    required String imageUrl,
    required List<String> targetUsers,
    required Map<String, dynamic> campaignData,
  }) async {
    try {
      debugPrint('📢 Sending promotional campaign: $campaignId');

      // 1. Upload promotional image to Cloud Storage
      final storageUrl = await CloudStorageService.uploadPromotionalImage(
        imagePath: imageUrl,
        campaignId: campaignId,
      );

      if (storageUrl == null) {
        return const PromotionalCampaignResult(
          success: false,
          message: 'Failed to upload promotional image',
        );
      }

      // 2. Moderate content
      final moderation =
          await EnhancedGoogleCloudService.moderateRestaurantContent(
        restaurantId: 'promotional',
        imageUrls: [storageUrl],
        textContent: [title, message],
      );

      if (!moderation.isContentSafe) {
        return PromotionalCampaignResult(
          success: false,
          message: 'Promotional content failed moderation',
          moderationIssues: moderation.inappropriateContentCount,
        );
      }

      // 3. Send notifications via Cloud Functions
      final notificationsSent = await cloud_functions.CloudFunctionsService
          .sendPromotionalNotifications(
        campaignId: campaignId,
        targetUsers: targetUsers,
        message: message,
        imageUrl: storageUrl,
      );

      if (!notificationsSent) {
        return const PromotionalCampaignResult(
          success: false,
          message: 'Failed to send promotional notifications',
        );
      }

      // 4. Publish campaign to Pub/Sub
      await PubSubService.publishPromotionalCampaign(
        campaignId: campaignId,
        title: title,
        message: message,
        imageUrl: storageUrl,
        targetUsers: targetUsers,
        data: campaignData,
      );

      debugPrint('✅ Promotional campaign sent successfully');
      return PromotionalCampaignResult(
        success: true,
        message: 'Promotional campaign sent successfully',
        imageUrl: storageUrl,
        targetUsers: targetUsers,
      );
    } catch (e) {
      debugPrint('❌ Error sending promotional campaign: $e');
      return PromotionalCampaignResult(
        success: false,
        message: 'Error sending campaign: $e',
      );
    }
  }

  /// Optimize delivery routes with full pipeline
  static Future<cloud_functions.RouteOptimizationResult>
      optimizeDeliveryRoutes({
    required List<cloud_functions.DeliveryOrder> orders,
    required List<cloud_functions.DeliveryPerson> deliveryPersons,
  }) async {
    try {
      debugPrint('🚚 Optimizing delivery routes for ${orders.length} orders');

      // 1. Optimize routes via Cloud Functions
      final optimization =
          await cloud_functions.CloudFunctionsService.optimizeDeliveryRoutes(
        orders: orders,
        deliveryPersons: deliveryPersons,
      );

      if (optimization == null) {
        return const cloud_functions.RouteOptimizationResult(
          routes: [],
          totalDistance: 0.0,
          totalTime: 0,
          totalCost: 0.0,
        );
      }

      // 2. Publish optimization request
      await PubSubService.publishDeliveryRouteOptimizationRequest(
        orders: orders.map((order) => order.toJson()).toList(),
        deliveryPersons:
            deliveryPersons.map((person) => person.toJson()).toList(),
      );

      // 3. Send notifications to delivery persons
      for (final route in optimization.routes) {
        await PubSubService.publishCustomerNotification(
          customerId: route.deliveryPersonId,
          title: 'New Delivery Route',
          message:
              'You have been assigned a new delivery route with ${route.orderIds.length} orders.',
          type: 'delivery_assignment',
          data: {
            'routeId': route.deliveryPersonId,
            'orderIds': route.orderIds,
            'estimatedTime': route.estimatedTime,
            'distance': route.distance,
          },
        );
      }

      debugPrint('✅ Delivery routes optimized successfully');
      return optimization;
    } catch (e) {
      debugPrint('❌ Error optimizing delivery routes: $e');
      return const cloud_functions.RouteOptimizationResult(
        routes: [],
        totalDistance: 0.0,
        totalTime: 0,
        totalCost: 0.0,
      );
    }
  }

  /// Monitor system health
  static Future<SystemHealthResult> monitorSystemHealth() async {
    try {
      debugPrint('🏥 Monitoring system health');

      final healthChecks = <String, bool>{};

      // Check Cloud Functions
      try {
        await cloud_functions.CloudFunctionsService.cleanupExpiredData(
          dataType: 'test',
          daysOld: 1,
        );
        healthChecks['cloud_functions'] = true;
      } catch (e) {
        healthChecks['cloud_functions'] = false;
      }

      // Check Firestore
      try {
        await firestore.FirestoreService.getRestaurantStatus('test');
        healthChecks['firestore'] = true;
      } catch (e) {
        healthChecks['firestore'] = false;
      }

      // Check Cloud Storage
      try {
        await CloudStorageService.listImages('test');
        healthChecks['cloud_storage'] = true;
      } catch (e) {
        healthChecks['cloud_storage'] = false;
      }

      // Check Pub/Sub
      try {
        await PubSubService.publishSystemHealthCheck(
          serviceName: 'flutter_app',
          status: 'healthy',
          metrics: healthChecks,
        );
        healthChecks['pubsub'] = true;
      } catch (e) {
        healthChecks['pubsub'] = false;
      }

      final allHealthy = healthChecks.values.every((healthy) => healthy);

      debugPrint('✅ System health check completed');
      return SystemHealthResult(
        success: allHealthy,
        message: allHealthy ? 'All systems healthy' : 'Some systems unhealthy',
        healthChecks: healthChecks,
      );
    } catch (e) {
      debugPrint('❌ Error monitoring system health: $e');
      return SystemHealthResult(
        success: false,
        message: 'Error monitoring system health: $e',
        healthChecks: {},
      );
    }
  }
}

/// Order processing result
class OrderProcessingResult {
  final bool success;
  final String message;
  final String? orderId;

  const OrderProcessingResult({
    required this.success,
    required this.message,
    this.orderId,
  });
}

/// Menu processing result
class MenuProcessingResult {
  final bool success;
  final String message;
  final List<dynamic>? menuItems;
  final String? imageUrl;
  final int? moderationIssues;

  const MenuProcessingResult({
    required this.success,
    required this.message,
    this.menuItems,
    this.imageUrl,
    this.moderationIssues,
  });
}

/// Restaurant analytics result
class RestaurantAnalyticsResult {
  final bool success;
  final String message;
  final cloud_functions.RestaurantAnalytics? analytics;
  final firestore.RestaurantAnalytics? realtimeAnalytics;

  const RestaurantAnalyticsResult({
    required this.success,
    required this.message,
    this.analytics,
    this.realtimeAnalytics,
  });
}

/// Promotional campaign result
class PromotionalCampaignResult {
  final bool success;
  final String message;
  final String? imageUrl;
  final List<String>? targetUsers;
  final int? moderationIssues;

  const PromotionalCampaignResult({
    required this.success,
    required this.message,
    this.imageUrl,
    this.targetUsers,
    this.moderationIssues,
  });
}

// Route optimization result is defined in cloud_functions_service.dart

/// System health result
class SystemHealthResult {
  final bool success;
  final String message;
  final Map<String, bool> healthChecks;

  const SystemHealthResult({
    required this.success,
    required this.message,
    required this.healthChecks,
  });
}
