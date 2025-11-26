// lib/screens/home_screen.dart
// Performance-optimized home screen for smooth scrolling on low-end devices.
// Refactored into modular architecture for better maintainability and
// performance.

import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_screenutil/flutter_screenutil.dart";
import "package:provider/provider.dart";

import "app_animations.dart";
import "home_header.dart";
import "models/restaurant.dart";
import "providers/delivery_fee_provider.dart";
import "providers/home_provider.dart";
import "providers/location_provider.dart";
import "screens/user_profile_edit_screen.dart";
import "services/auth_service.dart";
import "services/restaurant_search_service.dart";
import "services/transition_service.dart";
import "utils/performance_utils.dart";
import "widgets/cart_screen/floating_cart_icon.dart";
import "widgets/filter_chips_section/category_selector_modal.dart";
import "widgets/filter_chips_section/cuisine_selector_modal.dart";
import "widgets/filter_chips_section/price_selector_modal.dart";
import "widgets/home_screen/best_choices_section/best_choices_title.dart";
import "widgets/home_screen/best_choices_section/cached_menu_item_dimensions.dart";
import "widgets/home_screen/best_choices_section/menu_items_wrapper.dart";
import "widgets/home_screen/helpers/categories_wrapper.dart";
import "widgets/home_screen/helpers/combined_filter_service.dart";
import "widgets/home_screen/helpers/filter_chips_section_wrapper.dart";
import "widgets/home_screen/helpers/responsive_refresh_scroll_physics.dart";
import "widgets/home_screen/home_layout_helper.dart";
import "widgets/home_screen/limited_time_offer_section.dart";
import "widgets/home_screen/special_packs_section.dart";
import "widgets/home_screen/promo_codes_section.dart";
import "widgets/home_screen/restaurants_sliver_section.dart";
import "widgets/restaurant_details_screen/helpers/cached_restaurant_dimensions.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.initialTab,
  });

  final int? initialTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();

    // Configure performance optimizations for ultra-fast loading
    PerformanceUtils.configureImageCache();

    // ULTRA-FAST LOADING: Initialize synchronously for 0.05s target
    // All data loading happens in splash screen, home screen just renders instantly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProfileCompletion();
      _restoreUserState();
      _checkRoleBasedNavigation();
      // Skip session validation - already done in splash screen
      _initializeUltraFast();
    });
  }

  /// Ultra-fast initialization (no async operations)
  void _initializeUltraFast() {
    try {
      // Initialize provider synchronously (ultra-fast mode)
      final HomeProvider homeProvider =
          Provider.of<HomeProvider>(context, listen: false);
      homeProvider.initialize(skipDataLoading: true); // Use preloaded data

      // Set up DeliveryFeeProvider location listener for reactive updates
      _setupDeliveryFeeProviderListener();

      debugPrint("⚡ HomeScreen: Ultra-fast initialization completed");
    } on Exception catch (e) {
      debugPrint("❌ HomeScreen: Error in ultra-fast initialization: $e");
      // Don't crash the app if provider is not ready
    }
  }

  /// Set up DeliveryFeeProvider to listen to LocationProvider changes
  void _setupDeliveryFeeProviderListener() {
    try {
      final deliveryFeeProvider =
          Provider.of<DeliveryFeeProvider>(context, listen: false);
      final locationProvider =
          Provider.of<LocationProvider>(context, listen: false);

      // Initialize delivery fee provider
      deliveryFeeProvider.initialize();

      // Set location provider for reactive updates
      deliveryFeeProvider.setLocationProvider(locationProvider);

      debugPrint("📍 HomeScreen: DeliveryFeeProvider location listener set up");
    } catch (e) {
      debugPrint("⚠️ HomeScreen: Failed to set up delivery fee provider listener: $e");
    }
  }

  /// Check if user needs to complete their profile
  void _checkProfileCompletion() {
    try {
      final AuthService authService = Provider.of<AuthService>(
        context,
        listen: false,
      );
      final user = authService.currentUser;

      if (user != null && (user.name == null || user.name?.isEmpty == true)) {
        // Redirect to profile completion
        TransitionService.navigateWithTransition(
          context,
          const UserProfileEditScreen(),
          transitionType: TransitionType.slideFromBottom,
        );
      }
    } catch (e) {
      debugPrint("❌ HomeScreen: Error checking profile completion: $e");
      // Don't crash the app if provider is not ready
    }
  }

  /// Check if user should be redirected to role-specific screen
  void _checkRoleBasedNavigation() {
    // Role-based navigation removed - functionality no longer needed
  }

  // Session validation removed - now handled in splash screen for ultra-fast loading

  /// Restore user state from cache
  Future<void> _restoreUserState() async {
    try {
      // Restore user state logic here
      debugPrint("🏠 Restoring user state...");
    } on Exception catch (e) {
      debugPrint("❌ Error restoring user state: $e");
      // Don"t suppress errors - they might indicate session issues
    }
  }

  @override
  Widget build(BuildContext context) => FloatingCartIconWrapper(
        child: Scaffold(
          backgroundColor: Colors.orange.shade600,
          resizeToAvoidBottomInset:
              false, // Prevent bottom padding from keyboard
          body: Consumer<HomeProvider>(
            builder: (BuildContext context, HomeProvider homeProvider,
                    Widget? child) =>
                AnimatedSwitcher(
              duration: AppAnimationDefaults.tabSwitchDuration,
              switchInCurve: AppAnimationDefaults.tabSwitchCurve,
              switchOutCurve: AppAnimationDefaults.tabSwitchCurve,
              child: HomeContent(
                key: const ValueKey("home_content"),
                scrollController: homeProvider.mainScrollController,
              ),
            ),
          ),
        ),
      );
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key, this.scrollController});

  final ScrollController? scrollController;

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent>
    with AutomaticKeepAliveClientMixin {
  /// Track last precalculated restaurants to avoid duplicate calculations
  List<String>? _lastPrecalculatedRestaurants;

  /// Track if refresh is in progress to prevent multiple simultaneous refreshes
  bool _isRefreshing = false;

  @override
  bool get wantKeepAlive => true;

  // PERFORMANCE: ValueNotifier for high-performance scroll tracking
  // Avoids rebuilding entire widget tree on every scroll frame
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0.0);

  // PERFORMANCE: Track last scroll offset to throttle updates
  double _lastScrollOffset = 0.0;

  // PERFORMANCE: Throttle scroll updates to reduce rebuilds
  Timer? _scrollThrottleTimer;

  /// Track if loading more restaurants for pagination
  bool _isLoadingMore = false;

  /// Scroll controller for pagination detection
  ScrollController? _internalScrollController;

  // PERFORMANCE: Cached responsive dimensions (calculated once per screen size)
  // Avoids expensive MediaQuery calls on every card build
  double? _cachedCardHeight;
  late CachedRestaurantDimensions _cachedDimensions;
  CachedMenuItemDimensions? _cachedMenuItemDimensions;

  @override
  void initState() {
    super.initState();
    // Setup scroll controller with pagination listener
    _setupScrollListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Calculate restaurant card dimensions once when dependencies change
    _calculateCardDimensions();
  }

  /// Calculate fixed card dimensions for performance (CRITICAL optimization)
  /// This eliminates 15-20 MediaQuery calls per card build!
  void _calculateCardDimensions() {
    // QUICK WIN: Cache dimensions to avoid repeated MediaQuery lookups
    final size = MediaQuery.of(context).size;

    // Calculate all dimensions once - for BOTH restaurant cards AND menu item cards
    _cachedDimensions = CachedRestaurantDimensions.fromScreenWidth(size.width);
    _cachedCardHeight = _cachedDimensions.totalCardHeight;
    _cachedMenuItemDimensions =
        CachedMenuItemDimensions.fromScreenWidth(size.width);

    debugPrint('📏 Calculated restaurant card height: $_cachedCardHeight');
    debugPrint(
        '📐 Cached dimensions: cover=${_cachedDimensions.coverHeight}, logo=${_cachedDimensions.logoSize}');
    debugPrint('📱 Cached screen: ${size.width}x${size.height}');
    debugPrint(
        '🍽️ Cached menu item dimensions: ${_cachedMenuItemDimensions?.cardWidth}x${_cachedMenuItemDimensions?.cardHeight}');
  }

  @override
  void dispose() {
    _scrollThrottleTimer?.cancel();
    _scrollOffset.dispose();
    _internalScrollController?.dispose();
    super.dispose();
  }

  /// Setup scroll listener for pagination
  void _setupScrollListener() {
    // Get the controller from widget or create internal one
    _internalScrollController = widget.scrollController;

    // Add listener for pagination detection
    if (_internalScrollController != null) {
      _internalScrollController!.addListener(_onScroll);
    }
  }

  /// Handle scroll events for pagination
  void _onScroll() {
    final controller = _internalScrollController;
    if (controller == null || !controller.hasClients) return;

    final scrollPosition = controller.position.pixels;
    final maxScrollExtent = controller.position.maxScrollExtent;

    // PERFORMANCE FIX: Less aggressive threshold (800px instead of 200px)
    // Only trigger when user is actually near the bottom AND not already loading
    if (scrollPosition >= maxScrollExtent - 800) {
      if (!_isLoadingMore && mounted) {
        final homeProvider = Provider.of<HomeProvider>(context, listen: false);

        // BUG FIX: Check EVERYTHING before calling - prevent ANY attempts after end
        if (!homeProvider.isLoadingMoreRestaurants &&
            homeProvider.availableRestaurants.isNotEmpty &&
            homeProvider.hasMoreRestaurants) {
          // ← CRITICAL: Check end flag!
          _loadMoreRestaurants();
        }
      }
    }
  }

  /// Load more restaurants with pagination
  Future<void> _loadMoreRestaurants() async {
    if (_isLoadingMore || !mounted) return;

    final homeProvider = Provider.of<HomeProvider>(context, listen: false);

    // CRITICAL FIX: Check end flag BEFORE setting loading state
    if (!homeProvider.hasMoreRestaurants) {
      debugPrint('⏭️ Home: End reached, skipping load attempt');
      return;
    }

    // PERFORMANCE: Use local flag instead of setState to avoid rebuilds
    _isLoadingMore = true;

    try {
      // Double-check before making expensive network call
      if (homeProvider.isLoadingMoreRestaurants) {
        debugPrint('⏭️ Home: Already loading, skipping');
        return;
      }

      final hadMoreBefore = homeProvider.hasMoreRestaurants;
      await homeProvider.loadMoreRestaurants();

      // Only print success if we actually tried to load (hadn't reached end)
      if (hadMoreBefore && homeProvider.hasMoreRestaurants) {
        debugPrint('📈 Home: Loaded more restaurants');
      }
    } catch (e) {
      debugPrint('❌ Home: Error loading more restaurants: $e');
    } finally {
      // PERFORMANCE: No setState needed - loading state is managed by provider
      if (mounted) {
        _isLoadingMore = false;
      }
    }
  }

  /// Trigger batch delivery fee calculation for visible restaurants
  void _triggerBatchDeliveryFeeCalculation(List<dynamic> restaurants) {
    if (restaurants.isEmpty) {
      return;
    }

    // Convert to Restaurant list (filter out non-Restaurant types)
    final restaurantList = restaurants
        .whereType<Restaurant>()
        .take(20) // Only precalculate first 20 visible restaurants
        .toList();

    if (restaurantList.isEmpty) {
      return;
    }

    // Check if we've already precalculated for this exact list
    final currentIds = restaurantList.map((r) => r.id).toList();
    if (_lastPrecalculatedRestaurants != null &&
        _listsEqual(_lastPrecalculatedRestaurants!, currentIds)) {
      return; // Already precalculated
    }

    _lastPrecalculatedRestaurants = currentIds;

    // Schedule batch calculation after current frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final deliveryFeeProvider =
          Provider.of<DeliveryFeeProvider>(context, listen: false);
      final locationProvider =
          Provider.of<LocationProvider>(context, listen: false);
      final currentLocation = locationProvider.currentLocation;

      // Trigger batch precalculation (non-blocking)
      deliveryFeeProvider.precalculateFees(
        restaurants: restaurantList,
        customerLatitude: currentLocation?.latitude,
        customerLongitude: currentLocation?.longitude,
      );

      debugPrint(
          '🚀 Triggered batch delivery fee calculation for ${restaurantList.length} restaurants');
    });
  }

  /// Compare two lists for equality
  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ==================== REMOVED: Image precaching ====================
  // Image precaching is now handled by RestaurantsSliverSection widget
  // See restaurants_sliver_section.dart _precacheImages() for implementation

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Use comprehensive layout helper for all calculations
    final contentStartHeight = HomeLayoutHelper.getContentStartHeight(context);
    final imageHeight = HomeLayoutHelper.getImageHeight(context);
    final maxScrollOffset = HomeLayoutHelper.getMaxScrollOffset(context);
    final bottomExtension = HomeLayoutHelper.getBottomExtension(context);

    // Debug layout info - Enable for troubleshooting layout issues
    // debugPrint('🎯 Layout: ${HomeLayoutHelper.getDebugInfo(context)}');

    return Consumer<HomeProvider>(
      builder: (BuildContext context, HomeProvider home, Widget? _) =>
          Container(
        color: Colors.orange.shade600, // Full screen orange background
        child: Stack(
          children: <Widget>[
            // Background image layer - extends beyond content start for smooth transition
            // IgnorePointer allows touch events to pass through to scrollable content underneath
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: imageHeight, // 40% to create overlap with white container
              child: IgnorePointer(
                child: Image.asset(
                  'assets/main.png',
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),

            // Scrollable white container - positioned to fill entire screen for touch events
            // Transform.translate will handle visual positioning
            // Extended bottom responsively to prevent orange gap when scrolling
            Positioned.fill(
              top: 0, // Start from top to capture all touch events
              bottom:
                  bottomExtension, // Responsive extension based on max scroll + buffer
              // PERFORMANCE FIX: Use RepaintBoundary to isolate transform layer
              // This prevents the entire container from repainting on every scroll
              child: RepaintBoundary(
                // PERFORMANCE FIX: Use ValueListenableBuilder ONLY for transform offset
                // The child tree is cached and doesn't rebuild on scroll
                child: ValueListenableBuilder<double>(
                  valueListenable: _scrollOffset,
                  builder: (context, scrollOffset, child) {
                    // PERFORMANCE: Transform only affects the visual position, not the widget tree
                    return Transform.translate(
                      // Combined transform: Initial position (contentStartHeight) - scroll offset
                      // Starts at contentStartHeight, moves up as user scrolls
                      offset: Offset(0, contentStartHeight - scrollOffset),
                      child: child,
                    );
                  },
                  // CRITICAL: This child is cached and NEVER rebuilds on scroll
                  // Only the Transform.translate offset changes, not the widget tree
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24.r),
                        topRight: Radius.circular(24.r),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24.r),
                        topRight: Radius.circular(24.r),
                      ),
                      child: Stack(
                        children: <Widget>[
                          // Scrollable content underneath with refresh indicator
                          NotificationListener<ScrollNotification>(
                            onNotification:
                                (ScrollNotification scrollNotification) {
                              if (scrollNotification.metrics.axis ==
                                  Axis.vertical) {
                                final offset =
                                    scrollNotification.metrics.pixels;
                                final clampedOffset =
                                    offset.clamp(0.0, maxScrollOffset);

                                // PERFORMANCE FIX: Throttle scroll updates to reduce rebuilds
                                // Only update if offset changed significantly (> 2px) to reduce excessive rebuilds
                                if ((clampedOffset - _lastScrollOffset).abs() >
                                    2.0) {
                                  _lastScrollOffset = clampedOffset;

                                  // Update ValueNotifier immediately for transform (needs smooth animation)
                                  _scrollOffset.value = clampedOffset;

                                  // Throttle provider update (header animation can be less frequent)
                                  _scrollThrottleTimer?.cancel();
                                  _scrollThrottleTimer = Timer(
                                      const Duration(milliseconds: 16), () {
                                    if (mounted) {
                                      // Use Provider.of to avoid closure issues
                                      final homeProvider =
                                          Provider.of<HomeProvider>(context,
                                              listen: false);
                                      homeProvider
                                          .updateScrollOffset(clampedOffset);
                                    }
                                  });
                                }
                              }
                              return false;
                            },
                            child: RefreshIndicator(
                              onRefresh: () async {
                                // Prevent multiple simultaneous refreshes
                                if (_isRefreshing) {
                                  return;
                                }

                                try {
                                  setState(() {
                                    _isRefreshing = true;
                                  });

                                  // Provide haptic feedback when refresh is triggered
                                  await HapticFeedback.mediumImpact();

                                  // Show immediate feedback
                                  debugPrint(
                                      "🔄 Refresh triggered - updating data...");
                                  await home.refreshData();
                                  debugPrint(
                                      "✅ Refresh completed successfully");

                                  // Success haptic feedback
                                  await HapticFeedback.lightImpact();
                                } on Exception catch (e) {
                                  debugPrint("❌ Error refreshing data: $e");
                                  // Error haptic feedback
                                  await HapticFeedback.heavyImpact();
                                  // Error handling is done in the provider
                                } finally {
                                  if (mounted) {
                                    setState(() {
                                      _isRefreshing = false;
                                    });
                                  }
                                }
                              },
                              // Highly responsive refresh configuration
                              displacement:
                                  30.0, // Position indicator 30px from top
                              edgeOffset:
                                  0.0, // No offset needed since filter chips are in scrollable content
                              strokeWidth: 3.0, // Thicker for better visibility
                              color: Colors.orange.shade600, // Match app theme
                              backgroundColor: Colors.white.withOpacity(0.9),
                              // Trigger on edge for maximum responsiveness
                              triggerMode: RefreshIndicatorTriggerMode.onEdge,
                              // 🚀 PERFORMANCE FIX: Converted to CustomScrollView for 60 FPS scrolling
                              // REMOVED: SingleChildScrollView + Column (nested scrollables)
                              // ADDED: CustomScrollView + Slivers (single scroll axis, O(1) layout)
                              // NOTE: No inner Transform needed - outer Transform handles parallax
                              child: Container(
                                color: const Color(0xFFf8eded),
                                child: CustomScrollView(
                                  controller: widget.scrollController ??
                                      home.mainScrollController,
                                  physics: const ResponsiveRefreshScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                                  clipBehavior: Clip.hardEdge,
                                  // PERFORMANCE: Optimize cacheExtent - 1.5x is optimal for smooth scrolling
                                  // Cache only what's needed: visible viewport + prefetch area
                                  // Previous 2x was excessive and caused memory pressure
                                  cacheExtent:
                                      MediaQuery.of(context).size.height * 1.5,
                                  slivers: <Widget>[
                                    // Main content container sliver
                                    // PERFORMANCE FIX: Cache MediaQuery padding once per build
                                    SliverToBoxAdapter(
                                      child: Builder(
                                        builder: (context) {
                                          // Cache MediaQuery padding to avoid repeated lookups
                                          final viewPadding =
                                              MediaQuery.of(context).padding;
                                          return Padding(
                                            padding: EdgeInsets.only(
                                              left: viewPadding.left,
                                              right: viewPadding.right,
                                            ),
                                            child: Container(
                                              padding: EdgeInsets
                                                  .zero, // Removed all padding - spacing handled by slivers
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.only(
                                                  topLeft:
                                                      Radius.circular(24.r),
                                                  topRight:
                                                      Radius.circular(24.r),
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                            alpha: 0.00),
                                                    blurRadius: 16,
                                                    offset: const Offset(0, 4),
                                                    spreadRadius: 0,
                                                  ),
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                            alpha: 0.00),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                    spreadRadius: 0,
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: <Widget>[
                                                  // Responsive top spacing for category section
                                                  // Reduced from full safe area to responsive fixed value
                                                  Builder(
                                                    builder: (context) {
                                                      final screenHeight = MediaQuery.of(context).size.height;

                                                      // Responsive spacing: smaller on all devices, especially iPhone
                                                      // Use a fixed small value that works across all devices
                                                      double topSpacing;
                                                      if (screenHeight <= 667) {
                                                        // Small devices (iPhone SE, iPhone 6/7/8)
                                                        topSpacing = 8.0;
                                                      } else if (screenHeight <= 736) {
                                                        // Medium devices (iPhone 6/7/8 Plus)
                                                        topSpacing = 10.0;
                                                      } else if (screenHeight <= 812) {
                                                        // iPhone X/XS/11 Pro
                                                        topSpacing = 12.0;
                                                      } else if (screenHeight <= 844) {
                                                        // iPhone 12/13
                                                        topSpacing = 12.0;
                                                      } else if (screenHeight <= 926) {
                                                        // iPhone 12/13 Pro Max
                                                        topSpacing = 14.0;
                                                      } else {
                                                        // Larger devices (tablets)
                                                        topSpacing = 16.0;
                                                      }

                                                      return SizedBox(
                                                        height: topSpacing,
                                                      );
                                                    },
                                                  ),

                                                  // Categories section
                                                  // RepaintBoundary isolates category section repaints
                                                  // PERFORMANCE: Use Selector to only rebuild when categories change
                                                  RepaintBoundary(
                                                    child: Selector<
                                                        HomeProvider,
                                                        Set<String>>(
                                                      selector: (_, provider) =>
                                                          provider.state
                                                              .selectedCategories ??
                                                          {},
                                                      builder: (context,
                                                          selectedCategories,
                                                          child) {
                                                        return Selector<
                                                            HomeProvider,
                                                            Set<String>>(
                                                          selector: (_,
                                                                  provider) =>
                                                              provider.state
                                                                  .selectedCuisines ??
                                                              {},
                                                          builder: (context,
                                                              selectedCuisines,
                                                              child) {
                                                            return CategoriesWrapper(
                                                              selectedCategories:
                                                                  selectedCategories,
                                                              selectedCuisines:
                                                                  selectedCuisines,
                                                              onCategoryToggle:
                                                                  (String
                                                                      category) {
                                                                final homeProvider =
                                                                    Provider.of<
                                                                            HomeProvider>(
                                                                        context,
                                                                        listen:
                                                                            false);
                                                                final debouncedFunction =
                                                                    PerformanceUtils
                                                                        .debounce(
                                                                  (String
                                                                      category) {
                                                                    homeProvider
                                                                        .applyCategoryFilter(
                                                                      selectedCategories.contains(
                                                                              category)
                                                                          ? selectedCategories
                                                                              .where((c) =>
                                                                                  c !=
                                                                                  category)
                                                                              .toSet()
                                                                          : {
                                                                              ...selectedCategories,
                                                                              category
                                                                            },
                                                                    );
                                                                  },
                                                                  const Duration(
                                                                      milliseconds:
                                                                          350),
                                                                );
                                                                debouncedFunction(
                                                                    category);
                                                              },
                                                            );
                                                          },
                                                        );
                                                      },
                                                    ),
                                                  ),

                                                  // Best Choices section - only show when categories are selected
                                                  // RepaintBoundary isolates menu items section repaints
                                                  // PERFORMANCE: Use Selector to only rebuild when filters change
                                                  RepaintBoundary(
                                                    child: Selector<
                                                        HomeProvider,
                                                        Set<String>>(
                                                      selector: (_, provider) =>
                                                          provider.state
                                                              .selectedCategories ??
                                                          {},
                                                      builder: (context,
                                                          selectedCategories,
                                                          child) {
                                                        // Hide Best Choices section when no categories are selected
                                                        if (selectedCategories.isEmpty) {
                                                          return const SizedBox.shrink();
                                                        }

                                                        // Show Best Choices section when categories are selected
                                                        return Column(
                                                          mainAxisSize: MainAxisSize.min,
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            // Spacing between category section and menu item section
                                                            const SizedBox(height: 16),

                                                            // Best Choices section title
                                                            const BestChoicesTitle(),

                                                            // Menu items section (Best Choices) - without title
                                                            Selector<
                                                                HomeProvider,
                                                                Set<String>>(
                                                              selector: (_,
                                                                      provider) =>
                                                                  provider.state
                                                                      .selectedCuisines ??
                                                                  {},
                                                              builder: (context,
                                                                  selectedCuisines,
                                                                  child) {
                                                                return Selector<
                                                                    HomeProvider,
                                                                    RangeValues?>(
                                                                  selector: (_,
                                                                          provider) =>
                                                                      provider
                                                                          .searchService
                                                                          .priceRange,
                                                                  builder: (context,
                                                                      priceRange,
                                                                      child) {
                                                                    return Selector<
                                                                        HomeProvider,
                                                                        bool>(
                                                                      selector: (_,
                                                                              provider) =>
                                                                          provider
                                                                              .searchService
                                                                              .isLocationFilterActive,
                                                                      builder: (context,
                                                                          isLocationFilterActive,
                                                                          child) {
                                                                        return Selector<
                                                                            HomeProvider,
                                                                            String>(
                                                                          selector: (_,
                                                                                  provider) =>
                                                                              provider
                                                                                  .state
                                                                                  .currentSearchQuery,
                                                                          builder: (context,
                                                                              currentSearchQuery,
                                                                              child) {
                                                                            return Selector<
                                                                                HomeProvider,
                                                                                bool>(
                                                                              selector: (_,
                                                                                      provider) =>
                                                                                  provider
                                                                                      .state
                                                                                      .isSearchMode,
                                                                              builder: (context,
                                                                                  isSearchMode,
                                                                                  child) {
                                                                                final homeProvider = Provider.of<
                                                                                        HomeProvider>(
                                                                                    context,
                                                                                    listen:
                                                                                        false);

                                                                                // When search is active, filter menu items by restaurants from search results
                                                                                // When location filter is active, also filter by location-restricted restaurants
                                                                                final shouldFilterByRestaurants = isLocationFilterActive ||
                                                                                    (isSearchMode && homeProvider.state.searchResults.isNotEmpty);

                                                                                final restaurantIds = shouldFilterByRestaurants
                                                                                    ? homeProvider
                                                                                        .state
                                                                                        .searchResults
                                                                                        .map((r) => r.id)
                                                                                        .where((id) => id.isNotEmpty)
                                                                                        .toSet()
                                                                                    : null;

                                                                                return MenuItemsWrapper(
                                                                                  dimensions:
                                                                                      _cachedMenuItemDimensions,
                                                                                  selectedCategories:
                                                                                      selectedCategories,
                                                                                  selectedCuisines:
                                                                                      selectedCuisines,
                                                                                  priceRange:
                                                                                      priceRange,
                                                                                  searchQuery:
                                                                                      currentSearchQuery.isNotEmpty
                                                                                          ? currentSearchQuery
                                                                                          : null,
                                                                                  allowedRestaurantIds: restaurantIds,
                                                                                );
                                                                              },
                                                                            );
                                                                          },
                                                                        );
                                                                      },
                                                                    );
                                                                  },
                                                                );
                                                              },
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    ),
                                                  ),

                                                  // Special Packs section - above LTO section
                                                  const RepaintBoundary(
                                                    child: SpecialPacksSection(),
                                                  ),

                                                  // Limited Time Offer section - Compact height based on content
                                                  const RepaintBoundary(
                                                    child:
                                                        LimitedTimeOfferSection(),
                                                  ),

                                                  const SizedBox(height: 8),

                                                  // Promo codes section (offers)
                                                  const RepaintBoundary(
                                                    child: PromoCodesSection(),
                                                  ),

                                                  // Safe area spacing between promo codes and restaurant title
                                                  Builder(
                                                    builder: (context) {
                                                      final viewPadding =
                                                          MediaQuery.of(context).padding;
                                                      return SizedBox(
                                                        height: viewPadding.top * 0.5,
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),

                                    // Filter chips section - pinned at top when scrolling
                                    // Similar to category section in restaurant details screen
                                    SliverPersistentHeader(
                                      pinned: true,
                                      delegate: _PinnedFilterChipsDelegate(
                                        height: 50.0, // 8px top + 34px chip + 8px bottom
                                        child: RepaintBoundary(
                                          child: Container(
                                            color: Colors.white,
                                            child: Selector<HomeProvider,
                                                RestaurantSearchService>(
                                              selector: (_, provider) =>
                                                  provider.searchService,
                                              builder: (BuildContext context,
                                                  RestaurantSearchService searchService,
                                                  Widget? child) {
                                                // Get HomeProvider from context for callbacks
                                                final homeProvider =
                                                    Provider.of<HomeProvider>(context,
                                                        listen: false);

                                                // Create a combined filter service that includes
                                                // HomeProvider's delivery fee range
                                                final CombinedFilterService
                                                    combinedFilterService =
                                                    CombinedFilterService(
                                                  searchService: searchService,
                                                  homeProvider: homeProvider,
                                                );

                                                return FilterChipsSectionWrapper(
                                                  combinedFilterService:
                                                      combinedFilterService,
                                                  homeProvider: homeProvider,
                                                  onLocationTap: () {
                                                    // Show location selection dialog
                                                    _showLocationFilterDialog(
                                                        context, homeProvider);
                                                  },
                                                  onCuisineTap: () {
                                                    // Show cuisine selection dialog
                                                    _showCuisineFilterDialog(
                                                        context, homeProvider);
                                                  },
                                                  onCategoryTap: () {
                                                    // Show category selection dialog
                                                    _showCategoryFilterDialog(
                                                        context, homeProvider);
                                                  },
                                                  onPriceTap: () {
                                                    // Show price range selection dialog
                                                    _showPriceFilterDialog(
                                                        context, homeProvider);
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // 🚀 PERFORMANCE FIX: Restaurants as TRUE sliver (O(1) layout!)
                                    // REMOVED: RestaurantsSectionWrapper with shrinkWrap (O(N) layout)
                                    // ADDED: RestaurantsSliverSection with SliverList (true virtualization)
                                    RestaurantsSliverSection(
                                      dimensions: _cachedDimensions,
                                      selectedCategories:
                                          home.state.selectedCategories,
                                      selectedCuisines:
                                          home.state.selectedCuisines,
                                      priceRange: home.searchService.priceRange,
                                      searchQuery:
                                          home.state.currentSearchQuery,
                                      // Pass search results when search is active
                                      searchResults: home.state.isSearchMode
                                          ? home.state.searchResults
                                          : null,
                                      isSearchMode: home.state.isSearchMode,
                                      allowedRestaurantIds: (home.searchService
                                              .isLocationFilterActive)
                                          ? home.state.searchResults
                                              .map((r) => r.id)
                                              .where((id) => id.isNotEmpty)
                                              .toSet()
                                          : null,
                                      onDataChanged: () {
                                        _triggerBatchDeliveryFeeCalculation(
                                          home.state.hasActiveFilters
                                              ? home.state.searchResults
                                              : home.availableRestaurants,
                                        );
                                      },
                                    ),

                                    // Bottom padding removed - scroll buffer moved to last card's container
                                    // The last restaurant card's container includes the scroll buffer in its bottom padding
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Fixed header on top - stays visible during scroll
            // Positioned using comprehensive layout helper for consistent spacing
            // RepaintBoundary isolates header repaints from rest of screen
            Positioned(
              top: HomeLayoutHelper.getHeaderTopPosition(context),
              left: HomeLayoutHelper.getHeaderHorizontalPadding(context),
              right: HomeLayoutHelper.getHeaderHorizontalPadding(context),
              child: RepaintBoundary(
                // PERFORMANCE FIX: Use ValueListenableBuilder for scroll-dependent UI
                // This rebuilds ONLY HomeHeader on scroll, not the entire Consumer tree
                child: Consumer<HomeProvider>(
                  builder: (context, homeProvider, _) {
                    return ValueListenableBuilder<double>(
                      valueListenable: homeProvider.scrollOffsetNotifier,
                      builder: (context, scrollOffset, child) {
                        return HomeHeader(
                          scrollOffset: scrollOffset,
                          maxScrollOffset: maxScrollOffset,
                          onSearchTap: () {
                            // Search functionality will be handled by the header
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLocationFilterDialog(
      BuildContext context, HomeProvider homeProvider) async {
    try {
      // Import the map location picker screen
      final result = await Navigator.pushNamed(
        context,
        "/map-location-picker",
      );

      if (result != null && result is Map<String, dynamic>) {
        final address = result["address"] as String?;
        final latitude = (result["latitude"] as num?)?.toDouble();
        final longitude = (result["longitude"] as num?)?.toDouble();

        if (address != null && latitude != null && longitude != null) {
          // Update the location filter with both address and coordinates
          homeProvider.searchService
              .setLocationFilterWithCoordinates(address, latitude, longitude);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Location set to: $address"),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } on Exception catch (e) {
      debugPrint("❌ Error opening map location picker: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error opening map: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCuisineFilterDialog(
      BuildContext context, HomeProvider homeProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) =>
          CuisineSelectorModal(searchService: homeProvider.searchService),
    );
  }

  void _showCategoryFilterDialog(
      BuildContext context, HomeProvider homeProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) =>
          CategorySelectorModal(searchService: homeProvider.searchService),
    );
  }

  void _showPriceFilterDialog(BuildContext context, HomeProvider homeProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => PriceSelectorModal(
        searchService: homeProvider.searchService,
        cachedPriceRange: null, // We"ll let it load from database
      ),
    );
  }

  // ==================== REMOVED METHODS ====================
  // The following methods have been moved to RestaurantsSliverSection widget:
  // - _buildLoadingSkeleton() -> handled by RestaurantsSliverSection
  // - _buildEmptyState() -> handled by RestaurantsSliverSection
  // - _buildAnimatedRestaurantGrid() -> handled by RestaurantsSliverSection
  // - _buildRestaurantGridContent() -> handled by RestaurantsSliverSection
  // All restaurant rendering logic is now in RestaurantsSliverSection
}

/// Persistent header delegate for the pinned filter chips section
/// Similar to PinnedSearchAndCategoriesDelegate in restaurant details screen
class _PinnedFilterChipsDelegate extends SliverPersistentHeaderDelegate {
  _PinnedFilterChipsDelegate({
    required this.child,
    required this.height,
  });

  final Widget child;
  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: height,
      color: Colors.white,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedFilterChipsDelegate oldDelegate) {
    return child != oldDelegate.child || height != oldDelegate.height;
  }
}
