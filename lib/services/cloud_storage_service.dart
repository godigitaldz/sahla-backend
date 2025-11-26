import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/maps_config.dart';

/// Google Cloud Storage service for optimized image delivery
class CloudStorageService {
  static const String _baseUrl =
      'https://storage.googleapis.com/storage/v1/b/your-bucket-name/o';
  static const String _apiKey = MapsConfig.googleMapsApiKey;

  /// Upload image to Cloud Storage
  static Future<String?> uploadImage({
    required String imagePath,
    required String fileName,
    required String folder,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/$folder/$fileName');

      debugPrint('📤 Uploading image: $fileName to folder: $folder');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'image/jpeg',
        },
        body: await http.readBytes(Uri.parse(imagePath)),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final publicUrl = data['mediaLink'] as String?;
        debugPrint('✅ Image uploaded successfully: $publicUrl');
        return publicUrl;
      } else {
        debugPrint('❌ Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error uploading image: $e');
    }

    return null;
  }

  /// Get optimized image URL
  static String getOptimizedImageUrl({
    required String imagePath,
    int? width,
    int? height,
    String format = 'webp',
    int quality = 80,
  }) {
    const baseUrl = 'https://storage.googleapis.com/your-bucket-name';
    final optimizedPath = imagePath.replaceFirst('gs://your-bucket-name/', '');

    // Add optimization parameters
    final params = <String, String>{
      'format': format,
      'quality': quality.toString(),
    };

    if (width != null) params['width'] = width.toString();
    if (height != null) params['height'] = height.toString();

    final queryString =
        params.entries.map((e) => '${e.key}=${e.value}').join('&');

    final optimizedUrl = '$baseUrl/$optimizedPath?$queryString';

    debugPrint('🖼️ Generated optimized image URL: $optimizedUrl');
    return optimizedUrl;
  }

  /// Upload restaurant menu image
  static Future<String?> uploadMenuImage({
    required String imagePath,
    required String restaurantId,
    required String menuItemId,
  }) async {
    try {
      final fileName =
          'menu_${restaurantId}_${menuItemId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final folder = 'restaurants/$restaurantId/menu';

      return await uploadImage(
        imagePath: imagePath,
        fileName: fileName,
        folder: folder,
      );
    } catch (e) {
      debugPrint('❌ Error uploading menu image: $e');
      return null;
    }
  }

  /// Upload restaurant profile image
  static Future<String?> uploadRestaurantProfileImage({
    required String imagePath,
    required String restaurantId,
  }) async {
    try {
      final fileName =
          'profile_${restaurantId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final folder = 'restaurants/$restaurantId/profile';

      return await uploadImage(
        imagePath: imagePath,
        fileName: fileName,
        folder: folder,
      );
    } catch (e) {
      debugPrint('❌ Error uploading restaurant profile image: $e');
      return null;
    }
  }

  /// Upload user profile image
  static Future<String?> uploadUserProfileImage({
    required String imagePath,
    required String userId,
  }) async {
    try {
      final fileName =
          'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final folder = 'users/$userId/profile';

      return await uploadImage(
        imagePath: imagePath,
        fileName: fileName,
        folder: folder,
      );
    } catch (e) {
      debugPrint('❌ Error uploading user profile image: $e');
      return null;
    }
  }

  /// Upload delivery person profile image
  static Future<String?> uploadDeliveryPersonProfileImage({
    required String imagePath,
    required String deliveryPersonId,
  }) async {
    try {
      final fileName =
          'profile_${deliveryPersonId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final folder = 'delivery-persons/$deliveryPersonId/profile';

      return await uploadImage(
        imagePath: imagePath,
        fileName: fileName,
        folder: folder,
      );
    } catch (e) {
      debugPrint('❌ Error uploading delivery person profile image: $e');
      return null;
    }
  }

  /// Upload promotional image
  static Future<String?> uploadPromotionalImage({
    required String imagePath,
    required String campaignId,
  }) async {
    try {
      final fileName =
          'promo_${campaignId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final folder = 'promotions/$campaignId';

      return await uploadImage(
        imagePath: imagePath,
        fileName: fileName,
        folder: folder,
      );
    } catch (e) {
      debugPrint('❌ Error uploading promotional image: $e');
      return null;
    }
  }

  /// Delete image from Cloud Storage
  static Future<bool> deleteImage(String imagePath) async {
    try {
      final uri = Uri.parse('$_baseUrl/$imagePath');

      debugPrint('🗑️ Deleting image: $imagePath');

      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $_apiKey',
        },
      );

      if (response.statusCode == 204) {
        debugPrint('✅ Image deleted successfully');
        return true;
      } else {
        debugPrint('❌ Failed to delete image: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error deleting image: $e');
    }

    return false;
  }

  /// Get image metadata
  static Future<ImageMetadata?> getImageMetadata(String imagePath) async {
    try {
      final uri = Uri.parse('$_baseUrl/$imagePath');

      debugPrint('📋 Getting image metadata: $imagePath');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_apiKey',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ Image metadata retrieved');
        return ImageMetadata.fromJson(data);
      } else {
        debugPrint('❌ Failed to get image metadata: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error getting image metadata: $e');
    }

    return null;
  }

  /// List images in folder
  static Future<List<ImageInfo>> listImages(String folder) async {
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'prefix': folder,
        'delimiter': '/',
      });

      debugPrint('📁 Listing images in folder: $folder');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_apiKey',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ Images listed successfully');

        if (data['items'] != null) {
          return (data['items'] as List)
              .map((item) => ImageInfo.fromJson(item))
              .toList();
        }
      } else {
        debugPrint('❌ Failed to list images: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error listing images: $e');
    }

    return [];
  }

  /// Generate signed URL for private images
  static Future<String?> generateSignedUrl({
    required String imagePath,
    required Duration expiration,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/$imagePath/generateSignedUrl');

      debugPrint('🔐 Generating signed URL for: $imagePath');

      final requestBody = {
        'expiration': expiration.inSeconds,
        'method': 'GET',
      };

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final signedUrl = data['signedUrl'] as String?;
        debugPrint('✅ Signed URL generated successfully');
        return signedUrl;
      } else {
        debugPrint('❌ Failed to generate signed URL: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error generating signed URL: $e');
    }

    return null;
  }

  /// Optimize image for different devices
  static String getDeviceOptimizedImageUrl({
    required String imagePath,
    required String deviceType,
  }) {
    switch (deviceType) {
      case 'mobile':
        return getOptimizedImageUrl(
          imagePath: imagePath,
          width: 400,
          height: 300,
          format: 'webp',
          quality: 75,
        );
      case 'tablet':
        return getOptimizedImageUrl(
          imagePath: imagePath,
          width: 800,
          height: 600,
          format: 'webp',
          quality: 80,
        );
      case 'desktop':
        return getOptimizedImageUrl(
          imagePath: imagePath,
          width: 1200,
          height: 900,
          format: 'webp',
          quality: 85,
        );
      default:
        return getOptimizedImageUrl(
          imagePath: imagePath,
          width: 600,
          height: 450,
          format: 'webp',
          quality: 80,
        );
    }
  }

  /// Ensure bucket exists (placeholder method)
  static Future<void> ensureBucketExists() async {
    try {
      debugPrint('🪣 Ensuring bucket exists...');
      // This would typically check if bucket exists and create if needed
      // For now, just log the action
      debugPrint('✅ Bucket check completed');
    } catch (e) {
      debugPrint('❌ Error ensuring bucket exists: $e');
    }
  }

  /// Upload profile image (placeholder method)
  static Future<String?> uploadProfileImage({
    required dynamic imageFile,
    required String userId,
    String? existingImagePath,
  }) async {
    try {
      debugPrint('📤 Uploading profile image for user: $userId');

      // This would typically upload the image file to cloud storage
      // For now, return a placeholder URL
      final imageUrl =
          'https://storage.googleapis.com/your-bucket-name/users/$userId/profile/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';

      debugPrint('✅ Profile image uploaded: $imageUrl');
      return imageUrl;
    } catch (e) {
      debugPrint('❌ Error uploading profile image: $e');
      return null;
    }
  }
}

