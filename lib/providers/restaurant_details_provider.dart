import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/data/cache_monitor.dart';
import '../core/data/repositories/menu_item_repository.dart';
import '../models/menu_item.dart';
import '../models/restaurant.dart';
import '../services/delivery_fee_service.dart';
import '../services/geolocation_service.dart';
import '../services/menu_cache_service.dart';
import '../services/menu_item_variant_service.dart';
import '../services/performance_monitoring_service.dart';
import '../services/restaurant_service.dart';
import '../services/socket_service.dart';

/// ViewModel/Provider for RestaurantDetailsScreen
/// Manages all business logic and state for the restaurant details view
class RestaurantDetailsProvider extends ChangeNotifier {
  RestaurantDetailsProvider({
    required this.restaurant,
  }) {
    _initialize();
  }

  final Restaurant restaurant;

  // Services
  final RestaurantService _restaurantService = RestaurantService();
  final PerformanceMonitoringService _performanceMonitor =
      PerformanceMonitoringService();
  final MenuCacheService _cacheService = MenuCacheService();
  final MenuItemRepository _menuItemRepository = MenuItemRepository();
  final CacheMonitor _cacheMonitor = CacheMonitor();
  late SocketService _socketService;

  // State
  bool _isLoadingMenu = true;
  bool _isLoadingDrinks = false;
  String? _errorMessage;
  List<MenuItem> _menuItems = [];
  List<MenuItem> _drinks = [];
  String _selectedCategory = "All";
  String _searchQuery = "";
  double? _dynamicDeliveryFee;
  bool _isDisposed = false;

  // Pagination state
  static const int _itemsPerPage = 30;
  List<MenuItem> _displayedItems = [];
  bool _isLoadingMore = false;
  bool _hasMoreItems = true;

  // Caching
  final Map<String, String> _drinkImageCache = {};
  SharedPreferences? _prefs;
  List<String>? _cachedCategories;
  int? _lastMenuItemsLength;
  List<MenuItem>? _cachedFilteredMenuItems;
  String? _lastSearchQuery;
  String? _lastSelectedCategory;

  // Real-time subscriptions
  StreamSubscription? _restaurantStatusSubscription;
  StreamSubscription? _menuUpdatesSubscription;
  StreamSubscription? _promotionSubscription;

  // Getters
  bool get isLoadingMenu => _isLoadingMenu;
  bool get isLoadingDrinks => _isLoadingDrinks;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreItems => _hasMoreItems;
  String? get errorMessage => _errorMessage;
  List<MenuItem> get menuItems => _menuItems;
  List<MenuItem> get drinks => _drinks;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  double? get dynamicDeliveryFee => _dynamicDeliveryFee;

  List<String> get categories {
    // Return cached categories if menu items haven't changed
    if (_cachedCategories != null &&
        _lastMenuItemsLength == _menuItems.length) {
      return _cachedCategories!;
    }

    // Filter out drink-related categories from menu items
    final nonDrinkItems = _getNonDrinkItems(_menuItems);
    // Also filter out LTO items (both active and expired - they're displayed in the LTO section or should be hidden)
    final nonLTONonDrinkItems = nonDrinkItems
        .where((item) => !item.isOfferActive && !item.hasExpiredLTOOffer)
        .toList();
    final categories =
        nonLTONonDrinkItems.map((item) => item.category).toSet().toList();
    categories.insert(0, "All");

    _cachedCategories = categories;
    _lastMenuItemsLength = _menuItems.length;
    return categories;
  }

  List<MenuItem> get filteredMenuItems {
    // Return paginated displayed items
    return _displayedItems;
  }

  /// Get all filtered items (without pagination) for internal use
  List<MenuItem> get _allFilteredMenuItems {
    // Return cached result if inputs haven't changed
    if (_cachedFilteredMenuItems != null &&
        _lastSearchQuery == _searchQuery &&
        _lastSelectedCategory == _selectedCategory) {
      return _cachedFilteredMenuItems!;
    }

    // First, filter out drink items from all menu items
    var nonDrinkItems = _getNonDrinkItems(_menuItems);

    // Filter out LTO items (both active and expired - they're displayed in the LTO section or should be hidden)
    nonDrinkItems = nonDrinkItems
        .where((item) => !item.isOfferActive && !item.hasExpiredLTOOffer)
        .toList();

    // Apply search filter if query is not empty
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      nonDrinkItems = nonDrinkItems.where((item) {
        return item.name.toLowerCase().contains(query) ||
            item.description.toLowerCase().contains(query) ||
            item.category.toLowerCase().contains(query);
      }).toList();
    }

