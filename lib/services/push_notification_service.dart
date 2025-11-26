import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../config/push_config.dart';
import '../firebase_options.dart';
import '../models/push_notification.dart' as models;
import '../services/settings_service.dart';
import '../utils/notification_ui_helpers.dart';

class PushNotificationService extends ChangeNotifier {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final _client = Supabase.instance.client;

  // Firebase init guard to avoid repeated failures/log spam when config is missing
  static bool _firebaseInitAttempted = false;
  static bool _firebaseInitSucceeded = false;

  // Local notifications plugin
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Storage for notifications
  final List<models.PushNotification> _notifications = [];
  models.NotificationSettings _settings = const models.NotificationSettings();

  // Stream controllers
  final StreamController<models.PushNotification> _notificationController =
      StreamController<models.PushNotification>.broadcast();
  final StreamController<List<models.PushNotification>>
      _notificationsListController =
      StreamController<List<models.PushNotification>>.broadcast();
  final StreamController<int> _unreadCountController =
      StreamController<int>.broadcast();

  // Getters for streams
  Stream<models.PushNotification> get notificationStream =>
      _notificationController.stream;
  Stream<List<models.PushNotification>> get notificationsListStream =>
      _notificationsListController.stream;
  Stream<int> get unreadCountStream => _unreadCountController.stream;

  // FCM token and initialization
  String? _fcmToken;
  bool _isInitialized = false;
  FirebaseMessaging? _firebaseMessaging;

  // Getters
  List<models.PushNotification> get notifications =>
      List.unmodifiable(_notifications);
  models.NotificationSettings get settings => _settings;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;

  // Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone data
      tz.initializeTimeZones();

      // Initialize Firebase and FCM
      if (PushConfig.useFcm) {
        await _initializeFirebase();
        await initializeAndRegisterToken();
      }

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Create notification channels
      await _createNotificationChannels();

      // Load settings
      await _loadSettings();

      // Set up message handlers
      await _setupMessageHandlers();

      // Load existing notifications from storage
      await _loadStoredNotifications();

      _isInitialized = true;

      // Emit initial state
      _notificationsListController.add(_notifications);
      _unreadCountController.add(unreadCount);

