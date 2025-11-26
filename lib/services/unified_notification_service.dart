import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'enhanced_fcm_service.dart';
import 'notification_service.dart';
import 'socket_service.dart';

/// Unified Notification Service that combines FCM, Socket.io, and Database notifications
class UnifiedNotificationService extends ChangeNotifier {
  static final UnifiedNotificationService _instance =
      UnifiedNotificationService._internal();
  factory UnifiedNotificationService() => _instance;
  UnifiedNotificationService._internal();

  // Individual services
  final NotificationService _notificationService = NotificationService();
  final EnhancedFCMService _fcmService = EnhancedFCMService();
  final SocketService _socketService = SocketService();

  // Supabase client
  SupabaseClient get _supabase => Supabase.instance.client;

  // Subscriptions
  StreamSubscription? _fcmSubscription;
  StreamSubscription? _socketSubscription;
  StreamSubscription? _dbNotificationSubscription;

  // State
  bool _isInitialized = false;
  final List<Map<String, dynamic>> _allNotifications = [];

  // Stream controllers
  final StreamController<Map<String, dynamic>> _unifiedNotificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<List<Map<String, dynamic>>>
      _allNotificationsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<int> _unreadCountController =
      StreamController<int>.broadcast();

  // Getters
  Stream<Map<String, dynamic>> get unifiedNotificationStream =>
      _unifiedNotificationController.stream;
  Stream<List<Map<String, dynamic>>> get allNotificationsStream =>
      _allNotificationsController.stream;
  Stream<int> get unreadCountStream => _unreadCountController.stream;

  List<Map<String, dynamic>> get allNotifications =>
      List.unmodifiable(_allNotifications);
  int get unreadCount =>
      _allNotifications.where((n) => !(n['is_read'] ?? false)).length;
  bool get isInitialized => _isInitialized;

  /// Initialize all notification services
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🚀 Initializing Unified Notification Service...');

      // Initialize individual services
      await Future.wait([
        _notificationService.initialize(),
        _fcmService.initialize(),
        _socketService.initialize(),
      ]);

      // Set up cross-service integration
      _setupIntegration();

      // Load existing notifications
      await _loadAllNotifications();

