import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service.dart';

/// Centralized service for managing app-wide event notifications
/// This service integrates with all major app events and ensures
/// consistent notification delivery across the application
class AppEventNotificationService {
  static final AppEventNotificationService _instance =
      AppEventNotificationService._internal();
  factory AppEventNotificationService() => _instance;
  AppEventNotificationService._internal();

  final NotificationService _notificationService = NotificationService();
  SupabaseClient get _client => Supabase.instance.client;

  // ==================== AUTHENTICATION EVENTS ====================

  /// Handle user signup event
  Future<void> handleUserSignup({
    required String userId,
    required String userEmail,
    String? userName,
  }) async {
    try {
      debugPrint('🔔 Creating signup notification for user: $userId');

      await _notificationService.notifyUserSignup(
        userId: userId,
        userEmail: userEmail,
        userName: userName ?? '',
      );

      debugPrint('✅ Signup notification created successfully');
    } catch (e) {
      debugPrint('❌ Failed to create signup notification: $e');
    }
  }

  /// Handle email verification event
  Future<void> handleEmailVerification({
    required String userId,
    required bool isVerified,
    String? userEmail,
  }) async {
    try {
      debugPrint(
          '🔔 Creating email verification notification for user: $userId');

      await _notificationService.notifyEmailVerification(
        userId: userId,
        isVerified: isVerified,
        userEmail: userEmail ?? '',
      );

      debugPrint('✅ Email verification notification created successfully');
    } catch (e) {
      debugPrint('❌ Failed to create email verification notification: $e');
    }
  }

  /// Handle phone verification event
  Future<void> handlePhoneVerification({
    required String userId,
    required bool isVerified,
    String? phoneNumber,
  }) async {
    try {
      debugPrint(
          '🔔 Creating phone verification notification for user: $userId');

      await _notificationService.notifyPhoneVerification(
        userId: userId,
        isVerified: isVerified,
        phoneNumber: phoneNumber ?? '',
      );

      debugPrint('✅ Phone verification notification created successfully');
    } catch (e) {
      debugPrint('❌ Failed to create phone verification notification: $e');
    }
  }

  // ==================== HOST REQUEST EVENTS ====================

  /// Handle host request submission
  Future<void> handleHostRequestSubmitted({
    required String userId,
    required String requestId,
    String? businessName,
  }) async {
    try {
      debugPrint(
          '🔔 Creating host request submission notification for user: $userId');

      await _notificationService.notifyHostRequestSubmitted(
        userId: userId,
        requestId: requestId,
        businessName: businessName ?? '',
      );

      debugPrint('✅ Host request submission notification created successfully');
    } catch (e) {
      debugPrint('❌ Failed to create host request submission notification: $e');
    }
  }

  /// Handle host request approval/rejection (admin action)
  Future<void> handleHostRequestReview({
    required String userId,
    required String requestId,
    required bool isApproved,
    String? businessName,
    String? notes,
    String? resubmissionInstructions,
  }) async {
    try {
      debugPrint(
          '🔔 Creating host request review notification for user: $userId');

      if (isApproved) {
        await _notificationService.notifyHostRequestApproved(
          userId: userId,
          requestId: requestId,
          businessName: businessName ?? '',
          approvalNotes: notes,
        );
      } else {
        await _notificationService.notifyHostRequestRejected(
          userId: userId,
          requestId: requestId,
          businessName: businessName ?? '',
          reason: notes,
        );
      }

      debugPrint('✅ Host request review notification created successfully');
    } catch (e) {
      debugPrint('❌ Failed to create host request review notification: $e');
    }
  }

  // ==================== CAR EVENTS ====================

  /// Handle car approval/rejection (admin action)
  Future<void> handleCarReview({
    required String userId,
    required String carId,
    required String carName,
    required bool isApproved,
    String? approvalNotes,
  }) async {
    try {
      debugPrint('🔔 Creating car review notification for user: $userId');

      await _notificationService.sendNotification(
        userId: userId,
        title: isApproved ? 'Car Approved!' : 'Car Review Update',
        message: isApproved
            ? 'Your car "$carName" has been approved.'
            : 'Your car "$carName" requires changes. ${approvalNotes ?? ''}',
        type: 'car_review',
        data: {
          'carId': carId,
          'carName': carName,
          'isApproved': isApproved,
          'approvalNotes': approvalNotes,
        },
      );

      debugPrint('✅ Car review notification created successfully');
    } catch (e) {
      debugPrint('❌ Failed to create car review notification: $e');
    }
  }

