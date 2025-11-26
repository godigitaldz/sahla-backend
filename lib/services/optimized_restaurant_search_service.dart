// ignore_for_file: avoid_positional_boolean_parameters

import 'package:flutter/material.dart';

import '../models/restaurant.dart';
import '../utils/smart_text_detector.dart';
import 'menu_item_display_service.dart';
import 'optimized_restaurant_service.dart';
import 'performance_optimization_service.dart';
// Redis optimized service removed

/// Ultra-high performance RestaurantSearchService with 100% optimization
class OptimizedRestaurantSearchService extends ChangeNotifier {
  static final OptimizedRestaurantSearchService _instance =
      OptimizedRestaurantSearchService._internal();
  factory OptimizedRestaurantSearchService() => _instance;
  OptimizedRestaurantSearchService._internal();

  final OptimizedRestaurantService _restaurantService =
      OptimizedRestaurantService();
  final PerformanceOptimizationService _perfService =
      PerformanceOptimizationService();

  // Search state with intelligent caching
  String _searchQuery = '';
  List<Restaurant> _searchResults = [];
  List<Restaurant> _filteredResults = [];
  List<Restaurant> _allRestaurants = [];
  bool _isSearching = false;
  bool _isFiltering = false;
  String? _error;

  // Filter state with smart defaults
  String? _selectedLocation;
  Set<String> _selectedCuisines = {};
  Set<String> _selectedCategories = {};
  double? _minRating;
  RangeValues? _priceRange;
  RangeValues? _deliveryFeeRange;
  int? _maxDeliveryTime;
  bool? _isOpen;
  bool? _isFeatured;
  Set<String> _dietaryOptions = {};

  // Advanced pagination with virtual scrolling
  static const int _itemsPerPage = 20;
  int _currentPage = 0;
  bool _hasMoreData = true;
  final Map<int, List<Restaurant>> _pageCache = {};

  // Search optimization
  final Map<String, List<Restaurant>> _searchCache = {};
  final Map<String, DateTime> _searchTimestamps = {};
  static const Duration _searchCacheDuration = Duration(minutes: 10);

  // Performance metrics
  int _totalSearches = 0;
  int _cacheHits = 0;
  int _databaseHits = 0;
  Duration _totalSearchTime = Duration.zero;

  // Getters
  String get searchQuery => _searchQuery;
  List<Restaurant> get searchResults => _searchResults;
  List<Restaurant> get filteredResults => _filteredResults;
  List<Restaurant> get allRestaurants => _allRestaurants;
  bool get isSearching => _isSearching;
  bool get isFiltering => _isFiltering;
  String? get error => _error;
  bool get hasMoreData => _hasMoreData;

  // Filter getters
  String? get selectedLocation => _selectedLocation;
  Set<String> get selectedCuisines => _selectedCuisines;
  Set<String> get selectedCategories => _selectedCategories;
  double? get minRating => _minRating;
  RangeValues? get priceRange => _priceRange;
  RangeValues? get deliveryFeeRange => _deliveryFeeRange;
  int? get maxDeliveryTime => _maxDeliveryTime;
  bool? get isOpen => _isOpen;
  bool? get isFeatured => _isFeatured;
  Set<String> get dietaryOptions => _dietaryOptions;

  /// Get performance metrics
  Map<String, dynamic> get performanceMetrics => {
        'total_searches': _totalSearches,
        'cache_hits': _cacheHits,
        'database_hits': _databaseHits,
        'cache_hit_rate':
            _totalSearches > 0 ? _cacheHits / _totalSearches : 0.0,
        'avg_search_time_ms': _totalSearches > 0
            ? _totalSearchTime.inMilliseconds / _totalSearches
            : 0.0,
        'search_cache_size': _searchCache.length,
        'page_cache_size': _pageCache.length,
        'total_restaurants_loaded': _allRestaurants.length,
      };

  // Initialize service with maximum performance
  Future<void> initialize() async {
    await _perfService.initialize();
    await _loadAllRestaurantsOptimized();

    // Initialize filtered results with all restaurants
    if (_allRestaurants.isNotEmpty) {
      _filteredResults = _dedupeById(_allRestaurants);
      debugPrint(
          '🚀 OptimizedRestaurantSearchService: Initialized with ${_filteredResults.length} restaurants');
      notifyListeners();
    } else {
      _filteredResults = [];
      debugPrint(
          '🚀 OptimizedRestaurantSearchService: Initialized with no restaurants');
      notifyListeners();
    }
  }

