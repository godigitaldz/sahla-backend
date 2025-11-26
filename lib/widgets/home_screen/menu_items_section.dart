import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:provider/provider.dart";
import "package:shimmer/shimmer.dart";

import "../../l10n/app_localizations.dart";
import "../../models/menu_item.dart";
import "../../models/restaurant_search_filter.dart";
import "../../screens/menu_items_list_screen.dart";
import "../../services/home/home_cache_service.dart";
import "../../services/menu_item_delta_update_service.dart";
import "../../services/menu_item_display_service.dart";
import "../../services/menu_item_variant_service.dart";
import "../../services/predictive_preloading_service.dart";
import "../../services/socket_service.dart";
import "../../services/startup_data_service.dart";
import "../../utils/responsive_sizing.dart";
import "../menu_item_full_popup/helpers/popup_helper.dart";
import "best_choices_section/cached_menu_item_dimensions.dart";
import "best_choices_section/menu_item_section_card.dart";

// Widget for displaying a row of menu items grouped by category
class MenuItemsRow extends StatefulWidget {
  final String categoryId;
  final List<MenuItem> items;
  final VoidCallback? onViewAll;
  final VoidCallback? onDataChanged;
  final CachedMenuItemDimensions?
      dimensions; // PERFORMANCE: Accept cached dimensions!

  const MenuItemsRow({
    required this.categoryId,
    required this.items,
    super.key,
    this.onViewAll,
    this.onDataChanged,
    this.dimensions,
  });

  @override
  State<MenuItemsRow> createState() => _MenuItemsRowState();
}

class _MenuItemsRowState extends State<MenuItemsRow> {
  // Real-time services
  late SocketService _socketService;

  // Real-time state - use ValueNotifiers to avoid full rebuilds
  final Map<String, ValueNotifier<bool>> _itemAvailabilityNotifiers = {};
  final Map<String, ValueNotifier<double>> _dynamicPriceNotifiers = {};

  // Subscriptions
  StreamSubscription? _menuUpdatesSubscription;
  StreamSubscription? _priceUpdatesSubscription;

  // Performance: Cache MediaQuery dimensions
  late Size _screenSize;
  late double _cardWidth;
  late double _cardHeight;
  late bool _isRTL;

  // Performance: Cache text styles
  late TextStyle _viewAllTextStyle;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Performance: Cache MediaQuery lookups once
    _screenSize = MediaQuery.of(context).size;
    const double horizontalPadding = 32.0;
    const double cardSpacing = 8.0;
    final availableWidth =
        _screenSize.width - horizontalPadding - (cardSpacing * 2);
    _cardWidth = availableWidth / 3.0;
    // Use responsive height calculation from dimensions (not fixed aspect ratio)
    // This will be calculated based on actual content
    final dimensions = widget.dimensions ??
        CachedMenuItemDimensions.fromScreenWidth(_screenSize.width);
    _cardHeight = dimensions.cardHeight;
    _isRTL = Localizations.localeOf(context).languageCode == 'ar';

