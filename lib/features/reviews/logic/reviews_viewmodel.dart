import 'package:flutter/foundation.dart';

import '../data/models/review.dart';
import '../data/repositories/reviews_repository.dart';

/// ViewModel for managing reviews screen state with Provider.
class ReviewsViewModel extends ChangeNotifier {
  ReviewsViewModel({
    required this.restaurantId,
    ReviewsRepository? repository,
  }) : _repository = repository ?? ReviewsRepository();

  final String restaurantId;
  final ReviewsRepository _repository;

  List<Review> _reviews = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  bool _hasMore = true;
  int _currentPage = 0;
  String _sortBy = 'newest';
  String _searchQuery = '';
  String? _selectedMenuItem; // null means "All Reviews"

  List<Review> get reviews => _reviews;
  String get searchQuery => _searchQuery;
  String? get selectedMenuItem => _selectedMenuItem;

  /// Get unique menu items from reviews
  List<String> get uniqueMenuItems {
    final items = _reviews
        .where((review) => review.menuItemName != null)
        .map((review) => review.menuItemName!)
        .toSet()
        .toList();
    items.sort(); // Sort alphabetically
    return items;
  }

  List<Review> get filteredReviews {
    var filtered = _reviews;

    // Filter by selected menu item
    if (_selectedMenuItem != null) {
      filtered = filtered
          .where((review) => review.menuItemName == _selectedMenuItem)
          .toList();
    }

    // Filter by search query
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      debugPrint('🔍 Searching for: "$query" in ${_reviews.length} reviews');
      filtered = filtered.where((review) {
        final name = (review.userName ?? '').toLowerCase();
        final comment = (review.comment ?? '').toLowerCase();
        final menuItem = (review.menuItemName ?? '').toLowerCase();
        final matches = name.contains(query) ||
            comment.contains(query) ||
            menuItem.contains(query);
        if (matches) {
          debugPrint('✅ Match found - menuItem: "$menuItem", user: "$name"');
        }
        return matches;
      }).toList();
      debugPrint('📊 Found ${filtered.length} matching reviews');
    }

    return filtered;
  }

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  bool get hasMore => _hasMore;
  String get sortBy => _sortBy;
  bool get isEmpty => _reviews.isEmpty && !_isLoading;

  /// Initial load of reviews.
  Future<void> loadReviews() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _currentPage = 0;
    notifyListeners();

    try {
      final result = await _repository.getReviews(
        restaurantId: restaurantId,
        page: _currentPage,
        sortBy: _sortBy,
      );

      _reviews = result.items;
      _hasMore = result.hasMore;
      _error = null;
      debugPrint('📋 Loaded ${_reviews.length} reviews');
      for (final review in _reviews.take(5)) {
        debugPrint(
            '  - menuItemId: "${review.menuItemId}", menuItemName: "${review.menuItemName}", user: "${review.userName}"');
      }
      // Count reviews per menu item
      final menuItemCounts = <String, int>{};
      for (final review in _reviews) {
        final name = review.menuItemName ?? 'null';
        menuItemCounts[name] = (menuItemCounts[name] ?? 0) + 1;
      }
      debugPrint('📊 Reviews by menu item:');
      menuItemCounts.forEach((name, count) {
        debugPrint('  - "$name": $count reviews');
      });
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error loading reviews: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load next page of reviews.
  Future<void> loadMoreReviews() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final result = await _repository.getReviews(
        restaurantId: restaurantId,
        page: nextPage,
        sortBy: _sortBy,
      );

      _reviews.addAll(result.items);
      _hasMore = result.hasMore;
      _currentPage = nextPage;
      _error = null;

      debugPrint('📄 Loaded page $nextPage: ${result.items.length} reviews');
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error loading more reviews: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Refresh reviews (pull to refresh).
  Future<void> refresh() async {
    _currentPage = 0;
    _hasMore = true;

    try {
      final result = await _repository.getReviews(
        restaurantId: restaurantId,
        page: 0,
        sortBy: _sortBy,
        forceRefresh: true,
      );

      _reviews = result.items;
      _hasMore = result.hasMore;
      _error = null;

      debugPrint('🔄 Refreshed reviews: ${result.items.length} items');
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error refreshing reviews: $e');
    } finally {
      notifyListeners();
    }
  }

  /// Set search query and filter reviews locally.
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Set selected menu item filter
  void setSelectedMenuItem(String? menuItem) {
    _selectedMenuItem = menuItem;
    notifyListeners();
  }

  /// Change sort order.
  Future<void> changeSortOrder(String newSortBy) async {
    if (_sortBy == newSortBy) return;

    _sortBy = newSortBy;
    await loadReviews();
  }

  /// Check if should load more based on scroll position.
  void checkScrollPosition(double pixels, double maxScrollExtent) {
    if (pixels >= maxScrollExtent * 0.7) {
      loadMoreReviews();
    }
  }

  /// Retry loading after error.
  Future<void> retry() => loadReviews();
}