    // Apply category filter
    if (_selectedCategory != "All" && nonDrinkItems.isNotEmpty) {
      final normalizedSelectedCategory =
          _normalizeCategoryKey(_selectedCategory);
      final filtered = nonDrinkItems
          .where((item) =>
              _normalizeCategoryKey(item.category) ==
              normalizedSelectedCategory)
          .toList();

      // If no items found for selected category, fall back to all non-drink items
      if (filtered.isEmpty) {
        _cachedFilteredMenuItems = nonDrinkItems;
        _lastSearchQuery = _searchQuery;
        _lastSelectedCategory = _selectedCategory;
        return nonDrinkItems;
      }
      _cachedFilteredMenuItems = filtered;
      _lastSearchQuery = _searchQuery;
      _lastSelectedCategory = _selectedCategory;
      return filtered;
    }

    _cachedFilteredMenuItems = nonDrinkItems;
    _lastSearchQuery = _searchQuery;
    _lastSelectedCategory = _selectedCategory;
    return nonDrinkItems;
  }

  double get lowestMenuItemPrice {
    if (_menuItems.isEmpty) {
      return restaurant.minimumOrder;
    }

    final nonDrinkItems = _getNonDrinkItems(_menuItems);
    if (nonDrinkItems.isEmpty) {
      return restaurant.minimumOrder;
    }

    return nonDrinkItems
        .map((item) => item.price)
        .reduce((a, b) => a < b ? a : b);
  }

  double get averagePreparationTime {
    if (_menuItems.isEmpty) {
      return 15; // Default preparation time
    }
    final totalPrepTime =
        _menuItems.map((item) => item.preparationTime).reduce((a, b) => a + b);
    return totalPrepTime / _menuItems.length;
  }

  int get totalDeliveryTime {
    return (restaurant.estimatedDeliveryTime + averagePreparationTime).round();
  }

  // Initialization
  Future<void> _initialize() async {
    // Load menu items immediately
    unawaited(Future.microtask(() {
      if (!_isDisposed) {
        loadMenuItems();
      }
    }));

    // Load drink image cache
    await _loadDrinkImageCache();

    // Load drinks after a short delay
    unawaited(Future.delayed(const Duration(milliseconds: 500), () {
      if (!_isDisposed) {
        loadDrinks();
      }
    }));

    // Compute dynamic delivery fee
    unawaited(_computeDeliveryFee());
  }

  /// Initialize real-time services
  void initializeRealTime(SocketService socketService) {
    _socketService = socketService;
    _setupRealTimeListeners();
  }

  void _setupRealTimeListeners() {
    // Listen for restaurant status updates
    _restaurantStatusSubscription =
        _socketService.presenceStream.listen((data) {
      if (data["restaurantId"] == restaurant.id) {
        _handleRestaurantStatusUpdate(data);
      }
    });

    // Listen for menu updates
    _menuUpdatesSubscription = _socketService.notificationStream.listen((data) {
      if (data["type"] == "menu_update" &&
          data["restaurantId"] == restaurant.id) {
        _handleMenuUpdate(data);
      }
    });

    // Listen for promotions
    _promotionSubscription = _socketService.orderUpdatesStream.listen((data) {
      if (data["type"] == "promotion_update" &&
          data["restaurantId"] == restaurant.id) {
        _handlePromotionUpdate(data);
      }
    });
  }

  void _handleRestaurantStatusUpdate(Map<String, dynamic> data) {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void _handleMenuUpdate(Map<String, dynamic> data) {
    if (!_isDisposed) {
      loadMenuItems();
    }
  }

  void _handlePromotionUpdate(Map<String, dynamic> data) {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  // Data loading methods
  Future<void> loadMenuItems() async {
    final stopwatch = Stopwatch()..start();
    await _loadMenuItemsInternal(stopwatch);
  }

  Future<void> _loadMenuItemsInternal(Stopwatch stopwatch) async {
    try {
      _isLoadingMenu = true;
      _errorMessage = null;
      notifyListeners();

      debugPrint("🔄 Loading menu items for restaurant ${restaurant.id}");

      // ✅ PERFORMANCE: Use repository with 3-tier caching
      try {
        final menuItems = await _menuItemRepository.getByRestaurant(
          restaurant.id,
          offset: 0,
          limit: 100,
        );

        if (menuItems.isNotEmpty) {
          // Repository already returns MenuItem objects, no need to parse
          List<MenuItem> parsedItems = menuItems;

          // Expand variants to separate items
          parsedItems =
              MenuItemVariantService.expandVariantsToSeparateItems(parsedItems);

          _menuItems = parsedItems;
          _isLoadingMenu = false;
          _cachedFilteredMenuItems = null;
          _cachedCategories = null;

          // Initialize pagination
          _initializePagination();

          _cacheMonitor.trackCacheHit(CacheTier.memory, 'loadMenuItems');
          _cacheMonitor.trackOperationDuration(
              'loadMenuItems', stopwatch.elapsed);

          notifyListeners();

          // Load fresh data in background (stale-while-revalidate)
          unawaited(_loadFreshMenuItems());
          return;
        }
      } catch (e) {
        debugPrint('⚠️ Repository cache failed, falling back to service: $e');
        _cacheMonitor.trackCacheMiss(CacheTier.network, 'loadMenuItems');
      }

      // Fallback to original service
      final menuItemsData =
          await _restaurantService.getRestaurantMenu(restaurant.id);

      var menuItems =
          menuItemsData.map((json) => MenuItem.fromJson(json)).toList();

      // Expand variants to separate items
      menuItems =
          MenuItemVariantService.expandVariantsToSeparateItems(menuItems);

      // Cache the loaded menu items
      await _cacheService.cacheMenuItems(restaurant.id, menuItems);

      // Track performance metrics
      _performanceMonitor.trackApiRequest(
        endpoint: '/api/menu/${restaurant.id}',
        method: 'GET',
        duration: stopwatch.elapsed,
        success: true,
        metadata: {
          'menuItemsCount': menuItems.length,
          'restaurantId': restaurant.id,
        },
      );

      _menuItems = menuItems;
      _isLoadingMenu = false;
      _cachedFilteredMenuItems = null;
      _cachedCategories = null;

      // Initialize pagination
      _initializePagination();

      notifyListeners();

      debugPrint(
          "🚀 Loaded ${menuItems.length} menu items (${stopwatch.elapsedMilliseconds}ms)");
    } on Exception catch (e) {
      // Track error performance
      _performanceMonitor.trackApiRequest(
        endpoint: '/api/menu/${restaurant.id}',
        method: 'GET',
        duration: stopwatch.elapsed,
        success: false,
        metadata: {
          'error': e.toString(),
          'restaurantId': restaurant.id,
        },
      );

      debugPrint("❌ Error loading menu items: $e");
      _errorMessage = "Failed to load menu items. Please try again.";
      _isLoadingMenu = false;
      notifyListeners();
    } finally {
      stopwatch.stop();
    }
  }

  /// Load fresh menu items in background (after serving from cache)
  Future<void> _loadFreshMenuItems() async {
    try {
      // ✅ PERFORMANCE: Use repository with force refresh
      final menuItems = await _menuItemRepository.getByRestaurant(
        restaurant.id,
        offset: 0,
        limit: 100,
      );

      // Expand variants to separate items
      final expandedItems =
          MenuItemVariantService.expandVariantsToSeparateItems(menuItems);

      // Update cache with fresh data
      await _cacheService.cacheMenuItems(restaurant.id, expandedItems);

      // Only update UI if data has changed
      if (menuItems.length != _menuItems.length) {
        _menuItems = menuItems;
        _cachedFilteredMenuItems = null;
        _cachedCategories = null;
        _resetPagination();
        if (!_isDisposed) {
          notifyListeners();
        }
        debugPrint("🔄 Background refresh completed with updated data");
      }
    } catch (e) {
      debugPrint("❌ Background refresh failed: $e");
      // Fail silently - we already have cached data
    }
  }

  Future<void> loadDrinks() async {
    if (_isLoadingDrinks) return;

    try {
      _isLoadingDrinks = true;
      notifyListeners();

      final supabase = Supabase.instance.client;
      final response = await supabase
          .from("menu_items")
          .select("*")
          .eq("restaurant_id", restaurant.id)
          .or("category.eq.Drink,category.eq.Drinks,category.eq.drink,category.eq.drinks")
          .eq("is_available", true);

      // Parse items and handle missing images gracefully
      _drinks = <MenuItem>[];
      for (final item in (response as List)) {
        try {
          final menuItem = MenuItem.fromJson(item);
          // Only include items with valid images
          if (menuItem.image.isNotEmpty) {
            _drinks.add(menuItem);
          } else {
            debugPrint(
                '⚠️ RestaurantDetailsProvider: Skipping drink with empty image: ${item['id']}');
          }
        } catch (e) {
          // Skip items that can't be parsed (e.g., missing required fields like image)
          final itemId = item['id']?.toString() ?? 'unknown';
          debugPrint(
              '⚠️ RestaurantDetailsProvider: Skipping drink due to parsing error: $e');
          debugPrint('   Item ID: $itemId');
        }
      }

      debugPrint("🍹 Loaded ${_drinks.length} drinks");
    } on Exception catch (e) {
      debugPrint("❌ Error loading drinks: $e");
      _drinks = [];
    } finally {
      _isLoadingDrinks = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  Future<void> _computeDeliveryFee() async {
    try {
      final geo = GeolocationService();
      final last = await geo.getLastKnownLocation();
      final loc = last ?? await geo.getCurrentLocation();
      if (loc == null) return;

      final fee = await DeliveryFeeService().calculateDeliveryFee(
        restaurantId: restaurant.id,
        customerLatitude: loc.latitude,
        customerLongitude: loc.longitude,
      );

      _dynamicDeliveryFee = fee;
      if (!_isDisposed) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint(
          '⚠️ RestaurantDetailsProvider: Failed to compute delivery fee: $e');
      // Non-fatal: use default fee
    }
  }

  // Pagination methods
  void _initializePagination() {
    final allFiltered = _allFilteredMenuItems;
    _displayedItems = allFiltered.take(_itemsPerPage).toList();
    _hasMoreItems = allFiltered.length > _itemsPerPage;
    debugPrint(
        "📄 Initialized pagination: ${_displayedItems.length}/${allFiltered.length} items");
  }

  Future<void> loadMoreItems() async {
    if (_isLoadingMore || !_hasMoreItems || _isDisposed) {
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      // Simulate slight delay for smooth UX
      await Future.delayed(const Duration(milliseconds: 300));

      final allFiltered = _allFilteredMenuItems;
      final currentCount = _displayedItems.length;
      final nextBatch =
          allFiltered.skip(currentCount).take(_itemsPerPage).toList();

      _displayedItems.addAll(nextBatch);
      _hasMoreItems = _displayedItems.length < allFiltered.length;

      debugPrint(
          "📄 Loaded more items: ${_displayedItems.length}/${allFiltered.length} (has more: $_hasMoreItems)");
    } catch (e) {
      debugPrint("❌ Error loading more items: $e");
    } finally {
      _isLoadingMore = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  void _resetPagination() {
    _displayedItems = [];
    _hasMoreItems = true;
    _cachedFilteredMenuItems = null;
    _initializePagination();
  }

  // User actions
  void setSelectedCategory(String category) {
    _selectedCategory = category;
    _resetPagination();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _resetPagination();
    notifyListeners();
  }

  void updateSearchQuery(String query) => setSearchQuery(query);

  void updateSelectedCategory(String category) => setSelectedCategory(category);

  void clearSearch() {
    _searchQuery = "";
    _cachedFilteredMenuItems = null;
    notifyListeners();
  }

  // Helper methods
  String _normalizeCategoryKey(String input) {
    return input
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('-', '_')
        .replaceAll('&', 'and');
  }

  List<MenuItem> _getNonDrinkItems(List<MenuItem> items) {
    return items
        .where((item) =>
            !item.category.toLowerCase().contains("drink") &&
            item.category.toLowerCase() != "drinks" &&
            item.category.toLowerCase() != "beverage" &&
            item.category.toLowerCase() != "beverages")
        .toList();
  }

  // Drink image cache management
  Future<void> _loadDrinkImageCache() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final cacheJson = _prefs!.getString('drink_image_cache');
      if (cacheJson != null && cacheJson.isNotEmpty) {
        final Map<String, dynamic> decoded = json.decode(cacheJson);
        _drinkImageCache
            .addAll(decoded.map((k, v) => MapEntry(k, v.toString())));
        debugPrint(
            '✅ Loaded ${_drinkImageCache.length} drink image cache entries');
      }
    } catch (e) {
      debugPrint('❌ Error loading drink image cache: $e');
    }
  }

  Future<void> saveDrinkImageCache(String drinkId, String filename) async {
    try {
      _drinkImageCache[drinkId] = filename;
      _prefs ??= await SharedPreferences.getInstance();
      final cacheJson = json.encode(_drinkImageCache);
      await _prefs!.setString('drink_image_cache', cacheJson);
    } catch (e) {
      debugPrint('❌ Error saving drink image cache: $e');
    }
  }

  String? getDrinkImageCache(String drinkId) {
    return _drinkImageCache[drinkId];
  }

  // Lifecycle methods
  Future<void> refresh() async {
    await Future.wait([
      loadMenuItems(),
      loadDrinks(),
    ]);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _restaurantStatusSubscription?.cancel();
    _menuUpdatesSubscription?.cancel();
    _promotionSubscription?.cancel();
    super.dispose();
  }
}