    // Cache text styles
    _viewAllTextStyle = GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.black,
    );
  }

  void _initializeServices() {
    try {
      // Initialize Socket.io service
      _socketService = Provider.of<SocketService>(context, listen: false);

      // Set up real-time listeners
      _setupRealTimeListeners();

      // Performance: Initialize ValueNotifiers for real-time updates
      for (final item in widget.items) {
        _itemAvailabilityNotifiers[item.id] = ValueNotifier(item.isAvailable);
        _dynamicPriceNotifiers[item.id] = ValueNotifier(item.price);
      }
    } on Exception catch (e) {
      debugPrint("❌ Error initializing menu items services: $e");
    }
  }

  void _setupRealTimeListeners() {
    // Listen for menu item updates
    _menuUpdatesSubscription = _socketService.orderUpdatesStream.listen((data) {
      if (data["type"] == "menu_update") {
        _handleMenuUpdate(data);
      }
    });

    // Listen for price updates
    _priceUpdatesSubscription =
        _socketService.notificationStream.listen((data) {
      if (data["type"] == "price_update") {
        _handlePriceUpdate(data);
      }
    });
  }

  void _handleMenuUpdate(Map<String, dynamic> data) {
    final itemId = data["itemId"] as String?;
    final isAvailable = data["isAvailable"] as bool?;

    if (itemId != null &&
        isAvailable != null &&
        _itemAvailabilityNotifiers.containsKey(itemId)) {
      // Performance: Update ValueNotifier directly, no setState needed
      _itemAvailabilityNotifiers[itemId]?.value = isAvailable;
    }
  }

  void _handlePriceUpdate(Map<String, dynamic> data) {
    final itemId = data["itemId"] as String?;
    final newPrice = data["price"]?.toDouble();

    if (itemId != null &&
        newPrice != null &&
        _dynamicPriceNotifiers.containsKey(itemId)) {
      // Performance: Update ValueNotifier directly, no setState needed
      _dynamicPriceNotifiers[itemId]?.value = newPrice;
    }
  }

  @override
  void dispose() {
    _menuUpdatesSubscription?.cancel();
    _priceUpdatesSubscription?.cancel();

    // Performance: Dispose all ValueNotifiers
    for (final notifier in _itemAvailabilityNotifiers.values) {
      notifier.dispose();
    }
    for (final notifier in _dynamicPriceNotifiers.values) {
      notifier.dispose();
    }

    super.dispose();
  }

  // Performance: Removed _createEnhancedMenuItem to avoid per-frame allocations
  // Now passing ValueNotifiers directly to cards

  void _navigateToMenuItemDetails(MenuItem menuItem) {
    // Show the new full-width popup instead of navigating to details screen
    PopupHelper.showMenuItemPopup(
      context: context,
      menuItem: menuItem,
      // Restaurant information will be displayed from menuItem.restaurantName
      onItemAddedToCart: (orderItem) {
        // Show confirmation when item is added to cart
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "${orderItem.menuItem?.name ?? "Item"} added to cart",
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green[600],
            ),
          );
        }
      },
      onDataChanged: () {
        // Refresh the menu items when review is submitted
        if (mounted) {
          // Notify parent to reload data
          widget.onDataChanged?.call();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink(); // Don't show empty rows
    }

    // Return the list directly without Column wrapper to avoid extra spacing
    return _buildItemsList();
  }

  Widget _buildItemsList() {
    // Performance: Use cached dimensions
    final int totalItems = widget.items.length;
    final int visibleCount =
        totalItems > 10 ? 10 : totalItems; // show only top 10
    final bool showViewAllCard = totalItems > 10 && widget.onViewAll != null;
    final int itemCount = visibleCount + (showViewAllCard ? 1 : 0);

    const double cardSpacing = 8.0;

    return SizedBox(
      height: _cardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        // PERFORMANCE FIX: Set physics for nested horizontal scroll
        physics: const AlwaysScrollableScrollPhysics(),
        // PERFORMANCE FIX: Disable primary to prevent scroll conflicts
        primary: false,
        padding: const EdgeInsets.only(left: 16),
        clipBehavior: Clip.none,
        itemCount: itemCount,
        // Performance: Add itemExtent for O(1) layout
        itemExtent: _cardWidth + cardSpacing,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        // PERFORMANCE FIX: Optimize cache extent - cache only 3 viewport widths (visible + prefetch)
        cacheExtent: (_cardWidth + cardSpacing) * 3,
        itemBuilder: (context, index) {
          final bool isViewAll = showViewAllCard && index == itemCount - 1;
          if (isViewAll) {
            return _buildViewAllCard();
          }

          final menuItem = widget.items[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: RepaintBoundary(
              child: Builder(
                builder: (context) {
                  // PERFORMANCE: Use optimized card with cached dimensions
                  // Create dimensions from MediaQuery if not provided
                  final dimensions = widget.dimensions ??
                      CachedMenuItemDimensions.fromScreenWidth(
                        MediaQuery.of(context).size.width,
                      );
                  return MenuItemSectionCard(
                    key: ValueKey(menuItem.id),
                    menuItem: menuItem,
                    onTap: () => _navigateToMenuItemDetails(menuItem),
                    dimensions: dimensions,
                    variantName: null,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildViewAllCard() {
    // Performance: Use cached values
    final arrowIcon =
        _isRTL ? Icons.keyboard_arrow_left : Icons.keyboard_arrow_right;

    return Align(
      alignment: Alignment.center,
      child: Container(
        width: _screenSize.width * 0.25,
        margin: const EdgeInsets.only(right: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onViewAll,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                textDirection: _isRTL ? TextDirection.rtl : TextDirection.ltr,
                children: [
                  // View All text
                  Text(
                    AppLocalizations.of(context)?.viewAllLabel ??
                        (_isRTL ? "عرض الكل" : "View All"),
                    style: _viewAllTextStyle,
                    textDirection:
                        _isRTL ? TextDirection.rtl : TextDirection.ltr,
                  ),
                  const SizedBox(width: 4),
                  // Arrow icon with border
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black,
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      arrowIcon,
                      size: 12,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MenuItemsSection extends StatefulWidget {
  final String title;
  final bool showFeatured;
  final String? category;
  final VoidCallback? onViewAll;
  final Set<String>? selectedCategories;
  final Set<String>? selectedCuisines;
  final String? searchQuery;
  final Set<String>? allowedRestaurantIds;
  final RangeValues? priceRange;
  final CachedMenuItemDimensions?
      dimensions; // PERFORMANCE: Accept cached dimensions!

  const MenuItemsSection({
    required this.title,
    super.key,
    this.showFeatured = false,
    this.category,
    this.onViewAll,
    this.selectedCategories,
    this.selectedCuisines,
    this.searchQuery,
    this.allowedRestaurantIds,
    this.priceRange,
    this.dimensions,
  });

  @override
  State<MenuItemsSection> createState() => _MenuItemsSectionState();
}

class _MenuItemsSectionState extends State<MenuItemsSection> {
  final MenuItemDisplayService _menuItemService = MenuItemDisplayService();
  final MenuItemDeltaUpdateService _deltaUpdateService =
      MenuItemDeltaUpdateService();
  final PredictivePreloadingService _predictiveService =
      PredictivePreloadingService();
  Map<String, List<MenuItem>> _groupedItems = {};
  bool _isLoading = true;
  bool _hasError = false;

  // Debouncing for filter changes
  Timer? _filterDebounceTimer;
  static const Duration _debounceDelay = Duration(milliseconds: 300);

  // Preloading state - REMOVED: no longer needed with lazy loading

  // Retry state for exponential backoff
  int _retryAttempts = 0;
  static const int _maxRetryAttempts = 3;

  // Background refresh timer
  Timer? _backgroundRefreshTimer;
  static const Duration _backgroundRefreshInterval = Duration(minutes: 15);
  DateTime? _lastRefreshTime;

  // Memoized text styles for performance
  late final TextStyle _sectionTitleStyle;

  /// Retry with exponential backoff
  Future<void> _retryWithBackoff() async {
    if (_retryAttempts >= _maxRetryAttempts) {
      debugPrint("❌ Max retry attempts reached, giving up");
      return;
    }

    _retryAttempts++;
    final delay = Duration(seconds: _retryAttempts * 2); // 2s, 4s, 6s

    debugPrint(
        "🔄 Retrying in ${delay.inSeconds} seconds (attempt $_retryAttempts/$_maxRetryAttempts)");

    await Future.delayed(delay);
    await _loadMenuItems();
  }

  /// Reset retry attempts on successful load
  void _resetRetryAttempts() {
    _retryAttempts = 0;
  }

  /// Helper method to filter out drink items and LTO items from menu items
  /// (consistent with restaurant details screen)
  List<MenuItem> _getNonDrinkItems(List<MenuItem> items) {
    return items.where((item) {
      final itemName = item.name.toLowerCase();
      final itemCategory = item.category.toLowerCase();

      // Check category-based filtering first (most reliable)
      final isDrinkCategory = itemCategory.contains("drink") ||
          itemCategory == "drinks" ||
          itemCategory == "beverage" ||
          itemCategory == "beverages";

      // Check keyword-based filtering
      final hasDrinkKeywords = itemName.contains("drink") ||
          itemName.contains("juice") ||
          itemName.contains("soda") ||
          itemName.contains("coffee") ||
          itemName.contains("tea") ||
          itemName.contains("water") ||
          itemName.contains("smoothie") ||
          itemName.contains("cocktail") ||
          itemName.contains("mocktail") ||
          itemName.contains("coke") ||
          itemName.contains("pepsi") ||
          itemName.contains("fanta") ||
          itemName.contains("sprite") ||
          itemName.contains("beer") ||
          itemName.contains("wine") ||
          itemName.contains("alcohol");

      final isDrinkItem = isDrinkCategory || hasDrinkKeywords;

      if (isDrinkItem) {
        debugPrint(
            "🔍 Home Screen: Filtered out drink item: \"${item.name}\" (category: \"${item.category}\")");
      }

      // Filter out Limited Time Offer items (both active and expired - they have their own section or should be hidden)
      if (item.isOfferActive || item.hasExpiredLTOOffer) {
        debugPrint(
            "🔍 Home Screen: Filtered out LTO item: \"${item.name}\" (has ${item.isOfferActive ? 'active' : 'expired'} offer)");
        return false;
      }

      return !isDrinkItem;
    }).toList();
  }

  @override
  void initState() {
    super.initState();

    // Initialize memoized text styles
    _initializeMemoizedStyles();

    // Initialize predictive preloading
    _initializePredictivePreloading();

    // Aggressive preloading strategy
    _aggressivePreloadAndLoad();

    // Start background refresh timer
    _startBackgroundRefresh();
  }

  /// Initialize predictive preloading service
  Future<void> _initializePredictivePreloading() async {
    try {
      await _predictiveService.initialize();
      debugPrint('✅ MenuItemsSection: Predictive preloading initialized');

      // Use predictions for intelligent preloading
      // REMOVED: Predictive preloading - data loads on-demand
    } catch (e) {
      debugPrint(
          '❌ MenuItemsSection: Error initializing predictive preloading: $e');
    }
  }

  /// Initialize memoized text styles for better performance
  void _initializeMemoizedStyles() {
    _sectionTitleStyle = GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: Colors.black,
    );
  }

  /// Aggressive preloading strategy for maximum performance
  Future<void> _aggressivePreloadAndLoad() async {
    // Check if data was preloaded during splash screen
    final startupDataService = StartupDataService();
    if (startupDataService.isInitialized &&
        startupDataService.cachedMenuItems.isNotEmpty) {
      debugPrint(
          "🚀 MenuItemsSection: Using preloaded menu items from splash screen");

      try {
        // Convert cached data to MenuItem objects
        final menuItems = startupDataService.cachedMenuItems
            .map((json) => MenuItem.fromJson(json))
            .toList();

        // Group the menu items
        final groupedItems = _groupMenuItemsByCategory(menuItems);

        if (mounted) {
          setState(() {
            _groupedItems = groupedItems;
            _isLoading = false;
            _hasError = false;
          });
        }

        debugPrint(
            "✅ MenuItemsSection: Loaded ${menuItems.length} menu items from preloaded data");
        return;
      } on Exception catch (e) {
        debugPrint(
            "❌ MenuItemsSection: Error loading preloaded menu items: $e");
        // Fall through to normal loading
      }
    }

    // Check HomeCacheService for persistent cache
    final cacheKey = _getCacheKey();
    try {
      final cachedGroupedItems = await HomeCacheService.loadMenuItems(cacheKey);
      if (cachedGroupedItems != null &&
          cachedGroupedItems.isNotEmpty &&
          mounted) {
        debugPrint(
            "🚀 Using HomeCacheService cached menu items for instant loading");

        // Convert from Map<String, dynamic> back to MenuItem objects
        final Map<String, List<MenuItem>> groupedItems = {};
        for (final entry in cachedGroupedItems.entries) {
          groupedItems[entry.key] =
              entry.value.map((json) => MenuItem.fromJson(json)).toList();
        }

        setState(() {
          _groupedItems = groupedItems;
          _isLoading = false;
        });

        // REMOVED: Preloading - data loads on-demand
        return;
      } else if (cachedGroupedItems != null && cachedGroupedItems.isEmpty) {
        debugPrint(
            "⚠️ HomeCacheService returned empty cache for key: $cacheKey, loading fresh data");
      }
    } catch (e) {
      debugPrint("❌ Error loading from HomeCacheService: $e");
    }

    // Start loading immediately
    await _loadMenuItems();

    // REMOVED: Aggressive preloading - data loads on-demand
  }

  /// Group menu items by category (using only database category field)
  Map<String, List<MenuItem>> _groupMenuItemsByCategory(List<MenuItem> items) {
    final Map<String, List<MenuItem>> groupedItems = {};

    String normalize(String input) {
      return input
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r"[\s-]+"), "_")
          .replaceAll(RegExp("[^a-z0-9_]+"), "");
    }

    final selectedCuisineKeys =
        (widget.selectedCuisines ?? const <String>{}).map(normalize).toSet();

    // Check if category filter is active
    final hasCategoryFilter = widget.selectedCategories != null &&
        widget.selectedCategories!.isNotEmpty;

    // Debug: Log active filters
    debugPrint("🔍 Grouping ${items.length} items with filters:");
    debugPrint(
        "   📂 Categories: ${widget.selectedCategories ?? 'NONE (default → Special Packs only)'}");
    debugPrint("   🍕 Cuisines: ${widget.selectedCuisines ?? 'NONE'}");
    debugPrint("   💰 Price Range: ${widget.priceRange ?? 'NONE'}");
    debugPrint("   🔍 Search Query: ${widget.searchQuery ?? 'NONE'}");

    // Expand items with variants using the new service
    final expandedItems =
        MenuItemVariantService.expandVariantsToSeparateItems(items);

    for (final item in expandedItems) {
      // Use only the database category field, skip items without a category
      if (item.category.isEmpty) {
        debugPrint(
            "⚠️ Skipping item \"${item.name}\" - no category assigned in database");
        continue;
      }

      final String key = normalize(item.category);

      // Ensure key is not empty after normalization
      if (key.isEmpty) {
        debugPrint(
            "⚠️ Skipping item \"${item.name}\" - category normalized to empty string");
        continue;
      }

      // Apply category filtering logic based on active filters
      // If search query active -> show ALL matching categories (search results should show all categories)
      // If NO filters active (default) -> show ONLY Special Packs
      // If cuisine filter active (no category) -> show ALL categories (cuisine filtering happens below)
      // If category filter active -> show matching categories only

      final hasCuisineFilter = selectedCuisineKeys.isNotEmpty;
      final hasSearchQuery =
          widget.searchQuery != null && widget.searchQuery!.isNotEmpty;

      if (hasSearchQuery) {
        // Search mode: Show all matching items from all categories
        // Don't filter by Special Packs only when searching
        debugPrint(
            "✅ Item \"${item.name}\" matches search query - showing from category: ${item.category}");
      } else if (!hasCategoryFilter && !hasCuisineFilter) {
        // Default state: No filters active, show ONLY Special Packs
        if (!_isSpecialPacksKey(key)) {
          debugPrint(
              "🔍 Skipping item \"${item.name}\" - not Special Packs (default state)");
          continue;
        }
        debugPrint(
            "✅ Item \"${item.name}\" is Special Packs - showing by default");
      } else if (hasCategoryFilter) {
        // Category filter active: Match against selected categories
        final normalizedSelected =
            widget.selectedCategories!.map(normalize).toSet();
        if (!normalizedSelected.contains(key)) {
          debugPrint(
              "🔍 Filtering out item \"${item.name}\" (category: \"${item.category}\") - not in selected categories");
          continue;
        }
        debugPrint(
            "✅ Item \"${item.name}\" matches selected category: ${widget.selectedCategories}");
      }
      // else: Only cuisine filter active - allow all categories through
      // (cuisine matching happens in the next block)

      // If selected cuisines filter exists, include only items with matching cuisine
      if (selectedCuisineKeys.isNotEmpty) {
        final itemCuisineType = item.cuisineType;
        final itemCuisineTypeId = item.cuisineTypeId;

        final cuisineMatches = selectedCuisineKeys.any((cuisineKey) {
          if (itemCuisineType != null) {
            final itemCuisineName = normalize(itemCuisineType.name);
            if (itemCuisineName.contains(cuisineKey) ||
                cuisineKey.contains(itemCuisineName)) {
              return true;
            }
          }

          if (itemCuisineTypeId != null) {
            if (itemCuisineTypeId == cuisineKey) {
              return true;
            }
          }

          return false;
        });

        if (!cuisineMatches) {
          continue;
        }
      }

      // Add item to the appropriate category
      if (!groupedItems.containsKey(key)) {
        groupedItems[key] = [];
      }
      groupedItems[key]!.add(item);
    }

    return groupedItems;
  }

  // REMOVED: Preloading methods - replaced with lazy loading for better performance

  /// Get cache key based on current filters
  String _getCacheKey() {
    final categories =
        (widget.selectedCategories ?? const <String>{}).join(",");
    final cuisines = (widget.selectedCuisines ?? const <String>{}).join(",");
    final searchQuery = widget.searchQuery ?? "";
    final priceRangeKey = widget.priceRange != null
        ? "${widget.priceRange!.start.toStringAsFixed(0)}-${widget.priceRange!.end.toStringAsFixed(0)}"
        : "all";
    // Include allowed restaurant IDs to bind cache to location-aware filtering
    final allowed = () {
      if (widget.allowedRestaurantIds == null) return "all";
      final sorted = widget.allowedRestaurantIds!.toList()..sort();
      return sorted.join("|");
    }();
    return "menu_items_${categories}_${cuisines}_${searchQuery}_price=${priceRangeKey}_allowed=$allowed";
  }

  @override
  void didUpdateWidget(covariant MenuItemsSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Early return if widget is not mounted
    if (!mounted) return;

    final current = widget.selectedCategories ?? const <String>{};
    final previous = oldWidget.selectedCategories ?? const <String>{};
    final currentCuisine = widget.selectedCuisines ?? const <String>{};
    final previousCuisine = oldWidget.selectedCuisines ?? const <String>{};
    final currentSearchQuery = widget.searchQuery ?? "";
    final previousSearchQuery = oldWidget.searchQuery ?? "";
    final currentAllowed = widget.allowedRestaurantIds ?? const <String>{};
    final previousAllowed = oldWidget.allowedRestaurantIds ?? const <String>{};

    // Check if price range changed
    final currentPriceRange = widget.priceRange;
    final previousPriceRange = oldWidget.priceRange;
    final priceRangeChanged =
        (currentPriceRange == null && previousPriceRange != null) ||
            (currentPriceRange != null && previousPriceRange == null) ||
            (currentPriceRange != null &&
                previousPriceRange != null &&
                (currentPriceRange.start != previousPriceRange.start ||
                    currentPriceRange.end != previousPriceRange.end));

    // Check if filters actually changed
    if (setEquals(current, previous) &&
        setEquals(currentCuisine, previousCuisine) &&
        currentSearchQuery == previousSearchQuery &&
        setEquals(currentAllowed, previousAllowed) &&
        !priceRangeChanged) {
      return; // No change, skip reload
    }

    // Debounce filter changes for better performance
    _filterDebounceTimer?.cancel();
    _filterDebounceTimer = Timer(_debounceDelay, () {
      if (mounted) {
        _loadMenuItems();
      }
    });
  }

  @override
  void dispose() {
    _filterDebounceTimer?.cancel();
    _backgroundRefreshTimer?.cancel();
    super.dispose();
  }

  /// Start silent background refresh timer
  /// Refreshes data every 15 minutes silently without disrupting UI
  void _startBackgroundRefresh() {
    _backgroundRefreshTimer?.cancel();

    _backgroundRefreshTimer =
        Timer.periodic(_backgroundRefreshInterval, (timer) {
      if (mounted && !_isLoading) {
        debugPrint('🔄 MenuItemsSection: Starting silent background refresh');
        _performSilentRefresh();
      }
    });

    debugPrint(
        '⏰ MenuItemsSection: Background refresh timer started (every 15 minutes)');
  }

  /// Perform silent background refresh without showing loading state
  /// Uses delta updates for efficiency when possible
  Future<void> _performSilentRefresh() async {
    if (!mounted) return;

    try {
      _lastRefreshTime = DateTime.now();
      debugPrint('🔄 Silent refresh started at $_lastRefreshTime');

      final cacheKey = _getCacheKey();

      // Try delta update first for efficiency
      List<MenuItem> items;
      final shouldFullSync = _deltaUpdateService.shouldPerformFullSync();

      if (shouldFullSync) {
        debugPrint('🔄 Performing full sync (24+ hours since last update)');
        // Use the service method with intelligent fallback
        items = await _menuItemService.getMenuItemsWithFallback(
          selectedCategories: widget.selectedCategories,
          selectedCuisines: widget.selectedCuisines,
          searchQuery: widget.searchQuery,
          priceRange: widget.priceRange,
          limit: 50,
        );
      } else {
        debugPrint('🔄 Performing delta update (incremental changes only)');
        // Get delta updates
        final deltaResult =
            await _deltaUpdateService.getDeltaUpdates(limit: 50);

        if (deltaResult.hasChanges) {
          debugPrint(
              '✅ Delta update: ${deltaResult.changeCount} changes detected');

          // Merge delta updates with existing items
          final currentItems =
              _groupedItems.values.expand((list) => list).toList();
          items = _deltaUpdateService.mergeDeltaUpdates(
            existingItems: currentItems,
            deltaResult: deltaResult,
          );
        } else {
          debugPrint('ℹ️ Delta update: No changes detected');
          return; // No changes, skip update
        }
      }

      // Filter and process items
      var filteredItems = items;
      final allowedIds = widget.allowedRestaurantIds;
      if (allowedIds != null) {
        filteredItems = items
            .where((item) =>
                item.restaurantId.isNotEmpty &&
                allowedIds.contains(item.restaurantId))
            .toList();
      }

      // Expand variants and filter drinks
      filteredItems =
          MenuItemVariantService.expandVariantsToSeparateItems(filteredItems);
      filteredItems = _getNonDrinkItems(filteredItems);

      // Group by category
      final groupedItems = _groupMenuItemsByCategory(filteredItems);

      // Only update UI if data changed significantly
      if (_shouldUpdateUI(groupedItems)) {
        if (mounted) {
          setState(() {
            _groupedItems = groupedItems;
          });
        }

        // Update cache
        final groupedItemsJson = <String, List<Map<String, dynamic>>>{};
        for (final entry in groupedItems.entries) {
          groupedItemsJson[entry.key] =
              entry.value.map((item) => item.toJson()).toList();
        }
        await HomeCacheService.saveMenuItems(cacheKey, groupedItemsJson);

        debugPrint(
            '✅ Silent refresh completed successfully (${filteredItems.length} items)');
      } else {
        debugPrint('ℹ️ Silent refresh: No significant changes detected');
      }
    } catch (e) {
      debugPrint('❌ Silent refresh failed: $e');
      // Don't show error to user - this is a background operation
    }
  }

  /// Check if UI should be updated based on data changes
  /// Returns true if there are significant changes
  bool _shouldUpdateUI(Map<String, List<MenuItem>> newGroupedItems) {
    // If current data is empty, definitely update
    if (_groupedItems.isEmpty && newGroupedItems.isNotEmpty) {
      return true;
    }

    // Check if category count changed
    if (_groupedItems.length != newGroupedItems.length) {
      return true;
    }

    // Check if item counts in categories changed significantly (>10%)
    for (final category in newGroupedItems.keys) {
      final oldCount = _groupedItems[category]?.length ?? 0;
      final newCount = newGroupedItems[category]?.length ?? 0;

      if (oldCount == 0 && newCount > 0) return true;
      if (oldCount > 0 && newCount == 0) return true;

      final change = (newCount - oldCount).abs() / oldCount;
      if (change > 0.1) {
        // More than 10% change
        return true;
      }
    }

    return false;
  }

  Future<void> _loadMenuItems() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final cacheKey = _getCacheKey();

      // Use the new service method with intelligent fallback
      final items = await _menuItemService.getMenuItemsWithFallback(
        selectedCategories: widget.selectedCategories,
        selectedCuisines: widget.selectedCuisines,
        searchQuery: widget.searchQuery,
        priceRange: widget.priceRange,
        limit: 50,
      );

      // Filter items to only those belonging to allowed restaurants (from location filter)
      var filteredItems = items;
      final allowedIds = widget.allowedRestaurantIds;
      if (allowedIds != null) {
        filteredItems = items
            .where((item) =>
                item.restaurantId.isNotEmpty &&
                allowedIds.contains(item.restaurantId))
            .toList();
        debugPrint(
            "🔍 MenuItemsSection: Applied allowedRestaurantIds filter -> ${filteredItems.length} items");
      }

      // Expand items with variants using the new service
      filteredItems =
          MenuItemVariantService.expandVariantsToSeparateItems(filteredItems);

      // Filter out drinks/beverages from home screen
      filteredItems = _getNonDrinkItems(filteredItems);
      debugPrint(
          "🔍 After drink filtering: ${filteredItems.length} items remain");

      // Group by database category
      final groupedItems = _groupMenuItemsByCategory(filteredItems);

      debugPrint(
          "🔍 After category filtering: ${groupedItems.length} category groups");

      if (mounted) {
        setState(() {
          _groupedItems = groupedItems;
          _isLoading = false;
          _hasError = false;
        });
        _resetRetryAttempts();
      }

      // Cache the grouped results in HomeCacheService
      final groupedItemsJson = <String, List<Map<String, dynamic>>>{};
      for (final entry in groupedItems.entries) {
        groupedItemsJson[entry.key] =
            entry.value.map((item) => item.toJson()).toList();
      }
      await HomeCacheService.saveMenuItems(cacheKey, groupedItemsJson);
      debugPrint(
          "💾 Cached ${filteredItems.length} menu items to HomeCacheService");
    } on Exception catch (e) {
      debugPrint("❌ Error in _loadMenuItems: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // When title is empty, return content directly to avoid extra Column spacing
    if (widget.title.isEmpty) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: _isLoading
            ? KeyedSubtree(
                key: const ValueKey('loading'),
                child: _buildLoadingState(),
              )
            : _hasError
                ? KeyedSubtree(
                    key: const ValueKey('error'),
                    child: _buildErrorState(),
                  )
                : _groupedItems.isEmpty
                    ? KeyedSubtree(
                        key: const ValueKey('empty'),
                        child: _buildEmptyState(),
                      )
                    : KeyedSubtree(
                        key: ValueKey('content_${_groupedItems.length}'),
                        child: _buildGroupedRows(),
                      ),
      );
    }

    // When title exists, use Column layout
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section header with title and optional View All
        Padding(
          padding: EdgeInsets.only(
            left: MediaQuery.of(context).padding.left + 16,
            right: MediaQuery.of(context).padding.right + 8,
            bottom: 8,
          ),
          child: GestureDetector(
            onTap: _handleTitleTap,
            behavior: HitTestBehavior.opaque,
            child: Row(
              textDirection:
                  Localizations.localeOf(context).languageCode == 'ar'
                      ? TextDirection.rtl
                      : TextDirection.ltr,
              children: [
                Expanded(
                  child: Text(
                    _getSectionTitle(),
                    style: _sectionTitleStyle, // Use memoized style
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection:
                        Localizations.localeOf(context).languageCode == 'ar'
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                  ),
                ),
                if (widget.onViewAll != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8.0),
                    child: Container(
                      width: (ResponsiveSizing.fontSize(16, context) + 8) * 1.0,
                      height:
                          (ResponsiveSizing.fontSize(16, context) + 8) * 1.0,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.black,
                          width: 1.0,
                        ),
                      ),
                      child: Icon(
                        Localizations.localeOf(context).languageCode == 'ar'
                            ? Icons.keyboard_arrow_left
                            : Icons.keyboard_arrow_right,
                        size: ResponsiveSizing.fontSize(16, context) * 1.0,
                        color: Colors.black,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Content with smooth AnimatedSwitcher transition
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeIn,
          switchOutCurve: Curves.easeOut,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: _isLoading
              ? KeyedSubtree(
                  key: const ValueKey('loading'),
                  child: _buildLoadingState(),
                )
              : _hasError
                  ? KeyedSubtree(
                      key: const ValueKey('error'),
                      child: _buildErrorState(),
                    )
                  : _groupedItems.isEmpty
                      ? KeyedSubtree(
                          key: const ValueKey('empty'),
                          child: _buildEmptyState(),
                        )
                      : KeyedSubtree(
                          key: ValueKey('content_${_groupedItems.length}'),
                          child: _buildGroupedRows(),
                        ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    // Performance: Calculate dimensions once
    final screenWidth = MediaQuery.of(context).size.width;
    const double horizontalPadding = 32.0;
    const double cardSpacing = 8.0;
    final availableWidth = screenWidth - horizontalPadding - (cardSpacing * 2);
    final cardWidth = availableWidth / 3.0;
    // Use responsive height calculation from dimensions (not fixed aspect ratio)
    final dimensions = CachedMenuItemDimensions.fromScreenWidth(screenWidth);
    final cardHeight = dimensions.cardHeight;

    return SizedBox(
      height: cardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16),
        clipBehavior: Clip.none,
        itemCount: 5,
        itemExtent: cardWidth + cardSpacing,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return Container(
            width: cardWidth,
            margin: const EdgeInsets.only(right: cardSpacing),
            child: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              period: const Duration(milliseconds: 1500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image skeleton
                  Container(
                    width: cardWidth,
                    height: cardWidth,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Title skeleton
                  Container(
                    width: cardWidth * 0.8,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Subtitle skeleton
                  Container(
                    width: cardWidth * 0.6,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Price skeleton
                  Container(
                    width: cardWidth * 0.4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroupedRows() {
    // PERFORMANCE: Removed excessive debug prints (was causing console spam on every build)

    if (_groupedItems.isEmpty) {
      return _buildFallbackMessage();
    }

    // Sort categories with Special Packs first
    final sortedCategories =
        _sortCategoriesWithSpecialPacksFirst(_groupedItems);

    final rows = sortedCategories.map((categoryId) {
      final items = _groupedItems[categoryId] ?? [];

      // Ensure categoryId is not empty or null
      final safeCategoryId = categoryId.isEmpty ? "uncategorized" : categoryId;

      if (items.isEmpty) {
        return const SizedBox.shrink();
      }

      return MenuItemsRow(
        categoryId: safeCategoryId,
        items: items,
        onViewAll: () => _navigateToViewAllForCategory(safeCategoryId),
        onDataChanged: () {
          // Refresh menu items when data changes
          _loadMenuItems();
        },
        dimensions: widget.dimensions, // Pass cached dimensions to row!
      );
    }).toList();

    // Return rows directly without Column wrapper to avoid any implicit spacing
    // Use a single widget if only one row, otherwise use Column with no spacing
    if (rows.length == 1) {
      return rows.first;
    }

    // Use IntrinsicHeight to ensure no extra spacing between rows
    return IntrinsicHeight(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // Remove any implicit spacing between rows
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }

  Widget _buildFallbackMessage() {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu_outlined,
              size: 40,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)?.noItemsAvailable ??
                  "No items available",
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handle tapping the section title
  /// Scenario 1: No category selected → Show ALL items
  /// Scenario 3: Category selected → Show that specific category
  void _handleTitleTap() {
    if (widget.onViewAll != null) {
      widget.onViewAll!();
      return;
    }

    try {
      // Check if we have ANY active filters
      final hasActiveCategoryFilter = widget.selectedCategories != null &&
          widget.selectedCategories!.isNotEmpty;
      final hasActiveCuisineFilter = widget.selectedCuisines != null &&
          widget.selectedCuisines!.isNotEmpty;
      final hasActiveFilters =
          hasActiveCategoryFilter || hasActiveCuisineFilter;

      if (hasActiveFilters) {
        // Scenario 3: Navigate with ALL active filters (categories, cuisines, etc.)
        if (hasActiveCategoryFilter) {
          final firstCategory = widget.selectedCategories!.first;
          _predictiveService.trackCategoryView(firstCategory);
        }

        final filter = RestaurantSearchFilter(
          categories: widget.selectedCategories ?? {},
          cuisines: widget.selectedCuisines ?? {},
          priceRange: widget.priceRange,
        );

        debugPrint(
            '📱 Navigation: Title tap with filters → Categories: ${widget.selectedCategories}, Cuisines: ${widget.selectedCuisines}');

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MenuItemsListScreen(),
            settings: RouteSettings(arguments: filter),
          ),
        );
      } else {
        // Scenario 1: Navigate with NO filter (show all items)
        debugPrint('📱 Navigation: Title tap with NO filters → Show ALL');

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MenuItemsListScreen(),
            settings:
                const RouteSettings(arguments: null), // No filter = show all
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to handle title tap: $e');
    }
  }

  /// Handle tapping "View All" in a specific category row
  /// Scenario 2: No category selected + View All tap → Show SPECIAL PACKS
  /// Scenario 3: Category selected + View All tap → Show that specific category
  void _navigateToViewAllForCategory(String categoryId) {
    try {
      // Track category view for predictive preloading
      _predictiveService.trackCategoryView(categoryId);

      // Check if we have filters active
      final hasActiveCategoryFilter = widget.selectedCategories != null &&
          widget.selectedCategories!.isNotEmpty;
      final hasActiveCuisineFilter = widget.selectedCuisines != null &&
          widget.selectedCuisines!.isNotEmpty;

      // Convert normalized category ID back to display name
      final displayName = categoryId
          .split('_')
          .map((word) =>
              word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
          .join(' ');

      if (!hasActiveCategoryFilter &&
          !hasActiveCuisineFilter &&
          _isSpecialPacksKey(categoryId)) {
        // Scenario 2: Default state (no filters) + Special Packs row
        // Navigate to Special Packs only
        debugPrint(
            '📱 Navigation: View All tap on Special Packs (default) → Special Packs only');

        final filter = RestaurantSearchFilter(
          categories: {displayName},
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MenuItemsListScreen(),
            settings: RouteSettings(arguments: filter),
          ),
        );
      } else if (hasActiveCategoryFilter || hasActiveCuisineFilter) {
        // Scenario 3: Filters active + View All tap
        // Navigate with ALL current filters (categories + cuisines + price, etc.)
        debugPrint(
            '📱 Navigation: View All tap with filters → Categories: ${widget.selectedCategories}, Cuisines: ${widget.selectedCuisines}');

        final filter = RestaurantSearchFilter(
          categories: widget.selectedCategories ?? {},
          cuisines: widget.selectedCuisines ?? {},
          priceRange: widget.priceRange,
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MenuItemsListScreen(),
            settings: RouteSettings(arguments: filter),
          ),
        );
      } else {
        // Fallback: Navigate to the specific category
        debugPrint('📱 Navigation: View All tap → Category: $displayName');

        final filter = RestaurantSearchFilter(
          categories: {displayName},
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MenuItemsListScreen(),
            settings: RouteSettings(arguments: filter),
          ),
        );
      }
    } on Exception catch (e) {
      debugPrint("❌ Failed to navigate to category $categoryId: $e");
    }
  }

  /// Sort categories with Special Packs first, then by item count
  List<String> _sortCategoriesWithSpecialPacksFirst(
      Map<String, List<MenuItem>> groupedItems) {
    final categories = groupedItems.keys.toList();

    categories.sort((a, b) {
      // Check if either category is "Special Packs"
      final aIsSpecialPacks = _isSpecialPacksKey(a);
      final bIsSpecialPacks = _isSpecialPacksKey(b);

      // Special Packs always comes first
      if (aIsSpecialPacks && !bIsSpecialPacks) {
        return -1;
      } else if (!aIsSpecialPacks && bIsSpecialPacks) {
        return 1;
      }

      // Otherwise, sort by item count (descending)
      final aCount = groupedItems[a]?.length ?? 0;
      final bCount = groupedItems[b]?.length ?? 0;

      if (aCount != bCount) {
        return bCount.compareTo(aCount);
      }

      // Finally, sort alphabetically
      return a.compareTo(b);
    });

    return categories;
  }

  /// Check if a normalized category key represents "Special Packs"
  bool _isSpecialPacksKey(String normalizedKey) {
    return normalizedKey.contains("special") && normalizedKey.contains("pack");
  }

  Widget _buildErrorState() {
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red[400],
            ),
            const SizedBox(height: 12),
            Text(
              "Failed to load menu items",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                // Retry with exponential backoff
                _retryWithBackoff();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
              ),
              child: Text(AppLocalizations.of(context)?.retryLabel ?? "Retry"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu_outlined,
              size: 40,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)?.noItemsAvailable ??
                  "No items available",
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get the section title (without filter information)
  String _getSectionTitle() {
    return widget.title;
  }
}
