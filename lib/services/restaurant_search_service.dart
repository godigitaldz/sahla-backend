import "dart:async";
import "dart:collection";
import "dart:math";

import "package:flutter/material.dart";

import "../models/menu_item.dart";
import "../models/restaurant.dart";
import "../utils/debounce_service.dart";
import "../utils/performance_utils.dart";
import "../utils/smart_text_detector.dart";
import "../utils/working_hours_utils.dart";
import "../widgets/filter_chips_section/filter_chips_section.dart";
import "menu_item_display_service.dart";
import "restaurant_display_service.dart";
import "restaurant_service.dart";

class RestaurantSearchService extends ChangeNotifier implements FilterService {
  factory RestaurantSearchService() => _instance;
  RestaurantSearchService._internal();
  static final RestaurantSearchService _instance =
      RestaurantSearchService._internal();

  final RestaurantService _restaurantService = RestaurantService();
  final RestaurantDisplayService _restaurantDisplayService =
      RestaurantDisplayService();

  // Search state
  String _searchQuery = "";
  List<Restaurant> _searchResults = [];
  List<Restaurant> _filteredResults = [];
  List<Restaurant> _allRestaurants = [];
  bool _isSearching = false;
  bool _isFiltering = false;
  String? _error;

  // Search sequence tracking to prevent race conditions
  int _searchSequence = 0;

  // Filter state
  String? _selectedLocation;
  double? _selectedLatitude;
  double? _selectedLongitude;
  double _selectedRadiusKm = 25; // default 25km radius for proximity filtering
  Set<String> _selectedCuisines = {};
  Set<String> _selectedCategories = {};
  double? _minRating;
  RangeValues? _priceRange;
  RangeValues? _deliveryFeeRange;
  int? _maxDeliveryTime;
  bool? _isOpen;
  bool? _isFeatured;
  Set<String> _dietaryOptions = {};

  // Pagination
  static const int _itemsPerPage = 20;
  int _currentPage = 0;
  bool _hasMoreData = true;

  // Menu item display service for price range filtering
  final MenuItemDisplayService _menuItemDisplayService =
      MenuItemDisplayService();

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
  @override
  String? get selectedLocation => _selectedLocation;
  bool get isLocationFilterActive =>
      _selectedLocation != null ||
      (_selectedLatitude != null && _selectedLongitude != null);
  @override
  Set<String> get selectedCuisines => _selectedCuisines;
  @override
  Set<String> get selectedCategories => _selectedCategories;
  @override
  double? get minRating => _minRating;
  @override
  RangeValues? get priceRange => _priceRange;
  @override
  RangeValues? get deliveryFeeRange => _deliveryFeeRange;
  int? get maxDeliveryTime => _maxDeliveryTime;
  @override
  bool? get isOpen => _isOpen;
  bool? get isFeatured => _isFeatured;
  Set<String> get dietaryOptions => _dietaryOptions;

  bool _isInitialized = false;
  bool _isLoading = false;

  // Initialize service (only once)
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (_isLoading) {
      // Wait for ongoing initialization
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      return;
    }
    _isLoading = true;

