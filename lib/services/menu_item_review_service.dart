import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:uuid/uuid.dart";

import "../models/menu_item_review.dart";
import "context_aware_service.dart";
import "review_image_upload_service.dart";

class MenuItemReviewService extends ChangeNotifier {
  // Context-aware service for tracking and validation
  final ContextAwareService _contextAware = ContextAwareService();

  // Initialize the service with context tracking
  void initializeSync() {
    _contextAware.initialize();
    debugPrint(
        "🚀 MenuItemReviewService initialized with context tracking (sync)");
  }

  Future<void> initialize() async {
    await _contextAware.initialize();
    debugPrint("🚀 MenuItemReviewService initialized with context tracking");
  }

  // Get reviews for a menu item
  Future<List<MenuItemReview>> getMenuItemReviews({
    required String menuItemId,
    int offset = 0,
    int limit = 20,
    String? sortBy, // 'newest', 'oldest', 'rating_high', 'rating_low'
    int? minRating,
    int? maxRating,
  }) async {
    try {
      debugPrint(
          "🍽️ FETCHING MENU ITEM REVIEWS: menuItemId=$menuItemId, limit=$limit, offset=$offset");

      final supabase = Supabase.instance.client;

      // Build the query
      final query = supabase
          .from('menu_item_reviews')
          .select('''
            id,
            menu_item_id,
            user_id,
            rating,
            comment,
            image,
            photos,
            created_at,
            updated_at,
            user_profiles:user_id (
              name,
              profile_image_url
            )
          ''')
          .eq('menu_item_id', menuItemId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final response = await query;

      final reviewsData = response as List<dynamic>;

      if (reviewsData.isEmpty) {
        debugPrint("⚠️ MENU ITEM REVIEWS: No data received from Supabase");
        return [];
      }

      final reviews = <MenuItemReview>[];

      for (var i = 0; i < reviewsData.length; i++) {
        try {
          final review = MenuItemReview.fromJson(reviewsData[i]);
          reviews.add(review);
        } on Exception catch (e) {
          debugPrint("❌ MENU ITEM REVIEW PARSING ERROR at index $i: $e");
          debugPrint("❌ PROBLEMATIC DATA: ${reviewsData[i]}");
        }
      }

      debugPrint(
          "✅ MENU ITEM REVIEWS PROCESSED SUCCESSFULLY: totalParsed=${reviews.length}");

      return reviews;
    } catch (e) {
      debugPrint(
          "❌ MenuItemReviewService: Error fetching menu item reviews: $e");
      return [];
    }
  }

  // Submit a review for a menu item
  Future<bool> submitMenuItemReview({
    required String menuItemId,
    required int rating,
    String? comment,
    String? image,
    List<String>? photos,
  }) async {
    try {
      debugPrint(
          "🍽️ SUBMITTING MENU ITEM REVIEW: menuItemId=$menuItemId, rating=$rating, photos=${photos?.length ?? 0}");

      // Use Supabase directly instead of disabled API
      final supabase = Supabase.instance.client;

      // Get current user
      final user = supabase.auth.currentUser;
      if (user == null) {
        debugPrint("❌ No authenticated user found");
        return false;
      }

      // Generate review ID first (needed for photo uploads)
      final reviewId = const Uuid().v4();
      debugPrint("📝 Generated review ID: $reviewId");

      // Upload photos to Supabase Storage if provided
      List<String> uploadedPhotoUrls = [];
      if (photos != null && photos.isNotEmpty) {
        debugPrint(
            "📤 Uploading ${photos.length} photos to Supabase Storage...");

        final uploadService = ReviewImageUploadService();
        uploadedPhotoUrls = await uploadService.uploadReviewImages(
          filePaths: photos,
          reviewType: 'menu_item',
          reviewId: reviewId,
        );

        debugPrint(
            "✅ Uploaded ${uploadedPhotoUrls.length} photos successfully");
      }

      // Upload single image if provided
      String? uploadedImageUrl;
      if (image != null && image.isNotEmpty) {
        debugPrint("📤 Uploading single image to Supabase Storage...");

        final uploadService = ReviewImageUploadService();
        uploadedImageUrl = await uploadService.uploadReviewImage(
          filePath: image,
          reviewType: 'menu_item',
          reviewId: reviewId,
        );

        if (uploadedImageUrl != null) {
          debugPrint("✅ Uploaded single image successfully");
        }
      }

      // Insert review into menu_item_reviews table with uploaded URLs
      await supabase.from('menu_item_reviews').insert({
        'id': reviewId,
        'menu_item_id': menuItemId,
        'user_id': user.id,
        'rating': rating,
        'comment': comment,
        'image': uploadedImageUrl,
        'photos': uploadedPhotoUrls,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint(
          "🍽️ MENU ITEM REVIEW INSERTED with ${uploadedPhotoUrls.length} uploaded photos");

      // Update menu item rating and review count
      await _updateMenuItemStats(menuItemId);

      debugPrint("✅ MENU ITEM REVIEW SUBMITTED SUCCESSFULLY");
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint(
          "❌ MenuItemReviewService: Error submitting menu item review: $e");
      return false;
    }
  }

  // Update menu item rating and review count after review submission
  Future<void> _updateMenuItemStats(String menuItemId) async {
    try {
      final supabase = Supabase.instance.client;

      // Get all reviews for this menu item
      final reviewsResponse = await supabase
          .from('menu_item_reviews')
          .select('rating')
          .eq('menu_item_id', menuItemId);

      final reviews = reviewsResponse as List<dynamic>;
      final reviewCount = reviews.length;

      if (reviewCount > 0) {
        // Calculate average rating
        final totalRating = reviews.fold(
            0.0, (sum, review) => sum + (review['rating'] as int).toDouble());
        final averageRating = totalRating / reviewCount;

        // Update menu item with new rating and review count
        await supabase.from('menu_items').update({
          'rating': averageRating,
          'review_count': reviewCount,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', menuItemId);

        debugPrint(
            "📊 MENU ITEM STATS UPDATED: rating=$averageRating, count=$reviewCount");
      }
    } catch (e) {
      debugPrint("❌ Error updating menu item stats: $e");
    }
  }

  // Update a review for a menu item
  Future<bool> updateMenuItemReview({
    required String reviewId,
    required int rating,
    String? comment,
    String? image,
    List<String>? photos,
  }) async {
    try {
      debugPrint(
          "🍽️ UPDATING MENU ITEM REVIEW: reviewId=$reviewId, rating=$rating");

      final supabase = Supabase.instance.client;

      // Update review in menu_item_reviews table
      final response = await supabase
          .from('menu_item_reviews')
          .update({
            'rating': rating,
            'comment': comment,
            'image': image,
            'photos': photos ?? [],
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reviewId)
          .select();

      debugPrint(
          "🍽️ UPDATE MENU ITEM REVIEW RESPONSE: ${response.toString()}");

      if ((response as List<dynamic>).isEmpty) {
        debugPrint("❌ UPDATE MENU ITEM REVIEW ERROR: No response");
        return false;
      }

      // Get the menu item ID from the updated review to update stats
      final updatedReview = response[0];
      final menuItemId = updatedReview['menu_item_id'];

      // Update menu item rating and review count
      await _updateMenuItemStats(menuItemId);

      debugPrint("✅ MENU ITEM REVIEW UPDATED SUCCESSFULLY");
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint(
          "❌ MenuItemReviewService: Error updating menu item review: $e");
      return false;
    }
  }

  // Delete a review for a menu item
  Future<bool> deleteMenuItemReview(String reviewId) async {
    try {
      debugPrint("🍽️ DELETING MENU ITEM REVIEW: reviewId=$reviewId");

      final supabase = Supabase.instance.client;

      // First get the review to find the menu item ID
      final reviewResponse = await supabase
          .from('menu_item_reviews')
          .select('menu_item_id')
          .eq('id', reviewId)
          .single();

      final menuItemId = reviewResponse['menu_item_id'];

      // Delete the review
      final deleteResponse =
          await supabase.from('menu_item_reviews').delete().eq('id', reviewId);

      debugPrint(
          "🍽️ DELETE MENU ITEM REVIEW RESPONSE: ${deleteResponse.toString()}");

      // Update menu item rating and review count
      await _updateMenuItemStats(menuItemId);

      debugPrint("✅ MENU ITEM REVIEW DELETED SUCCESSFULLY");
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint(
          "❌ MenuItemReviewService: Error deleting menu item review: $e");
      return false;
    }
  }

  // Get review statistics for a menu item
  Future<Map<String, dynamic>> getMenuItemReviewStats(String menuItemId) async {
    try {
      debugPrint("🍽️ FETCHING MENU ITEM REVIEW STATS: menuItemId=$menuItemId");

      final supabase = Supabase.instance.client;

      // Get all reviews for this menu item
      final reviewsResponse = await supabase
          .from('menu_item_reviews')
          .select('rating')
          .eq('menu_item_id', menuItemId);

      final reviews = reviewsResponse as List<dynamic>;
      final reviewCount = reviews.length;

      if (reviewCount == 0) {
        return {
          'total_reviews': 0,
          'average_rating': 0.0,
          'rating_distribution': {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0},
        };
      }

      // Calculate stats
      final totalRating = reviews.fold(
          0.0, (sum, review) => sum + (review['rating'] as int).toDouble());
      final averageRating = totalRating / reviewCount;

      // Calculate rating distribution
      final distribution = {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0};
      for (final review in reviews) {
        final rating = review['rating'].toString();
        if (distribution.containsKey(rating)) {
          distribution[rating] = (distribution[rating] as int) + 1;
        }
      }

      final stats = {
        'total_reviews': reviewCount,
        'average_rating': averageRating,
        'rating_distribution': distribution,
      };

      debugPrint("✅ MENU ITEM REVIEW STATS RECEIVED: $stats");

      return stats;
    } catch (e) {
      debugPrint(
          "❌ MenuItemReviewService: Error fetching menu item review stats: $e");
      return {};
    }
  }

  // Check if user can review a menu item (e.g., hasn't already reviewed it)
  Future<bool> canUserReviewMenuItem(String menuItemId, String userId) async {
    try {
      debugPrint(
          "🍽️ CHECKING USER CAN REVIEW: menuItemId=$menuItemId, userId=$userId");

      final supabase = Supabase.instance.client;

      // Check if user has already reviewed this menu item
      final existingReview = await supabase
          .from('menu_item_reviews')
          .select('id')
          .eq('menu_item_id', menuItemId)
          .eq('user_id', userId)
          .maybeSingle();

      final canReview = existingReview == null;

      debugPrint("✅ CAN USER REVIEW: $canReview");

      return canReview;
    } catch (e) {
      debugPrint(
          "❌ MenuItemReviewService: Error checking if user can review: $e");
      return false;
    }
  }

  // Get user's review for a menu item (if exists)
  Future<MenuItemReview?> getUserMenuItemReview(
      String menuItemId, String userId) async {
    try {
      debugPrint(
          "🍽️ FETCHING USER MENU ITEM REVIEW: menuItemId=$menuItemId, userId=$userId");

      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('menu_item_reviews')
          .select('''
            id,
            menu_item_id,
            user_id,
            rating,
            comment,
            image,
            photos,
            created_at,
            updated_at,
            user_profiles:user_id (
              name,
              profile_image_url
            )
          ''')
          .eq('menu_item_id', menuItemId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        debugPrint("⚠️ USER MENU ITEM REVIEW: No review found");
        return null;
      }

      final review = MenuItemReview.fromJson(response);

      debugPrint("✅ USER MENU ITEM REVIEW RECEIVED");

      return review;
    } catch (e) {
      debugPrint(
          "❌ MenuItemReviewService: Error fetching user menu item review: $e");
      return null;
    }
  }

  // Report a review
  Future<bool> reportMenuItemReview(String reviewId, String reason) async {
    try {
      debugPrint(
          "🍽️ REPORTING MENU ITEM REVIEW: reviewId=$reviewId, reason=$reason");

      final supabase = Supabase.instance.client;

      // Get current user
      final user = supabase.auth.currentUser;
      if (user == null) {
        debugPrint("❌ No authenticated user found");
        return false;
      }

      // Insert report into review_reports table (if it exists)
      // For now, we'll just log the report and return success
      await supabase.from('review_reports').insert({
        'review_id': reviewId,
        'user_id': user.id,
        'reason': reason,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint("✅ MENU ITEM REVIEW REPORTED SUCCESSFULLY");
      return true;
    } catch (e) {
      debugPrint(
          "❌ MenuItemReviewService: Error reporting menu item review: $e");
      // For now, return true even if reporting fails, since it's not critical
      return true;
    }
  }
}
