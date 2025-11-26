import "dart:async";

import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:provider/provider.dart";
import "package:shimmer/shimmer.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../l10n/app_localizations.dart";
import "../../models/menu_item.dart";
import "../../screens/menu_items_list_screen.dart";
import "../../services/socket_service.dart";
import "../../utils/safe_parse.dart";
import "../menu_item_full_popup/helpers/popup_helper.dart";
import "lto_section/limited_time_offer_card.dart";

/// High-performance Limited Time Offer section
/// Optimized for minimal rebuilds and maximum performance
/// Compact height based on content (cards + title + curves) with horizontal scrollable cards
class LimitedTimeOfferSection extends StatefulWidget {
  const LimitedTimeOfferSection({super.key, this.restaurantId});

  /// Optional restaurant ID to filter LTO items by restaurant
  /// If not provided, shows LTO items from all restaurants
  final String? restaurantId;

  @override
  State<LimitedTimeOfferSection> createState() =>
      _LimitedTimeOfferSectionState();
}

class _LimitedTimeOfferSectionState extends State<LimitedTimeOfferSection>
    with SingleTickerProviderStateMixin {
  // Services
  late SocketService _socketService;
  final _supabase = Supabase.instance.client;

  // State
  bool _isLoading = true;
  bool _hasError = false;
  List<MenuItem> _ltoItems = [];

  // Performance: Cache max offers calculation to avoid recalculation on every build
  Map<String, dynamic>? _cachedMaxOffers;
  String? _cachedMaxOffersKey; // Cache key based on active items IDs

  // Real-time state - use ValueNotifier to avoid full rebuilds
  final Map<String, ValueNotifier<bool>> _itemAvailabilityNotifiers = {};
  final Map<String, ValueNotifier<double>> _dynamicPriceNotifiers = {};

  // Subscriptions
  StreamSubscription? _menuUpdatesSubscription;
  StreamSubscription? _priceUpdatesSubscription;

  // Auto-scroll functionality
  final ScrollController _scrollController = ScrollController();
  final ScrollController _offersScrollController = ScrollController();
  Timer? _autoScrollTimer;
  Timer? _userInteractionTimer;
  bool _isUserScrolling = false;
  bool _isParentScrolling = false; // Track parent scroll state
  int _currentCardIndex = 0;
  double _cachedCardWidth = 0;
  double _cachedCardSpacing = 0;
  static const Duration _autoScrollInterval = Duration(seconds: 2);
  static const Duration _scrollAnimationDuration = Duration(milliseconds: 800);
  static const Duration _userInteractionDelay = Duration(seconds: 5);

  // Smooth scrolling for offers - using AnimationController for butter-smooth animation
  AnimationController? _offersAnimationController;
  Animation<double>? _offersScrollAnimation;
  bool _hasStartedAnimation =
      false; // Track if animation has started (for cooldown on first launch)

  // Performance: Cache MediaQuery and dimensions
  late Size _screenSize;
  late double _sectionHeight;
  late double _cardHeight;
  late double _cardWidth;

  // Performance: Cache padding calculations
  late EdgeInsets _listPadding;
  late EdgeInsets _itemPadding;

  // Performance: Cache itemExtent calculation
  late double _itemExtent;
  late double _cacheExtent;

  // Background color constant
  static const Color _backgroundColor = Color(0xFFF8EDED);

  @override
  void initState() {
    super.initState();
    _initializeOffersAnimation();
    _initializeServices();
    _loadLTOItems();
    _setupScrollListener();
    _setupParentScrollDetection();
  }

  /// Initialize smooth animation for infinite scrolling
  void _initializeOffersAnimation() {
    _offersAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(
          seconds: 8), // Faster scroll speed - 8 seconds per segment
    );

    _offersScrollAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _offersAnimationController!,
      curve: Curves.linear, // Linear for constant, smooth speed
    ));

    // Listen to animation status to handle seamless infinite looping
    _offersAnimationController!.addStatusListener(_onAnimationStatusChanged);

    // Listen to animation updates and update scroll position
    _offersScrollAnimation!.addListener(_onOffersAnimationUpdate);
  }

  /// Handle animation status changes for infinite seamless looping
  void _onAnimationStatusChanged(AnimationStatus status) {
    if (!mounted || !_offersScrollController.hasClients) return;

    // When animation completes one cycle, seamlessly continue to next segment
    if (status == AnimationStatus.completed) {
      try {
        final maxScroll = _offersScrollController.position.maxScrollExtent;
        if (maxScroll <= 0) return;

        final segmentWidth = maxScroll / 2;
        final currentScroll = _offersScrollController.offset;

        // If we're in the duplicate segment (past segmentWidth), jump to equivalent position in original
        // This is seamless because duplicate matches original
        if (currentScroll >= segmentWidth) {
          // We've scrolled through duplicate, jump to equivalent position in original
          // This creates infinite scroll: original → duplicate → (seamless jump) → original → duplicate...
          _offersScrollController.jumpTo(currentScroll - segmentWidth);
        } else {
          // We're in original, jump to equivalent position in duplicate to continue forward
          _offersScrollController.jumpTo(currentScroll + segmentWidth);
        }

        // Immediately reset and continue animation for seamless infinite loop
        _offersAnimationController!.reset();
        _offersAnimationController!.forward();
      } catch (e) {
        // Silently handle errors
      }
    }
  }

  /// Handle animation updates for infinite smooth scrolling
  void _onOffersAnimationUpdate() {
    if (!mounted || !_offersScrollController.hasClients) return;

    try {
      final position = _offersScrollController.position;
      final maxScroll = position.maxScrollExtent;
      if (maxScroll <= 0) return;

      final segmentWidth = maxScroll / 2;
      final animationValue = _offersScrollAnimation!.value;
      final currentScroll = position.pixels;

      // Calculate scroll position within current segment
      // Animation value (0-1) maps to one segment width
      final segmentProgress = animationValue * segmentWidth;

      // Determine which segment we're in and calculate absolute position
      double scrollPosition;
      if (currentScroll < segmentWidth) {
        // We're in original segment, scroll forward
        scrollPosition = segmentProgress;
      } else {
        // We're in duplicate segment, continue scrolling forward
        scrollPosition = segmentWidth + segmentProgress;
      }

      // Clamp to valid range
      scrollPosition = scrollPosition.clamp(0.0, maxScroll);

      // Update scroll position smoothly
      if ((scrollPosition - currentScroll).abs() > 0.1) {
        _offersScrollController.jumpTo(scrollPosition);
      }
    } catch (e) {
      // Silently handle any errors - animation will continue seamlessly
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache MediaQuery dimensions once
    _screenSize = MediaQuery.of(context).size;

    // Calculate card width to show 3.1 cards per screen width
    // Formula: (screen width - total padding and spacing) / 3.1 cards
    // Breakdown: left padding (16px) + 3.1 cards + 2.1 spacings between cards (8px each = 16.8px)
    // Total padding + spacing = 16 + 16.8 = 32.8px
    // This ensures exactly 3.1 cards are visible with proper spacing, creating a peek effect for the next card
    _cardWidth = (_screenSize.width - 32.8) / 3.1;

    // Use fixed card height based on aspect ratio (width:height ratio ~1:1.4 for card design)
    // This ensures consistent card sizing regardless of screen height
    _cardHeight = _cardWidth * 1.4; // Aspect ratio maintains card proportions

    // Calculate section height based on actual content (title + cards + minimal bottom space)
    // Title starts at 0px (overlaps with top curve), then cards, then minimal bottom curve space
    final titleFontSize = _screenSize.width < 360 ? 20.0 : 24.0;
    final titleHeight = titleFontSize * 1.2;
    const titleTop =
        0.0; // Title positioned at 0px from top (overlaps with curve)
    const titleBottomGap = 12.0; // Proper safe space from title bottom to cards

    // Calculate section height: title + gap + cards + minimal bottom space
    // Section ends right after cards, bottom curve overlays on top of cards
    final titleBottom = titleTop + titleHeight;
    final cardsTop = titleBottom + titleBottomGap;
    final cardsBottom = cardsTop + _cardHeight;
    // Height = cards bottom position + tiny space (bottom curve overlaps cards)
    final minRequiredHeight =
        cardsBottom + 4.0; // Minimal 4px for bottom curve decorative overlay

    // Use the calculated minimum height based on content
    // Section height ends right after cards with minimal decorative space
    _sectionHeight = minRequiredHeight;

    // Cache padding calculations
    // Title and cards are now positioned absolutely, no need for topPadding
    _listPadding = const EdgeInsets.only(left: 16);
    _itemPadding = const EdgeInsets.only(right: 8);

    // Cache itemExtent and cacheExtent
    _cachedCardSpacing = 8.0;
    _itemExtent = _cardWidth + _cachedCardSpacing;
    _cacheExtent = _cardWidth * 3; // Only cache 3 cards ahead/behind
  }

  /// Setup listener to detect parent scroll view scrolling
  /// This pauses auto-scroll when user is scrolling the main screen
  void _setupParentScrollDetection() {
    // Try to find parent ScrollController via context
    // This is a best-effort approach - if parent scrolls, pause auto-scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Check if we're in a scrollable context
      final scrollable = Scrollable.maybeOf(context);
      if (scrollable != null) {
        // Listen to parent scroll notifications
        scrollable.position.isScrollingNotifier
            .addListener(_onParentScrollChanged);
      }
    });
  }

  void _onParentScrollChanged() {
    if (!mounted) return;
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable != null) {
      final isScrolling = scrollable.position.isScrollingNotifier.value;
      if (_isParentScrolling != isScrolling) {
        setState(() {
          _isParentScrolling = isScrolling;
        });
        if (isScrolling) {
          // Pause auto-scroll when parent is scrolling
          _autoScrollTimer?.cancel();
        } else if (_ltoItems.isNotEmpty && !_isUserScrolling) {
          // Resume auto-scroll when parent stops scrolling
          _setupAutoScroll();
        }
      }
    }
  }

  void _initializeServices() {
    try {
      // Initialize Socket.io service
      _socketService = Provider.of<SocketService>(context, listen: false);

      // Set up real-time listeners
      _setupRealTimeListeners();
    } on Exception catch (e) {
      debugPrint("❌ Error initializing LTO services: $e");
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

  /// Load Limited Time Offer items from database
  Future<void> _loadLTOItems() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      debugPrint("🎯 Loading Limited Time Offer items...");

      // Build query - add restaurant filter if specified
      var query =
          _supabase.from('menu_items').select('*').eq('is_available', true);

      // Filter by restaurant ID if provided
      if (widget.restaurantId != null && widget.restaurantId!.isNotEmpty) {
        final restaurantId = widget.restaurantId!;
        query = query.eq('restaurant_id', restaurantId);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(20); // Load top 20 most recent

      // Parse items and handle missing images gracefully
      final items = <MenuItem>[];
      for (final json in (response as List)) {
        try {
          final item = MenuItem.fromJson(json);
          // Only include items with active LTO offers and valid images
          if (item.isOfferActive &&
              !item.hasExpiredLTOOffer &&
              item.image.isNotEmpty) {
            items.add(item);
          }
        } catch (e) {
          // Skip items that can't be parsed (e.g., missing required fields like image)
          debugPrint("⚠️ Skipping LTO item due to parsing error: $e");
          // Log the item ID if available for debugging
          final itemId = json['id']?.toString() ?? 'unknown';
          debugPrint("   Item ID: $itemId");
        }
      }

      debugPrint("✅ Loaded ${items.length} LTO items");

      // Performance: Initialize ValueNotifiers for real-time updates
      // Dispose old notifiers first
      for (final notifier in _itemAvailabilityNotifiers.values) {
        notifier.dispose();
      }
      for (final notifier in _dynamicPriceNotifiers.values) {
        notifier.dispose();
      }
      _itemAvailabilityNotifiers.clear();
      _dynamicPriceNotifiers.clear();

      // Create new notifiers
      for (final item in items) {
        _itemAvailabilityNotifiers[item.id] = ValueNotifier(item.isAvailable);
        // Use price column for discounted price (not effectivePrice)
        _dynamicPriceNotifiers[item.id] = ValueNotifier(item.price);
      }

      if (mounted) {
        setState(() {
          _ltoItems = items;
          _isLoading = false;
          _hasError = false;
          // Performance: Clear max offers cache when items are reloaded
          _cachedMaxOffers = null;
          _cachedMaxOffersKey = null;
        });

        // Start auto-scroll after items are loaded
        if (items.isNotEmpty) {
          _setupAutoScroll();
          // Also setup offers auto-scroll
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _setupOffersAutoScroll();
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Error loading LTO items: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  // Performance: Removed _createEnhancedMenuItem to avoid per-frame allocations
  // Now passing ValueNotifiers directly to cards

  void _navigateToMenuItemDetails(MenuItem menuItem) {
    // Show the full-width popup
    PopupHelper.showMenuItemPopup(
      context: context,
      menuItem: menuItem,
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
        // Refresh LTO items when data changes
        if (mounted) {
          _loadLTOItems();
        }
      },
    );
  }

  /// Setup scroll listener to detect user interaction
  void _setupScrollListener() {
    _scrollController.addListener(() {
      // Detect if user is manually scrolling
      if (_scrollController.hasClients &&
          _scrollController.position.isScrollingNotifier.value) {
        _onUserScroll();
      }
    });
  }

  /// Setup smooth auto-scroll for offers text using animation
  void _setupOffersAutoScroll() {
    if (!mounted || _offersAnimationController == null) return;

    // Wait for the scroll controller to be attached
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_offersScrollController.hasClients) {
        // Retry after a short delay if controller isn't ready
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _offersScrollController.hasClients) {
            _startOffersAutoScroll();
          }
        });
        return;
      }
      _startOffersAutoScroll();
    });
  }

  void _startOffersAutoScroll() {
    if (!mounted || _offersAnimationController == null) return;

    // Check if scroll controller is ready and we have content to scroll
    if (!_offersScrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && _offersScrollController.hasClients) {
          _startOffersAutoScroll();
        }
      });
      return;
    }

    try {
      final maxScroll = _offersScrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;

      // Add cooldown before starting rolling on first launch
      if (!_hasStartedAnimation) {
        _hasStartedAnimation = true;
        // Wait 5 seconds before starting the animation on first launch
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted &&
              _offersAnimationController != null &&
              _offersScrollController.hasClients) {
            // Start the smooth continuous loop animation
            if (!_offersAnimationController!.isAnimating) {
              _offersAnimationController!.forward();
            }
          }
        });
      } else {
        // On subsequent starts (after first launch), start immediately
        if (!_offersAnimationController!.isAnimating) {
          _offersAnimationController!.forward();
        }
      }
    } catch (e) {
      // Silently handle errors
    }
  }

  /// Setup auto-scroll timer for cards

  void _setupAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(_autoScrollInterval, (_) {
      // Performance: Don't auto-scroll if user is scrolling or parent is scrolling
      if (!_isUserScrolling && !_isParentScrolling && mounted) {
        _scrollToNextCard();
      }
    });
  }

  /// Handle user scroll interaction
  void _onUserScroll() {
    // Performance: No setState needed, just update the flag
    _isUserScrolling = true;

    // Cancel existing timer
    _userInteractionTimer?.cancel();

    // Resume auto-scroll after delay
    _userInteractionTimer = Timer(_userInteractionDelay, () {
      if (mounted) {
        _isUserScrolling = false;
      }
    });
  }

  /// Pause auto-scroll (called when user taps a card)
  void _pauseAutoScroll() {
    _onUserScroll();
  }

  /// Scroll to next card with smooth animation
  void _scrollToNextCard() {
    if (!_scrollController.hasClients || _ltoItems.isEmpty) return;

    final int totalCards = _ltoItems.length > 10 ? 10 : _ltoItems.length;

    // Calculate next card index (loop back to start)
    _currentCardIndex = (_currentCardIndex + 1) % totalCards;

    // Calculate scroll offset
    final double targetOffset =
        _currentCardIndex * (_cachedCardWidth + _cachedCardSpacing);
    final double maxScroll = _scrollController.position.maxScrollExtent;

    // Ensure we don't scroll beyond the end
    final double scrollOffset = targetOffset > maxScroll ? 0 : targetOffset;

    // Performance: Use smooth animation for all transitions (including loop back)
    // This creates a seamless, continuous scrolling experience
    _scrollController.animateTo(
      scrollOffset,
      duration: _scrollAnimationDuration,
      curve: Curves.fastOutSlowIn, // Smoother curve than easeInOut
    );
  }

  /// Cache card dimensions for auto-scroll calculations
  void _cacheCardDimensions(double cardWidth, double cardSpacing) {
    _cachedCardWidth = cardWidth;
    _cachedCardSpacing = cardSpacing;
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _userInteractionTimer?.cancel();
    _offersScrollAnimation?.removeListener(_onOffersAnimationUpdate);
    _offersAnimationController?.removeStatusListener(_onAnimationStatusChanged);
    _offersAnimationController?.dispose();
    _scrollController.dispose();
    _offersScrollController.dispose();
    _menuUpdatesSubscription?.cancel();
    _priceUpdatesSubscription?.cancel();

    // Remove parent scroll listener (safely handle if widget is already deactivated)
    try {
      final scrollable = Scrollable.maybeOf(context);
      if (scrollable != null) {
        scrollable.position.isScrollingNotifier
            .removeListener(_onParentScrollChanged);
      }
    } catch (e) {
      // Widget may already be deactivated, ignore error
      debugPrint(
          '⚠️ LimitedTimeOfferSection: Error removing scroll listener: $e');
    }

    // Performance: Dispose all ValueNotifiers
    for (final notifier in _itemAvailabilityNotifiers.values) {
      notifier.dispose();
    }
    for (final notifier in _dynamicPriceNotifiers.values) {
      notifier.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Performance: Use cached dimensions instead of MediaQuery lookups

    // Show loading state
    if (_isLoading) {
      return _buildSkeletonLoading();
    }

    // Show error state
    if (_hasError) {
      return _buildErrorState();
    }

    // Filter out any expired items that may have expired since loading
    final activeItems = _ltoItems
        .where((item) => item.isOfferActive && !item.hasExpiredLTOOffer)
        .toList();

    // Update state if expired items were filtered out
    // Defer update to avoid setState during build phase
    final activeItemsCount = activeItems.length;
    if (activeItemsCount != _ltoItems.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Re-filter to ensure we have current state
          final currentActiveItems = _ltoItems
              .where((item) => item.isOfferActive && !item.hasExpiredLTOOffer)
              .toList();
          if (currentActiveItems.length != _ltoItems.length) {
            setState(() {
              _ltoItems = currentActiveItems;
              // Performance: Clear max offers cache when items are updated
              _cachedMaxOffers = null;
              _cachedMaxOffersKey = null;
            });
          }
        }
      });
    }

    // Show empty state if no LTO items
    if (activeItems.isEmpty) {
      return _buildEmptyState();
    }

    // Show LTO items in horizontal list with pink background and curved white sections
    return RepaintBoundary(
      child: SizedBox(
        height: _sectionHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Main pink background - fill entire stack
            Positioned.fill(
              child: Container(
                color: _backgroundColor,
              ),
            ),

            // Curved white section at top
            _buildCurvedWhiteTop(),

            // Curved white section at bottom
            _buildCurvedWhiteBottom(),

            // LTO Section Title with Baloo font - pass activeItems for dynamic updates
            _buildLTOTitle(activeItems),

            // Horizontal scrollable cards positioned below title
            _buildItemsList(activeItems),
          ],
        ),
      ),
    );
  }

  /// Build curved white section at the top
  Widget _buildCurvedWhiteTop() {
    const curveHeight = 20.0; // Reduced curve height for more compact design
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SizedBox(
        height: curveHeight,
        width: _screenSize.width,
        child: CustomPaint(
          painter: _CurvedWhiteTopPainter(),
        ),
      ),
    );
  }

  /// Build curved white section at the bottom
  Widget _buildCurvedWhiteBottom() {
    const curveHeight =
        10.0; // Minimal curve height - small decorative overlay at bottom
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SizedBox(
        height: curveHeight,
        width: _screenSize.width,
        child: CustomPaint(
          painter: _CurvedWhiteBottomPainter(),
        ),
      ),
    );
  }

  /// Calculate max discounts and delivery offers from all active LTO items
  Map<String, dynamic> _calculateMaxOffers(List<MenuItem> activeItems) {
    // Performance: Generate cache key based on active items IDs
    final cacheKey = activeItems.map((item) => item.id).join(',');

    // Performance: Return cached result if items haven't changed
    if (_cachedMaxOffers != null && _cachedMaxOffersKey == cacheKey) {
      return _cachedMaxOffers!;
    }

    double? maxDiscountPercent;
    bool hasFreeDelivery = false;
    double? maxDeliveryPercent;
    double? maxDeliveryAmount;

    debugPrint(
        '🎯 Calculating max offers from ${activeItems.length} active items');

    for (final item in activeItems) {
      // Calculate max discount percentage
      if (item.hasOfferType('special_price')) {
        final discount = item.discountPercentage;
        debugPrint('   Item ${item.name}: discount = $discount%');
        if (discount != null &&
            (maxDiscountPercent == null || discount > maxDiscountPercent)) {
          maxDiscountPercent = discount;
        }
      }

      // Calculate delivery offers - check active LTO pricing options only
      // Since hasOfferType() already finds the active pricing, we need to find active pricings ourselves
      final pricingOptions = item.pricingOptions;
      final now = DateTime.now();

      // Check all pricing options for active LTO offers with delivery
      for (final pricing in pricingOptions) {
        // Check if this is an active LTO pricing
        final isLTO = pricing['is_limited_offer'] == true;
        if (!isLTO) continue;

        // Check if offer is currently active (between start and end dates)
        // Use safeUtc for safe date parsing (handles ISO strings, timestamps, etc.)
        final startDate = safeUtc(pricing['offer_start_at']);
        final endDate = safeUtc(pricing['offer_end_at']);

        final startOk = startDate == null || now.isAfter(startDate);
        final endOk = endDate == null || now.isBefore(endDate);

        if (!startOk || !endOk) continue; // Skip inactive offers

        // Check if this active pricing has special_delivery
        final offerTypes = pricing['offer_types'] as List?;
        if (offerTypes != null && offerTypes.contains('special_delivery')) {
          debugPrint(
              '   Item ${item.name}: found ACTIVE pricing with special_delivery');
          final offerDetails =
              pricing['offer_details'] as Map<String, dynamic>?;
          debugPrint('   Item ${item.name}: offerDetails = $offerDetails');

          if (offerDetails != null && offerDetails.isNotEmpty) {
            final deliveryType = offerDetails['delivery_type'] as String?;
            final deliveryValue = offerDetails['delivery_value'];

            debugPrint(
                '   Item ${item.name}: deliveryType = $deliveryType, deliveryValue = $deliveryValue');

            if (deliveryType == 'free') {
              hasFreeDelivery = true;
              debugPrint('   Item ${item.name}: Found free delivery');
            } else if (deliveryType == 'percentage' && deliveryValue != null) {
              final percent = (deliveryValue is num)
                  ? deliveryValue.toDouble()
                  : double.tryParse(deliveryValue.toString());
              if (percent != null) {
                debugPrint(
                    '   Item ${item.name}: Found percentage delivery discount: $percent%');
                if (maxDeliveryPercent == null ||
                    percent > maxDeliveryPercent) {
                  maxDeliveryPercent = percent;
                }
              }
            } else if (deliveryType == 'fixed' && deliveryValue != null) {
              final amount = (deliveryValue is num)
                  ? deliveryValue.toDouble()
                  : double.tryParse(deliveryValue.toString());
              if (amount != null) {
                debugPrint(
                    '   Item ${item.name}: Found fixed delivery discount: $amount DA');
                if (maxDeliveryAmount == null || amount > maxDeliveryAmount) {
                  maxDeliveryAmount = amount;
                }
              }
            }
          } else {
            debugPrint('   Item ${item.name}: offerDetails is null or empty');
          }
        }
      }
    }

    debugPrint('🎯 Final max offers:');
    debugPrint('   maxDiscountPercent: $maxDiscountPercent');
    debugPrint('   hasFreeDelivery: $hasFreeDelivery');
    debugPrint('   maxDeliveryPercent: $maxDeliveryPercent');
    debugPrint('   maxDeliveryAmount: $maxDeliveryAmount');

    final result = {
      'maxDiscountPercent': maxDiscountPercent,
      'hasFreeDelivery': hasFreeDelivery,
      'maxDeliveryPercent': maxDeliveryPercent,
      'maxDeliveryAmount': maxDeliveryAmount,
    };

    // Performance: Cache the result
    _cachedMaxOffers = result;
    _cachedMaxOffersKey = cacheKey;

    return result;
  }

  /// Build rolling offers expression widget
  Widget _buildRollingOffers(List<MenuItem> activeItems) {
    final offers = _calculateMaxOffers(activeItems);
    final locale = Localizations.localeOf(context);
    final isArabic = locale.languageCode == 'ar';
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final l10n = AppLocalizations.of(context);

    final fontSize = _screenSize.width < 360 ? 12.0 : 14.0;
    final smallFontSize = _screenSize.width < 360 ? 10.0 : 12.0;

    final List<Widget> offerWidgets = [];

    // Add "up to [max % off]" in yellow container
    if (offers['maxDiscountPercent'] != null) {
      final maxPercent = (offers['maxDiscountPercent'] as double).round();
      offerWidgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.yellow[600],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            isArabic ? 'حتى $maxPercent% خصم' : 'Up to $maxPercent% off',
            style: GoogleFonts.poppins(
              fontSize: smallFontSize,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ),
      );
      offerWidgets.add(const SizedBox(width: 8));
    }

    // Fallback logic for delivery fees:
    // 1. If free delivery exists, show only free delivery (ignore others)
    // 2. If no free delivery, fall back to percentage discount
    // 3. If no free delivery and no percentage, show fixed amount
    // 4. If none exist, show only "up to" discount with no roll effect

    bool hasDeliveryOffer = false;

    if (offers['hasFreeDelivery'] == true) {
      // Priority 1: Free delivery exists - show only this, ignore others
      hasDeliveryOffer = true;
      offerWidgets.add(
        Text(
          isArabic ? 'استمتع بـ' : 'Enjoy',
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      );
      offerWidgets.add(const SizedBox(width: 6));
      offerWidgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFB2AC88),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.moped, size: smallFontSize, color: Colors.black87),
              const SizedBox(width: 4),
              Text(
                l10n?.freeDeliveryLabel ?? 'Free delivery',
                style: GoogleFonts.poppins(
                  fontSize: smallFontSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (offers['maxDeliveryPercent'] != null) {
      // Priority 2: No free delivery, but percentage discount exists
      hasDeliveryOffer = true;
      offerWidgets.add(
        Text(
          isArabic ? 'استمتع بـ' : 'Enjoy',
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      );
      offerWidgets.add(const SizedBox(width: 6));
      final maxPercent = (offers['maxDeliveryPercent'] as double).round();
      offerWidgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFB2AC88),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.moped, size: smallFontSize, color: Colors.black87),
              const SizedBox(width: 4),
              Text(
                isArabic ? '-$maxPercent%' : '-$maxPercent%',
                style: GoogleFonts.poppins(
                  fontSize: smallFontSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (offers['maxDeliveryAmount'] != null) {
      // Priority 3: No free delivery and no percentage, but fixed amount exists
      hasDeliveryOffer = true;
      offerWidgets.add(
        Text(
          isArabic ? 'استمتع بـ' : 'Enjoy',
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      );
      offerWidgets.add(const SizedBox(width: 6));
      final maxAmount = (offers['maxDeliveryAmount'] as double).round();
      offerWidgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFB2AC88),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.moped, size: smallFontSize, color: Colors.black87),
              const SizedBox(width: 4),
              Text(
                isArabic ? '-$maxAmount دج' : '-$maxAmount DA',
                style: GoogleFonts.poppins(
                  fontSize: smallFontSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      );
    }
    // Priority 4: No delivery offers - show only "up to" discount with no roll effect
    // (handled below by checking hasDeliveryOffer)

    // Return empty if no offers at all
    if (offerWidgets.isEmpty) {
      return const SizedBox.shrink();
    }

    // If no delivery offers exist, show only "up to" discount with no roll effect
    if (!hasDeliveryOffer) {
      // Just show the discount badge without scrolling
      return Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        children: offerWidgets,
      );
    }

    // Create rolling/marquee effect with auto-scroll when delivery offers exist
    // Takes full available width and scrolls when content overflows
    return LayoutBuilder(
      builder: (context, constraints) {
        // Measure content width to determine if scrolling is needed
        final contentWidth = offerWidgets.length * 200.0; // Approximate width
        final needsScroll = contentWidth > constraints.maxWidth;

        // Start auto-scroll after the widget is built and controller is attached
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && needsScroll) {
            _setupOffersAutoScroll();
          }
        });

        if (!needsScroll) {
          // Content fits, no scrolling needed - align to start
          return Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
            children: offerWidgets,
          );
        }

        // Content is long, enable auto-scrolling with seamless loop
        // Use RepaintBoundary to reduce repaint overhead and improve performance
        return RepaintBoundary(
          child: SingleChildScrollView(
            controller: _offersScrollController,
            scrollDirection: Axis.horizontal,
            physics:
                const NeverScrollableScrollPhysics(), // Disable manual scrolling for auto-scroll
            child: Row(
              mainAxisSize: MainAxisSize.min,
              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              children: [
                // First set of offers widgets
                ...offerWidgets,
                // Add spacing for seamless transition
                const SizedBox(width: 60),
                // Duplicate for seamless loop effect
                ...offerWidgets,
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build LTO section title with Baloo/Baloo Bhaijaan font
  Widget _buildLTOTitle(List<MenuItem> activeItems) {
    final locale = Localizations.localeOf(context);
    final isArabic = locale.languageCode == 'ar';
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final l10n = AppLocalizations.of(context);

    // Responsive font size
    final fontSize = _screenSize.width < 360 ? 20.0 : 24.0;

    // Use Baloo Bhaijaan 2 for Arabic, Baloo 2 for English/French
    // Using getFont for reliable font loading from Google Fonts
    final fontFamily = isArabic ? 'Baloo Bhaijaan 2' : 'Baloo 2';
    final textStyle = GoogleFonts.getFont(
      fontFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: Colors.black,
      height: 1.2,
      letterSpacing: -0.5,
      shadows: [
        Shadow(
          offset: const Offset(0, 1),
          blurRadius: 2,
          color: Colors.black.withOpacity(0.1),
        ),
      ],
    );

    // Position title at absolute top (0px) to eliminate any gap
    // Title sits directly on the curved white section overlay
    const titleTop = 0.0; // Position title at 0px from top to eliminate gap

    return Positioned(
      top: titleTop,
      left: isRTL ? null : 20,
      right: isRTL ? 20 : null,
      child: SizedBox(
        width: _screenSize.width -
            40, // Full width minus left/right padding (20 each)
        child: GestureDetector(
          onTap: _handleTitleTap,
          behavior: HitTestBehavior.opaque,
          child: Row(
            textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
            children: [
              // Title text with Baloo font
              Text(
                l10n?.limitedTimeOffers ?? 'Limited time offers',
                style: textStyle,
              ),
              const SizedBox(width: 8),
              // Rolling offers expression - takes full available space between title and arrow
              Expanded(
                child: _buildRollingOffers(activeItems),
              ),
              const SizedBox(width: 8),
              // Chevron icon with degraded linear gradient (90% opacity, bold)
              // Creates a faded/feathered edge effect matching the design
              // Positioned at the end of the width
              ShaderMask(
                shaderCallback: (Rect bounds) {
                  // Linear gradient at 90 degrees (vertical) for degraded/faded effect
                  // Creates soft, feathered edges from dark gray to lighter gray
                  // 90% opacity throughout for the degraded appearance
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF1A1A1A)
                          .withOpacity(0.9), // Very dark gray, 90% opacity
                      const Color(0xFF4A4A4A)
                          .withOpacity(0.9), // Medium dark gray, 90% opacity
                      const Color(0xFF6B6B6B).withOpacity(
                          0.85), // Lighter gray, 85% opacity for fade
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.srcIn,
                child: Icon(
                  isRTL ? Icons.chevron_left : Icons.chevron_right,
                  size: fontSize *
                      0.85, // Bold, prominent size (85% of title font size)
                  color: Colors
                      .black87, // Dark base color that gets masked by gradient
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handle tapping the LTO section title - navigate to menu items list screen in LTO mode
  void _handleTitleTap() {
    try {
      debugPrint('📱 Navigation: LTO title tap → Opening LTO mode');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const MenuItemsListScreen(),
          settings: const RouteSettings(arguments: {'ltoMode': true}),
        ),
      );
    } catch (e) {
      debugPrint('❌ Failed to handle LTO title tap: $e');
    }
  }

  Widget _buildItemsList(List<MenuItem> activeItems) {
    // Performance: Use cached dimensions and padding
    final int totalItems = activeItems.length;
    final int visibleCount =
        totalItems > 10 ? 10 : totalItems; // show only top 10

    // Cache dimensions for auto-scroll calculations (already cached in didChangeDependencies)
    _cacheCardDimensions(_cardWidth, _cachedCardSpacing);

    // Calculate title height and position to place cards right below it
    // Title is positioned at 0px from top to match height calculation
    const titleTop = 0.0;
    final fontSize = _screenSize.width < 360 ? 20.0 : 24.0;
    final titleHeight =
        fontSize * 1.2; // Font size * line height for accurate title height
    final titleBottom = titleTop + titleHeight; // Title bottom position
    final cardsTop =
        titleBottom + 12; // Proper safe space (12px) after title for better spacing

    return Positioned(
      top: cardsTop,
      left: 0,
      right: 0,
      child: SizedBox(
        height: _cardHeight,
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: _listPadding,
          clipBehavior: Clip.none,
          physics:
              const ClampingScrollPhysics(), // Smooth scroll physics for auto-scroll
          itemCount: visibleCount,
          // Performance: Use cached itemExtent for predictable layout (O(1) layout)
          itemExtent: _itemExtent,
          // Performance: Disable keep-alives to reduce memory (cards are simple)
          addAutomaticKeepAlives: false,
          // Performance: Enable repaint boundaries for each item
          addRepaintBoundaries: true,
          // Performance: Limit cache extent to render only visible + 3 cards (memory efficient)
          cacheExtent: _cacheExtent,
          itemBuilder: (context, index) {
            final menuItem = activeItems[index];
            // Performance: Pass ValueNotifiers directly instead of creating new MenuItem
            // Use cached padding to avoid EdgeInsets allocation per build
            // Use stable key to prevent widget tree conflicts
            return Padding(
              key: ValueKey('lto_card_${menuItem.id}'),
              padding: _itemPadding,
              child: LimitedTimeOfferCard(
                key: ValueKey(menuItem.id),
                menuItem: menuItem,
                availabilityNotifier: _itemAvailabilityNotifiers[menuItem.id],
                priceNotifier: _dynamicPriceNotifiers[menuItem.id],
                onTap: () {
                  _pauseAutoScroll();
                  _navigateToMenuItemDetails(menuItem);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  /// Build skeleton loading state with shimmer effect
  Widget _buildSkeletonLoading() {
    // Performance: Use cached dimensions
    // Match the same positioning as main build
    const titleTop = 0.0; // Title positioned at 0px from top to eliminate gap
    final fontSize = _screenSize.width < 360 ? 20.0 : 24.0;
    final titleHeight =
        fontSize * 1.2; // Font size * line height for accurate title height
    final titleBottom = titleTop + titleHeight;
    final cardsTop =
        titleBottom + 12; // Proper safe space (12px) after title for better spacing

    return SizedBox(
      width: double.infinity,
      height: _sectionHeight,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // Main pink background
          Container(
            color: _backgroundColor,
          ),

          // Curved white section at top
          _buildCurvedWhiteTop(),

          // Curved white section at bottom
          _buildCurvedWhiteBottom(),

          // LTO Section Title with Baloo font
          _buildLTOTitle([]), // Empty list for loading/error/empty states

          // Cards skeleton positioned below title
          Positioned(
            top: cardsTop,
            left: 0,
            right: 0,
            child: SizedBox(
              height: _cardHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      3,
                      (index) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Shimmer.fromColors(
                          baseColor: Colors.white.withOpacity(0.3),
                          highlightColor: Colors.white.withOpacity(0.1),
                          child: Container(
                            width: _cardWidth,
                            height: _cardHeight,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build error state
  Widget _buildErrorState() {
    // Performance: Use cached dimensions
    return SizedBox(
      width: double.infinity,
      height: _sectionHeight,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // Main pink background
          Container(
            color: _backgroundColor,
          ),

          // Curved white section at top
          _buildCurvedWhiteTop(),

          // Curved white section at bottom
          _buildCurvedWhiteBottom(),

          // LTO Section Title with Baloo font
          _buildLTOTitle([]), // Empty list for loading/error/empty states

          // Error message on top
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.grey[800],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Failed to load offers",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loadLTOItems,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.orange[600],
                    ),
                    child: Text(
                        AppLocalizations.of(context)?.retryLabel ?? "Retry"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build empty state when no LTO items available
  Widget _buildEmptyState() {
    // Performance: Use cached dimensions
    return SizedBox(
      width: double.infinity,
      height: _sectionHeight,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // Main pink background
          Container(
            color: _backgroundColor,
          ),

          // Curved white section at top
          _buildCurvedWhiteTop(),

          // Curved white section at bottom
          _buildCurvedWhiteBottom(),

          // LTO Section Title with Baloo font
          _buildLTOTitle([]), // Empty list for loading/error/empty states

          // Empty message on top
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_offer_outlined,
                    size: 48,
                    color: Colors.grey[800],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "No Limited Time Offers",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Check back later for special deals",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for curved white section at the top
class _CurvedWhiteTopPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();

    // Start from top-left corner
    path.moveTo(0, 0);

    // Draw straight line along the top edge
    path.lineTo(size.width, 0);

    // Draw curved bottom edge that dips down in the middle
    // Creates a smooth wave transition to pink background
    path.quadraticBezierTo(
      size.width * 0.8, size.height * 0.7, // Control point (right)
      size.width * 0.5, size.height, // Lowest point (center)
    );

    path.quadraticBezierTo(
      size.width * 0.2, size.height * 0.7, // Control point (left)
      0, size.height * 0.3, // End point
    );

    // Close the path back to start
    path.lineTo(0, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CurvedWhiteTopPainter oldDelegate) => false;
}

/// Custom painter for curved white section at the bottom
class _CurvedWhiteBottomPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();

    // Start from bottom-left corner
    path.moveTo(0, size.height);

    // Draw curved top edge that arches up in the middle
    // Creates a smooth wave transition to pink background
    path.quadraticBezierTo(
      size.width * 0.2, size.height * 0.3, // Control point (left)
      size.width * 0.5, 0, // Highest point (center)
    );

    path.quadraticBezierTo(
      size.width * 0.8, size.height * 0.3, // Control point (right)
      size.width, size.height * 0.7, // End point
    );

    // Draw straight line along the bottom edge
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CurvedWhiteBottomPainter oldDelegate) => false;
}