    return PerformanceUtils.measurePerformance(
        "RestaurantSearchServiceInitialize", () async {
      try {
        // Load restaurants asynchronously for immediate UI responsiveness
        await _loadAllRestaurantsInBackground();

        _isInitialized = true;
        notifyListeners();
      } finally {
        _isLoading = false;
      }
    });
  }

  // Ensure data persistence - reload if data is lost
  Future<void> ensureDataPersistence() async {
    if (_allRestaurants.isEmpty) {
      debugPrint(
          "🔄 RestaurantSearchService: Data lost, reloading restaurants...");
      await _loadAllRestaurantsInBackground();

      // If we now have restaurants but no filtered results, show all
      if (_allRestaurants.isNotEmpty && _filteredResults.isEmpty) {
        _filteredResults = _dedupeById(_allRestaurants);
        _currentPage = 0;
        _hasMoreData = _filteredResults.length > _itemsPerPage;
        debugPrint(
            "🔄 RestaurantSearchService: Restored ${_filteredResults.length} restaurants");
        notifyListeners();
      }
    }
  }

  /// Sync base restaurant dataset from an external source (e.g., HomeProvider)
  /// Useful when the UI has preloaded or cached restaurants before this service loads them.
  void syncBaseRestaurants(List<Restaurant> restaurants) {
    try {
      if (restaurants.isEmpty) {
        return;
      }

      // Replace base dataset only if empty or smaller to avoid unnecessary churn
      if (_allRestaurants.isEmpty ||
          restaurants.length > _allRestaurants.length) {
        _allRestaurants = List<Restaurant>.from(restaurants);
        _updateFilteredResultsIfNeeded();
        notifyListeners();
      }
    } on Exception catch (e) {
      debugPrint("❌ RestaurantSearchService: syncBaseRestaurants failed: $e");
    }
  }

  // Load restaurants asynchronously in background for immediate UI responsiveness
  Future<void> _loadAllRestaurantsInBackground() async {
    // Only load if we don't have restaurants yet (prevent duplicate loads)
    if (_allRestaurants.isNotEmpty) {
      _updateFilteredResultsIfNeeded();
      return;
    }

    // Load initial batch immediately for fast startup
    await _loadInitialRestaurants().then((_) {
      _updateFilteredResultsIfNeeded();
    }).catchError((error) {
      debugPrint("❌ RestaurantSearchService: Initial loading failed: $error");
      _error = "Failed to load restaurants";
      notifyListeners();
    });

    // Load remaining restaurants in background (deferred - not critical for startup)
    // This can happen after UI is ready
    unawaited(Future.delayed(const Duration(milliseconds: 500), () {
      _loadRemainingRestaurantsInBackground().catchError((error) {
        debugPrint(
            "❌ RestaurantSearchService: Background loading failed: $error");
      });
    }));
  }

  /// Set location filter with coordinates for distance-based filtering
  void setLocationFilterWithCoordinates(
      String? locationText, double lat, double lng,
      {double? radiusKm}) {
    _selectedLocation = locationText;
    _selectedLatitude = lat;
    _selectedLongitude = lng;
    if (radiusKm != null && radiusKm > 0) {
      _selectedRadiusKm = radiusKm;
    }
    applyFilters();
  }

  // Load initial batch of restaurants for fast startup
  Future<void> _loadInitialRestaurants() async {
    try {
      // Only clear if we're doing a fresh load (not if data already exists)
      if (_allRestaurants.isEmpty) {
        const int initialBatchSize = 20; // Small initial batch

        final batch = await _restaurantService.getRestaurants(
          offset: 0,
          limit: initialBatchSize,
        );

        if (batch.isNotEmpty) {
          _allRestaurants.addAll(batch);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("❌ RestaurantSearchService: Initial loading failed: $e");
      rethrow;
    }
  }

  // Load remaining restaurants in background (deferred - not critical for startup)
  Future<void> _loadRemainingRestaurantsInBackground() async {
    // Skip if we already have enough restaurants (prevent unnecessary loads)
    if (_allRestaurants.length >= 100) return;

    try {
      int offset = _allRestaurants.length;
      const int batchSize = 20;
      bool hasMore = true;

      while (hasMore && _allRestaurants.length < 100) {
        final batch = await _restaurantService.getRestaurants(
          offset: offset,
          limit: batchSize,
        );

        if (batch.isEmpty) {
          hasMore = false;
        } else {
          _allRestaurants.addAll(batch);
          offset += batch.length;

          // Notify listeners every 20 restaurants (throttled)
          if (_allRestaurants.length % 20 == 0) {
            notifyListeners();
          }
        }
      }

      // Final notification
      notifyListeners();
    } catch (e) {
      debugPrint("❌ RestaurantSearchService: Background loading failed: $e");
    }
  }

  // Update filtered results when restaurants are loaded and no filters are active
  void _updateFilteredResultsIfNeeded() {
    if (!hasActiveFilters &&
        _searchQuery.trim().isEmpty &&
        _allRestaurants.isNotEmpty) {
      _filteredResults = _dedupeById(_allRestaurants);
      // Reduced logging to prevent terminal spam
      // debugPrint("🔍 RestaurantSearchService: Updated filtered results to ${_filteredResults.length} restaurants");
      notifyListeners();
    } else if (_allRestaurants.isEmpty && _filteredResults.isNotEmpty) {
      // If restaurants were cleared but we have cached results, keep them for now
      // Reduced logging to prevent terminal spam
      // debugPrint("🔍 RestaurantSearchService: Keeping existing filtered results until restaurants reload");
    }
  }

  // Load restaurants in batches for better performance
  Future<void> _loadAllRestaurants() async {
    try {
      // Reduced logging to prevent terminal spam
      // debugPrint("🔍 RestaurantSearchService: Starting restaurant load...");
      _allRestaurants = [];
      int offset = 0;
      const int batchSize = 20; // Reduced batch size for faster startup
      bool hasMore = true;
      int totalLoaded = 0;

      while (hasMore) {
        // Reduced logging to prevent terminal spam
        // debugPrint("🔍 RestaurantSearchService: Loading batch at offset $offset...");
        final batch = await _restaurantService.getRestaurants(
          offset: offset,
          limit: batchSize,
        );

        if (batch.isEmpty) {
          hasMore = false;
          // Reduced logging to prevent terminal spam
          // debugPrint("🔍 RestaurantSearchService: No more restaurants to load");
        } else {
          _allRestaurants.addAll(batch);
          offset += batch.length;
          totalLoaded += batch.length;

          // Reduced logging to prevent terminal spam
          // debugPrint("🔍 RestaurantSearchService: Loaded batch of ${batch.length} restaurants (total: $totalLoaded)");

          // Reduced logging to prevent terminal spam
          // Notify listeners progressively for better UX
          if (totalLoaded % 100 == 0) {
            // Notify every 100 restaurants
            // debugPrint("🔍 RestaurantSearchService: Notifying listeners of progress - $totalLoaded restaurants loaded");
            notifyListeners();
          }

          // Prevent loading too many restaurants to avoid memory issues
          if (_allRestaurants.length >= 100) {
            // Reduced logging to prevent terminal spam
            // debugPrint("🔍 RestaurantSearchService: Limited to 100 restaurants for performance");
            break;
          }
        }
      }

      // Ensure no duplicates
      _allRestaurants = _dedupeById(_allRestaurants);
      // Reduced logging to prevent terminal spam
      // debugPrint("🔍 RestaurantSearchService: Loaded ${_allRestaurants.length} restaurants for search (after deduplication)");
    } on Exception catch (e, stackTrace) {
      debugPrint("❌ RestaurantSearchService: Error loading restaurants: $e");
      debugPrint("❌ RestaurantSearchService: Stack trace: $stackTrace");
      _error = "Failed to load restaurants";
      notifyListeners();
    }
  }

  // Search restaurants - REDIS OPTIMIZED with cancelable operations
  Future<void> search(String query) async {
    // Cancel any existing operations
    _cancelActiveOperations();

    // Increment search sequence to track this request
    _searchSequence++;
    final currentSequence = _searchSequence;

    if (query.trim().isEmpty) {
      _clearSearch();
      return;
    }

    _searchQuery = query.trim();
    _isSearching = true;
    _error = null;
    notifyListeners();

    try {
      // Check cache first
      final cacheKey = _generateSearchCacheKey(query);
      if (_searchCache.containsKey(cacheKey)) {
        final cacheEntry = _searchCache[cacheKey]!;
        if (DateTime.now().difference(cacheEntry.timestamp) < _cacheExpiry) {
          debugPrint("🔄 RestaurantSearchService: Cache hit for query: $query");

          // Check if this is still the latest search
          if (currentSequence != _searchSequence) {
            debugPrint(
                "🔄 RestaurantSearchService: Ignoring outdated cached result (sequence: $currentSequence, current: $_searchSequence)");
            return;
          }

          _searchResults = _dedupeById(cacheEntry.results);
          _filteredResults = _dedupeById(cacheEntry.results);
          _currentPage = 0;
          _hasMoreData = cacheEntry.results.length > _itemsPerPage;
          _isSearching = false;
          notifyListeners();
          return;
        } else {
          debugPrint(
              "🔄 RestaurantSearchService: Cache expired for query: $query");
          _searchCache.remove(cacheKey);
        }
      }

      // Redis optimization removed - using smart local search only

      // Fallback to smart local search using SmartTextDetector
      debugPrint(
          "🔍 RestaurantSearchService: Using smart text detection for local search...");
      final searchVariations =
          SmartTextDetector.generateSearchVariations(query);
      debugPrint(
          "🔍 RestaurantSearchService: Generated ${searchVariations.length} search variations: $searchVariations");

      // Debug multi-word search
      final queryWords = query
          .toLowerCase()
          .trim()
          .split(RegExp(r"\s+"))
          .where((word) => word.isNotEmpty)
          .toList();
      debugPrint(
          "🔍 RestaurantSearchService: Query words for multi-word search: $queryWords");

      final localSearchOperation = CancelableOperation.fromFuture(
        _performLocalSearch(query, searchVariations),
      );
      _activeOperations.add(localSearchOperation);

      final results = await localSearchOperation.value;

      // Check if this is still the latest search
      if (currentSequence != _searchSequence) {
        debugPrint(
            "🔍 RestaurantSearchService: Ignoring outdated local search result (sequence: $currentSequence, current: $_searchSequence)");
        return;
      }

      _searchResults = _dedupeById(results);
      _filteredResults = _dedupeById(results);
      _currentPage = 0;
      _hasMoreData = results.length > _itemsPerPage;

      // Cache the results
      _searchCache[cacheKey] = _SearchCacheEntry(
        results: results,
        timestamp: DateTime.now(),
      );
      _maintainCacheSize();

      debugPrint(
          "🔍 RestaurantSearchService: Found ${results.length} restaurants for query: $query");
    } on Exception catch (e) {
      debugPrint("❌ RestaurantSearchService: Error searching: $e");
      _error = "Search failed";
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  // Perform actual local search logic
  // OPTIMIZED: Search menu items first to get restaurant IDs, then use those restaurants directly
  // This reduces load by avoiding redundant restaurant name searches when menu items already provide restaurants
  Future<List<Restaurant>> _performLocalSearch(
      String query, List<String> searchVariations) async {
    // Split query into individual words for better multi-word search handling
    final queryWords = query
        .toLowerCase()
        .trim()
        .split(RegExp(r"\s+"))
        .where((word) => word.isNotEmpty)
        .toList();

    // OPTIMIZATION: Search menu items FIRST to get restaurant IDs
    // This allows us to use restaurants from menu item search directly, reducing redundant name searches
    Set<String> restaurantIdsFromMenuItems = {};
    try {
      final menuItemService = MenuItemDisplayService();

      // Use primary search variation for menu items (most efficient)
      final primaryVariation = searchVariations.isNotEmpty ? searchVariations.first : query;
      debugPrint(
          '🚀 RestaurantSearchService: Searching menu items FIRST with "$primaryVariation" (optimization: reduce restaurant search load)');

      try {
        final menuSearchOperation = CancelableOperation.fromFuture(
          menuItemService
              .searchMenuItems(query: primaryVariation, limit: 50)
              .timeout(
                const Duration(seconds: 3),
                onTimeout: () {
                  debugPrint(
                      "⏱️ RestaurantSearchService: Menu item search timeout");
                  return <MenuItem>[];
                },
              ),
        );
        _activeOperations.add(menuSearchOperation);

        final matchingMenuItems = await menuSearchOperation.value;

        if (matchingMenuItems.isNotEmpty) {
          debugPrint(
              '🚀 RestaurantSearchService: Found ${matchingMenuItems.length} matching menu items');

          // Get unique restaurant IDs from matching menu items
          restaurantIdsFromMenuItems = matchingMenuItems
              .map((item) => item.restaurantId)
              .where((id) => id.isNotEmpty)
              .toSet();

          debugPrint(
              "🚀 RestaurantSearchService: Found ${restaurantIdsFromMenuItems.length} restaurant IDs from menu items (will use these directly)");
        }
      } on TimeoutException catch (e) {
        debugPrint(
            "⏱️ RestaurantSearchService: Menu item search timeout - $e");
      } on Exception catch (e) {
        debugPrint(
            "⚠️ RestaurantSearchService: Error searching menu items - $e");
      }
    } on Exception catch (e) {
      debugPrint(
          "❌ RestaurantSearchService: Error in menu item search - $e");
    }

    // Start with restaurants from menu items (optimized path)
    final results = <Restaurant>[];
    if (restaurantIdsFromMenuItems.isNotEmpty) {
      final restaurantsFromMenuItems = _allRestaurants
          .where((restaurant) => restaurantIdsFromMenuItems.contains(restaurant.id))
          .toList();
      results.addAll(restaurantsFromMenuItems);
      debugPrint(
          "✅ RestaurantSearchService: Added ${restaurantsFromMenuItems.length} restaurants from menu item search (optimized - reduced load)");
    }

    // Also search restaurants by name/description, but skip those we already have from menu items
    final restaurantNameMatches = _allRestaurants.where((restaurant) {
      // Skip if we already have this restaurant from menu items (avoid duplicates)
      if (restaurantIdsFromMenuItems.contains(restaurant.id)) {
        return false;
      }

      // Use smart text detection for better matching
      final restaurantName = restaurant.name.toLowerCase().trim();
      final restaurantDescription = restaurant.description.toLowerCase().trim();
      final restaurantCity = restaurant.city.toLowerCase().trim();
      final restaurantWilaya = (restaurant.wilaya ?? "").toLowerCase().trim();

      // Check if any search variation matches any restaurant field (OR logic for variations)
      for (final variation in searchVariations) {
        if (restaurantName.contains(variation) ||
            restaurantDescription.contains(variation) ||
            restaurantCity.contains(variation) ||
            restaurantWilaya.contains(variation)) {
          debugPrint(
              '🔍 RestaurantSearchService: Found match for "$variation" in ${restaurant.name}');
          return true;
        }
      }

      // Multi-word search logic: check if ALL query words are present in restaurant fields
      if (queryWords.length > 1) {
        bool allWordsFound = true;
        for (final word in queryWords) {
          final bool wordFound = restaurantName.contains(word) ||
              restaurantDescription.contains(word) ||
              restaurantCity.contains(word) ||
              restaurantWilaya.contains(word);

          if (!wordFound) {
            allWordsFound = false;
            break;
          }
        }

        if (allWordsFound) {
          debugPrint(
              '🔍 RestaurantSearchService: Found multi-word match for "$query" in ${restaurant.name}');
          return true;
        }
      }

      // Single word fallback or similarity matching
      if (queryWords.length == 1) {
        if (SmartTextDetector.isSimilar(query, restaurantName) ||
            SmartTextDetector.isSimilar(query, restaurantDescription) ||
            SmartTextDetector.isSimilar(query, restaurantCity) ||
            SmartTextDetector.isSimilar(query, restaurantWilaya)) {
          debugPrint(
              '🔍 RestaurantSearchService: Found similar match for "$query" in ${restaurant.name}');
          return true;
        }
      }

      return false;
    }).toList();

    // Add restaurants found by name (avoiding duplicates)
    results.addAll(restaurantNameMatches);
    if (restaurantNameMatches.isNotEmpty) {
      debugPrint(
          "✅ RestaurantSearchService: Added ${restaurantNameMatches.length} restaurants from name/description search");
    }

    return results;
  }

  /// Get restaurant IDs that have menu items in the given price range
  Future<Set<String>> getRestaurantIdsWithMenuItemsInPriceRange(
      RangeValues priceRange) async {
    try {
      debugPrint(
          "💰 RestaurantSearchService: Getting restaurants with menu items in price range ${priceRange.start}-${priceRange.end}");

      // Get menu items filtered by price
      final menuItems = await _menuItemDisplayService.getAllMenuItemsFiltered(
        limit: 100,
        priceRange: priceRange,
      );

      // Extract unique restaurant IDs
      final restaurantIds = menuItems
          .map((item) => item.restaurantId)
          .where((id) => id.isNotEmpty)
          .toSet();

      debugPrint(
          "💰 RestaurantSearchService: Found ${restaurantIds.length} restaurants with menu items in price range");

      return restaurantIds;
    } on Exception catch (e) {
      debugPrint(
          "❌ RestaurantSearchService: Error getting restaurants with menu items in price range: $e");
      return {};
    }
  }

  // Apply filters to search results with caching and optimized notifications
  Future<void> applyFilters() async {
    // Cancel any existing operations
    _cancelActiveOperations();

    _isFiltering = true;
    _error = null;

    try {
      // Check cache first
      final cacheKey = _generateFilterCacheKey();
      if (_filterCache.containsKey(cacheKey)) {
        final cacheEntry = _filterCache[cacheKey]!;
        if (DateTime.now().difference(cacheEntry.timestamp) < _cacheExpiry) {
          debugPrint("🔄 RestaurantSearchService: Filter cache hit");
          _filteredResults = _dedupeById(cacheEntry.results);
          _currentPage = 0;
          _hasMoreData = _filteredResults.length > _itemsPerPage;
          _isFiltering = false;
          notifyListeners();
          return;
        } else {
          debugPrint("🔄 RestaurantSearchService: Filter cache expired");
          _filterCache.remove(cacheKey);
        }
      }

      // Base: when not searching, filter across all restaurants; otherwise on current search results
      List<Restaurant> results = _searchQuery.trim().isEmpty
          ? List.from(_allRestaurants)
          : List.from(_searchResults);
      results = _dedupeById(results);

      // Apply location filter (textual match and/or proximity if coordinates exist)
      if (_selectedLocation != null ||
          (_selectedLatitude != null && _selectedLongitude != null)) {
        final locationQuery = (_selectedLocation ?? '').toLowerCase().trim();
        final isCoordQuery = _isCoordinateQuery(locationQuery);
        results = results.where((restaurant) {
          final city = restaurant.city.toLowerCase();
          final state = restaurant.state.toLowerCase();
          final wilaya = (restaurant.wilaya ?? "").toLowerCase();

          bool textMatch = false;
          if (_selectedLocation != null &&
              locationQuery.isNotEmpty &&
              !isCoordQuery) {
            bool matches(String field) {
              if (field.isEmpty) return false;
              return field.contains(locationQuery) ||
                  locationQuery.contains(field);
            }

            textMatch = matches(city) || matches(state) || matches(wilaya);
          }

          bool proximityMatch = true; // default true if no coords provided
          if (_selectedLatitude != null && _selectedLongitude != null) {
            // Only apply proximity if the restaurant has coords
            if (restaurant.latitude != null && restaurant.longitude != null) {
              final distanceKm = _haversineKm(
                  _selectedLatitude!,
                  _selectedLongitude!,
                  restaurant.latitude!,
                  restaurant.longitude!);
              proximityMatch = distanceKm <= _selectedRadiusKm;
            } else {
              // If restaurant has no coords, keep it only if text matched
              proximityMatch = !isCoordQuery && textMatch;
            }
          }

          // Decision matrix:
          // - If query is coordinate-like: rely on proximity only
          // - If both text (non-coordinate) and coords present: require both
          // - If only text: use text
          // - If only coords: use proximity
          if (isCoordQuery &&
              _selectedLatitude != null &&
              _selectedLongitude != null) {
            return proximityMatch;
          }
          if (!isCoordQuery &&
              _selectedLocation != null &&
              _selectedLatitude != null &&
              _selectedLongitude != null) {
            return textMatch && proximityMatch;
          }
          if (_selectedLocation != null && !isCoordQuery) return textMatch;
          return proximityMatch;
        }).toList();
        debugPrint(
            "🔍 RestaurantSearchService: Location filter applied - ${results.length} restaurants");
      }

      // Apply rating filter
      if (_minRating != null) {
        results = results
            .where((restaurant) => restaurant.rating >= _minRating!)
            .toList();
        debugPrint(
            "🔍 RestaurantSearchService: Rating filter applied - ${results.length} restaurants");
      }

      // Apply price range filter based on menu item prices
      if (_priceRange != null) {
        debugPrint(
            "💰 RestaurantSearchService: Applying menu item price range filter: ${_priceRange!.start}-${_priceRange!.end}");

        // Get restaurant IDs that have menu items in this price range
        final allowedRestaurantIds =
            await getRestaurantIdsWithMenuItemsInPriceRange(_priceRange!);

        if (allowedRestaurantIds.isNotEmpty) {
          results = results
              .where(
                  (restaurant) => allowedRestaurantIds.contains(restaurant.id))
              .toList();
          debugPrint(
              "💰 RestaurantSearchService: Menu item price filter applied - ${results.length} restaurants have items in range");
        } else {
          // No restaurants have menu items in this price range
          results = [];
          debugPrint(
              "💰 RestaurantSearchService: No restaurants have menu items in price range ${_priceRange!.start}-${_priceRange!.end}");
        }
      }

      // Apply delivery fee range filter to restaurants
      if (_deliveryFeeRange != null) {
        results = results.where((restaurant) {
          final fee = restaurant.deliveryFee;
          return fee >= _deliveryFeeRange!.start &&
              fee <= _deliveryFeeRange!.end;
        }).toList();
        debugPrint(
            "🔍 RestaurantSearchService: Delivery fee filter applied - ${results.length} restaurants");
      }

      // Apply delivery time filter
      if (_maxDeliveryTime != null) {
        results = results
            .where((restaurant) =>
                restaurant.estimatedDeliveryTime <= _maxDeliveryTime!)
            .toList();
        debugPrint(
            "🔍 RestaurantSearchService: Delivery time filter applied - ${results.length} restaurants");
      }

      // Apply open status filter using WorkingHoursUtils for high-performance accuracy
      if (_isOpen != null) {
        debugPrint(
            "🔍 RestaurantSearchService: Applying open status filter: $_isOpen");
        results = results.where((restaurant) {
          // Use WorkingHoursUtils for accurate current status checking
          final isCurrentlyOpen =
              WorkingHoursUtils.isCurrentlyOpen(restaurant.openingHours);

          // If WorkingHoursUtils can determine status, use it; otherwise fallback to database field
          if (restaurant.openingHours != null &&
              restaurant.openingHours!.isNotEmpty) {
            final matchesFilter = isCurrentlyOpen == _isOpen;
            debugPrint(
                "🔍 RestaurantSearchService: ${restaurant.name} - WorkingHoursUtils: $isCurrentlyOpen, Filter: $_isOpen, Match: $matchesFilter");
            return matchesFilter;
          } else {
            // Fallback to simple database field
            final matchesFilter = restaurant.isOpen == _isOpen;
            debugPrint(
                "🔍 RestaurantSearchService: ${restaurant.name} - Database fallback: ${restaurant.isOpen}, Filter: $_isOpen, Match: $matchesFilter");
            return matchesFilter;
          }
        }).toList();
        debugPrint(
            "🔍 RestaurantSearchService: Open status filter applied - ${results.length} restaurants remaining");
      }

      // Apply featured filter
      if (_isFeatured != null) {
        results = results
            .where((restaurant) => restaurant.isFeatured == _isFeatured)
            .toList();
        debugPrint(
            "🔍 RestaurantSearchService: Featured filter applied - ${results.length} restaurants");
      }

      // Apply cuisine/category filtering if we have actual filters
      if (_selectedCuisines.isNotEmpty || _selectedCategories.isNotEmpty) {
        try {
          debugPrint(
              "🔍 RestaurantSearchService: Applying cuisine/category filters: cuisines=$_selectedCuisines, categories=$_selectedCategories");

          final cuisineFilterOperation = CancelableOperation.fromFuture(
            _restaurantDisplayService.getRestaurantsByCuisinesAndCategories(
              cuisineNames: _selectedCuisines,
              categoryNames: _selectedCategories,
              limit: 1000,
              minRating: _minRating,
              deliveryFeeRange: _deliveryFeeRange,
            ),
          );
          _activeOperations.add(cuisineFilterOperation);

          final filteredByMenu = await cuisineFilterOperation.value;

          debugPrint(
              "🔍 RestaurantSearchService: Cuisine/Category filter returned ${filteredByMenu.length} restaurants");

          if (filteredByMenu.isNotEmpty) {
            final allowed = filteredByMenu.map((r) => r.id).toSet();
            _filteredResults = _dedupeById(
                results.where((r) => allowed.contains(r.id)).toList());
            debugPrint(
                "🔍 RestaurantSearchService: After filtering: ${_filteredResults.length} restaurants remain");
          } else {
            debugPrint(
                "🔍 RestaurantSearchService: No restaurants found with applied filters, showing empty results");
            _filteredResults = [];
          }
        } on Exception catch (e) {
          debugPrint(
              "❌ RestaurantSearchService: Error in cuisine/category filtering: $e");
          _filteredResults = [];
        }
      } else {
        debugPrint(
            "🔍 RestaurantSearchService: No cuisine/category filters applied, using filtered results: ${results.length}");
        _filteredResults = _dedupeById(results);
      }

      _currentPage = 0;
      _hasMoreData = _filteredResults.length > _itemsPerPage;

      // Cache the results
      _filterCache[cacheKey] = _FilterCacheEntry(
        results: _filteredResults,
        timestamp: DateTime.now(),
      );
      _maintainCacheSize();

      debugPrint(
          "🔍 RestaurantSearchService: Applied filters, final results: ${_filteredResults.length} restaurants");
    } on Exception catch (e) {
      debugPrint("❌ RestaurantSearchService: Error applying filters: $e");
      _error = "Filter application failed";
      _filteredResults = [];
    } finally {
      _isFiltering = false;
      notifyListeners();
    }
  }

  // Set location filter
  void setLocationFilter(String? location) {
    _selectedLocation =
        (location != null && location.trim().isNotEmpty) ? location : null;
    // If location text is cleared, also clear coordinates to avoid hidden proximity filters
    if (_selectedLocation == null) {
      _selectedLatitude = null;
      _selectedLongitude = null;
    }
    applyFilters();
  }

  // Clear only location-related filters (text + coordinates)
  void clearLocationFilter() {
    _selectedLocation = null;
    _selectedLatitude = null;
    _selectedLongitude = null;
    applyFilters();
  }

  // Haversine distance in kilometers
  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371.0; // Earth radius in km
    final double dLat = _deg2rad(lat2 - lat1);
    final double dLon = _deg2rad(lon2 - lon1);
    final double a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            (sin(dLon / 2) * sin(dLon / 2));
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180.0);

  bool _isCoordinateQuery(String q) {
    if (q.isEmpty) return false;
    // Detect patterns like "34.86, 5.71" or a single numeric token
    final coordRegex =
        RegExp(r"^-?\d{1,3}(?:\.\d+)?\s*,\s*-?\d{1,3}(?:\.\d+)?$");
    if (coordRegex.hasMatch(q)) return true;
    // If it contains mostly digits/commas/periods and spaces and not letters
    final noLetters = RegExp(r"^[\d\s,\.\-]+$");
    return noLetters.hasMatch(q) && q.contains(',');
  }

  // Set cuisine filter
  void setCuisineFilter(Set<String> cuisines) {
    _selectedCuisines = Set<String>.from(cuisines);
    applyFilters();
  }

  // Set category filter
  void setCategoryFilter(Set<String> categories) {
    _selectedCategories = Set<String>.from(categories);
    applyFilters();
  }

  // Set rating filter
  void setRatingFilter(double? minRating) {
    _minRating = minRating;
    applyFilters();
  }

  // Set price range filter
  void setPriceRangeFilter(RangeValues? priceRange) {
    _priceRange = priceRange;
    applyFilters();
  }

  @override
  void setDeliveryFeeRangeFilter(RangeValues? deliveryFeeRange) {
    _deliveryFeeRange = deliveryFeeRange;
    applyFilters();
  }

  // Set delivery time filter
  void setDeliveryTimeFilter(int? maxDeliveryTime) {
    _maxDeliveryTime = maxDeliveryTime;
    applyFilters();
  }

  // Set open status filter
  void setOpenFilter({bool? isOpen}) {
    _isOpen = isOpen;
    applyFilters();
  }

  // Set featured filter
  void setFeaturedFilter({bool? isFeatured}) {
    _isFeatured = isFeatured;
    applyFilters();
  }

  // Set dietary options filter
  void setDietaryOptionsFilter(Set<String> dietaryOptions) {
    _dietaryOptions = Set<String>.from(dietaryOptions);
    applyFilters();
  }

  // Clear all filters
  @override
  void clearFilters() {
    _selectedLocation = null;
    _selectedLatitude = null;
    _selectedLongitude = null;
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
    if (_allRestaurants.isNotEmpty) {
      _filteredResults = _dedupeById(_allRestaurants);
      debugPrint(
          "🔍 RestaurantSearchService: Filters cleared, showing ${_filteredResults.length} restaurants from ${_allRestaurants.length} total");
    } else {
      debugPrint(
          "⚠️ RestaurantSearchService: Filters cleared but _allRestaurants is empty! Attempting to reload...");
      // Try to reload restaurants if they're missing
      _loadAllRestaurantsInBackground();
      _filteredResults = [];
    }

    _currentPage = 0;
    _hasMoreData = _filteredResults.length > _itemsPerPage;

    // Clear filter cache to avoid reuse of stale location-based entries
    _filterCache.clear();

    notifyListeners();
  }

  // Clear search with proper state synchronization
  void clearSearch() {
    debugPrint("🔍 RestaurantSearchService: Clearing search state...");

    // Cancel any ongoing operations
    _cancelActiveOperations();

    // Increment sequence to invalidate in-flight searches
    _searchSequence++;

    _searchQuery = "";
    _searchResults.clear();
    _error = null;

    // Clear caches related to search
    _searchCache.clear();

    // Reset filtered results to all restaurants with current filters
    clearFilters();

    debugPrint(
        "🔍 RestaurantSearchService: Search cleared - All: ${_allRestaurants.length}, Filtered: ${_filteredResults.length}");
    notifyListeners();
  }

  // Private clear search method
  void _clearSearch() {
    debugPrint("🔍 RestaurantSearchService: Private search clear...");

    // Increment sequence to invalidate in-flight searches
    _searchSequence++;

    _searchQuery = "";
    _searchResults.clear();

    // If restaurants are loaded, show them; otherwise keep current state
    if (_allRestaurants.isNotEmpty) {
      _filteredResults = _dedupeById(_allRestaurants);
      debugPrint(
          "🔍 RestaurantSearchService: Search cleared, showing ${_filteredResults.length} restaurants");
    } else {
      // Restaurants not loaded yet, keep current filtered results (likely empty)
      debugPrint(
          "🔍 RestaurantSearchService: Search cleared but no restaurants loaded yet");
    }

    _currentPage = 0;
    _hasMoreData = _filteredResults.length > _itemsPerPage;
    _error = null;
    _isSearching = false;

    debugPrint(
        "🔍 RestaurantSearchService: Search state - All: ${_allRestaurants.length}, Filtered: ${_filteredResults.length}");
    notifyListeners();
  }

  // Reset all state to initial values (for navigation isolation)
  void resetToInitialState() {
    debugPrint("🔄 RestaurantSearchService: Resetting to initial state...");

    // Cancel any ongoing operations
    _cancelActiveOperations();

    // Clear all caches
    _searchCache.clear();
    _filterCache.clear();

    _searchQuery = "";
    _searchResults.clear();
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
          "🔄 RestaurantSearchService: Reset to initial state with ${_filteredResults.length} restaurants");
    } else {
      _filteredResults = [];
      debugPrint(
          "🔄 RestaurantSearchService: Reset to initial state with no restaurants");
    }

    debugPrint("🔄 RestaurantSearchService: Reset to initial state");
    notifyListeners();
  }

  // Get paginated results
  List<Restaurant> getPaginatedResults() {
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex =
        (startIndex + _itemsPerPage).clamp(0, _filteredResults.length);
    return _filteredResults.sublist(startIndex, endIndex);
  }

  // Load more results
  void loadMore() {
    if (_hasMoreData && !_isSearching && !_isFiltering) {
      _currentPage++;
      _hasMoreData =
          _filteredResults.length > (_currentPage + 1) * _itemsPerPage;
      notifyListeners();
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
    if (_selectedLocation != null) {
      count++;
    }
    if (_selectedCuisines.isNotEmpty) {
      count++;
    }
    if (_selectedCategories.isNotEmpty) {
      count++;
    }
    if (_minRating != null) {
      count++;
    }
    if (_priceRange != null) {
      count++;
    }
    if (_deliveryFeeRange != null) {
      count++;
    }
    if (_maxDeliveryTime != null) {
      count++;
    }
    if (_isOpen != null) {
      count++;
    }
    if (_isFeatured != null) {
      count++;
    }
    if (_dietaryOptions.isNotEmpty) {
      count++;
    }
    return count;
  }

  // Refresh data with proper state synchronization
  Future<void> refresh() async {
    debugPrint("🔄 RestaurantSearchService: Refreshing data...");

    // Cancel any ongoing operations
    _cancelActiveOperations();

    // Clear caches since we're refreshing
    _searchCache.clear();
    _filterCache.clear();

    await _loadAllRestaurants();

    // Re-apply current search if exists
    if (_searchQuery.isNotEmpty) {
      await search(_searchQuery);
    } else {
      // Re-apply current filters if no search
      await applyFilters();
    }

    debugPrint("🔄 RestaurantSearchService: Data refreshed");
  }

  // Clear all caches and force refresh (for pull-to-refresh)
  Future<void> clearAllCachesAndRefresh() async {
    try {
      debugPrint(
          "🗑️ RestaurantSearchService: Clearing all caches and refreshing...");

      // Cancel any ongoing operations
      _cancelActiveOperations();

      // Clear all caches
      _searchCache.clear();
      _filterCache.clear();

      // Clear all restaurant data
      _allRestaurants.clear();
      _filteredResults.clear();
      _searchResults.clear();

      // Reset state
      _searchQuery = "";
      _isSearching = false;
      _isFiltering = false;
      _error = null;
      _currentPage = 0;
      _hasMoreData = true;

      // Force reload all restaurants
      await _loadAllRestaurants();

      // Re-apply current filters if any
      if (hasActiveFilters) {
        await applyFilters();
      }

      debugPrint(
          "✅ RestaurantSearchService: All caches cleared and data refreshed");
      notifyListeners();
    } catch (e) {
      debugPrint(
          "❌ RestaurantSearchService: Error clearing caches and refreshing: $e");
    }
  }

  // Public method to load restaurants (for pull-to-refresh)
  Future<void> loadRestaurants() async {
    try {
      debugPrint("🔄 RestaurantSearchService: Loading restaurants...");
      await _loadAllRestaurants();
      debugPrint("✅ RestaurantSearchService: Restaurants loaded");
    } catch (e) {
      debugPrint("❌ RestaurantSearchService: Error loading restaurants: $e");
    }
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

  // Cache management
  final LinkedHashMap<String, _SearchCacheEntry> _searchCache =
      LinkedHashMap<String, _SearchCacheEntry>();
  final LinkedHashMap<String, _FilterCacheEntry> _filterCache =
      LinkedHashMap<String, _FilterCacheEntry>();
  static const int _maxCacheSize = 50;
  static const Duration _cacheExpiry = Duration(minutes: 10);

  // Cancelable operations for timeout handling
  final Set<CancelableOperation> _activeOperations = <CancelableOperation>{};

  // Debounce service for search input
  final DebounceService _debounceService = DebounceService();

  // Maintain cache size by evicting oldest entries
  void _maintainCacheSize() {
    while (_searchCache.length > _maxCacheSize) {
      _searchCache.remove(_searchCache.keys.first);
    }
    while (_filterCache.length > _maxCacheSize) {
      _filterCache.remove(_filterCache.keys.first);
    }
  }

  // Generate consistent cache key for search
  String _generateSearchCacheKey(String query) {
    return "search:${query.toLowerCase().trim()}";
  }

  // Generate consistent cache key for filters
  String _generateFilterCacheKey() {
    final filterMap = {
      "location": _selectedLocation ?? "",
      "lat": _selectedLatitude?.toString() ?? "",
      "lng": _selectedLongitude?.toString() ?? "",
      "radiusKm": _selectedRadiusKm.toStringAsFixed(2),
      "cuisines": _selectedCuisines.join(","),
      "categories": _selectedCategories.join(","),
      "minRating": _minRating?.toString() ?? "",
      "priceRange": _priceRange?.toString() ?? "",
      "deliveryFeeRange": _deliveryFeeRange?.toString() ?? "",
      "maxDeliveryTime": _maxDeliveryTime?.toString() ?? "",
      "isOpen": _isOpen?.toString() ?? "",
      "isFeatured": _isFeatured?.toString() ?? "",
      "dietaryOptions": _dietaryOptions.join(","),
    };
    return 'filter:${filterMap.values.join(':')}';
  }

  // Cancel all active operations
  void _cancelActiveOperations() {
    for (final operation in _activeOperations) {
      operation.cancel();
    }
    _activeOperations.clear();
  }

  // Debounced search for real-time search input with fast response
  void debouncedSearch(String query) {
    _debounceService.call(() {
      search(query);
    }, duration: const Duration(milliseconds: 150));
  }

  // Immediate search (for when user wants instant results)
  Future<void> immediateSearch(String query) async {
    _debounceService.cancel();
    await search(query);
  }

  // Cleanup on dispose
  @override
  void dispose() {
    _cancelActiveOperations();
    _debounceService.dispose();
    super.dispose();
  }
}

// Cache entry classes
class _SearchCacheEntry {
  _SearchCacheEntry({required this.results, required this.timestamp});
  final List<Restaurant> results;
  final DateTime timestamp;
}

class _FilterCacheEntry {
  _FilterCacheEntry({required this.results, required this.timestamp});
  final List<Restaurant> results;
  final DateTime timestamp;
}

// Exception for canceled operations
class OperationCanceledException implements Exception {
  const OperationCanceledException();
}

// Cancelable operation wrapper
class CancelableOperation<T> {
  CancelableOperation._(this.value, this.onCancel);
  final Future<T> value;
  final VoidCallback? onCancel;
  bool _isCanceled = false;

  static CancelableOperation<T> fromFuture<T>(Future<T> future,
      {VoidCallback? onCancel}) {
    return CancelableOperation._(future, onCancel);
  }

  void cancel() {
    if (!_isCanceled) {
      _isCanceled = true;
      onCancel?.call();
    }
  }

  bool get isCanceled => _isCanceled;
}
