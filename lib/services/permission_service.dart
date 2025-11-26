import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static const String _permissionPermanentlyDeniedMessage =
      'Permission has been permanently denied. Please enable it in Settings.';

  /// Request camera permission for taking photos
  static Future<PermissionStatus> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status;
  }

  /// Request photo library permission for selecting images
  static Future<PermissionStatus> requestPhotoPermission() async {
    final status = await Permission.photos.request();
    return status;
  }

  /// Check if camera permission is granted
  static Future<bool> isCameraPermissionGranted() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Check if photo permission is granted
  static Future<bool> isPhotoPermissionGranted() async {
    final status = await Permission.photos.status;
    return status.isGranted;
  }

  /// Check if both camera and photo permissions are granted
  static Future<bool> areImagePermissionsGranted() async {
    final cameraGranted = await isCameraPermissionGranted();
    final photoGranted = await isPhotoPermissionGranted();
    return cameraGranted && photoGranted;
  }

  /// Request both camera and photo permissions
  static Future<Map<Permission, PermissionStatus>>
      requestImagePermissions() async {
    final permissions = await [
      Permission.camera,
      Permission.photos,
    ].request();
    return permissions;
  }

  /// Get permission status for camera and photos
  static Future<Map<String, PermissionStatus>>
      getImagePermissionStatus() async {
    final cameraStatus = await Permission.camera.status;
    final photoStatus = await Permission.photos.status;

    return {
      'camera': cameraStatus,
      'photos': photoStatus,
    };
  }

  /// Show permission dialog with appropriate message
  static Future<void> showPermissionDialog(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onSettingsPressed,
    VoidCallback? onCancel,
  }) async {
    if (!context.mounted) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            if (onCancel != null)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onCancel();
                },
                child: const Text('Cancel'),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onSettingsPressed();
              },
              child: const Text('Settings'),
            ),
          ],
        );
      },
    );
  }

  /// Handle camera permission request with native dialogs
  static Future<bool> handleCameraPermission(BuildContext context) async {
    final status = await requestCameraPermission();

    switch (status) {
      case PermissionStatus.granted:
        return true;
      case PermissionStatus.denied:
        // For denied permissions, we can try requesting again
        // The system will show the native permission dialog
        return false;
      case PermissionStatus.permanentlyDenied:
        // For permanently denied, we need to guide user to settings
        if (context.mounted) {
          await showPermissionDialog(
            context,
            title: 'Camera Permission Required',
            message: _permissionPermanentlyDeniedMessage,
            onSettingsPressed: () => openAppSettings(),
          );
        }
        return false;
      case PermissionStatus.restricted:
        // For restricted permissions, show explanation
        if (context.mounted) {
          await showPermissionDialog(
            context,
            title: 'Camera Permission Restricted',
            message: 'Camera permission is restricted on this device.',
            onSettingsPressed: () => openAppSettings(),
          );
        }
        return false;
      case PermissionStatus.limited:
        return true; // Limited access is still usable
      case PermissionStatus.provisional:
        return true; // Provisional access is usable
    }
  }

  /// Handle photo permission request with native dialogs
  static Future<bool> handlePhotoPermission(BuildContext context) async {
    final status = await requestPhotoPermission();

    switch (status) {
      case PermissionStatus.granted:
        return true;
      case PermissionStatus.denied:
        // For denied permissions, we can try requesting again
        // The system will show the native permission dialog
        return false;
      case PermissionStatus.permanentlyDenied:
        // For permanently denied, we need to guide user to settings
        if (context.mounted) {
          await showPermissionDialog(
            context,
            title: 'Photo Library Permission Required',
            message: _permissionPermanentlyDeniedMessage,
            onSettingsPressed: () => openAppSettings(),
          );
        }
        return false;
      case PermissionStatus.restricted:
        // For restricted permissions, show explanation
        if (context.mounted) {
          await showPermissionDialog(
            context,
            title: 'Photo Library Permission Restricted',
            message: 'Photo library permission is restricted on this device.',
            onSettingsPressed: () => openAppSettings(),
          );
        }
        return false;
      case PermissionStatus.limited:
        return true; // Limited access is still usable
      case PermissionStatus.provisional:
        return true; // Provisional access is usable
    }
  }

  /// Handle both camera and photo permissions
  static Future<bool> handleImagePermissions(BuildContext context) async {
    final cameraGranted = await isCameraPermissionGranted();
    final photoGranted = await isPhotoPermissionGranted();

    // If both are already granted, return true
    if (cameraGranted && photoGranted) {
      return true;
    }

    if (!context.mounted) return false;

    // Request permissions
    final permissions = await requestImagePermissions();
    final cameraStatus = permissions[Permission.camera]!;
    final photoStatus = permissions[Permission.photos]!;

    // Check if both are granted
    if (cameraStatus.isGranted && photoStatus.isGranted) {
      return true;
    }

    // Handle denied permissions
    bool allGranted = true;

    if (!cameraStatus.isGranted) {
      if (!context.mounted) return false;
      allGranted = await handleCameraPermission(context) && allGranted;
    }

    if (!photoStatus.isGranted) {
      if (!context.mounted) return false;
      allGranted = await handlePhotoPermission(context) && allGranted;
    }

    return allGranted;
  }

  /// Check if we can proceed with image operations using native dialogs
  static Future<bool> canProceedWithImageOperations(
      BuildContext context) async {
    final cameraGranted = await isCameraPermissionGranted();
    final photoGranted = await isPhotoPermissionGranted();

    if (cameraGranted && photoGranted) {
      return true;
    }

    // Use native permission request - the system will show native dialogs
    final permissions = await requestImagePermissions();
    final cameraStatus = permissions[Permission.camera]!;
    final photoStatus = permissions[Permission.photos]!;

    // Check if both are granted after native request
    if (cameraStatus.isGranted && photoStatus.isGranted) {
      return true;
    }

    // Only show custom dialog for permanently denied permissions
    if (cameraStatus.isPermanentlyDenied || photoStatus.isPermanentlyDenied) {
      if (context.mounted) {
        await showPermissionDialog(
          context,
          title: 'Permission Required',
          message:
              'Camera and photo permissions are required to upload images. Please enable them in Settings.',
          onSettingsPressed: () => openAppSettings(),
        );
      }
    }

    return false;
  }

  /// Simplified native permission request - relies on system dialogs
  static Future<bool> requestNativeImagePermissions() async {
    // Request both permissions at once - iOS will show native dialogs
    final permissions = await requestImagePermissions();
    final cameraStatus = permissions[Permission.camera]!;
    final photoStatus = permissions[Permission.photos]!;

    // Return true only if both are granted
    return cameraStatus.isGranted && photoStatus.isGranted;
  }

  /// Check permissions and request if needed using native dialogs only
  static Future<bool> checkAndRequestImagePermissions() async {
    // Check current status
    final cameraGranted = await isCameraPermissionGranted();
    final photoGranted = await isPhotoPermissionGranted();

    // If both already granted, return true
    if (cameraGranted && photoGranted) {
      return true;
    }

    // Request permissions using native system dialogs
    return requestNativeImagePermissions();
  }

  /// Get permission status message for debugging
  static Future<String> getPermissionStatusMessage() async {
    final statuses = await getImagePermissionStatus();
    return 'Camera: ${statuses['camera']}, Photos: ${statuses['photos']}';
  }
}
