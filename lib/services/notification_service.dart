import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'context_aware_service.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Context-aware service for tracking
  final ContextAwareService _contextAware = ContextAwareService();

  // Stream controllers
  final StreamController<List<Map<String, dynamic>>> _notificationsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<int> _unreadCountController =
      StreamController<int>.broadcast();
  final StreamController<Map<String, dynamic>> _newNotificationController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Getters for streams
  Stream<List<Map<String, dynamic>>> get notificationsStream =>
      _notificationsController.stream;
  Stream<int> get unreadCountStream => _unreadCountController.stream;
  Stream<Map<String, dynamic>> get newNotificationStream =>
      _newNotificationController.stream;

  // Cached data
  final List<Map<String, dynamic>> _notifications = [];
  final int _unreadCount = 0;
  bool _isInitialized = false;

  // Enhanced real-time subscriptions
  StreamSubscription? _socketNotificationSubscription;

  // Getters for cached data
  List<Map<String, dynamic>> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isInitialized => _isInitialized;

  /// Fetch all notifications (for compatibility with unified service)
  Future<List<Map<String, dynamic>>> fetchAll() async {
    try {
      return List<Map<String, dynamic>>.from(_notifications);
    } catch (e) {
      debugPrint('❌ Error fetching notifications: $e');
      return [];
    }
  }

  /// Mark a single notification as read (for compatibility)
  Future<bool> markAsRead(String notificationId) async {
    try {
      final index = _notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        _notifications[index]['is_read'] = true;
        _notificationsController.add(_notifications);
        _newNotificationController.add(_notifications[index]);
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark all notifications as read (for compatibility)
  Future<bool> markAllAsRead() async {
    try {
      for (final n in _notifications) {
        n['is_read'] = true;
      }
      _notificationsController.add(_notifications);
      _unreadCountController.add(0);
      return true;
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
      return false;
    }
  }

  /// Clear all notifications (for compatibility)
  Future<void> clearAllNotifications() async {
    try {
      _notifications.clear();
      _notificationsController.add(_notifications);
      _unreadCountController.add(0);
    } catch (e) {
      debugPrint('❌ Error clearing notifications: $e');
    }
  }

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _contextAware.initialize();
      await _loadNotifications();
      _isInitialized = true;
      debugPrint('🚀 NotificationService initialized');
    } catch (e) {
      debugPrint('❌ Error initializing NotificationService: $e');
    }
  }

  /// Load notifications from backend
  Future<void> _loadNotifications() async {
    try {
      // This would be called with actual user ID in real implementation
      // For now, we'll use a placeholder
      debugPrint('📱 Loading notifications...');
    } catch (e) {
      debugPrint('❌ Error loading notifications: $e');
    }
  }

  /// Get user notifications using Node.js backend
  Future<Map<String, dynamic>> getUserNotificationsFromBackend({
    required String userId,
    bool unreadOnly = false,
    String? type,
    int limit = 50,
  }) async {
    try {
      final response = await ApiClient.get(
          '/api/business/notifications/$userId',
          queryParameters: {
            'unreadOnly': unreadOnly.toString(),
            'type': type ?? '',
            'limit': limit.toString(),
          });

      if (!response['success']) {
        throw Exception('Failed to load notifications: ${response['error']}');
      }

      return response['data'];
    } catch (e) {
      debugPrint('❌ Error loading notifications from backend: $e');
      throw Exception('Failed to load notifications: $e');
    }
  }

  /// Mark notifications as read using Node.js backend
  Future<bool> markNotificationsAsReadFromBackend({
    required String userId,
    List<String>? notificationIds,
  }) async {
    try {
      final response = await ApiClient.post(
          '/api/business/notifications/$userId/read',
          data: {
            'notificationIds': notificationIds,
          });

      if (!response['success']) {
        throw Exception(
            'Failed to mark notifications as read: ${response['error']}');
      }

      // Update local state
      if (notificationIds != null && notificationIds.isNotEmpty) {
        for (final notification in _notifications) {
          if (notificationIds.contains(notification['id'])) {
            notification['is_read'] = true;
          }
        }
      } else {
        // Mark all as read
        for (final notification in _notifications) {
          notification['is_read'] = true;
        }
      }

      _notificationsController.add(_notifications);

      return true;
    } catch (e) {
      debugPrint('❌ Error marking notifications as read: $e');
      return false;
    }
  }

  /// Send notification using Node.js backend
  Future<bool> sendNotificationFromBackend({
    required String userId,
    required String title,
    required String message,
    String type = 'info',
    Map<String, dynamic> data = const {},
  }) async {
    try {
      final response =
          await ApiClient.post('/api/business/notifications/send', data: {
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'data': data,
      });

      if (!response['success']) {
        throw Exception('Failed to send notification: ${response['error']}');
      }

      // Add to local notifications if it's for the current user
      final newNotification = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': title,
        'message': message,
        'type': type,
        'data': data,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      _notifications.insert(0, newNotification);
      _notificationsController.add(_notifications);
      _newNotificationController.add(newNotification);

      return true;
    } catch (e) {
      debugPrint('❌ Error sending notification: $e');
      return false;
    }
  }

  /// Send notification (legacy method name)
  Future<bool> sendNotification({
    required String userId,
    required String title,
    required String message,
    String type = 'info',
    Map<String, dynamic> data = const {},
  }) async {
    return sendNotificationFromBackend(
      userId: userId,
      title: title,
      message: message,
      type: type,
      data: data,
    );
  }

  /// Notify user signup (legacy method name)
  Future<bool> notifyUserSignup({
    required String userId,
    required String userName,
    required String userEmail,
  }) async {
    return sendNotificationFromBackend(
      userId: userId,
      title: 'Welcome to Sahla!',
      message: 'Welcome $userName! Your account has been created successfully.',
      type: 'welcome',
      data: {
        'userName': userName,
        'userEmail': userEmail,
        'signupDate': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Notify email verification
  Future<bool> notifyEmailVerification({
    required String userId,
    required bool isVerified,
    required String userEmail,
  }) async {
    return sendNotificationFromBackend(
      userId: userId,
      title: isVerified ? 'Email Verified!' : 'Email Verification Required',
      message: isVerified
          ? 'Your email $userEmail has been successfully verified.'
          : 'Please verify your email address: $userEmail',
      type: 'verification',
      data: {
        'userEmail': userEmail,
        'verificationType': 'email',
        'isVerified': isVerified,
      },
    );
  }

  /// Notify phone verification
  Future<bool> notifyPhoneVerification({
    required String userId,
    required bool isVerified,
    required String phoneNumber,
  }) async {
    return sendNotificationFromBackend(
      userId: userId,
      title: isVerified ? 'Phone Verified!' : 'Phone Verification Required',
      message: isVerified
          ? 'Your phone number $phoneNumber has been successfully verified.'
          : 'Please verify your phone number: $phoneNumber',
      type: 'verification',
      data: {
        'phoneNumber': phoneNumber,
        'verificationType': 'phone',
        'isVerified': isVerified,
      },
    );
  }

  /// Notify host request submitted
  Future<bool> notifyHostRequestSubmitted({
    required String userId,
    required String requestId,
    required String businessName,
  }) async {
    return sendNotificationFromBackend(
      userId: userId,
      title: 'Host Request Submitted',
      message:
          'Your request to host "$businessName" has been submitted for review.',
      type: 'host_request',
      data: {
        'requestId': requestId,
        'businessName': businessName,
        'status': 'submitted',
      },
    );
  }

  /// Notify host request approved
  Future<bool> notifyHostRequestApproved({
    required String userId,
    required String requestId,
    required String businessName,
    String? approvalNotes,
  }) async {
    return sendNotificationFromBackend(
      userId: userId,
      title: 'Host Request Approved!',
      message:
          'Congratulations! Your request to host "$businessName" has been approved. ${approvalNotes ?? ''}',
      type: 'host_request',
      data: {
        'requestId': requestId,
        'businessName': businessName,
        'status': 'approved',
        'approvalNotes': approvalNotes,
      },
    );
  }

  /// Notify host request rejected
  Future<bool> notifyHostRequestRejected({
    required String userId,
    required String requestId,
    required String businessName,
    String? reason,
  }) async {
    return sendNotificationFromBackend(
      userId: userId,
      title: 'Host Request Update',
      message:
          'Your request to host "$businessName" was not approved. ${reason ?? 'Please contact support for more information.'}',
      type: 'host_request',
      data: {
        'requestId': requestId,
        'businessName': businessName,
        'status': 'rejected',
        'reason': reason,
      },
    );
  }

  /// Notify car approval
  Future<bool> notifyCarApproval({
    required String userId,
    required String carModel,
  }) async {
    return sendNotificationFromBackend(
      userId: userId,
      title: 'Car Approved!',
      message: 'Your $carModel has been approved for delivery service.',
      type: 'car_approval',
      data: {
        'carModel': carModel,
        'status': 'approved',
      },
    );
  }

  /// Notify new order
  Future<bool> notifyNewOrder({
    required String userId,
    required String orderId,
    required String restaurantName,
    required double totalAmount,
  }) async {
    return sendNotificationFromBackend(
      userId: userId,
      title: 'New Order Received!',
      message:
          'You have a new order from $restaurantName for ${totalAmount.toStringAsFixed(0)} DA',
      type: 'new_order',
      data: {
        'orderId': orderId,
        'restaurantName': restaurantName,
        'totalAmount': totalAmount,
      },
    );
  }

  /// Notify order confirmed
  Future<bool> notifyOrderConfirmed({
    required String userId,
    required String orderId,
    required String restaurantName,
  }) async {
    return sendNotificationFromBackend(
      userId: userId,
      title: 'Order Confirmed!',
      message:
          'Your order from $restaurantName has been confirmed and is being prepared.',
      type: 'order_confirmed',
      data: {
        'orderId': orderId,
        'restaurantName': restaurantName,
        'status': 'confirmed',
      },
    );
  }

  /// Notify payment received
  Future<bool> notifyPaymentReceived({
    required String userId,
    required String orderId,
    required double amount,
  }) async {
    return sendNotificationFromBackend(
      userId: userId,
      title: 'Payment Received!',
      message:
          'Payment of ${amount.toStringAsFixed(0)} DA has been received for order #$orderId',
      type: 'payment',
      data: {
        'orderId': orderId,
        'amount': amount,
        'status': 'received',
      },
    );
  }

  /// Dispose of the service
  @override
  void dispose() {
    _socketNotificationSubscription?.cancel();
    _notificationsController.close();
    _unreadCountController.close();
    _newNotificationController.close();
    super.dispose();
  }
}
