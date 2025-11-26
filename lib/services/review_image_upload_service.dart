// ignore_for_file: avoid_slow_async_io

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Unified service for uploading review images to Supabase Storage
/// Handles both restaurant reviews and menu item reviews
class ReviewImageUploadService {
  static final ReviewImageUploadService _instance =
      ReviewImageUploadService._internal();
  factory ReviewImageUploadService() => _instance;
  ReviewImageUploadService._internal();

  final _supabase = Supabase.instance.client;

  // Storage bucket names
  static const String _reviewImagesBucket = 'review-images';

  /// Upload a single review image to Supabase Storage
  /// Returns the public URL of the uploaded image
  Future<String?> uploadReviewImage({
    required String filePath,
    required String reviewType, // 'menu_item' or 'restaurant'
    required String reviewId,
  }) async {
    try {
      // Ensure bucket exists before uploading
      await ensureBucketExists();

      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('❌ File does not exist: $filePath');
        return null;
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(filePath);
      final fileName = '${reviewType}_${reviewId}_$timestamp$extension';

      // Upload path: review-images/{reviewType}/{reviewId}/{fileName}
      final uploadPath = '$reviewType/$reviewId/$fileName';

      debugPrint('📤 Uploading review image: $uploadPath');

      // Read file as bytes
      final bytes = await file.readAsBytes();

      // Upload to Supabase Storage
      try {
        debugPrint('🔍 Attempting upload to bucket: $_reviewImagesBucket');
        debugPrint('🔍 Upload path: $uploadPath');
        debugPrint('🔍 File size: ${bytes.length} bytes');

        await _supabase.storage.from(_reviewImagesBucket).uploadBinary(
              uploadPath,
              bytes,
              fileOptions: FileOptions(
                contentType: _getContentType(extension),
                upsert: false,
              ),
            );

        debugPrint('✅ Upload to storage successful');
      } catch (uploadError) {
        debugPrint('❌ Storage upload failed: $uploadError');
        throw Exception('Storage upload failed: $uploadError');
      }

      // Get public URL
      final publicUrl =
          _supabase.storage.from(_reviewImagesBucket).getPublicUrl(uploadPath);

      debugPrint('✅ Image uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e, stackTrace) {
      debugPrint('❌ Error uploading review image: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return null;
    }
  }

  /// Upload multiple review images
  /// Returns list of public URLs
  Future<List<String>> uploadReviewImages({
    required List<String> filePaths,
    required String reviewType,
    required String reviewId,
  }) async {
    debugPrint('🔍 uploadReviewImages called with ${filePaths.length} files');
    debugPrint('🔍 Review type: $reviewType, Review ID: $reviewId');
    debugPrint('🔍 File paths: $filePaths');

    final urls = <String>[];

    for (int i = 0; i < filePaths.length; i++) {
      final filePath = filePaths[i];
      debugPrint('🔍 Uploading image ${i + 1}/${filePaths.length}: $filePath');

      final url = await uploadReviewImage(
        filePath: filePath,
        reviewType: reviewType,
        reviewId: reviewId,
      );

      if (url != null) {
        urls.add(url);
        debugPrint('✅ Image ${i + 1} uploaded: $url');
      } else {
        debugPrint('❌ Failed to upload image ${i + 1}');
      }
    }

    debugPrint('✅ Uploaded ${urls.length} of ${filePaths.length} images');
    debugPrint('🔍 Final URLs: $urls');
    return urls;
  }

  /// Delete review images from storage
  Future<bool> deleteReviewImages({
    required String reviewType,
    required String reviewId,
  }) async {
    try {
      // List all files in the review folder
      final files = await _supabase.storage
          .from(_reviewImagesBucket)
          .list(path: '$reviewType/$reviewId');

      if (files.isEmpty) {
        debugPrint('ℹ️ No images to delete for review $reviewId');
        return true;
      }

      // Delete all files
      final filePaths =
          files.map((file) => '$reviewType/$reviewId/${file.name}').toList();

      await _supabase.storage.from(_reviewImagesBucket).remove(filePaths);

      debugPrint('✅ Deleted ${filePaths.length} images for review $reviewId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting review images: $e');
      return false;
    }
  }

  /// Get content type from file extension
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Ensure the storage bucket exists
  Future<void> ensureBucketExists() async {
    try {
      debugPrint('🔍 Checking if bucket "$_reviewImagesBucket" exists...');

      // Try to list buckets to check if our bucket exists
      final buckets = await _supabase.storage.listBuckets();
      final bucketExists = buckets.any((b) => b.id == _reviewImagesBucket);

      if (bucketExists) {
        debugPrint('✅ Review images bucket "$_reviewImagesBucket" exists');
        return;
      }

      debugPrint('ℹ️ Bucket "$_reviewImagesBucket" not found, creating...');

      // Bucket doesn't exist, try to create it
      try {
        await _supabase.storage.createBucket(
          _reviewImagesBucket,
          const BucketOptions(
            public: true,
            allowedMimeTypes: [
              'image/jpeg',
              'image/jpg',
              'image/png',
              'image/gif',
              'image/webp',
            ],
          ),
        );
        debugPrint('✅ Successfully created bucket "$_reviewImagesBucket"');
      } catch (createError) {
        debugPrint(
            '❌ Error creating bucket "$_reviewImagesBucket": $createError');
        debugPrint('⚠️ ====================================================');
        debugPrint('⚠️ MANUAL ACTION REQUIRED:');
        debugPrint('⚠️ Please create the storage bucket manually:');
        debugPrint('⚠️ 1. Go to Supabase Dashboard → Storage');
        debugPrint('⚠️ 2. Click "New bucket"');
        debugPrint('⚠️ 3. Name: $_reviewImagesBucket');
        debugPrint('⚠️ 4. Public bucket: ON');
        debugPrint('⚠️ 5. File size limit: 5MB (optional)');
        debugPrint('⚠️ 6. Allowed MIME types: image/* (optional)');
        debugPrint('⚠️ ====================================================');

        // Don't rethrow - allow upload to continue in case bucket was just created
        // and the error was transient
      }
    } catch (e) {
      debugPrint('❌ Error checking bucket existence: $e');
      // Continue anyway - maybe the bucket exists but we couldn't check
    }
  }
}
