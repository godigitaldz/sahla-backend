import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/menu_item.dart';
import '../models/order_item.dart';
import '../models/restaurant.dart';
import '../providers/restaurant_details_provider.dart';
import '../screens/restaurant_reviews_screen.dart';
import '../services/socket_service.dart';
import '../services/transition_service.dart';
import '../widgets/cart_screen/floating_cart_icon.dart';
import '../widgets/home_screen/limited_time_offer_section.dart';
import '../widgets/menu_item_full_popup/helpers/popup_helper.dart';
import '../widgets/restaurant_details_screen/drinks_section.dart';
import '../widgets/restaurant_details_screen/menu_item_card.dart';
import '../widgets/restaurant_details_screen/pinned_search_and_categories.dart';
import '../widgets/restaurant_details_screen/restaurant_details_header.dart';
import '../widgets/restaurant_details_screen/restaurant_info_section.dart';
import '../widgets/restaurant_details_screen/reviews_preview_section.dart';
import '../widgets/search_fab.dart';

/// Refactored Restaurant Details Screen using Provider pattern
/// and extracted widgets for better performance and maintainability
class RestaurantDetailsScreen extends StatefulWidget {
  const RestaurantDetailsScreen({
    required this.restaurant,
    super.key,
  });

  final Restaurant restaurant;

  @override
  State<RestaurantDetailsScreen> createState() =>
      _RestaurantDetailsScreenState();
}

class _RestaurantDetailsScreenState extends State<RestaurantDetailsScreen> {
  // Services
  late SocketService _socketService;

  // Scroll controller
  final ScrollController _scrollController = ScrollController();

  // State
  bool _hasInitializedSocketService = false;
  RestaurantDetailsProvider? _provider;

  // PERFORMANCE: Use ValueNotifier to avoid setState during scroll
  final ValueNotifier<double> _searchFabExpandProgress = ValueNotifier(0.0);

  // PERFORMANCE: Cache LTO positions to avoid recalculating on every build
  List<int>? _cachedLtoPositions;
  int? _cachedItemCount;

  // PERFORMANCE: Throttle scroll listener updates
  DateTime? _lastScrollUpdate;

  // Details button expansion state
  bool _isDetailsExpanded = false;

