import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_storage_service.dart';
import 'image_picker_service.dart';
import 'supabase_service.dart';

class ImageUploadService extends ChangeNotifier {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;

  // Pick image from gallery
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      return image != null ? File(image.path) : null;
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
      return null;
    }
  }

  // Take photo with camera
  Future<File?> takePhotoWithCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      return image != null ? File(image.path) : null;
    } catch (e) {
      debugPrint('Error taking photo with camera: $e');
      return null;
    }
  }

  // Pick multiple images
  Future<List<File>> pickMultipleImages({int maxImages = 10}) async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      final files = <File>[];
      for (final image in images.take(maxImages)) {
        files.add(File(image.path));
      }
      return files;
    } catch (e) {
      debugPrint('Error picking multiple images: $e');
      return [];
    }
  }

  // Upload user avatar
  Future<String?> uploadUserAvatar(String userId, File imageFile) async {
    try {
      _isUploading = true;
      _uploadProgress = 0.0;
      notifyListeners();

      // Read image bytes
      final bytes = await imageFile.readAsBytes();

      // Upload to Supabase
      final url = await SupabaseService.uploadUserAvatar(
          userId, Uint8List.fromList(bytes));

      _uploadProgress = 1.0;
      notifyListeners();

      return url;
    } catch (e) {
      debugPrint('Error uploading user avatar: $e');
      return null;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  // Upload restaurant logo image
  Future<String?> uploadRestaurantLogo(
      String restaurantId, File imageFile) async {
    try {
      _isUploading = true;
      _uploadProgress = 0.0;
      notifyListeners();

      // Validate restaurant logo
      if (!ImagePickerService.validateRestaurantLogo(imageFile)) {
        throw Exception(
            'Invalid restaurant logo. Please select a valid image under 3MB.');
      }

      // Read image bytes
      final bytes = await imageFile.readAsBytes();

      // Upload to Supabase storage
      final fileName =
          'restaurant_logo_${DateTime.now().millisecondsSinceEpoch}.${imageFile.path.split('.').last}';
      final filePath = 'restaurants/$restaurantId/$fileName';

      await Supabase.instance.client.storage
          .from('restaurant-images')
          .uploadBinary(filePath, Uint8List.fromList(bytes));

      // Get public URL
      final url = Supabase.instance.client.storage
          .from('restaurant-images')
          .getPublicUrl(filePath);

      _uploadProgress = 1.0;
      notifyListeners();

      return url;
    } catch (e) {
      debugPrint('Error uploading restaurant logo: $e');
      return null;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  // Upload menu item image
  Future<String?> uploadMenuItemImage(String menuItemId, File imageFile) async {
    try {
      _isUploading = true;
      _uploadProgress = 0.0;
      notifyListeners();

      // Validate menu item image
      if (!ImagePickerService.validateMenuItemImage(imageFile)) {
        throw Exception(
            'Invalid menu item image. Please select a valid image under 4MB.');
      }

      // Read image bytes
      final bytes = await imageFile.readAsBytes();

      // Upload to Supabase storage
      final fileName =
          'menu_item_${DateTime.now().millisecondsSinceEpoch}.${imageFile.path.split('.').last}';
      final filePath = 'menu-items/$menuItemId/$fileName';

      await Supabase.instance.client.storage
          .from('menu-item-images')
          .uploadBinary(filePath, Uint8List.fromList(bytes));

      // Get public URL
      final url = Supabase.instance.client.storage
          .from('menu-item-images')
          .getPublicUrl(filePath);

      _uploadProgress = 1.0;
      notifyListeners();

      return url;
    } catch (e) {
      debugPrint('Error uploading menu item image: $e');
      return null;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  // Upload multiple menu item images
  Future<List<String>> uploadMenuItemImages(
      String menuItemId, List<File> imageFiles) async {
    try {
      _isUploading = true;
      _uploadProgress = 0.0;
      notifyListeners();

      final urls = <String>[];
      final totalImages = imageFiles.length;

      for (int i = 0; i < imageFiles.length; i++) {
        final imageFile = imageFiles[i];

        // Validate each image
        if (!ImagePickerService.validateMenuItemImage(imageFile)) {
          debugPrint('Skipping invalid image: ${imageFile.path}');
          continue;
        }

        final bytes = await imageFile.readAsBytes();
        final fileName =
            'menu_item_${DateTime.now().millisecondsSinceEpoch}_$i.${imageFile.path.split('.').last}';
        final filePath = 'menu-items/$menuItemId/$fileName';

        await Supabase.instance.client.storage
            .from('menu-item-images')
            .uploadBinary(filePath, Uint8List.fromList(bytes));

        final url = Supabase.instance.client.storage
            .from('menu-item-images')
            .getPublicUrl(filePath);

        urls.add(url);

        _uploadProgress = (i + 1) / totalImages;
        notifyListeners();
      }

      return urls;
    } catch (e) {
      debugPrint('Error uploading menu item images: $e');
      return [];
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  // Upload restaurant cover image
  Future<String?> uploadRestaurantCoverImage(
      String restaurantId, File imageFile) async {
    try {
      _isUploading = true;
      _uploadProgress = 0.0;
      notifyListeners();

      // Validate image
      if (!ImagePickerService.validateImage(imageFile)) {
        throw Exception(
            'Invalid restaurant cover image. Please select a valid image under 5MB.');
      }

      // Read image bytes
      final bytes = await imageFile.readAsBytes();

      // Upload to Supabase storage
      final fileName =
          'restaurant_cover_${DateTime.now().millisecondsSinceEpoch}.${imageFile.path.split('.').last}';
      final filePath = 'restaurants/$restaurantId/$fileName';

      await Supabase.instance.client.storage
          .from('restaurant-images')
          .uploadBinary(filePath, Uint8List.fromList(bytes));

      // Get public URL
      final url = Supabase.instance.client.storage
          .from('restaurant-images')
          .getPublicUrl(filePath);

      _uploadProgress = 1.0;
      notifyListeners();

      return url;
    } catch (e) {
      debugPrint('Error uploading restaurant cover image: $e');
      return null;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  // Upload image with custom path
  Future<String?> uploadImageWithCustomPath(
    String bucketName,
    String path,
    File imageFile,
  ) async {
    try {
      _isUploading = true;
      _uploadProgress = 0.0;
      notifyListeners();

      // Read image bytes
      final bytes = await imageFile.readAsBytes();

      // Upload to Supabase storage
      await Supabase.instance.client.storage
          .from(bucketName)
          .uploadBinary(path, Uint8List.fromList(bytes));

      // Get public URL
      final url =
          Supabase.instance.client.storage.from(bucketName).getPublicUrl(path);

      _uploadProgress = 1.0;
      notifyListeners();

      return url;
    } catch (e) {
      debugPrint('Error uploading image with custom path: $e');
      return null;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  // Compress image
  Future<Uint8List> compressImage(File imageFile, {int quality = 85}) async {
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

  // Get image dimensions
  Future<Map<String, int>> getImageDimensions(File imageFile) async {
    try {
      // For now, return default dimensions
      // In a real app, you'd use a library to get actual dimensions
      return {'width': 1920, 'height': 1080};
    } catch (e) {
      debugPrint('Error getting image dimensions: $e');
      return {'width': 0, 'height': 0};
    }
  }

  // Validate image file
  bool validateImageFile(File imageFile) {
    try {
      // Check if file exists
      if (!imageFile.existsSync()) return false;

      // Check file size (max 10MB)
      final fileSize = imageFile.lengthSync();
      if (fileSize > 10 * 1024 * 1024) return false;

      // Check file extension
      final extension = imageFile.path.split('.').last.toLowerCase();
      final validExtensions = ['jpg', 'jpeg', 'png', 'webp'];
      if (!validExtensions.contains(extension)) return false;

      return true;
    } catch (e) {
      debugPrint('Error validating image file: $e');
      return false;
    }
  }

  // Delete image from storage
  Future<bool> deleteImage(String bucketName, String path) async {
    try {
      await Supabase.instance.client.storage.from(bucketName).remove([path]);
      return true;
    } catch (e) {
      debugPrint('Error deleting image: $e');
      return false;
    }
  }

  // Get storage bucket info
  Future<Map<String, dynamic>?> getBucketInfo(String bucketName) async {
    try {
      final response =
          await Supabase.instance.client.storage.from(bucketName).list();
      return {'files': response.length};
    } catch (e) {
      debugPrint('Error getting bucket info: $e');
      return null;
    }
  }

  // Create storage bucket (admin only)
  Future<bool> createBucket(String bucketName) async {
    try {
      // This would require admin privileges
      // For now, return false
      return false;
    } catch (e) {
      debugPrint('Error creating bucket: $e');
      return false;
    }
  }

  // Update upload progress
  void updateProgress(double progress) {
    _uploadProgress = progress;
    notifyListeners();
  }

  // Reset upload state
  void resetUploadState() {
    _isUploading = false;
    _uploadProgress = 0.0;
    notifyListeners();
  }

  // Upload profile image using new cloud storage service
  Future<Map<String, dynamic>> uploadProfileImageNew(File imageFile,
      {String? existingImageUrl}) async {
    try {
      _isUploading = true;
      _uploadProgress = 0.0;
      notifyListeners();

      // Validate image file
      if (!ImagePickerService.validateImage(imageFile)) {
        throw Exception(
            'Invalid image file. Please select a valid image under 5MB.');
      }

      // Get current user ID
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Ensure bucket exists
      await CloudStorageService.ensureBucketExists();

      // Upload image to cloud storage
      final imageUrl = await CloudStorageService.uploadProfileImage(
        imageFile: imageFile,
        userId: currentUser.id,
        existingImagePath: existingImageUrl,
      );

      if (imageUrl == null) {
        throw Exception('Failed to upload image to cloud storage');
      }

      _uploadProgress = 1.0;
      notifyListeners();

      resetUploadState();

      return {
        'success': true,
        'url': imageUrl,
        'size': ImagePickerService.getImageSizeInMB(imageFile),
      };
    } catch (e) {
      resetUploadState();
      debugPrint('Profile image upload error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Upload profile image (legacy method - kept for compatibility)
  Future<Map<String, dynamic>> uploadProfileImage(File imageFile) async {
    try {
      _isUploading = true;
      _uploadProgress = 0.0;
      notifyListeners();

      // Generate unique filename
      final fileExtension = imageFile.path.split('.').last;
      final fileName =
          'profile_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      // Get current user ID for the file path
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // File path must match RLS policy: {userId}/filename
      final filePath = '${currentUser.id}/$fileName';

      // Upload to Supabase Storage
      await Supabase.instance.client.storage
          .from('user-avatars')
          .upload(filePath, imageFile);

      _uploadProgress = 1.0;
      notifyListeners();

      // Get public URL
      final url = Supabase.instance.client.storage
          .from('user-avatars')
          .getPublicUrl(filePath);

      resetUploadState();

      return {
        'success': true,
        'url': url,
        'path': filePath,
      };
    } catch (e) {
      resetUploadState();
      debugPrint('Profile image upload error details: $e');
      debugPrint('Error type: ${e.runtimeType}');
      if (e.toString().contains('bucket')) {
        debugPrint('Bucket-related error detected');
      }
      if (e.toString().contains('policy')) {
        debugPrint('Policy-related error detected');
      }
      if (e.toString().contains('auth')) {
        debugPrint('Authentication error detected');
      }
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get upload status message
  String get uploadStatusMessage {
    if (!_isUploading) return 'Ready';
    if (_uploadProgress == 0.0) return 'Preparing upload...';
    if (_uploadProgress < 1.0) {
      return 'Uploading... ${(_uploadProgress * 100).toInt()}%';
    }
    return 'Upload complete!';
  }
}
