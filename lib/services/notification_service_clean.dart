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
