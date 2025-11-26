import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/review.dart';

/// API data source for fetching reviews from Supabase.
class ReviewsApiDataSource {
  ReviewsApiDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Fetches restaurant reviews with pagination.
  Future<List<Review>> getRestaurantReviews({
    required String restaurantId,
    required int page,
    required int limit,
    String sortBy = 'newest',
  }) async {
    final offset = page * limit;

    // Build query with sorting
    var query = _client
        .from('restaurant_reviews')
        .select('''
          id,
          customer_id,
          restaurant_id,
          order_id,
          rating,
          comment,
          created_at,
          updated_at,
          user_profiles:customer_id (
            name,
            profile_image_url
          )
        ''')
        .eq('restaurant_id', restaurantId)
        .range(offset, offset + limit - 1);

    // Apply sorting
    switch (sortBy) {
      case 'newest':
        query = query.order('created_at', ascending: false);
        break;
      case 'oldest':
        query = query.order('created_at', ascending: true);
        break;
      case 'rating_high':
        query = query
            .order('rating', ascending: false)
            .order('created_at', ascending: false);
        break;
      case 'rating_low':
        query = query
            .order('rating', ascending: true)
            .order('created_at', ascending: false);
        break;
    }

    final response = await query;
    return _parseReviews(response as List);
  }

  /// Fetches menu item reviews with pagination.
  Future<List<Review>> getMenuItemReviews({
    required String restaurantId,
    required int page,
    required int limit,
    String sortBy = 'newest',
  }) async {
    final offset = page * limit;

    // First get menu item IDs for this restaurant
    final menuItemsResponse = await _client
        .from('menu_items')
        .select('id')
        .eq('restaurant_id', restaurantId)
        .eq('is_available', true);

    final menuItemIds = (menuItemsResponse as List)
        .map((item) => item['id'] as String)
        .toList();

    if (menuItemIds.isEmpty) {
      return [];
    }

    // Build query with sorting
    var query = _client
        .from('menu_item_reviews')
        .select('''
          id,
          user_id,
          menu_item_id,
          rating,
          comment,
          image,
          photos,
          created_at,
          updated_at,
          user_profiles:user_id (
            name,
            profile_image_url
          ),
          menu_items:menu_item_id (
            name
          )
        ''')
        .inFilter('menu_item_id', menuItemIds)
        .range(offset, offset + limit - 1);

    // Apply sorting
    switch (sortBy) {
      case 'newest':
        query = query.order('created_at', ascending: false);
        break;
      case 'oldest':
        query = query.order('created_at', ascending: true);
        break;
      case 'rating_high':
        query = query
            .order('rating', ascending: false)
            .order('created_at', ascending: false);
        break;
      case 'rating_low':
        query = query
            .order('rating', ascending: true)
            .order('created_at', ascending: false);
        break;
    }

    final response = await query;

    // Debug: Log first 3 reviews to check menu_items structure
    if (response.isNotEmpty) {
      debugPrint('🔍 Sample menu item reviews:');
      for (var i = 0; i < response.length && i < 3; i++) {
        final review = response[i];
        debugPrint('  Review $i:');
        debugPrint('    menu_item_id: ${review['menu_item_id']}');
        debugPrint('    menu_items: ${review['menu_items']}');
        debugPrint('    user_profiles: ${review['user_profiles']}');
      }
    }

    return _parseReviews(response as List);
  }

  /// Parse reviews in isolate to avoid UI jank.
  Future<List<Review>> _parseReviews(List<dynamic> data) async {
    if (data.isEmpty) return [];

    return compute(_parseReviewsIsolate, data);
  }

  /// Isolate function for parsing reviews.
  static List<Review> _parseReviewsIsolate(List<dynamic> data) {
    return data
        .map((json) => Review.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