  // ==================== BOOKING EVENTS ====================

  /// Handle new booking creation
  Future<void> handleNewBooking({
    required String hostId,
    required String guestId,
    required String bookingId,
    required String carName,
    required String guestName,
    required DateTime startDate,
    required DateTime endDate,
    required double totalPrice,
  }) async {
    try {
      debugPrint('🔔 Creating new booking notification for host: $hostId');

      // Notify restaurant about new order
      await _notificationService.notifyNewOrder(
        userId: hostId,
        orderId: bookingId,
        restaurantName: carName,
        totalAmount: totalPrice,
      );

      debugPrint('✅ New booking notification created successfully');
    } catch (e) {
      debugPrint('❌ Failed to create new booking notification: $e');
    }
  }

  /// Handle booking confirmation
  Future<void> handleBookingConfirmed({
    required String guestId,
    required String hostId,
    required String bookingId,
    required String carName,
    required String hostName,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      debugPrint(
          '🔔 Creating booking confirmation notification for guest: $guestId');

      // Notify customer about order confirmation
      await _notificationService.notifyOrderConfirmed(
        userId: guestId,
        orderId: bookingId,
        restaurantName: carName,
      );

      debugPrint('✅ Booking confirmation notification created successfully');
    } catch (e) {
      debugPrint('❌ Failed to create booking confirmation notification: $e');
    }
  }

  // ==================== PAYMENT EVENTS ====================

  /// Handle payment received
  Future<void> handlePaymentReceived({
    required String userId,
    required String bookingId,
    required String carName,
    required double amount,
    required String paymentMethod,
  }) async {
    try {
      debugPrint('🔔 Creating payment received notification for user: $userId');

      await _notificationService.sendNotification(
        userId: userId,
        title: 'Payment Received!',
        message:
            'Payment of ${amount.toStringAsFixed(0)} DA received for $carName (Booking #$bookingId) via $paymentMethod',
        type: 'payment',
        data: {
          'bookingId': bookingId,
          'carName': carName,
          'amount': amount,
          'paymentMethod': paymentMethod,
        },
      );

      debugPrint('✅ Payment received notification created successfully');
    } catch (e) {
      debugPrint('❌ Failed to create payment received notification: $e');
    }
  }

  // ==================== REVIEW EVENTS ====================

  /// Handle new review submission
  Future<void> handleNewReview({
    required String carOwnerId,
    required String carId,
    required String carName,
    required String reviewerName,
    required double rating,
    String? reviewText,
  }) async {
    try {
      debugPrint(
          '🔔 Creating new review notification for car owner: $carOwnerId');

      // For delivery apps, we'll use a generic notification instead of review-specific
      await _notificationService.sendNotification(
        userId: carOwnerId,
        title: 'New Review Received! ⭐',
        message:
            '$reviewerName left a ${rating.toStringAsFixed(1)}-star review for $carName',
        type: 'review',
        data: {
          'restaurant_id': carId,
          'restaurant_name': carName,
          'reviewer_name': reviewerName,
          'rating': rating,
          'review_text': reviewText ?? '',
          'actionUrl': '/restaurants/$carId/reviews',
          'priority': 'normal',
        },
      );

      debugPrint('✅ New review notification created successfully');
    } catch (e) {
      debugPrint('❌ Failed to create new review notification: $e');
    }
  }

  // ==================== SYSTEM EVENTS ====================

  /// Handle system maintenance notifications
  Future<void> handleSystemMaintenance({
    required String title,
    required String message,
    DateTime? scheduledTime,
    DateTime? estimatedDuration,
  }) async {
    try {
      debugPrint('🔔 Creating system maintenance notification');

      await _notificationService.sendNotification(
        userId: 'system',
        title: title,
        message: message,
        type: 'system_maintenance',
        data: {
          'scheduledTime': scheduledTime?.toIso8601String(),
          'estimatedDuration': estimatedDuration?.toIso8601String(),
        },
      );

      debugPrint('✅ System maintenance notification created successfully');
    } catch (e) {
      debugPrint('❌ Failed to create system maintenance notification: $e');
    }
  }

