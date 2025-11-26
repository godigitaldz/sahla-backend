import "dart:async" show StreamSubscription, Timer, unawaited;

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:supabase_flutter/supabase_flutter.dart" as supa;

// NEW: Provider architecture imports
import "../features/menu_items/presentation/providers/menu_items_provider.dart";
import "../l10n/app_localizations.dart";
import "../models/menu_item.dart";
import "../screens/map_location_picker_screen.dart";
import "../services/enhanced_fcm_service.dart";
import "../services/menu_item_sorting_service.dart";
import "../services/performance_monitoring_service.dart";
import "../services/realtime_service.dart";
import "../services/restaurant_search_service.dart";
import "../services/socket_service.dart";
import "../utils/lru_cache.dart";
import "../utils/performance_utils.dart";
import "../utils/smart_text_detector.dart";
import "../widgets/filter_chips_section/category_selector_modal.dart";
import "../widgets/filter_chips_section/cuisine_selector_modal.dart";
import "../widgets/filter_chips_section/price_selector_modal.dart";
import "../widgets/menu_item_full_popup/helpers/special_pack_helper.dart";
import "../widgets/menu_items_list_screen/menu_item_card.dart";
import "../widgets/menu_items_list_screen/menu_items_fixed_section.dart";
import "../widgets/menu_items_list_screen/menu_items_list_content.dart";
import "../widgets/menu_items_list_screen/lto_list_card.dart";
import "../widgets/menu_items_list_screen/helpers/lto_mode_helper.dart";

// Performance debug flag (set to false for production)
const bool kEnableMenuItemsDebug = false;

// Localization typedef for convenience
typedef S = AppLocalizations;

class MenuItemsListScreen extends ConsumerStatefulWidget {
  const MenuItemsListScreen({super.key});

  @override
  ConsumerState<MenuItemsListScreen> createState() =>
      _MenuItemsListScreenState();
}

