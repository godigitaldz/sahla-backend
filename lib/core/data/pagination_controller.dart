import 'dart:async';

import 'package:flutter/foundation.dart';

/// Pagination controller with debounced preloading
class PaginationController<T> {
  final Future<List<T>> Function(int offset, int limit) loadPage;
  final int pageSize;
  final Duration debounceDelay;
  final double preloadThreshold; // Load next page at this scroll percentage

  int _currentOffset = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  final List<T> _items = [];
  Timer? _debounceTimer;

  PaginationController({
    required this.loadPage,
    this.pageSize = 20,
    this.debounceDelay = const Duration(milliseconds: 300),
    this.preloadThreshold = 0.7, // Load at 70% scroll
  });

  /// Get current items
  List<T> get items => List.unmodifiable(_items);

  /// Check if loading
  bool get isLoading => _isLoading;

  /// Check if has more data
  bool get hasMore => _hasMore;

  /// Get current offset
  int get currentOffset => _currentOffset;

  /// Load initial page
  Future<void> loadInitial() async {
    if (_isLoading) return;

    _currentOffset = 0;
    _hasMore = true;
    _items.clear();

    await _loadNext();
  }

  /// Load next page
  Future<void> loadNext() async {
    if (_isLoading || !_hasMore) return;

    _debounceTimer?.cancel();
    await _loadNext();
  }

  /// Load next page with debounce
  void loadNextDebounced() {
    if (_isLoading || !_hasMore) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDelay, () {
      _loadNext();
    });
  }

  /// Handle scroll position for preloading
  void onScroll(double position, double maxScroll) {
    if (!_hasMore || _isLoading) return;

    final scrollPercentage = position / (maxScroll > 0 ? maxScroll : 1);
    if (scrollPercentage >= preloadThreshold) {
      loadNextDebounced();
    }
  }

  /// Internal load next page
  Future<void> _loadNext() async {
    if (_isLoading || !_hasMore) return;

    try {
      _isLoading = true;

      final newItems = await loadPage(_currentOffset, pageSize);

      if (newItems.isEmpty) {
        _hasMore = false;
      } else {
        _items.addAll(newItems);
        _currentOffset += newItems.length;
        _hasMore = newItems.length == pageSize;
      }
    } catch (e) {
      debugPrint('Error loading next page: $e');
      // Don't update hasMore on error to allow retry
    } finally {
      _isLoading = false;
    }
  }

  /// Refresh data
  Future<void> refresh() async {
    _debounceTimer?.cancel();
    await loadInitial();
  }

  /// Clear all data
  void clear() {
    _debounceTimer?.cancel();
    _items.clear();
    _currentOffset = 0;
    _hasMore = true;
    _isLoading = false;
  }

  /// Dispose resources
  void dispose() {
    _debounceTimer?.cancel();
    _items.clear();
  }
}
