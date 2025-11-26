import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as permission_handler;

/// Service to handle permission flow and check if permissions are needed
class PermissionFlowService {
  /// Check if permissions screen should be shown
  static Future<bool> shouldShowPermissionsScreen() async {
    try {
      // Check if the permissions shown in the permissions screen are already granted
      final locationGranted = await _isLocationPermissionGranted();
      final notificationGranted = await _isNotificationPermissionGranted();

      debugPrint('📋 Permission check results:');
      debugPrint('   Location: $locationGranted');
      debugPrint('   Notification: $notificationGranted');

      // Only check location and notification permissions since those are what's shown in the permissions screen
      // If both are granted, skip the permissions screen
      if (locationGranted && notificationGranted) {
        debugPrint('✅ Location and notification permissions already granted - skipping permissions screen');
        return false;
      }

      debugPrint(
          '📋 Location or notification permissions not granted, showing permissions screen');
      return true;
    } catch (e) {
      debugPrint('❌ Error checking permissions: $e');
      // If there's an error, show permissions screen to be safe
      return true;
    }
  }

  /// Check if location permission is granted using Geolocator
  static Future<bool> _isLocationPermissionGranted() async {
    try {
      final permission = await Geolocator.checkPermission();
      final isGranted = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
      debugPrint('📍 Location permission status: $permission (granted: $isGranted)');
      return isGranted;
    } catch (e) {
      debugPrint('❌ Error checking location permission: $e');
      // Fallback to permission_handler
      try {
        final status = await permission_handler.Permission.locationWhenInUse.status;
        final isGranted = status.isGranted;
        debugPrint('📍 Fallback location permission status: $status (granted: $isGranted)');
        return isGranted;
      } catch (fallbackError) {
        debugPrint(
            '❌ Error in fallback location permission check: $fallbackError');
        return false;
      }
    }
  }

  /// Check if notification permission is granted
  static Future<bool> _isNotificationPermissionGranted() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final messaging = FirebaseMessaging.instance;
        final settings = await messaging.getNotificationSettings();
        final isGranted = settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
        debugPrint('🔔 iOS notification permission status: ${settings.authorizationStatus} (granted: $isGranted)');
        return isGranted;
      } else {
        // For Android, use permission_handler
        final status = await permission_handler.Permission.notification.status;
        final isGranted = status.isGranted;
        debugPrint('🔔 Android notification permission status: $status (granted: $isGranted)');
        return isGranted;
      }
    } catch (e) {
      debugPrint('❌ Error checking notification permission: $e');
      // Fallback: try permission_handler for all platforms
      try {
        final status = await permission_handler.Permission.notification.status;
        final isGranted = status.isGranted;
        debugPrint('🔔 Fallback notification permission status: $status (granted: $isGranted)');
        return isGranted;
      } catch (fallbackError) {
        debugPrint(
            '❌ Error in fallback notification permission check: $fallbackError');
        return false;
      }
    }
  }

  /// Check if all critical permissions are granted
  static Future<bool> areAllPermissionsGranted() async {
    try {
      final locationGranted = await _isLocationPermissionGranted();
      final notificationGranted = await _isNotificationPermissionGranted();
      final cameraGranted = await permission_handler.Permission.camera.isGranted;
      final photosGranted = await permission_handler.Permission.photos.isGranted;

      return locationGranted &&
          notificationGranted &&
          cameraGranted &&
          photosGranted;
    } catch (e) {
      debugPrint('❌ Error checking all permissions: $e');
      return false;
    }
  }

  /// Get permission status for debugging
  static Future<Map<String, bool>> getPermissionStatus() async {
    try {
      return {
        'location': await _isLocationPermissionGranted(),
        'notification': await _isNotificationPermissionGranted(),
        'camera': await permission_handler.Permission.camera.isGranted,
        'photos': await permission_handler.Permission.photos.isGranted,
      };
    } catch (e) {
      debugPrint('❌ Error getting permission status: $e');
      return {
        'location': false,
        'notification': false,
        'camera': false,
        'photos': false,
      };
    }
  }

  /// Get the status of permissions shown in the permissions screen
  static Future<Map<String, bool>> getScreenPermissionStatus() async {
    try {
      return {
        'location': await _isLocationPermissionGranted(),
        'notification': await _isNotificationPermissionGranted(),
      };
    } catch (e) {
      debugPrint('❌ Error getting screen permission status: $e');
      return {
        'location': false,
        'notification': false,
      };
    }
  }

  /// Request all permissions programmatically
  static Future<Map<String, bool>> requestAllPermissions() async {
    try {
      debugPrint('🚀 Requesting all permissions...');

      // Request notification permission first
      bool notificationGranted = false;
      try {
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          final messaging = FirebaseMessaging.instance;
          final settings = await messaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          );
          notificationGranted = settings.authorizationStatus ==
                  AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
        } else {
          final notificationStatus = await permission_handler.Permission.notification.request();
          notificationGranted = notificationStatus.isGranted;
        }
      } catch (e) {
        debugPrint('❌ Error requesting notification permission: $e');
      }

      // Request location permission after notification using Geolocator
      bool locationGranted = false;
      try {
        final geolocatorPermission = await Geolocator.requestPermission();
        locationGranted =
            geolocatorPermission == LocationPermission.whileInUse ||
                geolocatorPermission == LocationPermission.always;
        debugPrint('📍 Location permission: $geolocatorPermission');
      } catch (e) {
        debugPrint('❌ Error requesting location permission: $e');
        // Fallback to permission_handler
        final locationStatus = await permission_handler.Permission.locationWhenInUse.request();
        locationGranted = locationStatus.isGranted;
        debugPrint('📍 Fallback location permission: $locationStatus');
      }

      // Request camera permission
      final cameraStatus = await permission_handler.Permission.camera.request();
      debugPrint('📸 Camera permission: $cameraStatus');

      // Request photos permission
      final photosStatus = await permission_handler.Permission.photos.request();
      debugPrint('🖼️ Photos permission: $photosStatus');

      return {
        'location': locationGranted,
        'notification': notificationGranted,
        'camera': cameraStatus.isGranted,
        'photos': photosStatus.isGranted,
      };
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
      return {
        'location': false,
        'notification': false,
        'camera': false,
        'photos': false,
      };
    }
  }

  /// Open app settings for permission management
  static Future<void> openAppSettings() async {
    try {
      await permission_handler.openAppSettings();
    } catch (e) {
      debugPrint('❌ Error opening app settings: $e');
    }
  }
}