class _MenuItemsListScreenState extends ConsumerState<MenuItemsListScreen>
    with AutomaticKeepAliveClientMixin, AutoDisposeMixin {
  List<MenuItem> _items = [];
  bool _isLoadingMore = false;
  bool _hasCompletedInitialLoad = false;
  late RestaurantSearchService _searchService;
  late TextEditingController _searchController;
  final ScrollController _scrollController = ScrollController();

  // LTO mode state
  bool _isLTOMode = false;
  List<MenuItem> _ltoItems = [];
  bool _isLoadingLTO = false;

  // Two-phase scroll state (using ValueNotifier for performance)
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0.0);
  bool _isFirstFrame = true;

  // PERFORMANCE: Cached filtered items to avoid recomputation
  List<MenuItem>? _cachedFilteredItems;
  String? _lastFilterSignature;

  // PERFORMANCE: Cached variant expansion
  final LRUCache<String, List<MenuItem>> _variantExpansionCache = LRUCache(20);

  // Cache for instant popup loading
  Map<String, double>? _cachedPriceRange;

  // Legacy cache removed - now using provider's Hive cache

  // Integration services
  late SocketService _socketService;
  late EnhancedFCMService _fcmService;
  late RealtimeService _realtimeService;
  late PerformanceMonitoringService _performanceService;

  // Real-time state
  final List<Map<String, dynamic>> _liveNotifications = [];

  StreamSubscription? _socketSubscription;
  StreamSubscription? _fcmSubscription;
  Timer? _searchTimer;

  @override
  bool get wantKeepAlive =>
      true; // Keep the screen alive for better performance

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchService = RestaurantSearchService();
    _scrollController.addListener(_onScroll);

    // Check if we're in LTO mode from route arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is Map && args['ltoMode'] == true) {
          setState(() {
            _isLTOMode = true;
          });
          _loadLTOItems();
          return; // Skip normal initialization for LTO mode
        }
      }
    });

    // Initialize integration services
    _socketService = SocketService();
    _fcmService = EnhancedFCMService();
    _realtimeService = RealtimeService();
    _performanceService = PerformanceMonitoringService();

    // Add disposers for automatic cleanup
    addDisposer(_searchController.dispose);
    addDisposer(_scrollController.dispose);
    addDisposer(() => _socketSubscription?.cancel());
    addDisposer(() => _fcmSubscription?.cancel());
    addDisposer(() => _searchTimer?.cancel());

    // Initialize performance monitoring (non-blocking)
    _performanceService.initialize();

    // Add listener after initialization to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isLTOMode) {
        _searchService.addListener(_onSearchStateChanged);
        // Add listener to search controller for immediate UI updates
        _searchController.addListener(() {
          _onSearchChanged(_searchController.text);
        });
        // Mark first frame as complete to enable transforms
        setState(() {
          _isFirstFrame = false;
        });
      }
    });

    // PERFORMANCE: Load menu items IMMEDIATELY (highest priority)
    // Don't wait for other services - they can initialize in parallel/background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isLTOMode) {
        _loadMenuItemsFromProvider();
      }
    });

    // PERFORMANCE: Initialize services in parallel (non-blocking)
    // These don't need to complete before showing menu items
    if (!_isLTOMode) {
      unawaited(_initializeSearchService());
      unawaited(_preloadFilterData()); // Background pre-load for filters

      // PERFORMANCE: Defer real-time services until after initial load
      // Initialize them in background after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          unawaited(_initializeRealTimeServices());
        }
      });
    }
  }

  @override
  void dispose() {
    _searchService.removeListener(_onSearchStateChanged);
    _scrollOffset.dispose(); // PERFORMANCE: Clean up ValueNotifier
    super.dispose();
  }

  Future<void> _initializeSearchService() async {
    try {
      await _searchService.initialize();
      if (kEnableMenuItemsDebug) {
        debugPrint(
            "🍽️ MenuItemsList: Search service initialized with ${_searchService.allRestaurants.length} restaurants");
      }

      // Don't set _isLoading here - let the main data loading handle it
    } on Exception catch (e) {
      debugPrint("❌ MenuItemsList: Error initializing search service: $e");
      // Don't set _isLoading here - let the main data loading handle it
    }
  }

  /// Initialize real-time services (Socket, FCM, Redis, Node.js)
  Future<void> _initializeRealTimeServices() async {
    try {
      // Initialize Realtime Service with Socket.io and Supabase
      await _realtimeService.initialize();

      // Subscribe to menu item updates
      final StreamSubscription menuSubscription = _realtimeService
          .menuItemUpdates
          .listen(_handleMenuItemRealTimeUpdate);

      // Initialize Socket Service
      await _socketService.initialize();
      _socketSubscription =
          _socketService.notificationStream.listen(_handleSocketNotification);

      // Initialize FCM Service
      await _fcmService.initialize();
      _fcmSubscription = _fcmService.messageStream.listen(_handleFCMMessage);

      // Add disposers for automatic cleanup
      addDisposer(menuSubscription.cancel);

      debugPrint("🚀 MenuItemsList: Real-time services initialized");
    } on Exception catch (e) {
      debugPrint("❌ Error initializing real-time services: $e");
    }
  }

  /// Handle socket notifications
  void _handleSocketNotification(Map<String, dynamic> data) {
    if (mounted) {
      setState(() {
        _liveNotifications.add(data);
        // Keep only last 10 notifications
        if (_liveNotifications.length > 10) {
          _liveNotifications.removeAt(0);
        }
      });

      // Handle specific notification types
      final type = data["type"] as String?;
      switch (type) {
        case "menu_item_updated":
          _handleMenuItemUpdate(data);
          break;
        case "new_menu_item":
          _handleNewMenuItem(data);
          break;
        case "menu_item_unavailable":
          _handleMenuItemUnavailable(data);
          break;
      }
    }
  }

  /// Handle FCM messages
  void _handleFCMMessage(Object message) {
    if (mounted) {
      debugPrint("📱 FCM Message received: $message");
      // Handle FCM notification
      _showLocalNotification(message);
    }
  }

  /// Handle menu item updates from real-time
  void _handleMenuItemUpdate(Map<String, dynamic> data) {
    final menuItemId = data["menu_item_id"] as String?;
    if (menuItemId != null && mounted) {
      // Find and update the menu item in the list
      final index = _items.indexWhere((item) => item.id == menuItemId);
      if (index != -1) {
        // Refresh the specific menu item
        _refreshMenuItem(menuItemId);
      }
    }
  }

  /// Handle new menu item from real-time
  void _handleNewMenuItem(Map<String, dynamic> data) {
    final restaurantId = data["restaurant_id"] as String?;
    if (restaurantId != null &&
        mounted &&
        _searchService.filteredResults.any((r) => r.id == restaurantId)) {
      // Refresh the list to include new menu item using provider
      _loadMenuItemsFromProvider();
    }
  }

  /// Handle menu item unavailable from real-time
  void _handleMenuItemUnavailable(Map<String, dynamic> data) {
    final menuItemId = data["menu_item_id"] as String?;
    if (menuItemId != null && mounted) {
      setState(() {
        _items.removeWhere((item) => item.id == menuItemId);
      });
    }
  }

  /// Handle menu item real-time updates from Socket.io and Supabase
  void _handleMenuItemRealTimeUpdate(Map<String, dynamic> data) {
    try {
      final action = data["action"] as String?;
      final itemData = data["data"] as Map<String, dynamic>?;

      if (action == null || itemData == null) {
        return;
      }

      final source = data["source"] as String? ?? "supabase";

      debugPrint(
          '🔄 Real-time menu item $action from $source: ${itemData['id']}');

      switch (action) {
        case "created":
          // Add new menu item
          if (mounted) {
            final newItem = MenuItem.fromJson(itemData);
            setState(() {
              _items.insert(0, newItem);
            });
          }
          break;

        case "updated":
          // Update existing menu item
          if (mounted) {
            final itemId = itemData["id"] as String?;
            if (itemId != null) {
              final index = _items.indexWhere((item) => item.id == itemId);
              if (index != -1) {
                setState(() {
                  _items[index] = MenuItem.fromJson(itemData);
                });
              }
            }
          }
          break;

        case "deleted":
          // Remove deleted menu item
          if (mounted) {
            final itemId = itemData["id"] as String?;
            if (itemId != null) {
              setState(() {
                _items.removeWhere((item) => item.id == itemId);
              });
            }
          }
          break;
      }
    } on Exception catch (e) {
      debugPrint("❌ Error handling real-time menu item update: $e");
    }
  }

  /// Refresh a specific menu item
  Future<void> _refreshMenuItem(String menuItemId) async {
    try {
      // Refresh using provider (will update state automatically)
      await ref.read(menuItemsProvider.notifier).refresh();
    } on Exception catch (e) {
      debugPrint("❌ Error refreshing menu item: $e");
    }
  }

  // Legacy cache method removed - using provider cache now

  /// Show local notification
  void _showLocalNotification(Object message) {
    // Implementation for showing local notifications
    debugPrint("🔔 Showing local notification: $message");
  }

  /// Clear all filters and search
  void _clearAllFilters() {
    setState(() {
      _searchService.clearFilters();
      _searchController.clear();
    });
    // Trigger search to update filtered results
    _searchService.search("");
    // Reload data with cleared filters using provider
    _loadMenuItemsFromProvider();
  }

  /// Load menu items using new provider architecture
  Future<void> _loadMenuItemsFromProvider() async {
    if (kEnableMenuItemsDebug) {
      debugPrint("🔄 MenuItemsList: Loading via provider...");
    }

    // Get current filters from search service
    final query = _searchController.text.trim().isEmpty
        ? null
        : _searchController.text.trim();
    final categories = _searchService.selectedCategories.isEmpty
        ? null
        : _searchService.selectedCategories.toSet();
    final cuisines = _searchService.selectedCuisines.isEmpty
        ? null
        : _searchService.selectedCuisines.toSet();
    final priceRange =
        _searchService.priceRange; // Already Flutter's RangeValues

    await ref.read(menuItemsProvider.notifier).loadInitial(
          query: query,
          categories: categories,
          cuisines: cuisines,
          priceRange: priceRange,
        );
  }

  /// Load LTO items for LTO mode
  Future<void> _loadLTOItems() async {
    if (!mounted) return;

    setState(() {
      _isLoadingLTO = true;
    });

    try {
      final items = await LTOModeHelper.loadLTOItems();

      if (mounted) {
        setState(() {
          _ltoItems = items;
          _isLoadingLTO = false;
          _hasCompletedInitialLoad = true;
          _isFirstFrame = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Error loading LTO items: $e");
      if (mounted) {
        setState(() {
          _isLoadingLTO = false;
          _hasCompletedInitialLoad = true;
          _isFirstFrame = false;
        });
      }
    }
  }

  void _onSearchStateChanged() {
    if (kEnableMenuItemsDebug) {
      debugPrint(
          "🍽️ MenuItemsList: Search state changed. Filtering: ${_searchService.isFiltering}, Results: ${_searchService.filteredResults.length}");
    }

    if (mounted) {
      // Reload with new filters using provider
      _loadMenuItemsFromProvider();
    }
  }

  void _onSearchChanged(String query) {
    if (kEnableMenuItemsDebug) {
      debugPrint("🔍 MenuItemsList: Search changed to: \"$query\"");
      debugPrint(
          "🔍 MenuItemsList: Total items before filtering: ${_items.length}");
    }

    // Cancel previous timer
    _searchTimer?.cancel();

    if (query.trim().isEmpty) {
      // Clear search immediately
      _performSearch("");
      return;
    }

    // Trigger immediate UI update for search query changes
    if (mounted) {
      // Invalidate cache to trigger rebuild with new search
      _invalidateFilterCache();

      if (kEnableMenuItemsDebug) {
        debugPrint(
            "🔍 MenuItemsList: Triggering rebuild for search query: '$query'");
      }
    }

    // Debounce search with simple timer
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (mounted) {
      if (kEnableMenuItemsDebug) {
        debugPrint("🔍 MenuItemsList: Performing smart search for: \"$query\"");

        // Use smart text detection for better search results
        final normalizedQuery = SmartTextDetector.normalizeText(query);
        final searchVariations =
            SmartTextDetector.generateSearchVariations(query);

        debugPrint("🔍 MenuItemsList: Normalized query: \"$normalizedQuery\"");
        debugPrint("🔍 MenuItemsList: Search variations: $searchVariations");
      }

      await _searchService.search(query);

      if (kEnableMenuItemsDebug) {
        debugPrint(
            "🔍 MenuItemsList: Smart search completed. Results: ${_searchService.filteredResults.length}");
      }
    }
  }

  // Pre-load filter data for instant popup loading (non-blocking background task)
  Future<void> _preloadFilterData() async {
    try {
      // Set default values immediately so UI doesn't wait
      _cachedPriceRange = {"min": 0.0, "max": 1000.0};

      // Load filter data in parallel in background (non-blocking)
      // Use timeout to prevent blocking if query is slow
      final futures = await Future.wait([
        _getPriceRangeFromDatabase().timeout(
          const Duration(seconds: 3),
          onTimeout: () => {"min": 0.0, "max": 1000.0},
        ),
        _getDeliveryFeeRangeFromDatabase().timeout(
          const Duration(seconds: 3),
          onTimeout: () => {"min": 0.0, "max": 100.0},
        ),
      ]).timeout(
        const Duration(seconds: 5),
        onTimeout: () => [
          {"min": 0.0, "max": 1000.0},
          {"min": 0.0, "max": 100.0},
        ],
      );

      // Update cache with fetched values
      _cachedPriceRange = futures[0];

      debugPrint("✅ Filter data pre-loaded successfully");
    } on Exception catch (e) {
      debugPrint("❌ Error pre-loading filter data: $e");
      // Default values already set above, so UI continues to work
    }
  }

  // Legacy loading methods removed - using provider now

  // Legacy delivery fee pre-calculation removed - not needed with provider

  // Legacy cache clearing simplified - provider manages its own cache

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final scrollPosition = _scrollController.position.pixels;
    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    final providerState = ref.read(menuItemsProvider);

    // Trigger loading when user is within 200px of the bottom
    if (scrollPosition >= maxScrollExtent - 200) {
      if (!providerState.isLoadingMore &&
          providerState.hasMore &&
          !providerState.isLoading &&
          mounted) {
        ref.read(menuItemsProvider.notifier).loadMore();
      }
    }
  }

  // _loadMore() removed - now using provider's loadMore() via _onScroll()

  /// PERFORMANCE: Compute unique signature for current filter state
  String _computeFilterSignature() {
    final searchQuery = _searchController.text.trim();
    final filteredRestaurants = _searchService.filteredResults;

    return '${searchQuery}_'
        '${filteredRestaurants.length}_'
        '${_searchService.minRating ?? ""}_'
        '${_searchService.priceRange?.start ?? ""}_${_searchService.priceRange?.end ?? ""}_'
        '${_searchService.selectedCuisines.join(",")}_'
        '${_searchService.selectedCategories.join(",")}_'
        '${_searchService.isOpen ?? ""}_'
        '${_items.length}';
  }

  /// PERFORMANCE: Invalidate filter cache when data changes
  void _invalidateFilterCache() {
    _cachedFilteredItems = null;
    _lastFilterSignature = null;
  }

  /// PERFORMANCE: Cached getter for displayed menu items
  /// Only recomputes when filters or data actually change
  List<MenuItem> get _displayedMenuItems {
    // In LTO mode, return filtered LTO items
    if (_isLTOMode) {
      return LTOModeHelper.filterLTOItems(_ltoItems, _searchController.text);
    }

    // Check if cached result is still valid
    final currentSignature = _computeFilterSignature();
    if (_cachedFilteredItems != null &&
        _lastFilterSignature == currentSignature) {
      if (kEnableMenuItemsDebug) {
        debugPrint(
            "⚡ Using cached filtered items: ${_cachedFilteredItems!.length}");
      }
      return _cachedFilteredItems!;
    }

    // Compute new result (debug only in debug mode)
    if (kEnableMenuItemsDebug) {
      debugPrint("🔍 Computing filtered items. Total: ${_items.length}");
    }

    final result = _computeFilteredItems();

    // Cache for next access
    _cachedFilteredItems = result;
    _lastFilterSignature = currentSignature;

    return result;
  }

  /// PERFORMANCE: Separated filtering logic (no debug prints in hot path)
  List<MenuItem> _computeFilteredItems() {
    // Start with all menu items and filter out drinks
    List<MenuItem> filteredItems = _items
        .where((item) =>
            !item.category.toLowerCase().contains("drink") &&
            item.category.toLowerCase() != "drinks" &&
            item.category.toLowerCase() != "beverage" &&
            item.category.toLowerCase() != "beverages")
        .toList();

    // Apply search query filter first
    final searchQuery = _searchController.text.trim();
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filteredItems = filteredItems.where((item) {
        final matchesName = item.name.toLowerCase().contains(query);
        final matchesDescription =
            item.description.toLowerCase().contains(query);
        final matchesCategory = item.category.toLowerCase().contains(query);
        return matchesName || matchesDescription || matchesCategory;
      }).toList();
    }

    // Apply restaurant-based filtering if search service has filtered restaurants
    final filteredRestaurants = _searchService.filteredResults;
    if (filteredRestaurants.isNotEmpty) {
      final restaurantIds = filteredRestaurants.map((r) => r.id).toSet();
      filteredItems = filteredItems
          .where((item) => restaurantIds.contains(item.restaurantId))
          .toList();
    }

    // Apply direct menu item filters from search service
    if (_searchService.minRating != null) {
      filteredItems = filteredItems
          .where((item) => item.rating >= _searchService.minRating!)
          .toList();
    }

    // Apply availability filter
    if (_searchService.isOpen == true) {
      filteredItems = filteredItems.where((item) => item.isAvailable).toList();
    }

    // Apply price range filter
    if (_searchService.priceRange != null) {
      final start = _searchService.priceRange!.start;
      final end = _searchService.priceRange!.end;
      filteredItems = filteredItems
          .where((item) => item.price >= start && item.price <= end)
          .toList();
    }

    // Apply cuisine type filter
    if (_searchService.selectedCuisines.isNotEmpty) {
      final targetCuisines = _searchService.selectedCuisines
          .map((e) => e.toLowerCase().trim())
          .toSet();
      filteredItems = filteredItems.where((item) {
        final cuisineName = (item.cuisineType?.name ?? "").toLowerCase().trim();
        return targetCuisines.contains(cuisineName);
      }).toList();
    }

    // Apply category filter
    if (_searchService.selectedCategories.isNotEmpty) {
      final targetCategories = _searchService.selectedCategories
          .map((e) => e.toLowerCase().trim())
          .toSet();
      filteredItems = filteredItems.where((item) {
        final categoryName = item.category.toLowerCase().trim();
        return targetCategories.contains(categoryName);
      }).toList();
    }

    // Filter out LTO items (both active and expired - they're displayed in LTO sections on home/restaurant screens or should be hidden)
    filteredItems = filteredItems
        .where((item) => !item.isOfferActive && !item.hasExpiredLTOOffer)
        .toList();

    // Expand items with variants into separate cards (with caching)
    final expandedItems = _expandMenuItemsWithVariants(filteredItems);

    return expandedItems;
  }

  // Legacy smart sorting removed - provider handles server-side sorting

  Future<Map<String, double>> _getPriceRangeFromDatabase() async {
    try {
      final supabase = supa.Supabase.instance.client;

      // FIX: Use boolean true instead of string "true" for is_available
      // Get min and max prices from menu_items table efficiently
      final response = await supabase
          .from("menu_items")
          .select("price")
          .eq("is_available", true) // Use boolean, not string
          .order("price", ascending: true)
          .limit(1000); // Limit for performance

      if (response.isEmpty) {
        return {"min": 0.0, "max": 1000.0};
      }

      final prices = response
          .map((item) => (item["price"] as num?)?.toDouble() ?? 0.0)
          .where((price) => price > 0) // Filter out invalid prices
          .toList();

      if (prices.isEmpty) {
        return {"min": 0.0, "max": 1000.0};
      }

      final minPrice = prices.first;
      final maxPrice = prices.last;

      return {
        "min": minPrice,
        "max": maxPrice,
      };
    } on Exception catch (e) {
      debugPrint("Error getting price range from database: $e");
      return {"min": 0.0, "max": 1000.0};
    }
  }

  Future<Map<String, double>> _getDeliveryFeeRangeFromDatabase() async {
    try {
      final supabase = supa.Supabase.instance.client;

      // FIX: Remove is_available filter - column doesn't exist in restaurants table
      // Use limit to get min/max efficiently without filtering
      final response = await supabase
          .from("restaurants")
          .select("delivery_fee")
          .order("delivery_fee", ascending: true)
          .limit(1000); // Get enough records to find min/max

      if (response.isEmpty) {
        return {"min": 0.0, "max": 100.0};
      }

      final fees = response
          .map((item) => (item["delivery_fee"] as num?)?.toDouble() ?? 0.0)
          .where((fee) => fee > 0) // Filter out invalid fees
          .toList();

      if (fees.isEmpty) {
        return {"min": 0.0, "max": 100.0};
      }

      final minFee = fees.first;
      final maxFee = fees.last;

      return {
        "min": minFee,
        "max": maxFee,
      };
    } on Exception catch (e) {
      debugPrint("Error getting delivery fee range from database: $e");
      return {"min": 0.0, "max": 100.0};
    }
  }

  // Legacy _load() method removed - using provider now

  void _openLocationPicker() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MapLocationPickerScreen(
          onLocationSelected: (locationData) {
            // Use setLocationFilterWithCoordinates for distance-based filtering
            _searchService.setLocationFilterWithCoordinates(
              locationData.formattedAddress ?? locationData.displayAddress,
              locationData.latitude,
              locationData.longitude,
            );

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      "Location set to: ${locationData.formattedAddress ?? locationData.displayAddress}"),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
            _loadMenuItemsFromProvider();
          },
        ),
      ),
    );
  }

  Future<void> _openCuisineSelector() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CuisineSelectorModal(searchService: _searchService),
    );
    // Reload data with new filter using provider
    unawaited(_loadMenuItemsFromProvider());
  }

  Future<void> _openCategorySelector() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          CategorySelectorModal(searchService: _searchService),
    );
    // Reload data with new filter using provider
    unawaited(_loadMenuItemsFromProvider());
  }

  Future<void> _openPriceSelector() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PriceSelectorModal(
        searchService: _searchService,
        cachedPriceRange: _cachedPriceRange,
      ),
    );
    // Reload data with new filter using provider
    unawaited(_loadMenuItemsFromProvider());
  }

  /// Handle category toggle from SimpleCategoryFilter
  void _handleCategoryToggle(String category) {
    setState(() {
      final isAllCategory = category.toLowerCase() == "all" ||
          category.toLowerCase() == "all categories" ||
          category.toLowerCase() == "جميع الفئات" ||
          category == "All" ||
          category == "All Categories" ||
          category == "جميع الفئات" ||
          category == "الكل";

      if (isAllCategory) {
        _searchService.selectedCategories.clear();
      } else {
        // For Special Packs and other categories
        if (_searchService.selectedCategories.contains(category)) {
          _searchService.selectedCategories.remove(category);
        } else {
          _searchService.selectedCategories.add(category);
        }
      }
    });
    _searchService.search(_searchController.text);
    _loadMenuItemsFromProvider();
  }

  /// Handle delivery fee toggle from FilterChipsSection
  void _handleDeliveryFeeToggle({bool isActive = false}) {
    setState(() {
      if (isActive) {
        _searchService.setDeliveryFeeRangeFilter(null);
      } else {
        _searchService.setDeliveryFeeRangeFilter(const RangeValues(0, 0));
      }
    });
    _searchService.search(_searchController.text);
    _loadMenuItemsFromProvider();
  }

  /// Build empty state widget for when no menu items are found
  Widget _buildEmptyState() {
    final hasActiveFilters = _searchService.hasActiveFilters;
    final searchQuery = _searchController.text.trim();
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Empty state icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.restaurant_menu_outlined,
                size: 60,
                color: Colors.grey[400],
              ),
            ),

            const SizedBox(height: 24),

            // Title with RTL support
            Text(
              _getEmptyStateTitle(hasActiveFilters, searchQuery),
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
            ),

            const SizedBox(height: 12),

            // Description with proper text wrapping and RTL support
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                _getEmptyStateDescription(hasActiveFilters, searchQuery),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[500],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                softWrap: true,
                overflow: TextOverflow.visible,
              ),
            ),

            const SizedBox(height: 32),

            // Action buttons
            if (hasActiveFilters || searchQuery.isNotEmpty) ...[
              // Clear filters button
              ElevatedButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.clear_all, size: 18),
                label: Text(AppLocalizations.of(context)!.clearFilters),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],

            // Browse all button
            OutlinedButton.icon(
              onPressed: () {
                _clearAllFilters();
                _searchController.clear();
              },
              icon: const Icon(Icons.explore, size: 18),
              label: Text(AppLocalizations.of(context)!.browseAllItems),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange[600],
                side: BorderSide(color: Colors.orange[600]!),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get appropriate title for empty state
  String _getEmptyStateTitle(bool hasActiveFilters, String searchQuery) {
    final l10n = AppLocalizations.of(context)!;
    if (searchQuery.isNotEmpty) {
      return l10n.noItemsFoundForSearch(searchQuery);
    } else if (hasActiveFilters) {
      return l10n.noItemsMatchFilters;
    } else {
      return l10n.noMenuItemsAvailable;
    }
  }

  /// Get appropriate description for empty state
  String _getEmptyStateDescription(bool hasActiveFilters, String searchQuery) {
    final l10n = AppLocalizations.of(context)!;
    if (searchQuery.isNotEmpty) {
      return l10n.tryAdjustingSearchTerms;
    } else if (hasActiveFilters) {
      return l10n.tryRemovingFilters;
    } else {
      return l10n.checkBackLaterForNewItems;
    }
  }

  /// Calculate fixed item extent for ListView.builder
  /// This enables Flutter to skip expensive layout measurements
  double _calculateItemExtent(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth - 40; // 20px padding on each side
    final contentHeight = cardWidth * 0.3; // 30% of card width
    const padding = 12.0 * 2; // Top and bottom padding
    const headerHeight = 40.0; // Restaurant name + delivery fee
    const verticalMargin = 12.0 * 2; // Vertical margin from Padding widget

    return contentHeight + padding + headerHeight + verticalMargin;
  }

  /// Build horizontal menu item card using optimized widget
  ///
  /// Extracted into MenuItemCard for better performance with 1000+ items
  Widget _buildMenuItemCard(MenuItem menuItem) {
    // In LTO mode, use LTOListCard instead
    if (_isLTOMode) {
      return LTOListCard(
        key: ValueKey(menuItem.id), // Efficient key for list performance
        menuItem: menuItem,
        onCacheCleared: () {
          // Clear variant cache and filter cache
          _variantExpansionCache.clear();
          _invalidateFilterCache();
          MenuItemSortingService.clearCache();
        },
        onDataChanged: () => _loadLTOItems(),
      );
    }

    return MenuItemCard(
      key: ValueKey(menuItem.id), // Efficient key for list performance
      menuItem: menuItem,
      onCacheCleared: () {
        // Clear variant cache and filter cache
        _variantExpansionCache.clear();
        _invalidateFilterCache();
        MenuItemSortingService.clearCache();
      },
      onDataChanged: () => _loadMenuItemsFromProvider(),
    );
  }

  /// PERFORMANCE: Expand menu items with variants into separate cards (cached)
  List<MenuItem> _expandMenuItemsWithVariants(List<MenuItem> items) {
    // Create cache key from item IDs
    final cacheKey = items.map((i) => i.id).join('_');

    // Return cached if available
    final cached = _variantExpansionCache.get(cacheKey);
    if (cached != null) {
      if (kEnableMenuItemsDebug) {
        debugPrint("⚡ Using cached variant expansion: ${cached.length} items");
      }
      return cached;
    }

    // Compute expansion
    final expandedItems = <MenuItem>[];

    for (final item in items) {
      // Check if item is a special pack
      if (SpecialPackHelper.isSpecialPack(item)) {
        // Special packs: Show as single card with formatted name
        final packItem = SpecialPackHelper.processForDisplay(item);
        expandedItems.add(packItem);

        if (kEnableMenuItemsDebug) {
          debugPrint('🎁 Special pack: ${packItem.name}');
        }
      } else if (item.variants.isNotEmpty) {
        // Regular items with variants: Create a separate card for each variant
        int variantIndex = 0;
        for (final variantJson in item.variants) {
          try {
            final variantName = variantJson['name'] as String? ?? '';
            final variantId = variantJson['id'] as String? ?? '';

            // Find pricing for this variant if it exists
            double? variantPrice;
            if (item.pricingOptions.isNotEmpty) {
              for (final pricingJson in item.pricingOptions) {
                if (pricingJson['variant_id'] == variantId) {
                  final priceValue = pricingJson['price'];
                  if (priceValue != null) {
                    variantPrice = (priceValue is int)
                        ? priceValue.toDouble()
                        : (priceValue as num).toDouble();
                    break;
                  }
                }
              }
            }

            // Format variant ID to match PopupHelper's expected format
            final variantNameForId = variantName.replaceAll(' ', '_');
            final variantCardId =
                '${item.id}_variant_${variantIndex}_$variantNameForId';

            // Create a modified menu item for this variant
            final variantItem = item.copyWith(
              id: variantCardId,
              name: variantName.isNotEmpty
                  ? '${item.name} $variantName'
                  : item.name,
              price: variantPrice ?? item.price,
              variants: [], // Clear variants array for proper review name extraction
            );

            expandedItems.add(variantItem);
            variantIndex++;
          } catch (e) {
            if (kEnableMenuItemsDebug) {
              debugPrint('❌ Error expanding variant: $e');
            }
            // If variant parsing fails, add original item
            expandedItems.add(item);
          }
        }
      } else {
        // No variants, add original item
        expandedItems.add(item);
      }
    }

    // Cache result
    _variantExpansionCache.put(cacheKey, expandedItems);

    if (kEnableMenuItemsDebug) {
      debugPrint(
          "🔍 Expanded ${items.length} items to ${expandedItems.length} cards (cached)");
    }

    return expandedItems;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // In LTO mode, use local state
    if (_isLTOMode) {
      return _buildLTOMode(context);
    }

    // Use provider state instead of local state
    final providerState = ref.watch(menuItemsProvider);

    // Sync local state with provider state for filtering logic
    _items = providerState.items;
    _isLoadingMore = providerState.isLoadingMore;

    // Mark initial load as completed when provider finishes loading
    // (with items, error, or empty result - all are valid completion states)
    final isInitialLoadComplete = !providerState.isLoading &&
        (providerState.items.isNotEmpty ||
            providerState.error != null ||
            providerState.lastRefresh != null);

    if (isInitialLoadComplete && !_hasCompletedInitialLoad) {
      _hasCompletedInitialLoad = true;
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final contentStartHeight =
        screenHeight * 0.20; // Where white content starts (25%)
    final imageHeight =
        screenHeight * 0.30; // Image extends 5% more for overlap (30%)

    // Responsive spacing for fixed sections (simple category filter + filter chips)
    // Simple category filter: ~48px, Filter chips: ~48px = ~96px total
    final fixedSectionsSpacing = (screenHeight * 0.085).clamp(96.0, 106.0);

    // Calculate search bar position with additional padding for Android devices
    final statusBarHeight = MediaQuery.of(context).padding.top;
    // Responsive padding for Android: 8-10px based on device height
    final additionalTopPadding = statusBarHeight < 30
        ? (screenHeight * 0.012).clamp(8.0, 10.0) // Android: responsive 8-10px
        : 0.0; // iOS: no extra padding needed
    final searchBarTop = statusBarHeight + additionalTopPadding;

    // Calculate search bar height for scroll stop logic
    // Search bar position + search row height (~43.2px after 10% reduction)
    final searchBarHeight = searchBarTop + 43.2;

    // Add proper bottom padding as safe area between search bar and container's stop point
    final safeAreaPadding =
        screenHeight * 0.01; // 1% of screen height as buffer

    // Calculate maximum scroll offset - stop point with safe area padding
    final maxScrollOffset =
        contentStartHeight - searchBarHeight - safeAreaPadding;

    // Extend bottom to prevent orange gap
    final bottomExtension = -(maxScrollOffset + screenHeight * 0.3);

    return Scaffold(
      backgroundColor: Colors.orange[600],
      resizeToAvoidBottomInset: false, // Prevent resizing when keyboard appears
      body: Stack(
        children: [
          // Background image layer - IgnorePointer allows touch events through
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: imageHeight, // 30% to create overlap with white container
            child: IgnorePointer(
              child: Image.asset(
                'assets/main_menu.png',
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),

          // Scrollable white container - fills entire screen for touch events
          Positioned.fill(
            top: 0,
            bottom: bottomExtension,
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollNotification) {
                if (scrollNotification.metrics.axis == Axis.vertical) {
                  final offset = scrollNotification.metrics.pixels;
                  // PERFORMANCE: Use ValueNotifier instead of setState
                  // Avoids rebuilding entire widget tree on every scroll frame
                  _scrollOffset.value = offset.clamp(0.0, maxScrollOffset);
                }
                return false;
              },
              child: ValueListenableBuilder<double>(
                valueListenable: _scrollOffset,
                builder: (context, scrollOffset, child) {
                  return Transform.translate(
                    // Combined transform: Initial position - scroll offset
                    // Skip transform on first frame to prevent layout conflicts
                    offset: _isFirstFrame
                        ? Offset(0, contentStartHeight)
                        : Offset(0, contentStartHeight - scrollOffset),
                    child: child,
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        // Scrollable menu items content with two-phase compensation
                        MenuItemsListContent(
                          scrollOffset: _scrollOffset,
                          isFirstFrame: _isFirstFrame,
                          maxScrollOffset: maxScrollOffset,
                          scrollController: _scrollController,
                          fixedSectionsSpacing: _isLTOMode ? 0.0 : fixedSectionsSpacing,
                          isLoading: _isLTOMode ? _isLoadingLTO : providerState.isLoading,
                          hasCompletedInitialLoad: _hasCompletedInitialLoad,
                          displayedMenuItems: _displayedMenuItems,
                          isLoadingMore: _isLTOMode ? false : _isLoadingMore,
                          onBuildMenuItemCard: _buildMenuItemCard,
                          onCalculateItemExtent: _calculateItemExtent,
                          emptyStateWidget: _buildEmptyState(),
                        ),

                        // Fixed sections wrapped to prevent scroll gap - hide in LTO mode
                        if (!_isLTOMode)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: MenuItemsFixedSection(
                              searchService: _searchService,
                              selectedCategories:
                                  _searchService.selectedCategories.toSet(),
                              onCategoryToggle: _handleCategoryToggle,
                              onLocationTap: _openLocationPicker,
                              onCuisineTap: _openCuisineSelector,
                              onCategoryTap: _openCategorySelector,
                              onPriceTap: _openPriceSelector,
                              onClearAllTap: _clearAllFilters,
                              onDeliveryFeeToggle: _handleDeliveryFeeToggle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Fixed search bar - hide in LTO mode
          if (!_isLTOMode)
            Positioned(
              top: searchBarTop,
              left: 14,
              right: 14,
              child: Row(
                children: [
                  // Simple white back icon
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  // Search bar (no floating style)
                  Expanded(
                    child: SizedBox(
                      height: 43.2, // Explicit height constraint (48 × 0.9)
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 14), // Reduced font size
                        decoration: InputDecoration(
                          hintText: S.of(context)?.searchMenuItems ??
                              'Search menu items...',
                          hintStyle:
                              const TextStyle(fontSize: 14), // Reduced hint size
                          prefixIcon: const Icon(Icons.search,
                              color: Colors.grey, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 0, horizontal: 16),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true, // Reduces default height
                        ),
                        onChanged: (value) {
                          _searchService.search(value);
                          // Search is debounced in _onSearchChanged
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Back button for LTO mode (no search bar)
          if (_isLTOMode)
            Positioned(
              top: searchBarTop,
              left: 14,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
        ],
      ),
    );
  }

  /// Build LTO mode UI - simplified version without search bar and filters
  Widget _buildLTOMode(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final contentStartHeight = screenHeight * 0.20;
    final imageHeight = screenHeight * 0.30;

    // Calculate search bar position
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final additionalTopPadding = statusBarHeight < 30
        ? (screenHeight * 0.012).clamp(8.0, 10.0)
        : 0.0;
    final searchBarTop = statusBarHeight + additionalTopPadding;
    final searchBarHeight = searchBarTop + 43.2;
    final safeAreaPadding = screenHeight * 0.01;
    final maxScrollOffset = contentStartHeight - searchBarHeight - safeAreaPadding;
    final bottomExtension = -(maxScrollOffset + screenHeight * 0.3);

    return Scaffold(
      backgroundColor: const Color(0xFFECA11F),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Background image layer
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: imageHeight,
            child: IgnorePointer(
              child: Image.asset(
                'assets/main_menu.png',
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),

          // Scrollable content - no container in LTO mode
          Positioned.fill(
            top: 0,
            bottom: bottomExtension,
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollNotification) {
                if (scrollNotification.metrics.axis == Axis.vertical) {
                  final offset = scrollNotification.metrics.pixels;
                  _scrollOffset.value = offset.clamp(0.0, maxScrollOffset);
                }
                return false;
              },
              child: ValueListenableBuilder<double>(
                valueListenable: _scrollOffset,
                builder: (context, scrollOffset, child) {
                  return Transform.translate(
                    offset: _isFirstFrame
                        ? Offset(0, contentStartHeight)
                        : Offset(0, contentStartHeight - scrollOffset),
                    child: child,
                  );
                },
                child: MenuItemsListContent(
                  scrollOffset: _scrollOffset,
                  isFirstFrame: _isFirstFrame,
                  maxScrollOffset: maxScrollOffset,
                  scrollController: _scrollController,
                  fixedSectionsSpacing: 0.0,
                  isLoading: _isLoadingLTO,
                  hasCompletedInitialLoad: _hasCompletedInitialLoad,
                  displayedMenuItems: _displayedMenuItems,
                  isLoadingMore: false,
                  onBuildMenuItemCard: _buildMenuItemCard,
                  onCalculateItemExtent: _calculateItemExtent,
                  emptyStateWidget: _buildEmptyState(),
                ),
              ),
            ),
          ),

          // Back button for LTO mode
          Positioned(
            top: searchBarTop,
            left: 14,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }
}
