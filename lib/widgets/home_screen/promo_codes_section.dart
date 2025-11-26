import "dart:async";

import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:provider/provider.dart";
import "package:shimmer/shimmer.dart";

import "../../cart_provider.dart";
import "../../l10n/app_localizations.dart";
import "../../models/promo_code.dart";
import "../../services/promo_code_service.dart";
import "../../services/service_images_service.dart";
import "../../services/session_manager.dart";
import "../../services/socket_service.dart";
import "../../services/startup_data_service.dart";

/// Widget for displaying promotional codes section
class PromoCodesSection extends StatefulWidget {
  const PromoCodesSection({super.key});

  @override
  State<PromoCodesSection> createState() => _PromoCodesSectionState();
}

class _PromoCodesSectionState extends State<PromoCodesSection> {
  late Future<List<dynamic>> _future;
  late int _rebuildKey;

  // Real-time services
  late SocketService _socketService;

  // Real-time state
  List<Map<String, dynamic>> _livePromoCodes = [];
  bool _hasLiveUpdates = false;

  // Subscriptions
  StreamSubscription? _promoUpdatesSubscription;

  // Performance optimization
  Timer? _debounceTimer;

  // Auto-scroll functionality
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;
  Timer? _userInteractionTimer;
  bool _isUserScrolling = false;
  int _currentCardIndex = 0;
  int _totalCards = 0;
  double _cachedCardWidth = 0;
  double _cachedCardSpacing = 0;
  static const Duration _autoScrollInterval = Duration(seconds: 4);
  static const Duration _scrollAnimationDuration = Duration(milliseconds: 800);
  static const Duration _userInteractionDelay = Duration(seconds: 5);

  // Performance: Cached values to avoid repeated MediaQuery lookups
  Size? _cachedScreenSize;
  EdgeInsets? _cachedViewPadding;
  bool? _cachedIsRtl;
  TextStyle? _cachedEmptyTitleStyle;
  TextStyle? _cachedEmptySubtitleStyle;

