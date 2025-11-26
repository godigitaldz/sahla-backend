// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/cache_monitor.dart';
import '../../core/data/repositories/menu_item_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../models/menu_item.dart';
import '../../models/menu_item_supplement.dart';
import '../../models/restaurant.dart';
import '../../services/auth_service.dart';
import '../../services/menu_item_service.dart';
import '../../services/restaurant_service.dart';
import '../../services/restaurant_supplement_service.dart';
import 'add_new_menu_item_screen.dart';
import 'manage_menu_screen/menu_item_section/menu_item_details_handler.dart';
import 'manage_menu_screen/menu_item_section/menu_items_header_container_widget.dart';
import 'manage_menu_screen/menu_item_section/menu_items_list_widget.dart';
import 'manage_menu_screen/menu_item_section/menu_items_shimmer_widget.dart';
import 'manage_menu_screen/restaurant_panel_section/drinks_bottom_sheet.dart';
import 'manage_menu_screen/restaurant_panel_section/lto_bottom_sheet.dart';
import 'manage_menu_screen/restaurant_panel_section/manage_supplements_popup_widget.dart';

class ManageMenuScreen extends StatefulWidget {
  const ManageMenuScreen({super.key});

  @override
  State<ManageMenuScreen> createState() => _ManageMenuScreenState();
}

class _ManageMenuScreenState extends State<ManageMenuScreen> {
  late MenuItemService _menuItemService;
  final MenuItemRepository _menuItemRepository = MenuItemRepository();
  final CacheMonitor _cacheMonitor = CacheMonitor();
  final RestaurantSupplementService _restaurantSupplementService =
      RestaurantSupplementService();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  List<MenuItem> _menuItems = [];
  List<MenuItem> _cachedMenuItems = []; // For stale-while-revalidate

  // PERF: Memoized filtered items to avoid recomputing on every build
  List<MenuItem>? _memoizedFilteredItems;
  String _lastFilterKey = '';

  Restaurant? _restaurant;

  // Pagination
  static const int _itemsPerPage = 30;
  int _currentPage = 1;
  bool _hasMoreItems = true;
  final ScrollController _scrollController = ScrollController();

  // Filter and search
  final String _selectedCuisineTypeId = '';
  String _selectedCategoryId = '';
  final Set<String> _selectedCategories = {}; // For simple category filter
  final TextEditingController _searchController = TextEditingController();
  final String _sortBy = 'name'; // name, price, created_at
  final bool _sortAscending = true;
  final bool _showDrinks = false; // When false, drinks are hidden by default

