import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../firebase_options.dart';

/// Enhanced FCM Service with Supabase integration
class EnhancedFCMService extends ChangeNotifier {
  static final EnhancedFCMService _instance = EnhancedFCMService._internal();
  factory EnhancedFCMService() => _instance;
  EnhancedFCMService._internal();

  FirebaseMessaging? _messaging;
  FlutterLocalNotificationsPlugin? _localNotifications;
  SupabaseClient get _supabase => Supabase.instance.client;

  bool _isInitialized = false;
  String? _fcmToken;

  // Stream controllers
  final StreamController<RemoteMessage> _messageController =
      StreamController<RemoteMessage>.broadcast();
  final StreamController<String> _tokenController =
      StreamController<String>.broadcast();

  // Getters
  Stream<RemoteMessage> get messageStream => _messageController.stream;
  Stream<String> get tokenStream => _tokenController.stream;
  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;

  /// Initialize FCM with Supabase integration
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🚀 Initializing Enhanced FCM Service...');

      // Initialize Firebase
      await _initializeFirebase();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Initialize FCM
      await _initializeFCM();

      // Set up message handlers
      _setupMessageHandlers();

      // Register token with Supabase
      await _registerTokenWithSupabase();

      _isInitialized = true;
      debugPrint('✅ Enhanced FCM Service initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing Enhanced FCM Service: $e');
      // Don't rethrow - allow app to continue without FCM
    }
  }

  /// Initialize Firebase
  Future<void> _initializeFirebase() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('✅ Firebase initialized');
      }
    } catch (e) {
      debugPrint('❌ Firebase initialization failed: $e');
      rethrow;
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    try {
      _localNotifications = FlutterLocalNotificationsPlugin();

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

      await _localNotifications!.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // Create notification channels
      await _createNotificationChannels();

      debugPrint('✅ Local notifications initialized');
    } catch (e) {
      debugPrint('❌ Local notifications initialization failed: $e');
      rethrow;
    }
  }

  /// Initialize FCM
  Future<void> _initializeFCM() async {
    try {
      _messaging = FirebaseMessaging.instance;

      // Request permissions
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        criticalAlert: false,
        announcement: false,
      );

      debugPrint('📱 FCM Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get FCM token
        _fcmToken = await _messaging!.getToken();
        if (_fcmToken != null) {
          debugPrint(
              '📱 FCM Token obtained: ${_fcmToken!.substring(0, 20)}...');
          _tokenController.add(_fcmToken!);
        }

        // Listen for token refresh
        _messaging!.onTokenRefresh.listen((token) {
          debugPrint('🔄 FCM Token refreshed');
          _fcmToken = token;
          _tokenController.add(token);
          _registerTokenWithSupabase();
        });
      } else {
        debugPrint('❌ FCM permissions denied');
      }
    } catch (e) {
      debugPrint('❌ FCM initialization failed: $e');
      rethrow;
    }
  }

  /// Set up message handlers
  void _setupMessageHandlers() {
    if (_messaging == null) return;

    try {
      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📨 Foreground FCM message: ${message.notification?.title}');
        _messageController.add(message);
        _showLocalNotification(message);
      });

      // Handle message tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint(
            '📱 FCM message tapped (background): ${message.notification?.title}');
        _messageController.add(message);
        _handleMessageTap(message);
      });

      // Handle message tap when app is terminated
      FirebaseMessaging.instance
          .getInitialMessage()
          .then((RemoteMessage? message) {
        if (message != null) {
          debugPrint(
              '📱 FCM message tapped (terminated): ${message.notification?.title}');
          _messageController.add(message);
          _handleMessageTap(message);
        }
      });

      debugPrint('✅ FCM message handlers set up');
    } catch (e) {
      debugPrint('❌ Error setting up FCM message handlers: $e');
    }
  }

  /// Register FCM token with Supabase
  Future<void> _registerTokenWithSupabase() async {
    if (_fcmToken == null) {
      debugPrint('⚠️ No FCM token to register');
      return;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ No authenticated user for FCM token registration');
        return;
      }

      final platform = Platform.isAndroid ? 'android' : 'ios';
      final locale = Platform.localeName;

      // Check if table exists, if not create it
      await _ensureTokenTableExists();

      await _supabase.from('user_device_tokens').upsert({
        'user_id': user.id,
        'token': _fcmToken,
        'platform': platform,
        'locale': locale,
        'is_active': true,
        'last_seen_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ FCM token registered with Supabase');
    } catch (e) {
      debugPrint('❌ Error registering FCM token with Supabase: $e');
      // Don't rethrow - token registration failure shouldn't break the app
    }
  }

  /// Ensure the user_device_tokens table exists
  Future<void> _ensureTokenTableExists() async {
    try {
      // Try to query the table to check if it exists
      await _supabase.from('user_device_tokens').select('id').limit(1);
    } catch (e) {
      debugPrint(
          '⚠️ user_device_tokens table may not exist. Please create it in Supabase.');
      debugPrint('📋 SQL to create table:');
      debugPrint('''
CREATE TABLE user_device_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
    locale TEXT DEFAULT 'en',
    is_active BOOLEAN DEFAULT true,
    last_seen_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
      ''');
    }
  }

  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    if (!Platform.isAndroid) return;

    try {
      const channels = [
        AndroidNotificationChannel(
          'default',
          'Default Notifications',
          description: 'Default notification channel',
          importance: Importance.high,
        ),
        AndroidNotificationChannel(
          'orders',
          'Order Updates',
          description: 'Notifications about order status changes',
          importance: Importance.high,
        ),
        AndroidNotificationChannel(
          'messages',
          'Messages',
          description: 'Chat messages and communications',
          importance: Importance.high,
        ),
        AndroidNotificationChannel(
          'promotions',
          'Promotions',
          description: 'Special offers and promotions',
          importance: Importance.defaultImportance,
        ),
      ];

      final androidImplementation = _localNotifications!
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        for (final channel in channels) {
          await androidImplementation.createNotificationChannel(channel);
        }
        debugPrint('✅ Android notification channels created');
      }
    } catch (e) {
      debugPrint('❌ Error creating notification channels: $e');
    }
  }

  /// Show local notification for foreground messages
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null || _localNotifications == null) return;

    try {
      // Determine channel based on message data
      String channelId = 'default';
      if (message.data.containsKey('type')) {
        switch (message.data['type']) {
          case 'order':
          case 'order_update':
            channelId = 'orders';
            break;
          case 'message':
            channelId = 'messages';
            break;
          case 'promotion':
            channelId = 'promotions';
            break;
        }
      }

      final androidDetails = AndroidNotificationDetails(
        channelId,
        _getChannelName(channelId),
        channelDescription: _getChannelDescription(channelId),
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
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

      await _localNotifications!.show(
        message.hashCode,
        notification.title,
        notification.body,
        details,
        payload: message.data.toString(),
      );

      debugPrint('✅ Local notification shown: ${notification.title}');
    } catch (e) {
      debugPrint('❌ Error showing local notification: $e');
    }
  }

  /// Get channel name by ID
  String _getChannelName(String channelId) {
    switch (channelId) {
      case 'orders':
        return 'Order Updates';
      case 'messages':
        return 'Messages';
      case 'promotions':
        return 'Promotions';
      default:
        return 'Default Notifications';
    }
  }

  /// Get channel description by ID
  String _getChannelDescription(String channelId) {
    switch (channelId) {
      case 'orders':
        return 'Notifications about order status changes';
      case 'messages':
        return 'Chat messages and communications';
      case 'promotions':
        return 'Special offers and promotions';
      default:
        return 'Default notification channel';
    }
  }

  /// Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    debugPrint('📱 Local notification tapped: ${response.payload}');

    try {
      // Parse payload and handle navigation
      if (response.payload != null) {
        // You can parse the payload and navigate to appropriate screens
        _handleNotificationNavigation(response.payload!);
      }
    } catch (e) {
      debugPrint('❌ Error handling notification tap: $e');
    }
  }

  /// Handle FCM message tap
  void _handleMessageTap(RemoteMessage message) {
    debugPrint('📱 FCM message tapped: ${message.data}');

    try {
      // Handle navigation based on message data
      if (message.data.isNotEmpty) {
        _handleNotificationNavigation(message.data.toString());
      }
    } catch (e) {
      debugPrint('❌ Error handling FCM message tap: $e');
    }
  }

  /// Handle notification navigation
  void _handleNotificationNavigation(String data) {
    // Implement your navigation logic here
    // For example:
    // - Parse the data
    // - Determine the target screen
    // - Navigate using your app's navigation system
    debugPrint('🧭 Handling notification navigation: $data');
  }

  /// Send notification via Supabase Edge Function
  Future<bool> sendNotification({
    required String title,
    required String body,
    String? userId,
    List<String>? userIds,
    Map<String, dynamic>? data,
    String? image,
    String? clickAction,
  }) async {
    try {
      debugPrint('📤 Sending FCM notification via Supabase...');

      final response = await _supabase.functions.invoke(
        'send-push-notification',
        body: {
          if (userId != null) 'user_id': userId,
          if (userIds != null) 'user_ids': userIds,
          'title': title,
          'body': body,
          if (data != null) 'data': data,
          if (image != null) 'image': image,
          if (clickAction != null) 'click_action': clickAction,
        },
      );

      if (response.data != null && response.data['success'] == true) {
        debugPrint('✅ FCM notification sent successfully');
        debugPrint('📊 Results: ${response.data}');
        return true;
      } else {
        debugPrint('❌ Failed to send FCM notification: ${response.data}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error sending FCM notification: $e');
      return false;
    }
  }

  /// Send test notification
  Future<bool> sendTestNotification() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      debugPrint('❌ No authenticated user for test notification');
      return false;
    }

    return sendNotification(
      userId: user.id,
      title: 'Test Notification 🧪',
      body: 'This is a test notification from FCM + Supabase integration!',
      data: {
        'type': 'test',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Unregister FCM token from Supabase
  Future<void> unregisterToken() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null || _fcmToken == null) return;

      await _supabase
          .from('user_device_tokens')
          .update({'is_active': false})
          .eq('user_id', user.id)
          .eq('token', _fcmToken!);

      debugPrint('✅ FCM token unregistered from Supabase');
    } catch (e) {
      debugPrint('❌ Error unregistering FCM token: $e');
    }
  }

  /// Get notification permission status
  Future<AuthorizationStatus> getPermissionStatus() async {
    if (_messaging == null) return AuthorizationStatus.notDetermined;

    final settings = await _messaging!.getNotificationSettings();
    return settings.authorizationStatus;
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    if (_messaging == null) return false;

    try {
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('❌ Error requesting FCM permissions: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _messageController.close();
    _tokenController.close();
    super.dispose();
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('📨 Background FCM message: ${message.notification?.title}');

    // Handle background message processing here
    // Note: Don't call UI methods from background handler
  } catch (e) {
    debugPrint('❌ Error in background message handler: $e');
  }
}