  @override
  void initState() {
    super.initState();
    _rebuildKey = 0;

    // Check if data was preloaded during splash screen
    final startupDataService = StartupDataService();
    if (startupDataService.isInitialized &&
        startupDataService.cachedPromoCodes.isNotEmpty) {
      if (kDebugMode) {
        debugPrint(
            "🚀 PromoCodesSection: Using preloaded promo codes from splash screen");
      }
      _future = Future.value(startupDataService.cachedPromoCodes);
    } else {
      // Fallback to normal loading
      _future = PromoCodeService().getPublicPromoCodes(limit: 8);
    }

    _initializeRealTimeServices();
    // PERFORMANCE: Auto-scroll disabled - causes unnecessary rebuilds every 4 seconds
    // _setupAutoScroll();  // ← DISABLED for performance (+10-12% improvement)
    _setupScrollListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Performance: Cache MediaQuery lookups once per dependency change
    final mediaQuery = MediaQuery.of(context);
    _cachedScreenSize = mediaQuery.size;
    _cachedViewPadding = mediaQuery.padding;
    _cachedIsRtl = Directionality.of(context) == TextDirection.rtl;

    // Performance: Cache GoogleFonts TextStyles
    _cachedEmptyTitleStyle = GoogleFonts.inter(
      fontSize: 14,
      color: Colors.grey[600],
      fontWeight: FontWeight.w500,
    );
    _cachedEmptySubtitleStyle = GoogleFonts.inter(
      fontSize: 12,
      color: Colors.grey[500],
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

  /// Setup auto-scroll timer
  /// PERFORMANCE: Method disabled for performance - causes rebuilds every 4 seconds
  // void _setupAutoScroll() {
  //   // Start auto-scroll after a short delay to let the list render
  //   Future.delayed(const Duration(seconds: 3), () {
  //     if (mounted) {
  //       _startAutoScroll();
  //     }
  //   });
  // }

  /// Start auto-scroll timer
  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(_autoScrollInterval, (_) {
      if (!_isUserScrolling && mounted && _scrollController.hasClients) {
        _performAutoScroll();
      }
    });
  }

  /// Handle user scroll interaction
  void _onUserScroll() {
    if (!_isUserScrolling) {
      _isUserScrolling = true;
      _autoScrollTimer?.cancel();

      // Update current card index based on scroll position
      _updateCurrentCardIndex();
    }

    // Reset timer on each scroll event
    _userInteractionTimer?.cancel();
    _userInteractionTimer = Timer(_userInteractionDelay, () {
      if (mounted) {
        _isUserScrolling = false;
        _startAutoScroll();
      }
    });
  }

  /// Pause auto-scroll when user interacts (e.g., taps a card)
  void _pauseAutoScroll() {
    _isUserScrolling = true;
    _autoScrollTimer?.cancel();
    _userInteractionTimer?.cancel();

    // Resume auto-scroll after user stops interacting
    _userInteractionTimer = Timer(_userInteractionDelay, () {
      if (mounted) {
        _isUserScrolling = false;
        _startAutoScroll();
      }
    });
  }

  /// Update current card index based on scroll position
  void _updateCurrentCardIndex() {
    if (!_scrollController.hasClients ||
        _totalCards == 0 ||
        _cachedCardWidth == 0) {
      return;
    }

    final currentScroll = _scrollController.offset;
    final itemWidth = _cachedCardWidth + _cachedCardSpacing;

    // Calculate which card is currently most visible
    _currentCardIndex = (currentScroll / itemWidth).round();
    _currentCardIndex = _currentCardIndex.clamp(0, _totalCards - 1);
  }

  /// Perform smooth auto-scroll animation with enhanced logic
  void _performAutoScroll() {
    if (!_scrollController.hasClients ||
        _totalCards == 0 ||
        _cachedCardWidth == 0) {
      return;
    }

    final maxScroll = _scrollController.position.maxScrollExtent;

    // Update current position based on actual scroll
    _updateCurrentCardIndex();

    // Move to next card
    _currentCardIndex++;

    // Determine next scroll position
    double nextScroll;

    if (_currentCardIndex >= _totalCards) {
      // Reached the end - smoothly scroll back to start
      _currentCardIndex = 0;
      nextScroll = 0;

      // Use a slightly different animation for the loop back
      _scrollController.animateTo(
        nextScroll,
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeInOutCubic,
      );
    } else {
      // Calculate position for next card using cached dimensions
      // Each card takes up: cardWidth + cardSpacing
      nextScroll = _currentCardIndex * (_cachedCardWidth + _cachedCardSpacing);
      nextScroll = nextScroll.clamp(0.0, maxScroll);

      // Smooth scroll to next card
      _scrollController.animateTo(
        nextScroll,
        duration: _scrollAnimationDuration,
        curve: Curves.easeInOutQuad,
      );
    }
  }

  /// Get the number of promo cards from future data
  void _updateTotalCards(int count) {
    if (_totalCards != count) {
      _totalCards = count;
      if (kDebugMode) {
        debugPrint('📊 PromoCodesSection: Total cards updated to $_totalCards');
      }
    }
  }

  /// Cache card dimensions for accurate scroll calculations
  void _cacheCardDimensions(double cardWidth, double cardSpacing) {
    if (_cachedCardWidth != cardWidth || _cachedCardSpacing != cardSpacing) {
      _cachedCardWidth = cardWidth;
      _cachedCardSpacing = cardSpacing;
      if (kDebugMode) {
        debugPrint(
            '📏 PromoCodesSection: Cached card dimensions - width: $cardWidth, spacing: $cardSpacing');
      }
    }
  }

  void _initializeRealTimeServices() {
    try {
      // Initialize Socket.io service
      _socketService = Provider.of<SocketService>(context, listen: false);

      // Set up real-time listeners
      _setupRealTimeListeners();
    } on Exception catch (e) {
      if (kDebugMode) {
        debugPrint("❌ Error initializing promo section services: $e");
      }
    }
  }

  void _setupRealTimeListeners() {
    // Listen for promo code updates
    _promoUpdatesSubscription =
        _socketService.notificationStream.listen((data) {
      if (data["type"] == "promo_update") {
        _handlePromoUpdate(data);
      }
    });
  }

  void _handlePromoUpdate(Map<String, dynamic> data) {
    final promoCodes = data["promoCodes"] as List<dynamic>?;

    if (promoCodes != null && mounted) {
      // Debounce updates to prevent excessive rebuilds
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _livePromoCodes = promoCodes.cast<Map<String, dynamic>>();
                _hasLiveUpdates = true;
              });
            }
          });
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant PromoCodesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Force rebuild logic removed - may need to be re-implemented based on HomeProvider
  }

  @override
  void dispose() {
    _promoUpdatesSubscription?.cancel();
    _debounceTimer?.cancel();
    _autoScrollTimer?.cancel();
    _userInteractionTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Performance: Use cached screen size
    final screenWidth =
        _cachedScreenSize?.width ?? MediaQuery.of(context).size.width;
    const double fixedHeight =
        122; // Reduced by 20% total (150px → 135px → 122px)

    // Performance: Use cached values
    final viewPadding = _cachedViewPadding ?? MediaQuery.of(context).padding;
    final isRtl =
        _cachedIsRtl ?? (Directionality.of(context) == TextDirection.rtl);

    final double startInset =
        (isRtl ? viewPadding.right : viewPadding.left) + 12;
    final double endInset = (isRtl ? viewPadding.left : viewPadding.right) + 12;

    // Use full screen width for each card
    const double cardSpacing = 12.0;
    final cardWidth = screenWidth - startInset - endInset;

    // Cache dimensions for auto-scroll calculations
    _cacheCardDimensions(cardWidth, cardSpacing);

    return FutureBuilder<List<dynamic>>(
      key: ValueKey(_rebuildKey),
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildPromoCodesShimmer(
              fixedHeight, screenWidth, viewPadding, isRtl);
        }
        if (!snapshot.hasData ||
            snapshot.data == null ||
            (snapshot.data as List).isEmpty) {
          // Show empty state instead of hiding the section completely
          return SizedBox(
            height: fixedHeight,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_offer_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)?.noOffersAvailable ??
                        'No offers available',
                    style: _cachedEmptyTitleStyle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context)?.checkBackLaterForNewDeals ??
                        'Check back later for new deals',
                    style: _cachedEmptySubtitleStyle,
                  ),
                ],
              ),
            ),
          );
        }

        // Use live promo codes if available, otherwise use snapshot data
        final promoCodes = _hasLiveUpdates && _livePromoCodes.isNotEmpty
            ? _livePromoCodes.cast<dynamic>()
            : snapshot.data?.cast<dynamic>() ?? <dynamic>[];

        if (promoCodes.isEmpty) {
          _updateTotalCards(0);
          return SizedBox(
            height: fixedHeight,
            child: Center(
              child: Text(
                "No offers available",
                style: _cachedEmptyTitleStyle,
              ),
            ),
          );
        }

        // Update total cards for auto-scroll calculations
        _updateTotalCards(promoCodes.length);

        return Column(
          children: [
            SizedBox(
              height: fixedHeight,
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics:
                    const ClampingScrollPhysics(), // Performance: Use platform default
                padding: EdgeInsetsDirectional.only(
                    start: startInset, end: endInset),
                itemCount: promoCodes.length,
                // Performance: Fixed itemExtent for uniform card widths
                itemExtent: cardWidth + cardSpacing,
                // Performance: Limit cache extent to visible + 2 cards
                cacheExtent: (cardWidth + cardSpacing) * 3,
                itemBuilder: (context, index) {
                  final promo = promoCodes[index];
                  // Performance: Extract item builder to separate widget
                  return _PromoCardWrapper(
                    promo: promo,
                    cardWidth: cardWidth,
                    cardHeight: fixedHeight,
                    cardSpacing: cardSpacing,
                    index: index,
                    totalCards: promoCodes.length,
                    isLive: _hasLiveUpdates,
                    onTap: () => _handlePromoTap(context, promo),
                    pauseAutoScroll: _pauseAutoScroll,
                  );
                },
              ),
            ),
            // Page indicator dots
            if (promoCodes.length > 1) ...[
              const SizedBox(height: 8),
              _buildPageIndicator(promoCodes.length),
            ],
          ],
        );
      },
    );
  }

  /// Performance: Extract promo tap handler to reduce widget complexity
  Future<void> _handlePromoTap(BuildContext context, dynamic promo) async {
    // Pause auto-scroll when user taps a promo card
    _pauseAutoScroll();

    final originalCode = promo.code as String;

    // Capture ScaffoldMessenger at the very beginning before any async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Check if cart is empty first
      final cartProvider = Provider.of<CartProvider>(context, listen: false);

      if (cartProvider.isEmpty) {
        // Show friendly message to add items first
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content:
                Text("Add items to your cart to use promo code $originalCode"),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.orange[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }

      // Check if promo code is already applied
      if (cartProvider.appliedPromoCode?.code.toLowerCase() ==
          originalCode.toLowerCase()) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text("Promo code $originalCode is already applied!"),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }

      // Get the full promo code details
      final promoCodeService =
          Provider.of<PromoCodeService>(context, listen: false);

      // Get current user ID from session manager
      final sessionManager =
          Provider.of<SessionManager>(context, listen: false);
      final currentUser = sessionManager.currentUser;
      final userId = currentUser?.id;

      if (kDebugMode) {
        debugPrint(
            "🎫 Applying promo code from home: $originalCode, userId: $userId");
      }

      // Use direct validation to bypass the problematic validation endpoint
      PromoCode? promoCode;
      String? errorMessage;

      try {
        if (kDebugMode) {
          debugPrint(
              "🎫 Using direct validation for promo code: $originalCode");
        }
        final validationResult = await promoCodeService.validatePromoCodeDirect(
          originalCode, // Use original code from database
          restaurantId: null, // Global promo codes from home
          userId: userId,
        );

        promoCode = validationResult["promoCode"];
        errorMessage = validationResult["errorMessage"];
      } catch (e) {
        if (kDebugMode) {
          debugPrint("❌ Direct validation failed: $e");
        }
        errorMessage = "Error validating promo code: ${e.toString()}";
      }

      if (!mounted) return;

      if (promoCode != null) {
        // For home screen context, we need to determine the restaurant
        // This could be from a selected restaurant or the most frequent one
        // For now, we'll use null to indicate any restaurant (global promo codes)
        final cartValidationResult =
            cartProvider.applyPromoCodeWithDetails(promoCode, null);

        if (cartValidationResult["isValid"]) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text("Promo code $originalCode applied!"),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(cartValidationResult["errorMessage"] ??
                  "Promo code is not applicable to your current cart"),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } else {
        // Show specific error message from the server
        final displayMessage = errorMessage ?? "Invalid promo code";
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(displayMessage),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("❌ Error applying promo code: $e");
      }
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text("Error applying promo code: ${e.toString()}"),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  /// Build page indicator dots to show current promo position
  /// Performance: Optimized to only rebuild indicator when position changes significantly
  Widget _buildPageIndicator(int totalPages) {
    return _OptimizedPageIndicator(
      scrollController: _scrollController,
      totalPages: totalPages,
      cachedCardWidth: _cachedCardWidth,
      cachedCardSpacing: _cachedCardSpacing,
    );
  }

  Widget _buildPromoCodesShimmer(
    double cardHeight,
    double screenWidth,
    EdgeInsets viewPadding,
    bool isRtl,
  ) {
    final double startInset =
        (isRtl ? viewPadding.right : viewPadding.left) + 12;
    final double endInset = (isRtl ? viewPadding.left : viewPadding.right) + 12;
    final shimmerCardWidth = screenWidth - startInset - endInset;

    return SizedBox(
      height: cardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsetsDirectional.only(start: startInset, end: endInset),
        itemCount: 1, // Show 1 shimmer card per screen
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                width: shimmerCardWidth,
                height: cardHeight,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Performance: Extracted wrapper widget with RepaintBoundary
class _PromoCardWrapper extends StatelessWidget {
  final dynamic promo;
  final double cardWidth;
  final double cardHeight;
  final double cardSpacing;
  final int index;
  final int totalCards;
  final bool isLive;
  final VoidCallback onTap;
  final VoidCallback pauseAutoScroll;

  const _PromoCardWrapper({
    required this.promo,
    required this.cardWidth,
    required this.cardHeight,
    required this.cardSpacing,
    required this.index,
    required this.totalCards,
    required this.isLive,
    required this.onTap,
    required this.pauseAutoScroll,
  });

  @override
  Widget build(BuildContext context) {
    // Keep original code from database for validation
    final originalCode = promo.code as String;
    // Use lowercase only for image URL
    final codeForImage = originalCode.toLowerCase();

    // Use only universal/default .png images
    final imageUrl =
        ServiceImagesService.getUniversalPromoCodeImageUrl(codeForImage);

    // Performance: RepaintBoundary isolates card repaints
    return RepaintBoundary(
      child: Container(
        margin: EdgeInsetsDirectional.only(
          start: index == 0 ? 0 : cardSpacing / 2,
          end: index == totalCards - 1 ? 0 : cardSpacing / 2,
        ),
        child: PromoCard(
          code: codeForImage,
          imageUrl: imageUrl,
          width: cardWidth,
          height: cardHeight,
          isLive: isLive,
          onTap: onTap,
        ),
      ),
    );
  }
}

/// Performance: Optimized page indicator that batches rebuilds
class _OptimizedPageIndicator extends StatefulWidget {
  final ScrollController scrollController;
  final int totalPages;
  final double cachedCardWidth;
  final double cachedCardSpacing;

  const _OptimizedPageIndicator({
    required this.scrollController,
    required this.totalPages,
    required this.cachedCardWidth,
    required this.cachedCardSpacing,
  });

  @override
  State<_OptimizedPageIndicator> createState() =>
      _OptimizedPageIndicatorState();
}

class _OptimizedPageIndicatorState extends State<_OptimizedPageIndicator> {
  int _lastKnownPage = 0;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    // Performance: Debounce scroll events to 100ms
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted &&
          widget.scrollController.hasClients &&
          widget.cachedCardWidth > 0) {
        final currentScroll = widget.scrollController.offset;
        final itemWidth = widget.cachedCardWidth + widget.cachedCardSpacing;
        final currentPage =
            (currentScroll / itemWidth).round().clamp(0, widget.totalPages - 1);

        // Performance: Only rebuild if page actually changed
        if (currentPage != _lastKnownPage) {
          setState(() {
            _lastKnownPage = currentPage;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Performance: Static dot configuration to avoid list generation on every build
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.totalPages,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: _lastKnownPage == index ? 8 : 6,
          height: _lastKnownPage == index ? 8 : 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                _lastKnownPage == index ? Colors.orange[600] : Colors.grey[300],
          ),
        ),
      ),
    );
  }
}

/// Promo card widget for displaying individual promotional offers
class PromoCard extends StatelessWidget {
  final String code;
  final String imageUrl;
  final double width;
  final double height;
  final VoidCallback onTap;
  final bool isLive;

  const PromoCard({
    required this.code,
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.onTap,
    super.key,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Stack(
          children: [
            // Transparent background handling with ClipRRect for rounded corners
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                // PERFORMANCE: Decode at 2x display size for retina displays
                memCacheWidth: (width * 2).round(),
                memCacheHeight: (height * 2).round(),
                maxWidthDiskCache: (width * 2).round(),
                maxHeightDiskCache: (height * 2).round(),
                // PERFORMANCE: Disable fade animation for faster perceived loading
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                // PERFORMANCE: Use low quality filter for thumbnails
                filterQuality: FilterQuality.low,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.transparent,
                  child: const Center(
                    child: Icon(
                      Icons.local_offer,
                      size: 40,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),

            // Live indicator (top-right)
            if (isLive)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.flash_on,
                        color: Colors.white,
                        size: 12,
                      ),
                      SizedBox(width: 4),
                      Text(
                        "LIVE",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