  @override
  void initState() {
    super.initState();
    _menuItemService = MenuItemService();

    _setupScrollListener();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      // Load more when user scrolls to 80% of the list
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent * 0.8 &&
          !_isLoadingMore &&
          _hasMoreItems &&
          !_isLoading) {
        _loadMoreItems();
      }
    });
  }

  Future<void> _loadData({bool isRefresh = false}) async {
    // Stale-while-revalidate: Show cached data immediately on refresh
    if (isRefresh && _cachedMenuItems.isNotEmpty) {
      // Keep showing current data while refreshing
      // RefreshIndicator will show its own loading indicator
    } else {
      setState(() => _isLoading = true);
    }

    try {
      // Get current user
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        throw Exception(AppLocalizations.of(context)!.userNotAuthenticated);
      }

      // PERF: Load restaurant and menu items in parallel for faster TTI
      // This reduces total load time from ~2-3s to ~1.2s
      final stopwatch = Stopwatch()..start();

      final restaurantService =
          Provider.of<RestaurantService>(context, listen: false);

      // Parallel loading: restaurant + menu items (if restaurant ID known)
      // Since we need restaurant ID for menu items, we load restaurant first
      // but this is still faster than sequential await chains
      _restaurant =
          await restaurantService.getRestaurantByOwnerId(currentUser.id);

      if (_restaurant == null) {
        debugPrint('⚠️ No restaurant found for user: ${currentUser.id}');
        setState(() {
          _menuItems = [];
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.noRestaurantFound),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pop(); // Return to dashboard
        }
        return;
      }

      debugPrint(
          '✅ Loaded restaurant: ${_restaurant!.name} (${_restaurant!.id})');

      // Load menu items with caching (stale-while-revalidate)
      // This will return cached data immediately if available, then refresh in background
      final allMenuItems = await _menuItemRepository.getByRestaurant(
        _restaurant!.id,
        offset: 0,
        limit: 100, // Load more initially, then paginate
        forceRefresh: isRefresh, // Force refresh on pull-to-refresh
      );

      stopwatch.stop();
      debugPrint('⏱️ Total load time: ${stopwatch.elapsedMilliseconds}ms');

      // Track cache hit
      _cacheMonitor.trackCacheHit(CacheTier.memory, 'loadMenuItems');

      debugPrint(
          '✅ Loaded ${allMenuItems.length} menu items for restaurant: ${_restaurant!.name}');

      // Reset pagination
      _currentPage = 1;
      final initialItems = allMenuItems.take(_itemsPerPage).toList();
      _hasMoreItems = allMenuItems.length > _itemsPerPage;

      setState(() {
        _menuItems = initialItems;
        _cachedMenuItems = allMenuItems; // Cache all items
        _isLoading = false;
        // PERF: Invalidate memoization cache
        _memoizedFilteredItems = null;
        _lastFilterKey = '';
        // Clear category filters on reload
        _selectedCategories.clear();
        _selectedCategoryId = '';
      });
    } catch (e) {
      debugPrint('❌ Error loading menu data: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${AppLocalizations.of(context)!.failedToLoadMenuData}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMoreItems() async {
    if (!_hasMoreItems || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      await Future.delayed(const Duration(milliseconds: 300)); // Smooth UX

      final nextPage = _currentPage + 1;
      final startIndex = _currentPage * _itemsPerPage;
      final endIndex = startIndex + _itemsPerPage;

      final moreItems =
          _cachedMenuItems.skip(startIndex).take(_itemsPerPage).toList();

      setState(() {
        _menuItems.addAll(moreItems);
        _currentPage = nextPage;
        _hasMoreItems = endIndex < _cachedMenuItems.length;
        _isLoadingMore = false;
        // PERF: Invalidate memoization cache
        _memoizedFilteredItems = null;
        _lastFilterKey = '';
      });

      debugPrint('✅ Loaded page $nextPage - ${moreItems.length} more items');
    } catch (e) {
      debugPrint('❌ Error loading more items: $e');
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _handleRefresh() async {
    debugPrint('🔄 Pull to refresh triggered');
    _menuItemService.clearCache();
    await _loadData(isRefresh: true);
  }

  // PERF: Memoized filtering and sorting to avoid O(N) operations on every frame
  List<MenuItem> get _filteredMenuItems {
    // Create a cache key based on filter state
    final searchQuery = _searchController.text.trim();
    final categoriesKey = _selectedCategories.toList()..sort();
    final filterKey =
        '$searchQuery|$_selectedCuisineTypeId|$_selectedCategoryId|${categoriesKey.join(",")}|$_showDrinks|$_sortBy|$_sortAscending|${_menuItems.length}';

    // Return cached result if filters haven't changed
    if (_lastFilterKey == filterKey && _memoizedFilteredItems != null) {
      return _memoizedFilteredItems!;
    }

    // Compute filtered items
    final filtered = _menuItems.where((item) {
      // Search filter
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        if (!item.name.toLowerCase().contains(query) &&
            !item.description.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Cuisine type filter
      if (_selectedCuisineTypeId.isNotEmpty) {
        if (item.cuisineTypeId != _selectedCuisineTypeId) {
          return false;
        }
      }

      // Category filter (by ID - PillDropdown)
      if (_selectedCategoryId.isNotEmpty) {
        if (item.categoryId != _selectedCategoryId) {
          return false;
        }
      }

      // Simple category filter (by name)
      if (_selectedCategories.isNotEmpty) {
        // Check if "All" is selected (empty set means all)
        final hasAllCategory = _selectedCategories.any((cat) {
          final lowerCat = cat.toLowerCase();
          return lowerCat == "all" ||
              lowerCat == "all categories" ||
              lowerCat == "جميع الفئات" ||
              cat == "All" ||
              cat == "All Categories" ||
              cat == "جميع الفئات" ||
              cat == "الكل";
        });

        if (!hasAllCategory) {
          // Check if item's category matches any selected category
          final itemCategoryName = item.category.trim();
          final itemCategoryObjName = item.categoryObj?.name.trim() ?? "";

          final matchesCategory = _selectedCategories.any((selectedCat) {
            final normalizedSelected = selectedCat.trim().toLowerCase();
            final normalizedItem = itemCategoryName.toLowerCase();
            final normalizedItemObj = itemCategoryObjName.toLowerCase();

            return normalizedItem == normalizedSelected ||
                normalizedItemObj == normalizedSelected;
          });

          if (!matchesCategory) {
            return false;
          }
        }
      }

      // Drinks filter - toggle between showing only drinks or only non-drinks
      final categoryLower = item.category.toLowerCase();
      final isDrink = categoryLower.contains('drink') ||
          categoryLower.contains('beverage') ||
          categoryLower.contains('مشروب'); // Arabic for drink

      if (_showDrinks) {
        // When drinks chip is selected, show ONLY drinks
        if (!isDrink) {
          return false;
        }
      } else {
        // When drinks chip is not selected, show ONLY non-drinks
        if (isDrink) {
          return false;
        }
      }

      // Filter out LTO items (both active and expired - they're displayed in LTO sections or should be hidden)
      if (item.isOfferActive || item.hasExpiredLTOOffer) {
        return false;
      }

      return true;
    }).toList();

    // Sort
    filtered.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'name':
          comparison = a.name.compareTo(b.name);
          break;
        case 'price':
          comparison = a.price.compareTo(b.price);
          break;
        case 'created_at':
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    // Cache the result
    _memoizedFilteredItems = filtered;
    _lastFilterKey = filterKey;

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    // Set system UI overlay style for white status bar and navigation bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFf8eded),
      body: SafeArea(
        top: false, // Don't add padding at top - we handle it manually
        bottom: false, // Remove bottom safe area padding
        child: Stack(
          children: [
            if (_isLoading) const MenuItemsShimmerWidget() else _buildBody(),
            // White container wrapping status bar, header, panel, and categories
            _buildWhiteContainer(),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildWhiteContainer() {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.of(context).size.width;

    return MenuItemsHeaderContainerWidget(
      statusBarHeight: statusBarHeight,
      screenWidth: screenWidth,
      searchController: _searchController,
      onBack: () => Navigator.of(context).pop(),
      onSearchChanged: (query) {
        setState(() {
          // Invalidate filter cache when search changes
          _memoizedFilteredItems = null;
          _lastFilterKey = '';
        });
      },
      onDrinksTap: _openDrinksBottomSheet,
      onSupplementsTap: _openSupplementsBottomSheet,
      onLTOTap: _openLTOBottomSheet,
      selectedCategories: _selectedCategories,
      categories: _restaurantCategories,
      onCategoryToggle: (category) {
        setState(() {
          // Handle "All" category
          final isAllCategory = category.toLowerCase() == "all" ||
              category.toLowerCase() == "all categories" ||
              category.toLowerCase() == "جميع الفئات" ||
              category == "All" ||
              category == "All Categories" ||
              category == "جميع الفئات" ||
              category == "الكل";

          if (isAllCategory) {
            // Toggle "All" - clear all selections or select all
            _selectedCategories.clear();
          } else {
            // Toggle individual category
            if (_selectedCategories.contains(category)) {
              _selectedCategories.remove(category);
            } else {
              _selectedCategories.add(category);
            }
          }

          // PERF: Invalidate filter cache
          _memoizedFilteredItems = null;
          _lastFilterKey = '';
        });
      },
    );
  }

  Widget _buildBody() {
    // Calculate top padding to position content below the white container
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.of(context).size.width;
    const headerHeight = 43.2;

    // Calculate white container height (must match MenuItemsHeaderContainerWidget exactly)
    const headerPanelSpacing = 8.0;
    const panelTopPadding = 8.0;
    const panelBottomPadding = 8.0;
    final panelCardHeight = ((screenWidth - 48) / 3) * 0.75;
    final panelHeight = panelTopPadding + panelCardHeight + panelBottomPadding;
    const categoryHeight = 48;
    final whiteContainerHeight = statusBarHeight +
        headerHeight +
        headerPanelSpacing +
        panelHeight +
        categoryHeight;

    // PERF: Use CustomScrollView with slivers for unified scrolling
    // This eliminates nested scrollable structure (Column + Expanded + ListView)
    // and improves scrolling performance by reducing layout thrashing
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: const Color(0xFFd47b00),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // Top padding to position content below white container
          SliverToBoxAdapter(
            child: SizedBox(height: whiteContainerHeight + 12),
          ),
          // Menu items list as sliver
          MenuItemsListWidget(
            filteredItems: _filteredMenuItems,
            isLoading: _isLoading,
            isLoadingMore: _isLoadingMore,
            scrollController: _scrollController,
            searchController: _searchController,
            selectedCuisineTypeId: _selectedCuisineTypeId,
            selectedCategoryId: _selectedCategoryId,
            selectedCategories: _selectedCategories,
            showDrinks: _showDrinks,
            onRefresh: _handleRefresh,
            onShowDetails: (item) =>
                MenuItemDetailsHandler.showMenuItemDetails(context, item),
            onToggleAvailability: _toggleAvailability,
            onDelete: _deleteMenuItem,
          ),
        ],
      ),
    );
  }

  /// Get unique categories from restaurant's menu items
  List<String> get _restaurantCategories {
    if (_cachedMenuItems.isEmpty) return [];

    final categories = <String>{};

    for (final item in _cachedMenuItems) {
      // Add category from legacy field
      if (item.category.isNotEmpty) {
        final categoryName = item.category.trim();
        // Exclude drinks categories
        final categoryLower = categoryName.toLowerCase();
        final isDrink = categoryLower.contains('drink') ||
            categoryLower.contains('beverage') ||
            categoryLower.contains('boissons') ||
            categoryLower.contains('مشروب');

        if (!isDrink) {
          categories.add(categoryName);
        }
      }

      // Add category from category object if available
      if (item.categoryObj != null && item.categoryObj!.name.isNotEmpty) {
        final categoryName = item.categoryObj!.name.trim();
        final categoryLower = categoryName.toLowerCase();
        final isDrink = categoryLower.contains('drink') ||
            categoryLower.contains('beverage') ||
            categoryLower.contains('boissons') ||
            categoryLower.contains('مشروب');

        if (!isDrink) {
          categories.add(categoryName);
        }
      }
    }

    final sortedCategories = categories.toList()..sort();
    return sortedCategories;
  }

  /// Get drinks from menu items
  List<MenuItem> get _drinks {
    return _menuItems.where((item) {
      final categoryLower = item.category.toLowerCase();
      final categoryObjLower = (item.categoryObj?.name ?? '').toLowerCase();
      final nameLower = item.name.toLowerCase();

      return categoryLower.contains('drink') ||
          categoryLower.contains('beverage') ||
          categoryLower.contains('boissons') ||
          categoryLower.contains('مشروب') || // Arabic for drink
          categoryObjLower.contains('drink') ||
          categoryObjLower.contains('beverage') ||
          categoryObjLower.contains('boissons') ||
          categoryObjLower.contains('مشروب') ||
          nameLower.contains('drink') ||
          nameLower.contains('juice') ||
          nameLower.contains('soda') ||
          nameLower.contains('coffee') ||
          nameLower.contains('tea') ||
          nameLower.contains('water');
    }).toList();
  }

  /// Get LTO items from menu items (both active and expired)
  List<MenuItem> get _ltoItems {
    return _cachedMenuItems.where((item) {
      return item.isOfferActive || item.hasExpiredLTOOffer;
    }).toList();
  }

  /// Get restaurant ID from restaurant object
  String? get _restaurantId => _restaurant?.id;

  /// Get supplements from menu_item_supplements table
  Future<List<MenuItemSupplement>> _loadSupplements() async {
    try {
      final restaurantId = _restaurantId;
      if (restaurantId == null || restaurantId.isEmpty) {
        debugPrint('⚠️ Cannot load supplements: restaurant ID is null');
        return [];
      }

      debugPrint(
          '🔍 Loading supplements from restaurant_supplements table for restaurant: $restaurantId');

      // Load supplements from restaurant_supplements table using service
      final supplementsList =
          await _restaurantSupplementService.getRestaurantSupplements(
        restaurantId,
      );

      debugPrint(
          '✅ Loaded ${supplementsList.length} supplements from restaurant_supplements table');
      return supplementsList;
    } catch (e) {
      debugPrint('❌ Error loading supplements: $e');
      return [];
    }
  }

  /// Open supplements bottom sheet
  Future<void> _openSupplementsBottomSheet() async {
    // Load supplements from restaurant_supplements table
    final supplements = await _loadSupplements();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ManageSupplementsPopupWidget(
        supplements: supplements,
        onRefresh: () async {
          await _loadData(isRefresh: true);
        },
        onToggleAvailability: (supplement) async {
          await _toggleSupplementAvailability(supplement);
          // Refresh supplements list after toggle
          if (mounted) {
            Navigator.of(context).pop(); // Close bottom sheet
            _openSupplementsBottomSheet(); // Reopen to show updated list
          }
        },
        onDelete: (supplement) async {
          Navigator.of(context).pop(); // Close bottom sheet
          await _deleteSupplement(supplement);
        },
      ),
    );
  }

  /// Open drinks bottom sheet
  void _openDrinksBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DrinksBottomSheet(
        drinks: _drinks,
        onRefresh: () => _loadData(isRefresh: true),
        onToggleAvailability: (drink) async {
          await _toggleAvailability(drink);
          // Refresh drinks list after toggle
          if (mounted) {
            Navigator.of(context).pop(); // Close bottom sheet
            _openDrinksBottomSheet(); // Reopen to show updated list
          }
        },
        onDelete: (drink) {
          Navigator.of(context).pop(); // Close bottom sheet
          _deleteMenuItem(drink);
        },
      ),
    );
  }

  /// Open LTO bottom sheet
  void _openLTOBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LTOBottomSheet(
        ltoItems: _ltoItems,
        onRefresh: () => _loadData(isRefresh: true),
        onToggleAvailability: (ltoItem) async {
          await _toggleAvailability(ltoItem);
          // Refresh LTO items list after toggle
          if (mounted) {
            Navigator.of(context).pop(); // Close bottom sheet
            _openLTOBottomSheet(); // Reopen to show updated list
          }
        },
        onDelete: (ltoItem) {
          Navigator.of(context).pop(); // Close bottom sheet
          _deleteMenuItem(ltoItem);
        },
        onReactivate: (ltoItem, startDate, endDate) async {
          await _reactivateLTOItem(ltoItem, startDate, endDate);
          // Refresh LTO items list after reactivation
          if (mounted) {
            Navigator.of(context).pop(); // Close bottom sheet
            _openLTOBottomSheet(); // Reopen to show updated list
          }
        },
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () async {
        final result = await Navigator.push<bool>(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const AddNewMenuItemScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 1.0);
              const end = Offset.zero;
              const curve = Curves.easeInOutCubic;

              final tween =
                  Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              final offsetAnimation = animation.drive(tween);

              final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
                ),
              );

              return SlideTransition(
                position: offsetAnimation,
                child: FadeTransition(
                  opacity: fadeAnimation,
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 400),
            reverseTransitionDuration: const Duration(milliseconds: 350),
          ),
        );
        // Only refresh if an item was actually added (result == true)
        if (result == true && mounted) {
          await _loadData();
        }
      },
      backgroundColor: const Color(0xFFd47b00),
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: Text(
        AppLocalizations.of(context)!.addItem,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
    );
  }

  /// Toggle supplement availability in menu_item_supplements table
  Future<void> _toggleSupplementAvailability(
      MenuItemSupplement supplement) async {
    try {
      debugPrint('🔄 Toggling supplement availability: ${supplement.name}');

      final supabase = Supabase.instance.client;
      await supabase.from('menu_item_supplements').update({
        'is_available': !supplement.isAvailable,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', supplement.id);

      debugPrint('✅ Supplement availability toggled successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              supplement.isAvailable ? 'Supplement hidden' : 'Supplement shown',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error toggling supplement availability: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Delete supplement from menu_item_supplements table
  Future<void> _deleteSupplement(MenuItemSupplement supplement) async {
    try {
      debugPrint('🗑️ Deleting supplement: ${supplement.name}');

      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Supplement'),
          content:
              Text('Are you sure you want to delete "${supplement.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final supabase = Supabase.instance.client;
      final restaurantId = _restaurantId;

      // Delete from menu_item_supplements table
      // This will cascade delete from restaurant_supplements if foreign key constraint is set
      await supabase
          .from('menu_item_supplements')
          .delete()
          .eq('id', supplement.id);

      // Also remove from restaurant_supplements if it exists (in case cascade is not set)
      if (restaurantId != null && restaurantId.isNotEmpty) {
        try {
          await supabase
              .from('restaurant_supplements')
              .delete()
              .eq('restaurant_id', restaurantId)
              .eq('supplement_id', supplement.id);
          debugPrint('✅ Removed supplement from restaurant_supplements');
        } catch (e) {
          // Ignore if entry doesn't exist or cascade already handled it
          debugPrint('ℹ️ Could not remove from restaurant_supplements: $e');
        }
      }

      debugPrint('✅ Supplement deleted successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Supplement deleted'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Refresh supplements list
        _openSupplementsBottomSheet();
      }
    } catch (e) {
      debugPrint('❌ Error deleting supplement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _toggleAvailability(MenuItem item) async {
    try {
      // Optimistically update UI immediately for instant feedback
      final itemIndex = _menuItems.indexWhere((i) => i.id == item.id);
      if (itemIndex == -1) return;

      // Store old value for rollback if needed
      final oldAvailability = _menuItems[itemIndex].isAvailable;

      // Update UI immediately (optimistic update)
      setState(() {
        _menuItems[itemIndex] = _menuItems[itemIndex].copyWith(
          isAvailable: !oldAvailability,
        );
        // PERF: Invalidate filter cache
        _memoizedFilteredItems = null;
        _lastFilterKey = '';
      });

      // Toggle availability in database
      final success =
          await _menuItemService.toggleMenuItemAvailability(item.id);

      if (success && mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(oldAvailability
                ? AppLocalizations.of(context)!.successfullyHidItem(item.name)
                : AppLocalizations.of(context)!
                    .successfullyShowedItem(item.name)),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      } else if (mounted) {
        // Rollback on failure
        setState(() {
          _menuItems[itemIndex] = _menuItems[itemIndex].copyWith(
            isAvailable: oldAvailability,
          );
          _memoizedFilteredItems = null;
          _lastFilterKey = '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!
                .failedToUpdateAvailability(item.name)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Rollback on error
        final itemIndex = _menuItems.indexWhere((i) => i.id == item.id);
        if (itemIndex != -1) {
          setState(() {
            _menuItems[itemIndex] = _menuItems[itemIndex].copyWith(
              isAvailable: !_menuItems[itemIndex].isAvailable,
            );
            _memoizedFilteredItems = null;
            _lastFilterKey = '';
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!
                .errorUpdatingAvailability(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Reactivate expired LTO item with new dates
  Future<void> _reactivateLTOItem(
      MenuItem item, DateTime startDate, DateTime endDate) async {
    try {
      debugPrint('🔄 Reactivating LTO item: ${item.name}');

      // Find and update the expired LTO pricing option
      final updatedPricingOptions =
          List<Map<String, dynamic>>.from(item.pricingOptions);

      for (int i = 0; i < updatedPricingOptions.length; i++) {
        final pricing = updatedPricingOptions[i];
        if (pricing['is_limited_offer'] == true) {
          // Update the expired LTO with new dates
          updatedPricingOptions[i] = Map<String, dynamic>.from(pricing)
            ..['offer_start_at'] = startDate.toUtc().toIso8601String()
            ..['offer_end_at'] = endDate.toUtc().toIso8601String();

          debugPrint('✅ Updated LTO pricing option with new dates');
          debugPrint('   Start: ${startDate.toUtc().toIso8601String()}');
          debugPrint('   End: ${endDate.toUtc().toIso8601String()}');
          break;
        }
      }

      // Create updated menu item
      final updatedItem = item.copyWith(
        pricingOptions: updatedPricingOptions,
        updatedAt: DateTime.now(),
      );

      // Update in database
      final success = await _menuItemService.updateMenuItem(updatedItem);

      if (success && mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('LTO "${item.name}" reactivated successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Refresh data
        await _loadData(isRefresh: true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reactivate LTO: ${item.name}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error reactivating LTO item: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reactivating LTO: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _deleteMenuItem(MenuItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)!.deleteMenuItem,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          AppLocalizations.of(context)!.deleteMenuItemConfirmation(item.name),
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();

              try {
                // Show loading indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        AppLocalizations.of(context)!.deletingItem(item.name)),
                    backgroundColor: Colors.blue[600],
                    duration: const Duration(seconds: 1),
                  ),
                );

                // Delete item from database
                final success = await _menuItemService.deleteMenuItem(item.id);

                if (success && mounted) {
                  // Refresh the menu items list
                  await _loadData();

                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!
                          .successfullyDeletedItem(item.name)),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!
                          .failedToDeleteItem(item.name)),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!
                          .errorDeletingItem(e.toString())),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              AppLocalizations.of(context)!.delete,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