      debugPrint('✅ PushNotificationService initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize PushNotificationService: $e');
      rethrow;
    }
  }

  /// Initialize Firebase Core
  Future<void> _initializeFirebase() async {
    if (!PushConfig.useFcm) return;

    if (!_firebaseInitAttempted) {
      _firebaseInitAttempted = true;
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }
        _firebaseInitSucceeded = true;
        debugPrint('✅ Firebase initialized successfully');
      } catch (e) {
        debugPrint('❌ Firebase initialization failed: $e');
        _firebaseInitSucceeded = false;
        rethrow;
      }
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    debugPrint('✅ Local notifications initialized');
  }

  /// Set up Firebase message handlers
  Future<void> _setupMessageHandlers() async {
    if (!PushConfig.useFcm || _firebaseMessaging == null) return;

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle notification tap when app is terminated
    final initialMessage = await _firebaseMessaging!.getInitialMessage();
    if (initialMessage != null) {
      unawaited(_handleNotificationTap(initialMessage));
    }

    debugPrint('✅ Firebase message handlers set up');
  }

  Future<void> initializeAndRegisterToken() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (!PushConfig.useFcm) return;

    if (!_firebaseInitSucceeded) {
      debugPrint('⚠️ Firebase not initialized, skipping token registration');
      return;
    }

    try {
      _firebaseMessaging = FirebaseMessaging.instance;

      // Request permission with proper handling
      final settings = await _firebaseMessaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        criticalAlert: false,
        announcement: false,
        carPlay: false,
      );

      // Persist notification preference
      try {
        final granted =
            settings.authorizationStatus == AuthorizationStatus.authorized ||
                settings.authorizationStatus == AuthorizationStatus.provisional;
        await SettingsService().setNotificationsEnabled(granted);
      } catch (_) {}

      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        debugPrint('⚠️ Notification permission denied');
        return;
      }

      // Get FCM token
      _fcmToken = await _firebaseMessaging!.getToken();
      if (_fcmToken == null || _fcmToken!.isEmpty) {
        debugPrint('⚠️ Failed to get FCM token');
        return;
      }

      debugPrint('📱 FCM Token: $_fcmToken');

      // Register token with Supabase
      await _registerTokenWithSupabase(_fcmToken!);

      // Listen for token refresh
      _firebaseMessaging!.onTokenRefresh.listen(_onTokenRefresh);

      debugPrint('✅ FCM token registered successfully');
    } catch (e) {
      debugPrint('❌ Error registering FCM token: $e');
      rethrow;
    }
  }

  /// Register FCM token with Supabase
  Future<void> _registerTokenWithSupabase(String token) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('⚠️ No authenticated user, skipping token registration');
        return;
      }

      final platform = Platform.isAndroid ? 'android' : 'ios';
      final locale =
          WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag();

      await _client.from('user_device_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': platform,
        'locale': locale,
        'is_active': true,
        'last_seen_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Token registered with Supabase');
    } catch (e) {
      debugPrint('❌ Error registering token with Supabase: $e');
    }
  }

  /// Handle token refresh
  Future<void> _onTokenRefresh(String newToken) async {
    try {
      _fcmToken = newToken;
      await _registerTokenWithSupabase(newToken);
      debugPrint('🔄 FCM token refreshed');
    } catch (e) {
      debugPrint('❌ Error refreshing FCM token: $e');
    }
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📱 Received foreground message: ${message.messageId}');

    final notification = _createNotificationFromMessage(message);
    if (notification != null) {
      _addNotification(notification);
      await _showLocalNotification(notification);
    }
  }

  /// Handle notification tap
  Future<void> _handleNotificationTap(RemoteMessage message) async {
    debugPrint('👆 Notification tapped: ${message.messageId}');

    final notification = _createNotificationFromMessage(message);
    if (notification != null) {
      _addNotification(notification);
      await handleNotificationTap(notification.id);
    }
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('👆 Local notification tapped: ${response.id}');

    if (response.payload != null) {
      final notificationId = response.payload!;
      handleNotificationTap(notificationId);
    }
  }

  /// Create notification from Firebase message
  models.PushNotification? _createNotificationFromMessage(
      RemoteMessage message) {
    try {
      final data = message.data;
      final notification = message.notification;

      if (notification == null) return null;

      return models.PushNotification(
        id: message.messageId ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: notification.title ?? 'Notification',
        body: notification.body ?? '',
        type: _getNotificationTypeFromData(data),
        priority: _getNotificationPriorityFromData(data),
        timestamp: DateTime.now(),
        data: data,
        imageUrl:
            notification.android?.imageUrl ?? notification.apple?.imageUrl,
        actionUrl: data['action_url'],
        actions: _getNotificationActionsFromData(data),
      );
    } catch (e) {
      debugPrint('❌ Error creating notification from message: $e');
      return null;
    }
  }

  /// Get notification type from message data
  models.NotificationType _getNotificationTypeFromData(
      Map<String, dynamic> data) {
    final typeString = data['type'] as String?;
    switch (typeString) {
      case 'order':
        return models.NotificationType.order;
      case 'message':
        return models.NotificationType.message;
      case 'payment':
        return models.NotificationType.payment;
      case 'reminder':
        return models.NotificationType.reminder;
      case 'promotion':
        return models.NotificationType.promotion;
      case 'delivery':
        return models.NotificationType.delivery;
      case 'system':
        return models.NotificationType.system;
      default:
        return models.NotificationType.system; // Fallback for unknown types
    }
  }

  /// Get notification priority from message data
  models.NotificationPriority _getNotificationPriorityFromData(
      Map<String, dynamic> data) {
    final priorityString = data['priority'] as String?;
    switch (priorityString) {
      case 'high':
        return models.NotificationPriority.high;
      case 'urgent':
        return models.NotificationPriority.urgent;
      case 'low':
        return models.NotificationPriority.low;
      case 'normal':
        return models.NotificationPriority.normal;
      default:
        return models
            .NotificationPriority.normal; // Fallback for unknown priorities
    }
  }

  /// Get notification actions from message data
  List<models.NotificationAction> _getNotificationActionsFromData(
      Map<String, dynamic> data) {
    try {
      final actionsData = data['actions'] as List?;
      if (actionsData == null) return [];

      return actionsData.map((action) {
        return models.NotificationAction(
          id: action['id'] as String? ?? '',
          title: action['title'] as String? ?? '',
          actionUrl: action['action_url'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Error parsing notification actions: $e');
      return [];
    }
  }

  /// Load stored notifications from Supabase
  Future<void> _loadStoredNotifications() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _client
          .from('user_notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      _notifications.clear();
      for (final data in response) {
        final notification = models.PushNotification.fromMap(data);
        _notifications.add(notification);
      }

      _sortNotifications();
      debugPrint('✅ Loaded ${_notifications.length} stored notifications');
    } catch (e) {
      debugPrint('❌ Error loading stored notifications: $e');
    }
  }

  /// Store notification in Supabase
  Future<void> _storeNotification(models.PushNotification notification) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      await _client.from('user_notifications').insert({
        'id': notification.id,
        'user_id': userId,
        'title': notification.title,
        'body': notification.body,
        'type': notification.type.name,
        'priority': notification.priority.name,
        'data': notification.data,
        'is_read': notification.isRead,
        'image_url': notification.imageUrl,
        'action_url': notification.actionUrl,
        'actions': notification.actions.map((a) => a.toMap()).toList(),
        'created_at': notification.timestamp.toIso8601String(),
      });
    } catch (e) {
      debugPrint('❌ Error storing notification: $e');
    }
  }

  Future<void> _createNotificationChannels() async {
    if (Platform.isAndroid) {
      // Use NotificationUIHelpers to get default channels
      final channels = NotificationUIHelpers.getDefaultChannels();

      for (final channel in channels) {
        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(
              AndroidNotificationChannel(
                channel.id,
                channel.name,
                description: channel.description,
                importance: _getImportance(channel.importance),
                playSound: true,
              ),
            );
      }

      debugPrint('✅ Notification channels created using NotificationUIHelpers');
    }
  }

  Future<void> _loadSettings() async {
    // In a real app, load from SharedPreferences or secure storage
    // For now, use default settings
    _settings = const models.NotificationSettings();
  }

  Future<void> _saveSettings() async {
    // In a real app, save to SharedPreferences or secure storage
    debugPrint('Notification settings saved');
    notifyListeners();
  }

  // Send a notification
  Future<void> sendNotification(models.PushNotification notification) async {
    // Respect user preference from SettingsService
    if (!SettingsService().notificationsEnabled) {
      debugPrint('⚠️ Notifications disabled by user settings');
      return;
    }

    if (!_settings.isNotificationTypeEnabled(notification.type)) {
      debugPrint('⚠️ Notification type ${notification.type} is disabled');
      return;
    }

    // Check quiet hours using NotificationUIHelpers
    final isQuietHours = NotificationUIHelpers.isInQuietHours(
        _settings.quietHoursStart, _settings.quietHoursEnd);

    if (isQuietHours &&
        notification.priority != models.NotificationPriority.urgent) {
      debugPrint('🔇 Notification suppressed due to quiet hours');
      return;
    }

    _addNotification(notification);
    await _storeNotification(notification);

    // Show local notification
    await _showLocalNotification(notification);

    // Vibrate if enabled
    if (_settings.vibrationEnabled) {
      await _vibrate();
    }
  }

  void _addNotification(models.PushNotification notification) {
    _notifications.insert(0, notification);
    _sortNotifications();

    // Emit events
    _notificationController.add(notification);
    _notificationsListController.add(_notifications);
    _unreadCountController.add(unreadCount);

    notifyListeners();
  }

  Future<void> _showLocalNotification(
      models.PushNotification notification) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        _getChannelId(notification.type),
        _getChannelName(notification.type),
        channelDescription: _getChannelDescription(notification.type),
        importance: _getImportance(notification.priority),
        priority: _getPriority(notification.priority),
        icon: '@mipmap/ic_launcher',
        largeIcon: null, // Image loading temporarily disabled
        actions: notification.actions
            .map((action) => AndroidNotificationAction(
                  action.id,
                  action.title,
                  icon: const DrawableResourceAndroidBitmap(
                      '@drawable/ic_notification'),
                ))
            .toList(),
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        badgeNumber: unreadCount,
        attachments: notification.imageUrl != null
            ? [DarwinNotificationAttachment(notification.imageUrl!)]
            : null,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        notification.id.hashCode,
        notification.title,
        notification.body,
        details,
        payload: notification.id,
      );

      debugPrint('✅ Local notification displayed: ${notification.title}');
    } catch (e) {
      debugPrint('❌ Failed to show local notification: $e');
    }
  }

  /// Get channel ID for notification type
  String _getChannelId(models.NotificationType type) {
    switch (type) {
      case models.NotificationType.order:
        return 'orders';
      case models.NotificationType.delivery:
        return 'delivery';
      case models.NotificationType.promotion:
        return 'promotions';
      case models.NotificationType.message:
      case models.NotificationType.payment:
      case models.NotificationType.reminder:
      case models.NotificationType.system:
        return 'system';
    }
  }

  /// Get channel name for notification type
  String _getChannelName(models.NotificationType type) {
    switch (type) {
      case models.NotificationType.order:
        return 'Order Notifications';
      case models.NotificationType.delivery:
        return 'Delivery Updates';
      case models.NotificationType.promotion:
        return 'Promotions';
      case models.NotificationType.message:
      case models.NotificationType.payment:
      case models.NotificationType.reminder:
      case models.NotificationType.system:
        return 'System Notifications';
    }
  }

  /// Get channel description for notification type
  String _getChannelDescription(models.NotificationType type) {
    switch (type) {
      case models.NotificationType.order:
        return 'Notifications about your food orders';
      case models.NotificationType.delivery:
        return 'Real-time delivery tracking updates';
      case models.NotificationType.promotion:
        return 'Special offers and promotions';
      case models.NotificationType.message:
      case models.NotificationType.payment:
      case models.NotificationType.reminder:
      case models.NotificationType.system:
        return 'App updates and system messages';
    }
  }

  /// Get importance level for priority
  Importance _getImportance(models.NotificationPriority priority) {
    switch (priority) {
      case models.NotificationPriority.urgent:
        return Importance.max;
      case models.NotificationPriority.high:
        return Importance.high;
      case models.NotificationPriority.normal:
        return Importance.defaultImportance;
      case models.NotificationPriority.low:
        return Importance.low;
    }
  }

  /// Get priority level for priority
  Priority _getPriority(models.NotificationPriority priority) {
    switch (priority) {
      case models.NotificationPriority.urgent:
        return Priority.max;
      case models.NotificationPriority.high:
        return Priority.high;
      case models.NotificationPriority.normal:
        return Priority.defaultPriority;
      case models.NotificationPriority.low:
        return Priority.low;
    }
  }

  Future<void> _vibrate() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('Vibration failed: $e');
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);

      _notificationsListController.add(_notifications);
      _unreadCountController.add(unreadCount);
      notifyListeners();
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    bool hasChanges = false;
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
        hasChanges = true;
      }
    }

    if (hasChanges) {
      _notificationsListController.add(_notifications);
      _unreadCountController.add(unreadCount);
      notifyListeners();
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications.removeAt(index);

      _notificationsListController.add(_notifications);
      _unreadCountController.add(unreadCount);
      notifyListeners();
    }
  }

  // Clear all notifications
  Future<void> clearAllNotifications() async {
    _notifications.clear();

    _notificationsListController.add(_notifications);
    _unreadCountController.add(unreadCount);
    notifyListeners();
  }

  // Update settings
  Future<void> updateSettings(models.NotificationSettings newSettings) async {
    _settings = newSettings;
    await _saveSettings();
  }

  // Get notifications by type
  List<models.PushNotification> getNotificationsByType(
      models.NotificationType type) {
    return _notifications.where((n) => n.type == type).toList();
  }

  // Get unread notifications
  List<models.PushNotification> getUnreadNotifications() {
    return _notifications.where((n) => !n.isRead).toList();
  }

  // Search notifications
  List<models.PushNotification> searchNotifications(String query) {
    final lowerQuery = query.toLowerCase();
    return _notifications.where((n) {
      return n.title.toLowerCase().contains(lowerQuery) ||
          n.body.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  void _sortNotifications() {
    _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  // Handle notification tap
  Future<void> handleNotificationTap(String notificationId) async {
    await markAsRead(notificationId);

    final notification = _notifications.firstWhere(
      (n) => n.id == notificationId,
      orElse: () => models.PushNotification(
        id: '',
        title: '',
        body: '',
        type: models.NotificationType.system,
        timestamp: DateTime.now(),
      ),
    );

    if (notification.id.isNotEmpty && notification.actionUrl != null) {
      // In a real app, navigate to the appropriate screen
      debugPrint('Navigating to: ${notification.actionUrl}');
    }
  }

  // Handle notification action
  Future<void> handleNotificationAction(
      String notificationId, String actionId) async {
    await markAsRead(notificationId);

    final notification = _notifications.firstWhere(
      (n) => n.id == notificationId,
      orElse: () => models.PushNotification(
        id: '',
        title: '',
        body: '',
        type: models.NotificationType.system,
        timestamp: DateTime.now(),
      ),
    );

    final action = notification.actions.firstWhere(
      (a) => a.id == actionId,
      orElse: () => const models.NotificationAction(id: '', title: ''),
    );

    if (action.id.isNotEmpty && action.actionUrl != null) {
      // In a real app, navigate to the appropriate screen
      debugPrint('Executing action: ${action.title} -> ${action.actionUrl}');
    }
  }

  // Request permissions
  Future<bool> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.notification.request();
        return status.isGranted;
      } else if (Platform.isIOS) {
        if (_firebaseMessaging != null) {
          final settings = await _firebaseMessaging!.requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          );
          return settings.authorizationStatus ==
                  AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
      return false;
    }
  }

  // Check if permissions are granted
  Future<bool> arePermissionsGranted() async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        return status.isGranted;
      } else if (Platform.isIOS) {
        if (_firebaseMessaging != null) {
          final settings = await _firebaseMessaging!.getNotificationSettings();
          return settings.authorizationStatus ==
                  AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error checking permissions: $e');
      return false;
    }
  }

  // Schedule a notification
  Future<void> scheduleNotification({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    models.NotificationType type = models.NotificationType.reminder,
    Map<String, dynamic>? data,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        _getChannelId(type),
        _getChannelName(type),
        channelDescription: _getChannelDescription(type),
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.zonedSchedule(
        id.hashCode,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        details,
        payload: id,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      debugPrint('✅ Notification scheduled: $title for $scheduledTime');
    } catch (e) {
      debugPrint('❌ Error scheduling notification: $e');
    }
  }

  // Cancel scheduled notification
  Future<void> cancelScheduledNotification(String id) async {
    try {
      await _localNotifications.cancel(id.hashCode);
      debugPrint('✅ Cancelled scheduled notification: $id');
    } catch (e) {
      debugPrint('❌ Error cancelling scheduled notification: $e');
    }
  }

  @override
  void dispose() {
    _notificationController.close();
    _notificationsListController.close();
    _unreadCountController.close();
    super.dispose();
  }
}

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📱 Background message received: ${message.messageId}');

  // Initialize Firebase if not already done
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL', // Replace with actual URL
    anonKey: 'YOUR_SUPABASE_ANON_KEY', // Replace with actual key
  );

  // Store notification in database
  try {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    if (userId != null) {
      await client.from('user_notifications').insert({
        'id': message.messageId ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        'user_id': userId,
        'title': message.notification?.title ?? 'Notification',
        'body': message.notification?.body ?? '',
        'type': message.data['type'] ?? 'system',
        'priority': message.data['priority'] ?? 'normal',
        'data': message.data,
        'is_read': false,
        'image_url': message.notification?.android?.imageUrl ??
            message.notification?.apple?.imageUrl,
        'action_url': message.data['action_url'],
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  } catch (e) {
    debugPrint('❌ Error storing background notification: $e');
  }
}
