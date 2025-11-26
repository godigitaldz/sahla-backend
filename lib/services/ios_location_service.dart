import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// iOS-specific location service for enhanced iPhone compatibility
class IOSLocationService {
  /// Check iOS location permission status with detailed logging
  static Future<IOSLocationStatus> checkIOSLocationStatus() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return IOSLocationStatus(
        hasPermission: false,
        isLocationEnabled: false,
        needsPermission: false,
        needsLocationServices: false,
        message: 'Not running on iOS',
      );
    }

    try {
      debugPrint('🍎 iOS Location Service: Checking status...');

      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('🍎 iOS Location Services enabled: $serviceEnabled');

      if (!serviceEnabled) {
        return IOSLocationStatus(
          hasPermission: false,
          isLocationEnabled: false,
          needsPermission: false,
          needsLocationServices: true,
          message:
              'Location Services are disabled. Please enable them in Settings > Privacy & Security > Location Services.',
        );
      }

      // Check permission status
      final permission = await Geolocator.checkPermission();
      debugPrint('🍎 iOS Permission status: $permission');

      switch (permission) {
        case LocationPermission.denied:
          return IOSLocationStatus(
            hasPermission: false,
            isLocationEnabled: true,
            needsPermission: true,
            needsLocationServices: false,
            message:
                'Location permission is required. Please allow location access when prompted.',
          );

        case LocationPermission.deniedForever:
          return IOSLocationStatus(
            hasPermission: false,
            isLocationEnabled: true,
            needsPermission: false,
            needsLocationServices: false,
            needsSettings: true,
            message:
                'Location permission is permanently denied. Please enable it in Settings > Privacy & Security > Location Services > Sahla.',
          );

        case LocationPermission.whileInUse:
        case LocationPermission.always:
          return IOSLocationStatus(
            hasPermission: true,
            isLocationEnabled: true,
            needsPermission: false,
            needsLocationServices: false,
            message: 'Location permission granted',
          );

        case LocationPermission.unableToDetermine:
          return IOSLocationStatus(
            hasPermission: false,
            isLocationEnabled: true,
            needsPermission: true,
            needsLocationServices: false,
            message:
                'Unable to determine location permission status. Please try again.',
          );
      }
    } catch (e) {
      debugPrint('❌ iOS Location Service error: $e');
      return IOSLocationStatus(
        hasPermission: false,
        isLocationEnabled: false,
        needsPermission: false,
        needsLocationServices: false,
        message: 'Error checking location status: $e',
      );
    }
  }

  /// Request iOS location permission with proper error handling
  static Future<IOSLocationStatus> requestIOSLocationPermission() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return IOSLocationStatus(
        hasPermission: false,
        isLocationEnabled: false,
        needsPermission: false,
        needsLocationServices: false,
        message: 'Not running on iOS',
      );
    }

    try {
      debugPrint('🍎 iOS Location Service: Requesting permission...');

      // First check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return IOSLocationStatus(
          hasPermission: false,
          isLocationEnabled: false,
          needsPermission: false,
          needsLocationServices: true,
          message:
              'Location Services are disabled. Please enable them in Settings > Privacy & Security > Location Services.',
        );
      }

      // Request permission
      final permission = await Geolocator.requestPermission();
      debugPrint('🍎 iOS Permission request result: $permission');

      switch (permission) {
        case LocationPermission.denied:
          return IOSLocationStatus(
            hasPermission: false,
            isLocationEnabled: true,
            needsPermission: true,
            needsLocationServices: false,
            message:
                'Location permission was denied. Please allow location access when prompted.',
          );

        case LocationPermission.deniedForever:
          return IOSLocationStatus(
            hasPermission: false,
            isLocationEnabled: true,
            needsPermission: false,
            needsLocationServices: false,
            needsSettings: true,
            message:
                'Location permission is permanently denied. Please enable it in Settings > Privacy & Security > Location Services > Sahla.',
          );

        case LocationPermission.whileInUse:
        case LocationPermission.always:
          return IOSLocationStatus(
            hasPermission: true,
            isLocationEnabled: true,
            needsPermission: false,
            needsLocationServices: false,
            message: 'Location permission granted successfully',
          );

        case LocationPermission.unableToDetermine:
          return IOSLocationStatus(
            hasPermission: false,
            isLocationEnabled: true,
            needsPermission: true,
            needsLocationServices: false,
            message: 'Unable to determine permission status. Please try again.',
          );
      }
    } catch (e) {
      debugPrint('❌ iOS Location Service permission request error: $e');
      return IOSLocationStatus(
        hasPermission: false,
        isLocationEnabled: false,
        needsPermission: false,
        needsLocationServices: false,
        message: 'Error requesting location permission: $e',
      );
    }
  }

  /// Open iOS location settings
  static Future<void> openIOSLocationSettings() async {
    try {
      debugPrint('🍎 iOS Location Service: Opening location settings...');
      await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('❌ Error opening iOS location settings: $e');
    }
  }

  /// Open iOS app settings
  static Future<void> openIOSAppSettings() async {
    try {
      debugPrint('🍎 iOS Location Service: Opening app settings...');
      await openAppSettings();
    } catch (e) {
      debugPrint('❌ Error opening iOS app settings: $e');
    }
  }

  /// Request iOS location permission using native system dialog
  static Future<IOSLocationStatus> requestIOSLocationPermissionNative() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return IOSLocationStatus(
        hasPermission: false,
        isLocationEnabled: false,
        needsPermission: false,
        needsLocationServices: false,
        message: 'Not running on iOS',
      );
    }

    try {
      debugPrint(
          '🍎 iOS Location Service: Requesting permission with native dialog...');

      // First check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return IOSLocationStatus(
          hasPermission: false,
          isLocationEnabled: false,
          needsPermission: false,
          needsLocationServices: true,
          message:
              'Location Services are disabled. Please enable them in Settings > Privacy & Security > Location Services.',
        );
      }

      // Request permission - this will show the native iOS permission dialog
      final permission = await Geolocator.requestPermission();
      debugPrint('🍎 iOS Native permission dialog result: $permission');

      switch (permission) {
        case LocationPermission.denied:
          return IOSLocationStatus(
            hasPermission: false,
            isLocationEnabled: true,
            needsPermission: false, // User already saw the dialog
            needsLocationServices: false,
            needsSettings: true, // Direct to settings
            message:
                'Location permission was denied. Please enable it in Settings > Privacy & Security > Location Services > Sahla.',
          );

        case LocationPermission.deniedForever:
          return IOSLocationStatus(
            hasPermission: false,
            isLocationEnabled: true,
            needsPermission: false,
            needsLocationServices: false,
            needsSettings: true,
            message:
                'Location permission is permanently denied. Please enable it in Settings > Privacy & Security > Location Services > Sahla.',
          );

        case LocationPermission.whileInUse:
        case LocationPermission.always:
          return IOSLocationStatus(
            hasPermission: true,
            isLocationEnabled: true,
            needsPermission: false,
            needsLocationServices: false,
            message: 'Location permission granted successfully',
          );

        case LocationPermission.unableToDetermine:
          return IOSLocationStatus(
            hasPermission: false,
            isLocationEnabled: true,
            needsPermission: false,
            needsLocationServices: false,
            needsSettings: true,
            message:
                'Unable to determine permission status. Please check Settings.',
          );
      }
    } catch (e) {
      debugPrint('❌ iOS Location Service native permission request error: $e');
      return IOSLocationStatus(
        hasPermission: false,
        isLocationEnabled: false,
        needsPermission: false,
        needsLocationServices: false,
        message: 'Error requesting location permission: $e',
      );
    }
  }

  /// Show simple location services message and open settings
  static Future<void> showIOSLocationServicesMessageAndOpenSettings(
    BuildContext context, {
    required String message,
  }) async {
    // Show a simple snackbar message
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Open Settings',
            onPressed: () async {
              await openIOSLocationSettings();
            },
          ),
        ),
      );
    }
  }
}

/// iOS location status result
class IOSLocationStatus {
  final bool hasPermission;
  final bool isLocationEnabled;
  final bool needsPermission;
  final bool needsLocationServices;
  final bool needsSettings;
  final String message;

  IOSLocationStatus({
    required this.hasPermission,
    required this.isLocationEnabled,
    required this.needsPermission,
    required this.needsLocationServices,
    required this.message,
    this.needsSettings = false,
  });

  bool get isReady => hasPermission && isLocationEnabled;
  bool get needsAction =>
      needsPermission || needsLocationServices || needsSettings;
}