      _isInitialized = true;
      debugPrint('✅ Unified Notification Service initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing Unified Notification Service: $e');
      // Don't rethrow - allow app to continue with partial functionality
    }
  }

  /// Set up integration between services
  void _setupIntegration() {
    try {
      // Listen to FCM messages and integrate with other systems
      _fcmSubscription = _fcmService.messageStream.listen((message) {
        _handleFCMMessage(message);
      });

      // Listen to Socket.io notifications
      _socketSubscription = _socketService.notificationStream.listen((data) {
        _handleSocketNotification(data);
      });

      // Listen to database notifications
      _dbNotificationSubscription =
          _notificationService.newNotificationStream.listen((notification) {
        _handleDatabaseNotification(notification);
      });

      debugPrint('✅ Notification service integration set up');
    } catch (e) {
      debugPrint('❌ Error setting up notification integration: $e');
    }
  }

  /// Handle FCM message
  Future<void> _handleFCMMessage(dynamic message) async {
    try {
      debugPrint('📨 Processing FCM message: ${message.notification?.title}');

      final notification = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': message.notification?.title ?? 'FCM Notification',
        'message': message.notification?.body ?? '',
        'type': 'fcm',
        'source': 'firebase',
        'data': message.data ?? {},
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
        'priority': 'normal',
      };

      // Add to unified notifications
      _addUnifiedNotification(notification);

      // Store in database for persistence
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _notificationService.sendNotification(
          userId: user.id,
          title: notification['title'] ?? 'Notification',
          message: notification['message'] ?? '',
          type: 'fcm',
          data: {
            'fcm_data': message.data,
            'source': 'firebase_messaging',
          },
        );
      }
    } catch (e) {
      debugPrint('❌ Error handling FCM message: $e');
    }
  }

  /// Handle Socket notification
  Future<void> _handleSocketNotification(Map<String, dynamic> data) async {
    try {
      debugPrint('🔌 Processing Socket notification: ${data['title']}');

      final notification = {
        'id': data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'title': data['title'] ?? 'Socket Notification',
        'message': data['message'] ?? '',
        'type': data['type'] ?? 'socket',
        'source': 'socket_io',
        'data': data['data'] ?? {},
        'is_read': false,
        'created_at': data['timestamp'] ?? DateTime.now().toIso8601String(),
        'priority': data['priority'] ?? 'normal',
      };

      // Add to unified notifications
      _addUnifiedNotification(notification);
    } catch (e) {
      debugPrint('❌ Error handling Socket notification: $e');
    }
  }

  /// Handle database notification
  Future<void> _handleDatabaseNotification(
      Map<String, dynamic> notification) async {
    try {
      debugPrint(
          '💾 Processing database notification: ${notification['title']}');

      final unifiedNotification = {
        'id': notification['id'],
        'title': notification['title'],
        'message': notification['message'],
        'type': notification['type'] ?? 'database',
        'source': 'supabase',
        'data': notification['data'] ?? {},
        'is_read': notification['is_read'] ?? false,
        'created_at': notification['created_at'],
        'priority': notification['priority'] ?? 'normal',
      };

      // Add to unified notifications
      _addUnifiedNotification(unifiedNotification);
    } catch (e) {
      debugPrint('❌ Error handling database notification: $e');
    }
  }

  /// Add notification to unified list
  void _addUnifiedNotification(Map<String, dynamic> notification) {
    try {
      // Check for duplicates
      final existingIndex = _allNotifications.indexWhere((n) =>
          n['id'] == notification['id'] ||
          (n['title'] == notification['title'] &&
              n['message'] == notification['message'] &&
              n['created_at'] == notification['created_at']));

      if (existingIndex == -1) {
        // Add new notification
        _allNotifications.insert(0, notification);

        // Limit to 100 notifications to prevent memory issues
        if (_allNotifications.length > 100) {
          _allNotifications.removeLast();
        }

        // Sort by creation time
        _allNotifications.sort((a, b) {
          final aTime =
              DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
          final bTime =
              DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now();
          return bTime.compareTo(aTime);
        });

        // Emit events
        _unifiedNotificationController.add(notification);
        _allNotificationsController.add(_allNotifications);
        _unreadCountController.add(unreadCount);

        notifyListeners();

        debugPrint('📝 Added unified notification: ${notification['title']}');
      }
    } catch (e) {
      debugPrint('❌ Error adding unified notification: $e');
    }
  }

  /// Load all existing notifications
  Future<void> _loadAllNotifications() async {
    try {
      debugPrint('📥 Loading all existing notifications...');

      // Load from database
      final dbNotifications = await _notificationService.fetchAll();

      // Convert to unified format
      for (final notification in dbNotifications) {
        final unifiedNotification = {
          'id': notification['id'],
          'title': notification['title'],
          'message': notification['message'],
          'type': notification['type'] ?? 'database',
          'source': 'supabase',
          'data': notification['data'] ?? {},
          'is_read': notification['is_read'] ?? false,
          'created_at': notification['created_at'],
          'priority': notification['priority'] ?? 'normal',
        };

        _allNotifications.add(unifiedNotification);
      }

      // Sort by creation time
      _allNotifications.sort((a, b) {
        final aTime =
            DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
        final bTime =
            DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now();
        return bTime.compareTo(aTime);
      });

      // Emit initial state
      _allNotificationsController.add(_allNotifications);
      _unreadCountController.add(unreadCount);

      debugPrint('✅ Loaded ${_allNotifications.length} existing notifications');
    } catch (e) {
      debugPrint('❌ Error loading existing notifications: $e');
    }
  }

  /// Send notification through all channels
  Future<bool> sendUnifiedNotification({
    required String title,
    required String body,
    String? userId,
    List<String>? userIds,
    String? type,
    Map<String, dynamic>? data,
    String? priority,
    bool sendPush = true,
    bool sendSocket = true,
    bool storeInDB = true,
  }) async {
    try {
      debugPrint('📤 Sending unified notification: $title');

      bool success = true;
      final results = <String, bool>{};

      // Store in database first
      if (storeInDB) {
        try {
          final dbSuccess = await _notificationService.sendNotification(
            userId: userId ?? 'system',
            title: title,
            message: body,
            type: type ?? 'info',
            data: data ?? {},
          );
          results['database'] = dbSuccess;
          success = success && dbSuccess;
        } catch (e) {
          debugPrint('❌ Database notification failed: $e');
          results['database'] = false;
          success = false;
        }
      }

      // Send via FCM
      if (sendPush && _fcmService.isInitialized) {
        try {
          final pushSuccess = await _fcmService.sendNotification(
            userId: userId,
            userIds: userIds,
            title: title,
            body: body,
            data: data,
          );
          results['fcm'] = pushSuccess;
          success = success && pushSuccess;
        } catch (e) {
          debugPrint('❌ FCM notification failed: $e');
          results['fcm'] = false;
        }
      }

      // Send via Socket.io
      if (sendSocket && _socketService.isConnected) {
        try {
          if (userId != null) {
            _socketService.sendNotification(
              userId,
              title,
              body,
              data: data,
            );
            results['socket'] = true;
          } else if (userIds != null) {
            for (final id in userIds) {
              _socketService.sendNotification(
                id,
                title,
                body,
                data: data,
              );
            }
            results['socket'] = true;
          }
        } catch (e) {
          debugPrint('❌ Socket notification failed: $e');
          results['socket'] = false;
        }
      }

      debugPrint('📊 Unified notification results: $results');
      return success;
    } catch (e) {
      debugPrint('❌ Error sending unified notification: $e');
      return false;
    }
  }

  /// Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      // Update local state
      final index =
          _allNotifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        _allNotifications[index]['is_read'] = true;
        _allNotificationsController.add(_allNotifications);
        _unreadCountController.add(unreadCount);
        notifyListeners();
      }

      // Update in database
      final dbSuccess = await _notificationService.markAsRead(notificationId);

      return dbSuccess;
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllAsRead() async {
    try {
      // Update local state
      for (final notification in _allNotifications) {
        notification['is_read'] = true;
      }
      _allNotificationsController.add(_allNotifications);
      _unreadCountController.add(0);
      notifyListeners();

      // Update in database
      final dbSuccess = await _notificationService.markAllAsRead();

      return dbSuccess;
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
      return false;
    }
  }

  /// Get notifications by type
  List<Map<String, dynamic>> getNotificationsByType(String type) {
    return _allNotifications.where((n) => n['type'] == type).toList();
  }

  /// Get notifications by source
  List<Map<String, dynamic>> getNotificationsBySource(String source) {
    return _allNotifications.where((n) => n['source'] == source).toList();
  }

  /// Get unread notifications
  List<Map<String, dynamic>> getUnreadNotifications() {
    return _allNotifications.where((n) => !(n['is_read'] ?? false)).toList();
  }

  /// Search notifications
  List<Map<String, dynamic>> searchNotifications(String query) {
    final lowerQuery = query.toLowerCase();
    return _allNotifications.where((n) {
      final title = (n['title'] ?? '').toString().toLowerCase();
      final message = (n['message'] ?? '').toString().toLowerCase();
      return title.contains(lowerQuery) || message.contains(lowerQuery);
    }).toList();
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    try {
      _allNotifications.clear();
      _allNotificationsController.add(_allNotifications);
      _unreadCountController.add(0);
      notifyListeners();

      // Clear from database
      await _notificationService.clearAllNotifications();

      debugPrint('🗑️ All notifications cleared');
    } catch (e) {
      debugPrint('❌ Error clearing notifications: $e');
    }
  }

  /// Get service status
  Map<String, dynamic> getServiceStatus() {
    return {
      'unified_service': _isInitialized,
      'fcm_service': _fcmService.isInitialized,
      'socket_service': _socketService.isConnected,
      'notification_service': _notificationService.isInitialized,
      'total_notifications': _allNotifications.length,
      'unread_count': unreadCount,
      'fcm_token': _fcmService.fcmToken != null,
    };
  }

  @override
  void dispose() {
    _fcmSubscription?.cancel();
    _socketSubscription?.cancel();
    _dbNotificationSubscription?.cancel();
    _unifiedNotificationController.close();
    _allNotificationsController.close();
    _unreadCountController.close();
    super.dispose();
  }
}
