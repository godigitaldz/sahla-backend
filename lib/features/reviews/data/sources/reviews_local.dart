import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/review.dart';

/// Local data source for caching reviews using Hive.
class ReviewsLocalDataSource {
  static const String _boxName = 'reviews_cache';
  static const Duration _defaultTtl = Duration(minutes: 30);
  Box<dynamic>? _box;

  /// Initialize Hive box
  Future<void> _ensureInitialized() async {
    if (_box != null && Hive.isBoxOpen(_boxName)) return;

    try {
      if (!Hive.isBoxOpen(_boxName)) {
        _box = await Hive.openBox(_boxName);
      } else {
        _box = Hive.box(_boxName);
      }
    } catch (e) {
      debugPrint('❌ Failed to initialize reviews cache: $e');
    }
  }

  /// Generate cache key from query parameters.
  String _getCacheKey({
    required String restaurantId,
    required int page,
    required String sortBy,
  }) {
    return 'reviews_${restaurantId}_${sortBy}_$page';
  }

  /// Fetch cached reviews for a specific page.
  Future<List<Review>?> getCachedReviews({
    required String restaurantId,
    required int page,
    required String sortBy,
  }) async {
    await _ensureInitialized();
    if (_box == null) return null;

    final cacheKey = _getCacheKey(
      restaurantId: restaurantId,
      page: page,
      sortBy: sortBy,
    );

    final cached = _box!.get(cacheKey);
    if (cached == null) return null;

    try {
      final data = Map<String, dynamic>.from(cached);
      final timestamp =
          DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int);
      final ttl = Duration(milliseconds: data['ttl'] as int);

      // Check if expired
      if (DateTime.now().difference(timestamp) > ttl) {
        await _box!.delete(cacheKey);
        return null;
      }

      final reviewsJson = data['reviews'] as List;
      return compute(_parseReviewsFromCache, reviewsJson);
    } catch (e) {
      debugPrint('❌ Error parsing cached reviews: $e');
      await _box!.delete(cacheKey);
      return null;
    }
  }

  /// Parse reviews from cached JSON (in isolate).
  static List<Review> _parseReviewsFromCache(List<dynamic> jsonList) {
    return jsonList
        .map((json) => Review.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// Cache reviews for a specific page.
  Future<void> cacheReviews({
    required String restaurantId,
    required int page,
    required String sortBy,
    required List<Review> reviews,
    required bool hasMore,
  }) async {
    await _ensureInitialized();
    if (_box == null) return;

    final cacheKey = _getCacheKey(
      restaurantId: restaurantId,
      page: page,
      sortBy: sortBy,
    );

    try {
      final reviewsJson = reviews.map((r) => r.toJson()).toList();

      final cacheData = {
        'reviews': reviewsJson,
        'hasMore': hasMore,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'ttl': _defaultTtl.inMilliseconds,
      };

      await _box!.put(cacheKey, cacheData);
    } catch (e) {
      debugPrint('❌ Error caching reviews: $e');
    }
  }

  /// Clear all cached reviews.
  Future<void> clearCache() async {
    await _ensureInitialized();
    if (_box == null) return;

    try {
      await _box!.clear();
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
    }
  }

  /// Clear cache for specific restaurant.
  Future<void> clearCacheForRestaurant(String restaurantId) async {
    await _ensureInitialized();
    if (_box == null) return;

    try {
      final keysToDelete = <String>[];
      for (final key in _box!.keys) {
        if (key is String && key.startsWith('reviews_$restaurantId')) {
          keysToDelete.add(key);
        }
      }

      for (final key in keysToDelete) {
        await _box!.delete(key);
      }
    } catch (e) {
      debugPrint('❌ Error clearing restaurant cache: $e');
    }
  }

  /// Check if next page has more reviews.
  Future<bool> hasMoreCached({
    required String restaurantId,
    required int page,
    required String sortBy,
  }) async {
    await _ensureInitialized();
    if (_box == null) return true;

    final cacheKey = _getCacheKey(
      restaurantId: restaurantId,
      page: page,
      sortBy: sortBy,
    );

    final cached = _box!.get(cacheKey);
    if (cached == null) return true;

    try {
      final data = Map<String, dynamic>.from(cached);
      return data['hasMore'] as bool? ?? true;
    } catch (e) {
      return true;
    }
  }
}
