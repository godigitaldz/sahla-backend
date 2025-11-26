import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../models/restaurant_review.dart";
import "context_aware_service.dart";

class RestaurantReviewService extends ChangeNotifier {
  // Context-aware service for tracking and validation
  final ContextAwareService _contextAware = ContextAwareService();

  // Initialize the service with context tracking
  void initializeSync() {
    _contextAware.initialize();
    debugPrint(
        "🚀 RestaurantReviewService initialized with context tracking (sync)");
  }

  Future<void> initialize() async {
    await _contextAware.initialize();
    debugPrint("🚀 RestaurantReviewService initialized with context tracking");
  }

  // Get reviews for a restaurant (using Supabase)
  Future<List<RestaurantReview>> getRestaurantReviews({
    required String restaurantId,
    int offset = 0,
    int limit = 20,
    String? sortBy, // 'newest', 'oldest', 'rating_high', 'rating_low'
    int? minRating,
    int? maxRating,
  }) async {
    try {
      debugPrint(
          "🏪 FETCHING RESTAURANT REVIEWS: restaurantId=$restaurantId, limit=$limit, offset=$offset");

      final supabase = Supabase.instance.client;

      dynamic query = supabase
          .from('restaurant_reviews')
          .select('*, user_profiles:customer_id (name, profile_image_url)')
          .eq('restaurant_id', restaurantId);

      // Apply rating filters if provided
      if (minRating != null) {
        query = query.gte('rating', minRating);
      }
      if (maxRating != null) {
        query = query.lte('rating', maxRating);
      }

      // Apply sorting and pagination
      if (sortBy == 'oldest') {
        query = query.order('created_at', ascending: true);
      } else if (sortBy == 'rating_high') {
        query = query.order('rating', ascending: false);
      } else if (sortBy == 'rating_low') {
        query = query.order('rating', ascending: true);
      } else {
        // Default: newest first
        query = query.order('created_at', ascending: false);
      }

      // Apply pagination
      final response = await query.range(offset, offset + limit - 1);

      if (response.isEmpty) {
        debugPrint("⚠️ RESTAURANT REVIEWS: No reviews found");
        return [];
      }

      final reviews = <RestaurantReview>[];

      for (var i = 0; i < (response as List).length; i++) {
        try {
          final review = RestaurantReview.fromJson(response[i]);
          reviews.add(review);
        } catch (e) {
          debugPrint("❌ RESTAURANT REVIEW PARSING ERROR at index $i: $e");
          debugPrint("❌ PROBLEMATIC DATA: ${response[i]}");
        }
      }

      debugPrint(
          "✅ RESTAURANT REVIEWS PROCESSED SUCCESSFULLY: totalParsed=${reviews.length}");

      return reviews;
    } catch (e) {
      debugPrint(
          "❌ RestaurantReviewService: Error fetching restaurant reviews: $e");
      return [];
    }
  }

