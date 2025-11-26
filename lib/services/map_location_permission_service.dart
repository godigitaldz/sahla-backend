import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Service to handle location permissions and services for map location picker
class MapLocationPermissionService {
  /// Check and request location permissions with proper error handling
  static Future<LocationPermissionResult>
      checkAndRequestLocationPermission() async {
    try {
      debugPrint('📍 Checking location permissions...');
      debugPrint('📱 Platform: ${defaultTargetPlatform.name}');

      // Check if location services are enabled first
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('📍 Location services enabled: $serviceEnabled');

      if (!serviceEnabled) {
        debugPrint('❌ Location services are disabled');
        return LocationPermissionResult(
          granted: false,
          needsLocationServices: true,
          message: defaultTargetPlatform == TargetPlatform.iOS
              ? 'Location services are disabled. Please enable Location Services in Settings > Privacy & Security > Location Services.'
              : 'Location services are disabled. Please enable GPS to use this feature.',
        );
      }

      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('📍 Current permission status: $permission');

      // Handle different permission states with iOS-specific logic
      switch (permission) {
        case LocationPermission.denied:
          debugPrint('📍 Permission denied, requesting...');

          // For iOS, we need to be more careful about permission requests
          if (defaultTargetPlatform == TargetPlatform.iOS) {
            // On iOS, we should check if we can request permission
            // Some iOS versions require specific handling
            try {
              permission = await Geolocator.requestPermission();
              debugPrint('📍 iOS permission request result: $permission');
            } catch (e) {
              debugPrint('❌ iOS permission request failed: $e');
              return LocationPermissionResult(
                granted: false,
                needsSettings: true,
                message:
                    'Unable to request location permission. Please enable it in Settings > Privacy & Security > Location Services.',
              );
            }
          } else {
            permission = await Geolocator.requestPermission();
          }

          if (permission == LocationPermission.denied) {
            return LocationPermissionResult(
              granted: false,
              needsPermission: true,
              message: defaultTargetPlatform == TargetPlatform.iOS
                  ? 'Location permission is required. Please allow location access when prompted.'
                  : 'Location permission is required to use this feature.',
            );
          }
          break;

        case LocationPermission.deniedForever:
          debugPrint('❌ Permission permanently denied');
          return LocationPermissionResult(
            granted: false,
            needsSettings: true,
            message: defaultTargetPlatform == TargetPlatform.iOS
                ? 'Location permission is permanently denied. Please enable it in Settings > Privacy & Security > Location Services > Sahla.'
                : 'Location permission is permanently denied. Please enable it in app settings.',
          );

        case LocationPermission.whileInUse:
        case LocationPermission.always:
          debugPrint('✅ Location permission granted');
          return LocationPermissionResult(
            granted: true,
            message: 'Location permission granted',
          );

        case LocationPermission.unableToDetermine:
          debugPrint('❌ Unable to determine permission status');
          return LocationPermissionResult(
            granted: false,
            needsPermission: true,
            message: 'Unable to determine location permission status.',
          );
      }

      // Final check
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return LocationPermissionResult(
          granted: false,
          needsPermission: permission == LocationPermission.denied,
          needsSettings: permission == LocationPermission.deniedForever,
          message: permission == LocationPermission.deniedForever
              ? 'Location permission is permanently denied. Please enable it in app settings.'
              : 'Location permission is required to use this feature.',
        );
      }

      return LocationPermissionResult(
        granted: true,
        message: 'Location permission granted',
      );
    } catch (e) {
      debugPrint('❌ Error checking location permissions: $e');
      return LocationPermissionResult(
        granted: false,
        needsPermission: true,
        message: 'Error checking location permissions: $e',
      );
    }
  }

  /// Open location settings
  static Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('❌ Error opening location settings: $e');
    }
  }

  /// Open app settings
  static Future<void> openAppSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('❌ Error opening app settings: $e');
    }
  }

  /// Show permission dialog with proper actions
  static Future<bool> showPermissionDialog(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onRequestPermission,
    required VoidCallback onOpenSettings,
  }) async {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              if (!isIOS) // On iOS, we don't show "Request Permission" as it's handled automatically
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                    onRequestPermission();
                  },
                  child: const Text('Request Permission'),
                ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                  onOpenSettings();
                },
                child: Text(isIOS ? 'Open Settings' : 'Open Settings'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Show location services dialog
  static Future<bool> showLocationServicesDialog(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onOpenSettings,
  }) async {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                  onOpenSettings();
                },
                child: Text(isIOS ? 'Open Settings' : 'Enable Location'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

/// Result of location permission check
class LocationPermissionResult {
  final bool granted;
  final bool needsPermission;
  final bool needsSettings;
  final bool needsLocationServices;
  final String message;

  LocationPermissionResult({
    required this.granted,
    required this.message,
    this.needsPermission = false,
    this.needsSettings = false,
    this.needsLocationServices = false,
  });

  bool get needsAction =>
      needsPermission || needsSettings || needsLocationServices;
}