  @override
  void initState() {
    super.initState();
    _setupScrollListener();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;

      final scrollPosition = _scrollController.position.pixels;
      final maxScrollExtent = _scrollController.position.maxScrollExtent;

      // PERFORMANCE: Throttle updates to max 60 FPS (every ~16ms)
      final now = DateTime.now();
      if (_lastScrollUpdate != null &&
          now.difference(_lastScrollUpdate!).inMilliseconds < 16) {
        return;
      }
      _lastScrollUpdate = now;

      // Calculate expand progress for search FAB (0.0 to 1.0)
      // Start expanding after scrolling 100px, fully expanded at 300px
      const startExpanding = 100.0;
      const fullyExpanded = 300.0;
      final newProgress =
          ((scrollPosition - startExpanding) / (fullyExpanded - startExpanding))
              .clamp(0.0, 1.0);

      // PERFORMANCE: Only update if change is significant (>0.01)
      if ((newProgress - _searchFabExpandProgress.value).abs() > 0.01) {
        _searchFabExpandProgress.value = newProgress;
      }

      // Trigger loading when user is within 200px of the bottom
      if (scrollPosition >= maxScrollExtent - 200) {
        if (_provider != null &&
            !_provider!.isLoadingMore &&
            _provider!.hasMoreItems &&
            mounted) {
          _provider!.loadMoreItems();
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize socket service after provider is available
    if (!_hasInitializedSocketService) {
      _hasInitializedSocketService = true;
      _initializeSocketService();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchFabExpandProgress.dispose(); // PERFORMANCE: Dispose ValueNotifier
    super.dispose();
  }

  void _initializeSocketService() {
    _socketService = SocketService();
    if (_provider != null) {
      _provider!.initializeRealTime(_socketService);
    }
  }

  void _onCategorySelected(String category) {
    _provider?.updateSelectedCategory(category);
  }

  void _onSearchChanged(String query) {
    _provider?.updateSearchQuery(query);
  }

  void _onSearchCleared() {
    _provider?.clearSearch();
  }

  void _showMenuItemPopup(MenuItem menuItem) {
    PopupHelper.showMenuItemPopup(
      context: context,
      menuItem: menuItem,
      restaurant: widget.restaurant,
      onItemAddedToCart: (OrderItem orderItem) {
        // Show success message when item is added to cart
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "${orderItem.menuItem?.name ?? AppLocalizations.of(context)!.item} ${AppLocalizations.of(context)!.addedToCart}"),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green[600],
            ),
          );
        }
      },
      onDataChanged: () {
        // Refresh menu items data when review is submitted
        _provider?.loadMenuItems();
      },
    );
  }

  Widget _buildLogoAndNameSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: Directionality.of(context),
        children: [
          // Logo on the left
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(4),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl:
                    widget.restaurant.logoUrl ?? widget.restaurant.image ?? "",
                fit: BoxFit.cover,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  period: const Duration(milliseconds: 1500),
                  child: Container(
                    color: Colors.grey[300],
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Icon(
                    Icons.restaurant,
                    color: Colors.grey,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Name and reviews on the right - aligned to logo height (50px)
          Expanded(
            child: SizedBox(
              height: 50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // Restaurant name - matching home card style
                  Flexible(
                    child: Text(
                      widget.restaurant.name,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: Directionality.of(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Rating row - matching home card style
                  Row(
                    textDirection: Directionality.of(context),
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 5-star rating display with half-star support
                      ..._buildStarRating(context),
                      const SizedBox(width: 4),
                      // Review count
                      Text(
                        "(${widget.restaurant.reviewCount})",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                        textDirection: Directionality.of(context),
                      ),
                      const SizedBox(width: 6),
                      // Tappable review text
                      Flexible(
                        child: GestureDetector(
                          onTap: () {
                            TransitionService.navigateWithTransition(
                              context,
                              RestaurantReviewsScreen(
                                restaurant: widget.restaurant,
                              ),
                              transitionType: TransitionType.slideFromRight,
                            );
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            child: Text(
                              () {
                                final locale = Localizations.localeOf(context).languageCode;
                                if (locale == 'ar') return "اضغط لعرض التقييمات";
                                if (locale == 'fr') return "Appuyez pour voir les avis";
                                return "Tap to view reviews";
                              }(),
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textDirection: Directionality.of(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Details button on the right
          const SizedBox(width: 8),
          _buildDetailsButton(context),
        ],
      ),
    );
  }

  Widget _buildDetailsButton(BuildContext context) {
    // Build list of available social icons
    final List<Widget> icons = [];

    // Phone icon (always available)
    icons.add(
      Icon(
        Icons.phone,
        size: 16,
        color: Colors.grey[700],
      ),
    );

    // Add social media icons if available
    if (widget.restaurant.instagram != null) {
      icons.add(const SizedBox(width: 4));
      icons.add(
        Image.asset(
          'assets/icon/instagram.png',
          width: 16,
          height: 16,
          fit: BoxFit.contain,
        ),
      );
    }

    if (widget.restaurant.facebook != null) {
      icons.add(const SizedBox(width: 4));
      icons.add(
        Image.asset(
          'assets/icon/facebook.png',
          width: 16,
          height: 16,
          fit: BoxFit.contain,
        ),
      );
    }

    if (widget.restaurant.tiktok != null) {
      icons.add(const SizedBox(width: 4));
      icons.add(
        Image.asset(
          'assets/icon/tiktok.png',
          width: 16,
          height: 16,
          fit: BoxFit.contain,
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _isDetailsExpanded = !_isDetailsExpanded;
        });
      },
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Combined icons
            ...icons,
            const SizedBox(width: 6),
            // Down arrow
            AnimatedRotation(
              turns: _isDetailsExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableSocialSection(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: _isDetailsExpanded
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: RepaintBoundary(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  child: _buildSocialBar(context),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildSocialBar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final spacing = screenWidth < 360 ? 5.0 : 7.0;
    final mapsWidth = screenWidth < 360 ? 90.0 : 102.0;
    final mapsHeight = screenWidth < 360 ? 30.0 : 34.0;
    final chipSize = screenWidth < 360 ? 34.0 : 37.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: Directionality.of(context),
      children: [
        // Call chip
        _buildActionChip(
          onTap: () => _makePhoneCall(context),
          icon: Icons.phone,
          color: Colors.green[600]!,
          size: chipSize,
        ),
        SizedBox(width: spacing),
        // Google Maps button
        GestureDetector(
          onTap: () => _openGoogleMaps(context),
          child: Container(
            width: mapsWidth,
            height: mapsHeight,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 7,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Image.asset(
              'assets/icon/google maps.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        SizedBox(width: spacing),
        // Social media chips
        if (widget.restaurant.instagram != null) ...[
          _buildSocialChip(
            imagePath: 'assets/icon/instagram.png',
            onTap: () => _openSocialMedia(
                context, 'instagram', widget.restaurant.instagram!),
            size: chipSize,
          ),
          SizedBox(width: spacing),
        ],
        if (widget.restaurant.facebook != null) ...[
          _buildSocialChip(
            imagePath: 'assets/icon/facebook.png',
            onTap: () => _openSocialMedia(
                context, 'facebook', widget.restaurant.facebook!),
            size: chipSize,
          ),
          SizedBox(width: spacing),
        ],
        if (widget.restaurant.tiktok != null)
          _buildSocialChip(
            imagePath: 'assets/icon/tiktok.png',
            onTap: () =>
                _openSocialMedia(context, 'tiktok', widget.restaurant.tiktok!),
            size: chipSize,
          ),
      ],
    );
  }

  Widget _buildActionChip({
    required VoidCallback onTap,
    required IconData icon,
    required Color color,
    double size = 37.0,
  }) {
    final iconSize = size * 0.46;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size / 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 7,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            size: iconSize,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildSocialChip({
    required String imagePath,
    required VoidCallback onTap,
    double size = 37.0,
  }) {
    final padding = size * 0.23;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size / 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 7,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(BuildContext context) async {
    final phoneNumber = widget.restaurant.phone;

    if (phoneNumber.isNotEmpty) {
      final url = "tel:$phoneNumber";
      final uri = Uri.parse(url);

      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception("Could not launch phone dialer");
        }
      } on Exception catch (e) {
        debugPrint("Error making phone call: $e");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.error),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.phoneNumberNotAvailable),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _openGoogleMaps(BuildContext context) async {
    final lat = widget.restaurant.latitude;
    final lng = widget.restaurant.longitude;

    if (lat != null && lng != null) {
      final url = "https://www.google.com/maps/search/?api=1&query=$lat,$lng";
      final uri = Uri.parse(url);

      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception("Could not launch Google Maps");
        }
      } on Exception catch (e) {
        debugPrint("Error opening Google Maps: $e");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.error),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.notAvailable),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _openSocialMedia(
    BuildContext context,
    String platform,
    String handle,
  ) async {
    String url;

    switch (platform) {
      case 'instagram':
        if (handle.startsWith('http')) {
          url = handle;
        } else {
          final username =
              handle.startsWith('@') ? handle.substring(1) : handle;
          url = 'https://www.instagram.com/$username';
        }
        break;
      case 'facebook':
        if (handle.startsWith('http')) {
          url = handle;
        } else {
          url = 'https://www.facebook.com/$handle';
        }
        break;
      case 'tiktok':
        if (handle.startsWith('http')) {
          url = handle;
        } else {
          final username =
              handle.startsWith('@') ? handle.substring(1) : handle;
          url = 'https://www.tiktok.com/@$username';
        }
        break;
      default:
        return;
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open $platform'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error opening $platform: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening $platform'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Build 5-star rating with half-star support - matching home card style
  List<Widget> _buildStarRating(BuildContext context) {
    return List.generate(5, (starIndex) {
      final rating = widget.restaurant.rating;
      final starValue = starIndex + 1;

      if (rating >= starValue) {
        // Full star
        return Icon(
          Icons.star,
          size: 14,
          color: Colors.amber[600],
        );
      } else if (rating >= starValue - 0.5) {
        // Half star
        return Icon(
          Icons.star_half,
          size: 14,
          color: Colors.amber[600],
        );
      } else {
        // Empty star
        return Icon(
          Icons.star_border,
          size: 14,
          color: Colors.amber[600],
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RestaurantDetailsProvider(restaurant: widget.restaurant),
      child: Consumer<RestaurantDetailsProvider>(
        builder: (context, provider, child) {
          // Store provider reference for callbacks
          _provider = provider;

          return Scaffold(
            backgroundColor:
                Colors.transparent, // Transparent for floating effect
            floatingActionButton: const FloatingCartIcon(),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            body: Stack(
              children: [
                // Background layer
                Container(
                  color: const Color(0xFFECA11F),
                ),
                RefreshIndicator(
                  onRefresh: () => provider.refresh(),
                  child: CustomScrollView(
                    controller: _scrollController,
                    // Clamp scrolling to prevent overscroll bounce/drag
                    physics: const ClampingScrollPhysics(),
                    // PERFORMANCE: Optimize cache extent - cache only 1.5x screen height (enough for prefetch)
                    // Previous 3x was excessive and caused memory pressure
                    cacheExtent: MediaQuery.of(context).size.height * 1.5,
                    slivers: [
                      // Header with logo, name, and rating
                      RestaurantDetailsHeader(restaurant: widget.restaurant),

                      // Floating white container starts here with rounded top
                      SliverToBoxAdapter(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(28),
                            topRight: Radius.circular(28),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.0),
                                  blurRadius: 16,
                                  offset: const Offset(0, -4),
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Logo, name, and reviews section
                                _buildLogoAndNameSection(context),
                                // Expandable social section
                                _buildExpandableSocialSection(context),
                                // Info cards
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                  child: RestaurantInfoSection(
                                    restaurant: widget.restaurant,
                                    totalDeliveryTime:
                                        provider.totalDeliveryTime,
                                    lowestMenuItemPrice:
                                        provider.lowestMenuItemPrice,
                                    dynamicDeliveryFee:
                                        provider.dynamicDeliveryFee,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Pinned search and categories (with white background)
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: PinnedSearchAndCategoriesDelegate(
                          height: 45, // 45 for chips (reduced by 10%)
                          child: Container(
                            color: Colors.white,
                            child: PinnedSearchAndCategories(
                              categories: provider.categories,
                              selectedCategory: provider.selectedCategory,
                              onCategoryToggle: _onCategorySelected,
                              normalizeCategoryKey: (key) =>
                                  key.toLowerCase().replaceAll(' ', '_'),
                            ),
                          ),
                        ),
                      ),

                      // Menu items list
                      _buildMenuItemsList(provider),

                      // Drinks section
                      SliverToBoxAdapter(
                        child: Container(
                          color: Colors.white,
                          child: DrinksSection(
                            drinks: provider.drinks,
                            restaurant: widget.restaurant,
                            isLoading: provider.isLoadingDrinks,
                            onItemAddedToCart: () {
                              // Optional callback for when drink is added
                            },
                          ),
                        ),
                      ),

                      // Reviews preview section
                      SliverToBoxAdapter(
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                          child: ReviewsPreviewSection(
                            restaurant: widget.restaurant,
                          ),
                        ),
                      ),

                      // Bottom padding with white background
                      SliverToBoxAdapter(
                        child: Container(
                          color: Colors.white,
                          height: 100,
                        ),
                      ),
                    ],
                  ),
                ),
                // Search FAB positioned in top-right corner (RTL aware)
                PositionedDirectional(
                  top: MediaQuery.of(context).padding.top + 8,
                  end: 8,
                  child: ValueListenableBuilder<double>(
                    valueListenable: _searchFabExpandProgress,
                    builder: (context, expandProgress, child) {
                      return SearchFab(
                        onChanged: _onSearchChanged,
                        onCleared: _onSearchCleared,
                        initialQuery: provider.searchQuery,
                        visible: true,
                        expandProgress: expandProgress,
                        showFloatingStyle: false,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuItemsList(RestaurantDetailsProvider provider) {
    // Loading state
    if (provider.isLoadingMenu) {
      return SliverToBoxAdapter(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(32),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    // Error state
    if (provider.errorMessage != null) {
      return SliverToBoxAdapter(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                const SizedBox(height: 16),
                Text(
                  provider.errorMessage!,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => provider.loadMenuItems(),
                  child: Text(AppLocalizations.of(context)!.retry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final filteredItems = provider.filteredMenuItems;

    // Empty state
    if (filteredItems.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.restaurant_menu, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  provider.searchQuery.isNotEmpty
                      ? AppLocalizations.of(context)!.noResultsFound
                      : AppLocalizations.of(context)!.noItemsAvailable,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // PERFORMANCE: Cache LTO positions to avoid recalculating on every build
    final int itemCount = filteredItems.length;
    List<int> ltoPositions;

    if (_cachedLtoPositions != null && _cachedItemCount == itemCount) {
      // Use cached positions if item count hasn't changed
      ltoPositions = _cachedLtoPositions!;
    } else {
      // Calculate LTO placement based on item count
      ltoPositions = [];
      if (itemCount < 5) {
        // Less than 5 items: Show LTO at the bottom
        ltoPositions.add(itemCount);
      } else if (itemCount < 10) {
        // Between 5 and 9 items: Center the LTO (after middle item)
        ltoPositions.add(itemCount ~/ 2);
      } else {
        // 10 or more items: Show LTO every 4 items
        for (int i = 4; i < itemCount; i += 4) {
          ltoPositions.add(i);
        }
      }
      // Cache the result
      _cachedLtoPositions = ltoPositions;
      _cachedItemCount = itemCount;
    }

    // Calculate total items including LTO sections and loading indicator
    final int totalItems = itemCount + ltoPositions.length;

    // Menu items list with loading indicator
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Show loading indicator at the end if loading more
          if (index == totalItems) {
            return Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          // Check if we should insert an LTO section at this position
          // Count how many LTO sections come before this index
          int ltoSectionsBefore = 0;
          bool isAtLtoPosition = false;
          for (final ltoPos in ltoPositions) {
            if (index == ltoPos) {
              isAtLtoPosition = true;
              break;
            } else if (index > ltoPos) {
              ltoSectionsBefore++;
            }
          }

          if (isAtLtoPosition) {
            // Insert LTO section at the calculated position
            return Container(
              color: Colors.white,
              padding: const EdgeInsets.only(top: 12, bottom: 12),
              child: RepaintBoundary(
                child: LimitedTimeOfferSection(
                  restaurantId: widget.restaurant.id,
                ),
              ),
            );
          }

          // Calculate the actual menu item index
          final int menuItemIndex = index - ltoSectionsBefore;

          // Show menu item card
          final menuItem = filteredItems[menuItemIndex];
          return Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RepaintBoundary(
              key: ValueKey("menu_item_${menuItem.id}_$menuItemIndex"),
              child: MenuItemCard(
                menuItem: menuItem,
                onTap: () => _showMenuItemPopup(menuItem),
              ),
            ),
          );
        },
        childCount: totalItems + (provider.isLoadingMore ? 1 : 0),
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        addSemanticIndexes: false,
        // PERFORMANCE: Optimize findChildIndexCallback - cache parsed indexes
        findChildIndexCallback: (Key key) {
          if (key is ValueKey<String>) {
            final String valueKey = key.value;
            // Fast check: does it start with 'menu_item_'?
            if (valueKey.startsWith('menu_item_') && valueKey.length > 10) {
              // Extract index from key like "menu_item_123_5"
              // PERFORMANCE: Use lastIndexOf for faster extraction than split
              final lastUnderscoreIndex = valueKey.lastIndexOf('_');
              if (lastUnderscoreIndex > 0 &&
                  lastUnderscoreIndex < valueKey.length - 1) {
                final indexStr = valueKey.substring(lastUnderscoreIndex + 1);
                return int.tryParse(indexStr);
              }
            }
          }
          return null;
        },
      ),
    );
  }
}