  // Submit a review for a restaurant (using Supabase)
  Future<bool> submitRestaurantReview({
    required String restaurantId,
    required int rating,
    String? comment,
    String? image,
    List<String>? photos,
  }) async {
    try {
      debugPrint(
          "🏪 SUBMITTING RESTAURANT REVIEW: restaurantId=$restaurantId, rating=$rating");

      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        debugPrint("❌ No authenticated user found");
        return false;
      }

      // Insert the review (using correct schema: customer_id, no photos)
      await supabase.from('restaurant_reviews').insert({
        'restaurant_id': restaurantId,
        'customer_id': userId,
        'rating': rating,
        'comment': comment,
      });

      debugPrint("✅ RESTAURANT REVIEW SUBMITTED SUCCESSFULLY");

      // Update restaurant stats
      await _updateRestaurantStats(restaurantId);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint(
          "❌ RestaurantReviewService: Error submitting restaurant review: $e");
      return false;
    }
  }

  /// Update restaurant rating and review count statistics
  Future<void> _updateRestaurantStats(String restaurantId) async {
    try {
      final supabase = Supabase.instance.client;

      // Calculate average rating and count from restaurant_reviews
      final response = await supabase
          .from('restaurant_reviews')
          .select('rating')
          .eq('restaurant_id', restaurantId);

      if (response.isEmpty) {
        return;
      }

      final reviews = response as List;
      final totalReviews = reviews.length;
      final averageRating = reviews.fold<double>(
            0.0,
            (sum, review) => sum + (review['rating'] as num).toDouble(),
          ) /
          totalReviews;

      // Update the restaurant table
      await supabase.from('restaurants').update({
        'rating': averageRating,
        'review_count': totalReviews,
      }).eq('id', restaurantId);

      debugPrint(
          "✅ Updated restaurant stats: rating=$averageRating, count=$totalReviews");
    } catch (e) {
      debugPrint("❌ Error updating restaurant stats: $e");
    }
  }

  // Update a review for a restaurant (using Supabase)
  Future<bool> updateRestaurantReview({
    required String reviewId,
    required int rating,
    String? comment,
    String? image,
    List<String>? photos,
  }) async {
    try {
      debugPrint(
          "🏪 UPDATING RESTAURANT REVIEW: reviewId=$reviewId, rating=$rating");

      final supabase = Supabase.instance.client;

      await supabase.from('restaurant_reviews').update({
        'rating': rating,
        'comment': comment,
      }).eq('id', reviewId);

      debugPrint("✅ RESTAURANT REVIEW UPDATED SUCCESSFULLY");

      // Get restaurant_id to update stats
      final reviewData = await supabase
          .from('restaurant_reviews')
          .select('restaurant_id')
          .eq('id', reviewId)
          .maybeSingle();

      if (reviewData != null) {
        await _updateRestaurantStats(reviewData['restaurant_id']);
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint(
          "❌ RestaurantReviewService: Error updating restaurant review: $e");
      return false;
    }
  }

  // Delete a review for a restaurant (using Supabase)
  Future<bool> deleteRestaurantReview(String reviewId) async {
    try {
      debugPrint("🏪 DELETING RESTAURANT REVIEW: reviewId=$reviewId");

      final supabase = Supabase.instance.client;

      // Get restaurant_id before deleting
      final reviewData = await supabase
          .from('restaurant_reviews')
          .select('restaurant_id')
          .eq('id', reviewId)
          .maybeSingle();

      await supabase.from('restaurant_reviews').delete().eq('id', reviewId);

      debugPrint("✅ RESTAURANT REVIEW DELETED SUCCESSFULLY");

      // Update stats if we had the restaurant_id
      if (reviewData != null) {
        await _updateRestaurantStats(reviewData['restaurant_id']);
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint(
          "❌ RestaurantReviewService: Error deleting restaurant review: $e");
      return false;
    }
  }

  // Get review statistics for a restaurant (using Supabase)
  Future<Map<String, dynamic>> getRestaurantReviewStats(
      String restaurantId) async {
    try {
      debugPrint(
          "🏪 FETCHING RESTAURANT REVIEW STATS: restaurantId=$restaurantId");

      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('restaurant_reviews')
          .select('rating')
          .eq('restaurant_id', restaurantId);

      if (response.isEmpty) {
        return {'average_rating': 0.0, 'total_reviews': 0};
      }

      final reviews = response as List;
      final totalReviews = reviews.length;
      final averageRating = reviews.fold<double>(
            0.0,
            (sum, review) => sum + (review['rating'] as num).toDouble(),
          ) /
          totalReviews;

      final stats = {
        'average_rating': averageRating,
        'total_reviews': totalReviews,
      };

      debugPrint("✅ RESTAURANT REVIEW STATS RECEIVED: $stats");

      return stats;
    } catch (e) {
      debugPrint(
          "❌ RestaurantReviewService: Error fetching restaurant review stats: $e");
      return {};
    }
  }

  // Check if user can review a restaurant (returns true for now)
  Future<bool> canUserReviewRestaurant(
      String restaurantId, String userId) async {
    try {
      debugPrint(
          "🏪 CHECKING USER CAN REVIEW: restaurantId=$restaurantId, userId=$userId");

      final supabase = Supabase.instance.client;

      // Check if user already reviewed
      final existingReview = await supabase
          .from('restaurant_reviews')
          .select('id')
          .eq('restaurant_id', restaurantId)
          .eq('customer_id', userId)
          .maybeSingle();

      final canReview = existingReview == null;

      debugPrint("✅ CAN USER REVIEW: $canReview");

      return canReview;
    } catch (e) {
      debugPrint(
          "❌ RestaurantReviewService: Error checking if user can review: $e");
      return true; // Allow review by default
    }
  }

  // Get user's review for a restaurant (if exists)
  Future<RestaurantReview?> getUserRestaurantReview(
      String restaurantId, String userId) async {
    try {
      debugPrint(
          "🏪 FETCHING USER RESTAURANT REVIEW: restaurantId=$restaurantId, userId=$userId");

      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('restaurant_reviews')
          .select('*, user_profiles:customer_id (name, profile_image_url)')
          .eq('restaurant_id', restaurantId)
          .eq('customer_id', userId)
          .maybeSingle();

      if (response == null) {
        debugPrint("⚠️ USER RESTAURANT REVIEW: No review found");
        return null;
      }

      final review = RestaurantReview.fromJson(response);

      debugPrint("✅ USER RESTAURANT REVIEW RECEIVED");

      return review;
    } catch (e) {
      debugPrint(
          "❌ RestaurantReviewService: Error fetching user restaurant review: $e");
      return null;
    }
  }

  // Report a review (using Supabase)
  Future<bool> reportRestaurantReview(String reviewId, String reason) async {
    try {
      debugPrint(
          "🏪 REPORTING RESTAURANT REVIEW: reviewId=$reviewId, reason=$reason");

      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        debugPrint("❌ No authenticated user found");
        return false;
      }

      await supabase.from('review_reports').insert({
        'review_id': reviewId,
        'customer_id': userId,
        'reason': reason,
      });

      debugPrint("✅ RESTAURANT REVIEW REPORTED SUCCESSFULLY");
      return true;
    } catch (e) {
      debugPrint(
          "❌ RestaurantReviewService: Error reporting restaurant review: $e");
      return false;
    }
  }
}