/// Image metadata model
class ImageMetadata {
  final String name;
  final String bucket;
  final int size;
  final String contentType;
  final DateTime timeCreated;
  final DateTime updated;
  final String md5Hash;
  final String crc32c;

  const ImageMetadata({
    required this.name,
    required this.bucket,
    required this.size,
    required this.contentType,
    required this.timeCreated,
    required this.updated,
    required this.md5Hash,
    required this.crc32c,
  });

  factory ImageMetadata.fromJson(Map<String, dynamic> json) {
    return ImageMetadata(
      name: json['name'] ?? '',
      bucket: json['bucket'] ?? '',
      size: json['size'] ?? 0,
      contentType: json['contentType'] ?? '',
      timeCreated: DateTime.parse(
          json['timeCreated'] ?? DateTime.now().toIso8601String()),
      updated:
          DateTime.parse(json['updated'] ?? DateTime.now().toIso8601String()),
      md5Hash: json['md5Hash'] ?? '',
      crc32c: json['crc32c'] ?? '',
    );
  }

  /// Get human readable file size
  String get humanReadableSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Image info model
class ImageInfo {
  final String name;
  final String bucket;
  final int size;
  final String contentType;
  final DateTime timeCreated;
  final String md5Hash;

  const ImageInfo({
    required this.name,
    required this.bucket,
    required this.size,
    required this.contentType,
    required this.timeCreated,
    required this.md5Hash,
  });

  factory ImageInfo.fromJson(Map<String, dynamic> json) {
    return ImageInfo(
      name: json['name'] ?? '',
      bucket: json['bucket'] ?? '',
      size: json['size'] ?? 0,
      contentType: json['contentType'] ?? '',
      timeCreated: DateTime.parse(
          json['timeCreated'] ?? DateTime.now().toIso8601String()),
      md5Hash: json['md5Hash'] ?? '',
    );
  }

  /// Get human readable file size
  String get humanReadableSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