  // Load restaurants with maximum optimization
  Future<void> _loadAllRestaurantsOptimized() async {
    try {
      _allRestaurants = [];
      int offset = 0;
      const int batchSize = 100; // Larger batches for better performance
      bool hasMore = true;

      while (hasMore) {
        final batch = await _restaurantService.getRestaurants(
          offset: offset,
          limit: batchSize,
        );

        if (batch.isEmpty) {
          hasMore = false;
        } else {
          _allRestaurants.addAll(batch);
          offset += batch.length;

          // Limit to prevent memory issues but allow more data
          if (_allRestaurants.length >= 1000) {
            debugPrint(
                '🚀 OptimizedRestaurantSearchService: Limited to 1000 restaurants for optimal performance');
            break;
          }
        }
      }

      debugPrint(
          '🚀 OptimizedRestaurantSearchService: Loaded ${_allRestaurants.length} restaurants for search');
      _allRestaurants = _dedupeById(_allRestaurants);
    } catch (e) {
      debugPrint(
          '❌ OptimizedRestaurantSearchService: Error loading restaurants: $e');
      _error = 'Failed to load restaurants';
      notifyListeners();
    }
  }

  // Ultra-fast search with intelligent caching
  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      _clearSearch();
      return;
    }

    final stopwatch = Stopwatch()..start();
    _totalSearches++;

    _searchQuery = query.trim();
    _isSearching = true;
    _error = null;
    notifyListeners();

    try {
      // Check search cache first
      if (_isSearchCacheValid(query)) {
        _searchResults = _searchCache[query]!;
        _filteredResults = _dedupeById(_searchResults);
        _currentPage = 0;
        _hasMoreData = _searchResults.length > _itemsPerPage;
        _cacheHits++;

        stopwatch.stop();
        _totalSearchTime += stopwatch.elapsed;

        debugPrint(
            '🚀 OptimizedRestaurantSearchService: Found ${_searchResults.length} restaurants from search cache for query: $query');
        return;
      }

      // Redis optimization removed - using local search only

      // Fallback to ultra-fast local search with smart text detection
      final results = _allRestaurants.where((restaurant) {
        // Generate search variations for better matching
        final searchVariations =
            SmartTextDetector.generateSearchVariations(query);

        final name = restaurant.name.toLowerCase();
        final description = restaurant.description.toLowerCase();
        final city = restaurant.city.toLowerCase();
        final state = restaurant.state.toLowerCase();
        final wilaya = (restaurant.wilaya ?? '').toLowerCase();

        // Check if any search variation matches any restaurant field
        for (final variation in searchVariations) {
          if (name.contains(variation) ||
              description.contains(variation) ||
              city.contains(variation) ||
              state.contains(variation) ||
              wilaya.contains(variation)) {
            return true;
          }

          // Also check for similarity (fuzzy matching)
          if (SmartTextDetector.isSimilar(variation, name) ||
              SmartTextDetector.isSimilar(variation, description) ||
              SmartTextDetector.isSimilar(variation, city) ||
              SmartTextDetector.isSimilar(variation, state) ||
              SmartTextDetector.isSimilar(variation, wilaya)) {
            return true;
          }
        }

        return false;
      }).toList();

      // If no restaurants found by name/description, check menu items
      if (results.isEmpty) {
        debugPrint(
            '🚀 OptimizedRestaurantSearchService: No restaurants found by name, checking menu items...');
        try {
          final menuItemService = MenuItemDisplayService();
          final matchingMenuItems =
              await menuItemService.searchMenuItems(query: query, limit: 100);

          if (matchingMenuItems.isNotEmpty) {
            debugPrint(
                '🚀 OptimizedRestaurantSearchService: Found ${matchingMenuItems.length} matching menu items');

            // Get unique restaurant IDs from matching menu items
            final restaurantIds = matchingMenuItems
                .map((item) => item.restaurantId)
                .where((id) => id.isNotEmpty)
                .toSet()
                .toList();

            debugPrint(
                '🚀 OptimizedRestaurantSearchService: Found ${restaurantIds.length} unique restaurant IDs');

            // Find restaurants that match these IDs
            final restaurantsWithMatchingMenuItems = _allRestaurants
                .where((restaurant) => restaurantIds.contains(restaurant.id))
                .toList();

            debugPrint(
                '🚀 OptimizedRestaurantSearchService: Found ${restaurantsWithMatchingMenuItems.length} restaurants with matching menu items');

            // Add these restaurants to the results
            results.addAll(restaurantsWithMatchingMenuItems);
          }
        } catch (e) {
          debugPrint(
              '❌ OptimizedRestaurantSearchService: Error checking menu items: $e');
        }
      }

      _searchResults = _dedupeById(results);
      _filteredResults = _dedupeById(results);
      _currentPage = 0;
      _hasMoreData = results.length > _itemsPerPage;

      // Cache the results
      _searchCache[query] = _searchResults;
      _searchTimestamps[query] = DateTime.now();

      stopwatch.stop();
      _totalSearchTime += stopwatch.elapsed;
      _databaseHits++;

      debugPrint(
          '🚀 OptimizedRestaurantSearchService: Found ${results.length} restaurants for query: $query');
    } catch (e) {
      stopwatch.stop();
      _totalSearchTime += stopwatch.elapsed;
      debugPrint('❌ OptimizedRestaurantSearchService: Error searching: $e');
      _error = 'Search failed';
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  // Ultra-fast filter application with intelligent caching
  Future<void> applyFilters() async {
    _isFiltering = true;
    notifyListeners();

    try {
      // Base: when not searching, filter across all restaurants; otherwise on current search results
      List<Restaurant> results = _searchQuery.trim().isEmpty
          ? List.from(_allRestaurants)
          : List.from(_searchResults);
      results = _dedupeById(results);

      // Apply filters with optimized logic
      results = await _applyOptimizedFilters(results);

      _filteredResults = _dedupeById(results);
      _currentPage = 0;
      _hasMoreData = _filteredResults.length > _itemsPerPage;

      debugPrint(
          '🚀 OptimizedRestaurantSearchService: Applied filters, final results: ${_filteredResults.length} restaurants');
    } catch (e) {
      debugPrint(
          '❌ OptimizedRestaurantSearchService: Error applying filters: $e');
      _error = 'Filter application failed';
      _filteredResults = [];
    } finally {
      _isFiltering = false;
      notifyListeners();
    }
  }

  // Apply filters with maximum optimization
  Future<List<Restaurant>> _applyOptimizedFilters(
      List<Restaurant> results) async {
    var filtered = results;
    // Apply basic filters first (fastest)
    if (_selectedLocation != null) {
      filtered = filtered.where((restaurant) {
        final location = _selectedLocation!.toLowerCase();
        return restaurant.city.toLowerCase().contains(location) ||
            restaurant.state.toLowerCase().contains(location) ||
            (restaurant.wilaya ?? '').toLowerCase().contains(location);
      }).toList();
    }

    if (_minRating != null) {
      filtered = filtered
          .where((restaurant) => restaurant.rating >= _minRating!)
          .toList();
    }

    if (_priceRange != null) {
      filtered = filtered.where((restaurant) {
        final minOrder = restaurant.minimumOrder;
        return minOrder >= _priceRange!.start && minOrder <= _priceRange!.end;
      }).toList();
    }

    if (_deliveryFeeRange != null) {
      filtered = filtered.where((restaurant) {
        final fee = restaurant.deliveryFee;
        return fee >= _deliveryFeeRange!.start && fee <= _deliveryFeeRange!.end;
      }).toList();
    }

    if (_maxDeliveryTime != null) {
      filtered = filtered
          .where((restaurant) =>
              restaurant.estimatedDeliveryTime <= _maxDeliveryTime!)
          .toList();
    }

    if (_isOpen != null) {
      filtered =
          filtered.where((restaurant) => restaurant.isOpen == _isOpen).toList();
    }

    if (_isFeatured != null) {
      filtered = filtered
          .where((restaurant) => restaurant.isFeatured == _isFeatured)
          .toList();
    }

    // Apply complex filters (cuisine/category) only if needed
    if (_selectedCuisines.isNotEmpty || _selectedCategories.isNotEmpty) {
      try {
        debugPrint(
            '🚀 OptimizedRestaurantSearchService: Applying cuisine/category filters: cuisines=$_selectedCuisines, categories=$_selectedCategories');

        // Use performance optimization service for complex filtering
        final filteredByMenu = await _perfService.getOptimizedRestaurants(
          cuisine:
              _selectedCuisines.isNotEmpty ? _selectedCuisines.first : null,
          category:
              _selectedCategories.isNotEmpty ? _selectedCategories.first : null,
          limit: 1000,
          minRating: _minRating,
        );

        debugPrint(
            '🚀 OptimizedRestaurantSearchService: Cuisine/Category filter returned ${filteredByMenu.length} restaurants');

        if (filteredByMenu.isNotEmpty) {
          final allowed = filteredByMenu.map((r) => r.id).toSet();
          filtered = filtered.where((r) => allowed.contains(r.id)).toList();
          debugPrint(
              '🚀 OptimizedRestaurantSearchService: After filtering: ${filtered.length} restaurants remain');
        } else {
          debugPrint(
              '🚀 OptimizedRestaurantSearchService: No restaurants found with applied filters, showing empty results');
          filtered = [];
        }
      } catch (e) {
        debugPrint(
            '❌ OptimizedRestaurantSearchService: Error in cuisine/category filtering: $e');
        filtered = [];
      }
    }

    return filtered;
  }

  // Filter methods with instant application
  void setLocationFilter(String? location) {
    _selectedLocation = location;
    applyFilters();
  }

  void setCuisineFilter(Set<String> cuisines) {
    _selectedCuisines = Set<String>.from(cuisines);
    applyFilters();
  }

  void setCategoryFilter(Set<String> categories) {
    _selectedCategories = Set<String>.from(categories);
    applyFilters();
  }

  void setRatingFilter(double? minRating) {
    _minRating = minRating;
    applyFilters();
  }

  void setPriceRangeFilter(RangeValues? priceRange) {
    _priceRange = priceRange;
    applyFilters();
  }

  void setDeliveryFeeRangeFilter(RangeValues? deliveryFeeRange) {
    _deliveryFeeRange = deliveryFeeRange;
    applyFilters();
  }

  void setDeliveryTimeFilter(int? maxDeliveryTime) {
    _maxDeliveryTime = maxDeliveryTime;
    applyFilters();
  }

  void setOpenFilter(bool? isOpen) {
    _isOpen = isOpen;
    applyFilters();
  }

  void setFeaturedFilter(bool? isFeatured) {
    _isFeatured = isFeatured;
    applyFilters();
  }

  void setDietaryOptionsFilter(Set<String> dietaryOptions) {
    _dietaryOptions = Set<String>.from(dietaryOptions);
    applyFilters();
  }

  // Clear all filters with instant response
  void clearFilters() {
    _selectedLocation = null;
    _selectedCuisines = <String>{};
    _selectedCategories = <String>{};
    _minRating = null;
    _priceRange = null;
    _deliveryFeeRange = null;
    _maxDeliveryTime = null;
    _isOpen = null;
    _isFeatured = null;
    _dietaryOptions = <String>{};

    // Reset to all restaurants when filters are cleared
    _filteredResults = _dedupeById(_allRestaurants);
    _currentPage = 0;
    _hasMoreData = _filteredResults.length > _itemsPerPage;

    debugPrint(
        '🚀 OptimizedRestaurantSearchService: Filters cleared, showing ${_filteredResults.length} restaurants');
    notifyListeners();
  }

  // Clear search with instant response
  void clearSearch() {
    _searchQuery = '';
    _searchResults.clear();
    _filteredResults.clear();
    _currentPage = 0;
    _hasMoreData = false;
    _error = null;
    clearFilters();
    notifyListeners();
  }

  // Private clear search method
  void _clearSearch() {
    clearSearch();
  }

  // Reset all state to initial values with instant response
  void resetToInitialState() {
    _searchQuery = '';
    _searchResults.clear();
    _filteredResults.clear();
    _isSearching = false;
    _isFiltering = false;
    _error = null;

    // Reset all filters
    _selectedLocation = null;
    _selectedCuisines = <String>{};
    _selectedCategories = <String>{};
    _minRating = null;
    _priceRange = null;
    _deliveryFeeRange = null;
    _maxDeliveryTime = null;
    _isOpen = null;
    _isFeatured = null;
    _dietaryOptions = <String>{};

    // Reset pagination
    _currentPage = 0;
    _hasMoreData = true;

    // Reload filtered results with all restaurants when no filters are applied
    if (_allRestaurants.isNotEmpty) {
      _filteredResults = _dedupeById(_allRestaurants);
      debugPrint(
          '🔄 OptimizedRestaurantSearchService: Reset to initial state with ${_filteredResults.length} restaurants');
    } else {
      _filteredResults = [];
      debugPrint(
          '🔄 OptimizedRestaurantSearchService: Reset to initial state with no restaurants');
    }

    debugPrint('🔄 OptimizedRestaurantSearchService: Reset to initial state');
    notifyListeners();
  }

  // Get paginated results with intelligent caching
  List<Restaurant> getPaginatedResults() {
    // Check page cache first
    if (_pageCache.containsKey(_currentPage)) {
      return _pageCache[_currentPage]!;
    }

    final startIndex = _currentPage * _itemsPerPage;
    final endIndex =
        (startIndex + _itemsPerPage).clamp(0, _filteredResults.length);
    final results = _filteredResults.sublist(startIndex, endIndex);

    // Cache the page
    _pageCache[_currentPage] = results;

    return results;
  }

  // Load more results with intelligent prefetching
  void loadMore() {
    if (_hasMoreData && !_isSearching && !_isFiltering) {
      _currentPage++;
      _hasMoreData =
          _filteredResults.length > (_currentPage + 1) * _itemsPerPage;

      // Prefetch next page if available
      if (_hasMoreData) {
        _prefetchNextPage();
      }

      notifyListeners();
    }
  }

  // Prefetch next page for instant loading
  void _prefetchNextPage() {
    final nextPage = _currentPage + 1;
    if (!_pageCache.containsKey(nextPage)) {
      final startIndex = nextPage * _itemsPerPage;
      final endIndex =
          (startIndex + _itemsPerPage).clamp(0, _filteredResults.length);
      if (startIndex < _filteredResults.length) {
        _pageCache[nextPage] = _filteredResults.sublist(startIndex, endIndex);
      }
    }
  }

  // Check if filters are active
  bool get hasActiveFilters {
    return _selectedLocation != null ||
        _selectedCuisines.isNotEmpty ||
        _selectedCategories.isNotEmpty ||
        _minRating != null ||
        _priceRange != null ||
        _deliveryFeeRange != null ||
        _maxDeliveryTime != null ||
        _isOpen != null ||
        _isFeatured != null ||
        _dietaryOptions.isNotEmpty;
  }

  // Get active filter count
  int get activeFilterCount {
    int count = 0;
    if (_selectedLocation != null) count++;
    if (_selectedCuisines.isNotEmpty) count++;
    if (_selectedCategories.isNotEmpty) count++;
    if (_minRating != null) count++;
    if (_priceRange != null) count++;
    if (_deliveryFeeRange != null) count++;
    if (_maxDeliveryTime != null) count++;
    if (_isOpen != null) count++;
    if (_isFeatured != null) count++;
    if (_dietaryOptions.isNotEmpty) count++;
    return count;
  }

  // Refresh data with optimization
  Future<void> refresh() async {
    await _loadAllRestaurantsOptimized();
    if (_searchQuery.isNotEmpty) {
      await search(_searchQuery);
    }
  }

  // Check if search cache is valid
  bool _isSearchCacheValid(String query) {
    if (!_searchCache.containsKey(query)) return false;

    final timestamp = _searchTimestamps[query];
    if (timestamp == null) return false;

    return DateTime.now().difference(timestamp) < _searchCacheDuration;
  }

  // Dedupe helper to ensure unique restaurants by id preserving order
  List<Restaurant> _dedupeById(List<Restaurant> list) {
    final seen = <String>{};
    final deduped = <Restaurant>[];
    for (final r in list) {
      if (!seen.contains(r.id)) {
        seen.add(r.id);
        deduped.add(r);
      }
    }
    return deduped;
  }

  // Clear all caches for memory management
  void clearAllCaches() {
    _searchCache.clear();
    _searchTimestamps.clear();
    _pageCache.clear();
    debugPrint('🚀 OptimizedRestaurantSearchService: All caches cleared');
  }

  // Get comprehensive performance metrics
  Map<String, dynamic> getComprehensiveMetrics() {
    return {
      ...performanceMetrics,
      'search_cache_hit_rate': _searchCache.isNotEmpty
          ? _cacheHits / (_cacheHits + _databaseHits)
          : 0.0,
      'page_cache_efficiency': _pageCache.length / (_currentPage + 1),
      'memory_usage_estimate': {
        'search_cache_size': _searchCache.length,
        'page_cache_size': _pageCache.length,
        'total_restaurants': _allRestaurants.length,
      },
    };
  }
}
