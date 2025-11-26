import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'logging_service.dart';

class MenuItemImageService {
  static final MenuItemImageService _instance =
      MenuItemImageService._internal();
  factory MenuItemImageService() => _instance;
  MenuItemImageService._internal();

  static const String _bucketName = 'menu-item-images';
  static const int _maxFileSize = 10 * 1024 * 1024; // 10MB for food images
  static const List<String> _allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

  // Logging service for business metrics and performance tracking
  final LoggingService _logger = LoggingService();

  // Performance tracking
  final Map<String, DateTime> _uploadStartTimes = {};
  final Map<String, int> _uploadCounts = {};

  // Cache for processed images
  final Map<String, String> _processedImageCache = {};

  /// Initialize the service
  Future<void> initialize() async {
    try {
      _logger.startPerformanceTimer('menu_image_service_init');
      await ensureBucketExists();
      _logger.endPerformanceTimer('menu_image_service_init',
          details: 'MenuItemImageService initialized successfully');
      _logger.info('MenuItemImageService initialized', tag: 'MENU_IMAGE');
    } catch (e) {
      _logger.error('Failed to initialize MenuItemImageService',
          tag: 'MENU_IMAGE', error: e);
      rethrow;
    }
  }

  /// Upload menu item images to Supabase Storage
  /// Returns list of public URLs for uploaded images
  Future<List<String>> uploadMenuItemImages({
    required List<File> images,
    required String menuItemId,
    required String restaurantId,
    required Function(double) onProgress,
  }) async {
    final uploadSessionId =
        '${menuItemId}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      _logger.startPerformanceTimer('menu_image_upload', metadata: {
        'menu_item_id': menuItemId,
        'restaurant_id': restaurantId,
        'image_count': images.length,
        'upload_session_id': uploadSessionId,
      });

      _logger.logUserAction(
        'menu_image_upload_started',
        data: {
          'menu_item_id': menuItemId,
          'restaurant_id': restaurantId,
          'image_count': images.length,
          'upload_session_id': uploadSessionId,
        },
      );

      debugPrint(
          '🍽️ Starting upload of ${images.length} food images for menu item $menuItemId');

      final List<String> uploadedUrls = [];
      final supabase = Supabase.instance.client;

      // Track upload start time
      _uploadStartTimes[uploadSessionId] = DateTime.now();
      _uploadCounts[uploadSessionId] = images.length;

      for (int i = 0; i < images.length; i++) {
        final File imageFile = images[i];

        // Update progress
        onProgress((i + 1) / images.length);

        // Validate file
        await _validateImageFile(imageFile);

        // Generate unique filename
        final String fileName = _generateFileName(imageFile, i);
        final String filePath =
            'menu-items/$restaurantId/$menuItemId/$fileName';

        debugPrint('📤 Uploading food image $i: $filePath');

        // Read file bytes
        final bytes = await imageFile.readAsBytes();

        // Upload to Supabase Storage
        await supabase.storage.from(_bucketName).uploadBinary(
              filePath,
              bytes,
              fileOptions: FileOptions(
                contentType: _getContentType(imageFile),
                upsert: true,
              ),
            );

        // Get the public URL for the uploaded image
        final publicUrl =
            supabase.storage.from(_bucketName).getPublicUrl(filePath);

        // Store the public URL for database storage
        uploadedUrls.add(publicUrl);

        // Cache the processed image
        _processedImageCache[filePath] = publicUrl;

        debugPrint('✅ Food image $i uploaded successfully: $publicUrl');

        // Log individual image upload metrics
        _logger.logLocationMetrics(
          deliveryPersonId: restaurantId,
          latitude: 0,
          longitude: 0,
          additionalData: {
            'operation': 'image_upload',
            'menu_item_id': menuItemId,
            'image_index': i,
            'file_size': bytes.length,
            'file_path': filePath,
            'public_url': publicUrl,
          },
        );
      }

      // Calculate upload performance metrics
      final uploadDuration =
          DateTime.now().difference(_uploadStartTimes[uploadSessionId]!);
      final totalSize =
          images.fold<int>(0, (sum, file) => sum + file.lengthSync());

      _logger.logUserAction(
        'menu_image_upload_completed',
        data: {
          'menu_item_id': menuItemId,
          'restaurant_id': restaurantId,
          'image_count': images.length,
          'upload_session_id': uploadSessionId,
          'upload_duration_ms': uploadDuration.inMilliseconds,
          'total_size_bytes': totalSize,
          'average_size_per_image': totalSize / images.length,
          'uploaded_urls': uploadedUrls,
        },
      );

      _logger.endPerformanceTimer('menu_image_upload',
          details: 'All images uploaded successfully');

      debugPrint(
          '🎉 All ${uploadedUrls.length} food images uploaded successfully');
      return uploadedUrls;
    } catch (e, stackTrace) {
      _logger.error(
        'Error uploading menu item images',
        tag: 'MENU_IMAGE',
        error: e,
        stackTrace: stackTrace,
        additionalData: {
          'menu_item_id': menuItemId,
          'restaurant_id': restaurantId,
          'image_count': images.length,
          'upload_session_id': uploadSessionId,
        },
      );

      _logger.endPerformanceTimer('menu_image_upload',
          details: 'Image upload failed');

      debugPrint('❌ Error uploading menu item images: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Failed to upload menu item images: $e');
    } finally {
      // Clean up tracking data
      _uploadStartTimes.remove(uploadSessionId);
      _uploadCounts.remove(uploadSessionId);
    }
  }

  /// Validate image file before upload
  Future<void> _validateImageFile(File file) async {
    // Check if file exists
    if (!file.existsSync()) {
      throw Exception('Image file does not exist');
    }

    // Check file size
    final fileSize = await file.length();
    if (fileSize > _maxFileSize) {
      throw Exception(
          'Image file size exceeds maximum allowed size of ${_maxFileSize ~/ (1024 * 1024)}MB');
    }

    // Check file extension
    final extension = path.extension(file.path).toLowerCase().substring(1);
    if (!_allowedExtensions.contains(extension)) {
      throw Exception(
          'Image file type not supported. Allowed types: ${_allowedExtensions.join(', ')}');
    }
  }

  /// Generate unique filename for image
  String _generateFileName(File file, int index) {
    final extension = path.extension(file.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'food_${index}_$timestamp$extension';
  }

  /// Get content type for file
  String _getContentType(File file) {
    final extension = path.extension(file.path).toLowerCase();
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Get public URL for menu item image
  Future<String> getMenuItemImageUrl(String storagePath) async {
    try {
      final supabase = Supabase.instance.client;
      final url = supabase.storage.from(_bucketName).getPublicUrl(storagePath);

      debugPrint('🔗 Generated public URL for menu item image: $url');
      return url;
    } catch (e) {
      debugPrint('❌ Error generating public URL: $e');
      throw Exception('Failed to generate public URL: $e');
    }
  }

  /// Ensure image URL is properly formatted (converts storage paths to public URLs)
  String ensureImageUrl(String imagePath) {
    // If it's already a full URL, return as is
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    // If it's a storage path, convert to public URL
    if (imagePath.startsWith('menu-items/')) {
      final supabase = Supabase.instance.client;
      return supabase.storage.from(_bucketName).getPublicUrl(imagePath);
    }

    // If it's empty or invalid, return empty string
    return '';
  }

  /// Delete menu item image from storage
  Future<void> deleteMenuItemImage(String storagePath) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.storage.from(_bucketName).remove([storagePath]);

      debugPrint('🗑️ Deleted menu item image: $storagePath');
    } catch (e) {
      debugPrint('❌ Error deleting menu item image: $e');
      throw Exception('Failed to delete menu item image: $e');
    }
  }

  /// Delete all images for a menu item
  Future<void> deleteMenuItemImages(
      String menuItemId, String restaurantId) async {
    try {
      _logger.startPerformanceTimer('menu_image_deletion', metadata: {
        'menu_item_id': menuItemId,
        'restaurant_id': restaurantId,
      });

      _logger.logUserAction(
        'menu_image_deletion_started',
        data: {
          'menu_item_id': menuItemId,
          'restaurant_id': restaurantId,
        },
      );

      final supabase = Supabase.instance.client;
      final folderPath = 'menu-items/$restaurantId/$menuItemId/';

      // List all files in the folder
      final files =
          await supabase.storage.from(_bucketName).list(path: folderPath);

      if (files.isNotEmpty) {
        final filePaths =
            files.map((file) => '$folderPath${file.name}').toList();
        await supabase.storage.from(_bucketName).remove(filePaths);

        // Remove from cache
        filePaths.forEach(_processedImageCache.remove);

        _logger.logUserAction(
          'menu_image_deletion_completed',
          data: {
            'menu_item_id': menuItemId,
            'restaurant_id': restaurantId,
            'deleted_count': filePaths.length,
            'deleted_paths': filePaths,
          },
        );

        debugPrint(
            '🗑️ Deleted ${filePaths.length} menu item images for $menuItemId');
      } else {
        _logger.info('No images found to delete for menu item $menuItemId',
            tag: 'MENU_IMAGE');
      }

      _logger.endPerformanceTimer('menu_image_deletion',
          details: 'Menu item images deleted successfully');
    } catch (e) {
      _logger.error(
        'Error deleting menu item images',
        tag: 'MENU_IMAGE',
        error: e,
        additionalData: {
          'menu_item_id': menuItemId,
          'restaurant_id': restaurantId,
        },
      );

      _logger.endPerformanceTimer('menu_image_deletion',
          details: 'Menu item image deletion failed');

      debugPrint('❌ Error deleting menu item images: $e');
      throw Exception('Failed to delete menu item images: $e');
    }
  }

  /// Get storage usage for a restaurant's menu items
  Future<int> getRestaurantMenuStorageUsage(String restaurantId) async {
    try {
      final supabase = Supabase.instance.client;
      final folderPath = 'menu-items/$restaurantId/';

      // List all files in the restaurant's folder
      final files = await supabase.storage.from(_bucketName).list(
          path: folderPath, searchOptions: const SearchOptions(limit: 1000));

      int totalSize = 0;
      for (final file in files) {
        final sizeValue = file.metadata?['size'];
        if (sizeValue != null) {
          totalSize += int.tryParse(sizeValue.toString()) ?? 0;
        }
      }

      debugPrint(
          '📊 Restaurant $restaurantId menu storage usage: ${totalSize ~/ (1024 * 1024)}MB');
      return totalSize;
    } catch (e) {
      debugPrint('❌ Error getting restaurant menu storage usage: $e');
      return 0;
    }
  }

  /// Ensure the menu item images bucket exists
  Future<void> ensureBucketExists() async {
    try {
      final supabase = Supabase.instance.client;

      // Check if bucket exists
      final buckets = await supabase.storage.listBuckets();
      final bucketExists = buckets.any((bucket) => bucket.name == _bucketName);

      if (!bucketExists) {
        try {
          // Create bucket
          await supabase.storage.createBucket(
            _bucketName,
            const BucketOptions(
              public: true,
              allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
              fileSizeLimit: '10485760', // 10MB as string
            ),
          );

          debugPrint('🪣 Created menu item images bucket: $_bucketName');
        } catch (createError) {
          // If bucket creation fails due to RLS policy, log warning but continue
          if (createError.toString().contains('row-level security policy') ||
              createError.toString().contains('403') ||
              createError.toString().contains('Unauthorized')) {
            debugPrint(
                '⚠️ Cannot create bucket due to RLS policy - bucket may need to be created by admin');
            debugPrint(
                '⚠️ Continuing without bucket creation - uploads may fail if bucket does not exist');
            return;
          }
          rethrow;
        }
      } else {
        debugPrint('🪣 Menu item images bucket already exists: $_bucketName');
      }
    } catch (e) {
      debugPrint('❌ Error ensuring menu item images bucket exists: $e');

      // If it's an RLS policy error, don't throw - just log and continue
      if (e.toString().contains('row-level security policy') ||
          e.toString().contains('403') ||
          e.toString().contains('Unauthorized')) {
        debugPrint(
            '⚠️ RLS policy prevents bucket operations - continuing without bucket verification');
        return;
      }

      throw Exception('Failed to ensure menu item images bucket exists: $e');
    }
  }

  /// Compress image for better performance
  Future<Uint8List> compressImage(File imageFile, {int quality = 85}) async {
    try {
      // For now, return the original bytes
      // In a real implementation, you would use image compression libraries
      final bytes = await imageFile.readAsBytes();
      return bytes;
    } catch (e) {
      debugPrint('❌ Error compressing image: $e');
      throw Exception('Failed to compress image: $e');
    }
  }

  /// Get performance analytics for the service
  Map<String, dynamic> getPerformanceAnalytics() {
    final now = DateTime.now();
    final analytics = <String, dynamic>{
      'total_uploads':
          _uploadCounts.values.fold<int>(0, (sum, count) => sum + count),
      'active_uploads': _uploadCounts.length,
      'cached_images': _processedImageCache.length,
      'service_uptime': now
          .difference(_uploadStartTimes.isNotEmpty
              ? _uploadStartTimes.values.reduce((a, b) => a.isBefore(b) ? a : b)
              : now)
          .inMinutes,
    };

    _logger.info('MenuItemImageService performance analytics',
        tag: 'MENU_IMAGE', additionalData: analytics);
    return analytics;
  }

  /// Clear performance cache
  void clearPerformanceCache() {
    _uploadStartTimes.clear();
    _uploadCounts.clear();
    _processedImageCache.clear();
    _logger.info('MenuItemImageService performance cache cleared',
        tag: 'MENU_IMAGE');
  }

  /// Get cached image URL
  String? getCachedImageUrl(String filePath) {
    return _processedImageCache[filePath];
  }

  /// Preload images for better performance
  Future<void> preloadImages(List<String> imageUrls) async {
    try {
      _logger.startPerformanceTimer('image_preload', metadata: {
        'image_count': imageUrls.length,
      });

      for (final url in imageUrls) {
        // In a real implementation, you would preload images here
        // For now, we'll just cache the URLs
        _processedImageCache[url] = url;
      }

      _logger.endPerformanceTimer('image_preload',
          details: 'Images preloaded successfully');
      _logger.info('Preloaded ${imageUrls.length} images', tag: 'MENU_IMAGE');
    } catch (e) {
      _logger.error('Failed to preload images', tag: 'MENU_IMAGE', error: e);
    }
  }
}