  // ==================== PROMOTIONAL EVENTS ====================

  /// Handle promotional offer notifications
  Future<void> handlePromotionalOffer({
    required String userId,
    required String title,
    required String message,
    required String offerCode,
    DateTime? expiresAt,
    Map<String, dynamic>? offerDetails,
  }) async {
    try {
      debugPrint(
          '🔔 Creating promotional offer notification for user: $userId');

      await _notificationService.sendNotification(
        userId: userId,
        title: title,
        message: message,
        type: 'promotional_offer',
        data: {
          'offerCode': offerCode,
          'expiresAt': expiresAt?.toIso8601String(),
          'offerDetails': offerDetails,
        },
      );

      debugPrint('✅ Promotional offer notification created successfully');
    } catch (e) {
      debugPrint('❌ Failed to create promotional offer notification: $e');
    }
  }

  // ==================== BULK NOTIFICATIONS ====================

  /// Send notification to all active users
  Future<void> sendBulkNotification({
    required String title,
    required String message,
    String? type,
    String? subtype,
    String? actionUrl,
    Map<String, dynamic>? metadata,
    String? priority,
    DateTime? expiresAt,
  }) async {
    try {
      debugPrint('🔔 Sending bulk notification to all active users');

      // Get all active users
      final response = await _client
          .from('user_profiles')
          .select('user_id')
          .eq('is_active', true);

      final userIds = response.map((row) => row['user_id'] as String).toList();

      debugPrint('📊 Sending to ${userIds.length} active users');

      // Send notification to each user
      for (final userId in userIds) {
        try {
          await _notificationService.sendNotification(
            userId: userId,
            title: title,
            message: message,
            type: type ?? 'info',
            data: {
              'subtype': subtype,
              'actionUrl': actionUrl,
              'metadata': metadata,
              'priority': priority,
              'expiresAt': expiresAt?.toIso8601String(),
            },
          );
        } catch (e) {
          debugPrint('⚠️ Failed to send bulk notification to user $userId: $e');
          // Continue with other users
        }
      }

      debugPrint('✅ Bulk notification completed');
    } catch (e) {
      debugPrint('❌ Failed to send bulk notification: $e');
    }
  }

  // ==================== NOTIFICATION MANAGEMENT ====================

  /// Get notification statistics for a user
  Future<Map<String, dynamic>> getUserNotificationStats(String userId) async {
    try {
      final response = await _client
          .from('notifications')
          .select('type, read, created_at')
          .eq('user_id', userId);

      final notifications = response as List<dynamic>;

      final stats = <String, dynamic>{
        'total': notifications.length,
        'unread': notifications.where((n) => !(n['read'] ?? false)).length,
        'by_type': <String, int>{},
        'recent': notifications
            .where((n) => DateTime.parse(n['created_at'])
                .isAfter(DateTime.now().subtract(const Duration(days: 7))))
            .length,
      };

      // Count by type
      for (final notification in notifications) {
        if (notification != null) {
          final type = notification['type'] as String? ?? 'general';
          final byType = stats['by_type'] as Map<String, int>;
          byType[type] = (byType[type] ?? 0) + 1;
        }
      }

      return stats;
    } catch (e) {
      debugPrint('❌ Failed to get notification stats: $e');
      return {
        'total': 0,
        'unread': 0,
        'by_type': {},
        'recent': 0,
      };
    }
  }

  /// Clean up expired notifications
  Future<void> cleanupExpiredNotifications() async {
    try {
      debugPrint('🧹 Cleaning up expired notifications');

      final response = await _client
          .rpc('archive_old_notifications', params: {'p_days_old': 30});

      final archivedCount = response as int? ?? 0;
      debugPrint('✅ Archived $archivedCount expired notifications');
    } catch (e) {
      debugPrint('❌ Failed to cleanup expired notifications: $e');
    }
  }
}
