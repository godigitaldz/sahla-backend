import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ImagePickerService {
  static final ImagePicker _picker = ImagePicker();

  /// Show image source selection dialog
  static Future<File?> showImageSourceDialog(BuildContext context) async {
    return showDialog<File?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () async {
                  // Don't pop yet - wait for image selection
                  final image = await _pickImageFromCamera();
                  if (context.mounted) {
                    Navigator.of(context).pop(image);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () async {
                  // Don't pop yet - wait for image selection
                  final image = await _pickImageFromGallery();
                  if (context.mounted) {
                    Navigator.of(context).pop(image);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  /// Pick image from camera
  static Future<File?> _pickImageFromCamera() async {
    try {
      debugPrint('📷 Image Picker: Requesting camera permission...');
      // Check camera permission
      final cameraStatus = await Permission.camera.request();
      debugPrint('📷 Image Picker: Camera permission status: $cameraStatus');
      if (cameraStatus != PermissionStatus.granted) {
        debugPrint('❌ Image Picker: Camera permission denied');
        throw Exception('Camera permission denied');
      }

      debugPrint('📷 Image Picker: Opening camera...');
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        debugPrint('✅ Image Picker: Image selected from camera: ${image.path}');
        return File(image.path);
      }
      debugPrint('📷 Image Picker: No image selected from camera (user canceled)');
      return null;
    } catch (e) {
      debugPrint('❌ Image Picker: Error picking image from camera: $e');
      return null;
    }
  }

  /// Pick image from gallery
  static Future<File?> _pickImageFromGallery() async {
    try {
      debugPrint('🖼️ Image Picker: Requesting photos permission...');
      // Check photos permission
      final photosStatus = await Permission.photos.request();
      debugPrint('🖼️ Image Picker: Photos permission status: $photosStatus');
      if (photosStatus != PermissionStatus.granted) {
        debugPrint('❌ Image Picker: Photos permission denied');
        throw Exception('Photos permission denied');
      }

      debugPrint('🖼️ Image Picker: Opening gallery...');
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        debugPrint('✅ Image Picker: Image selected from gallery: ${image.path}');
        return File(image.path);
      }
      debugPrint('🖼️ Image Picker: No image selected from gallery (user canceled)');
      return null;
    } catch (e) {
      debugPrint('❌ Image Picker: Error picking image from gallery: $e');
      return null;
    }
  }

  /// Pick image with source selection
  static Future<File?> pickImage(BuildContext context) async {
    return showImageSourceDialog(context);
  }

  /// Pick restaurant logo image
  static Future<File?> pickRestaurantLogo(BuildContext context) async {
    return showImageSourceDialog(context);
  }

  /// Pick menu item image
  static Future<File?> pickMenuItemImage(BuildContext context) async {
    return showImageSourceDialog(context);
  }

  /// Pick multiple menu item images
  static Future<List<File>> pickMultipleMenuItemImages(BuildContext context,
      {int maxImages = 5}) async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      final files = <File>[];
      for (final image in images.take(maxImages)) {
        files.add(File(image.path));
      }
      return files;
    } catch (e) {
      debugPrint('Error picking multiple menu item images: $e');
      return [];
    }
  }

  /// Validate image file
  static bool validateImage(File imageFile) {
    // Check file size (max 5MB)
    const maxSizeInBytes = 5 * 1024 * 1024; // 5MB
    if (imageFile.lengthSync() > maxSizeInBytes) {
      return false;
    }

    // Check file extension
    final extension = imageFile.path.split('.').last.toLowerCase();
    const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

    return allowedExtensions.contains(extension);
  }

  /// Validate restaurant logo image
  static bool validateRestaurantLogo(File imageFile) {
    // Check file size (max 3MB for logos)
    const maxSizeInBytes = 3 * 1024 * 1024; // 3MB
    if (imageFile.lengthSync() > maxSizeInBytes) {
      return false;
    }

    // Check file extension
    final extension = imageFile.path.split('.').last.toLowerCase();
    const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

    return allowedExtensions.contains(extension);
  }

  /// Validate menu item image
  static bool validateMenuItemImage(File imageFile) {
    // Check file size (max 4MB for menu items)
    const maxSizeInBytes = 4 * 1024 * 1024; // 4MB
    if (imageFile.lengthSync() > maxSizeInBytes) {
      return false;
    }

    // Check file extension
    final extension = imageFile.path.split('.').last.toLowerCase();
    const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

    return allowedExtensions.contains(extension);
  }

  /// Get image file size in MB
  static double getImageSizeInMB(File imageFile) {
    return imageFile.lengthSync() / (1024 * 1024);
  }

  /// Get image dimensions (placeholder implementation)
  static Future<Map<String, int>> getImageDimensions(File imageFile) async {
    try {
      // For now, return default dimensions
      // In a real app, you'd use a library to get actual dimensions
      return {'width': 1024, 'height': 1024};
    } catch (e) {
      debugPrint('Error getting image dimensions: $e');
      return {'width': 0, 'height': 0};
    }
  }

  /// Compress image for food delivery app
  static Future<Uint8List> compressImageForFoodDelivery(File imageFile,
      {int quality = 85}) async {
    try {
      final bytes = await imageFile.readAsBytes();

      // For now, return original bytes
      // In a real app, you'd use a compression library like flutter_image_compress
      return Uint8List.fromList(bytes);
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return Uint8List(0);
    }
  }
}
