import 'package:flutter/foundation.dart';

import '../models/paged_result.dart';
import '../models/review.dart';
import '../sources/reviews_api.dart';
import '../sources/reviews_local.dart';

/// Repository for managing reviews data with caching strategy.
/// Implements offline-first approach with background refresh.
class ReviewsRepository {
  ReviewsRepository({
    ReviewsApiDataSource? apiDataSource,
    ReviewsLocalDataSource? localDataSource,
  })  : _apiDataSource = apiDataSource ?? ReviewsApiDataSource(),
        _localDataSource = localDataSource ?? ReviewsLocalDataSource();

  final ReviewsApiDataSource _apiDataSource;
  final ReviewsLocalDataSource _localDataSource;

  /// Fetches reviews with offline-first strategy.
  /// Returns cached data immediately, then fetches fresh data in background.
  Future<PagedResult<Review>> getReviews({
    required String restaurantId,
    required int page,
    int limit = 20,
    String sortBy = 'newest',
    bool forceRefresh = false,
  }) async {
    // Try cache first (unless force refresh)
    if (!forceRefresh) {
      final cached = await _localDataSource.getCachedReviews(
        restaurantId: restaurantId,
        page: page,
        sortBy: sortBy,
      );

      if (cached != null) {
        final hasMore = await _localDataSource.hasMoreCached(
          restaurantId: restaurantId,
          page: page,
          sortBy: sortBy,
        );

        debugPrint(
            '📦 Loaded ${cached.length} reviews from cache (page $page)');

        // Return cached data and optionally refresh in background
        _refreshInBackground(
          restaurantId: restaurantId,
          page: page,
          limit: limit,
          sortBy: sortBy,
        );

        return PagedResult(
          items: cached,
          hasMore: hasMore,
          nextPage: hasMore ? page + 1 : null,
        );
      }
    }

    // Fetch from network
    return _fetchFromNetwork(
      restaurantId: restaurantId,
      page: page,
      limit: limit,
      sortBy: sortBy,
    );
  }

  /// Fetches reviews from network and caches them.
  Future<PagedResult<Review>> _fetchFromNetwork({
    required String restaurantId,
    required int page,
    required int limit,
    required String sortBy,
  }) async {
    debugPrint('🌐 Fetching reviews from network (page $page)');

    // Fetch both restaurant and menu item reviews in parallel
    final results = await Future.wait([
      _apiDataSource.getRestaurantReviews(
        restaurantId: restaurantId,
        page: page,
        limit: limit ~/ 2,
        sortBy: sortBy,
      ),
      _apiDataSource.getMenuItemReviews(
        restaurantId: restaurantId,
        page: page,
        limit: limit ~/ 2,
        sortBy: sortBy,
      ),
    ]);

    final restaurantReviews = results[0];
    final menuItemReviews = results[1];

    // Combine and sort reviews
    final allReviews = [...restaurantReviews, ...menuItemReviews];
    _sortReviews(allReviews, sortBy);

    // Take only the limit we need
    final reviews = allReviews.take(limit).toList();
    final hasMore = allReviews.length >= limit;

    // Cache the results
    await _localDataSource.cacheReviews(
      restaurantId: restaurantId,
      page: page,
      sortBy: sortBy,
      reviews: reviews,
      hasMore: hasMore,
    );

    debugPrint('✅ Fetched and cached ${reviews.length} reviews');

    return PagedResult(
      items: reviews,
      hasMore: hasMore,
      nextPage: hasMore ? page + 1 : null,
    );
  }

  /// Refreshes data in background without blocking UI.
  void _refreshInBackground({
    required String restaurantId,
    required int page,
    required int limit,
    required String sortBy,
  }) {
    _fetchFromNetwork(
      restaurantId: restaurantId,
      page: page,
      limit: limit,
      sortBy: sortBy,
    ).catchError((error) {
      debugPrint('Background refresh failed: $error');
      return const PagedResult<Review>(items: [], hasMore: false);
    });
  }

  /// Sort reviews based on sort criteria.
  void _sortReviews(List<Review> reviews, String sortBy) {
    switch (sortBy) {
      case 'newest':
        reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'oldest':
        reviews.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'rating_high':
        reviews.sort((a, b) {
          final ratingCompare = b.rating.compareTo(a.rating);
          if (ratingCompare != 0) return ratingCompare;
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case 'rating_low':
        reviews.sort((a, b) {
          final ratingCompare = a.rating.compareTo(b.rating);
          if (ratingCompare != 0) return ratingCompare;
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
    }
  }

  /// Clears all cached reviews.
  Future<void> clearCache() => _localDataSource.clearCache();

  /// Clears cache for specific restaurant.
  Future<void> clearCacheForRestaurant(String restaurantId) =>
      _localDataSource.clearCacheForRestaurant(restaurantId);
}
