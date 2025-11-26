import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../../models/menu_item.dart';
import '../../../../../services/menu_item_image_service.dart';
import 'special_pack_operations.dart';

/// Image Operations Helper
/// Provides business logic for image operations
class ImageOperationsHelper {
  /// Show image source selection dialog
  static Future<ImageSource?> showImageSourceDialog(BuildContext context) {
    return showDialog<ImageSource>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () =>
                    Navigator.of(dialogContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () =>
                    Navigator.of(dialogContext).pop(ImageSource.gallery),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  /// Request image permissions
  static Future<bool> requestImagePermissions(ImageSource source) async {
    if (source == ImageSource.camera) {
      final cameraStatus = await Permission.camera.request();
      return cameraStatus.isGranted;
    } else {
      final photosStatus = await Permission.photos.request();
      return photosStatus.isGranted;
    }
  }

  /// Upload and update image
  static Future<String?> uploadAndUpdateImage(
    MenuItem item,
    File imageFile,
  ) async {
    // Upload image
    final imageService = MenuItemImageService();
    final uploadedUrls = await imageService.uploadMenuItemImages(
      menuItemId: item.id,
      restaurantId: item.restaurantId,
      images: [imageFile],
      onProgress: (progress) {
        // Progress callback - can be used for progress indicator if needed
      },
    );

    if (uploadedUrls.isEmpty) {
      throw Exception('Failed to upload image');
    }

    final newImageUrl = uploadedUrls.first;

    // Update menu item
    final success = await EditOperationsHelper.updateMenuItem(
      item,
      (item) => item.copyWith(image: newImageUrl),
    );

    if (!success) {
      throw Exception('Failed to update menu item');
    }

    return newImageUrl;
  }
}
