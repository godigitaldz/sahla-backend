import "dart:async";

import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:provider/provider.dart";
import "package:shimmer/shimmer.dart";
import "package:supabase_flutter/supabase_flutter.dart" as supa;

import "../../services/cuisine_service.dart";
import "../../services/home/home_cache_service.dart";
import "../../services/menu_item_display_service.dart";
import "../../services/service_images_service.dart";
import "../../services/socket_service.dart";
import "../../services/startup_data_service.dart";
import "../../utils/responsive_utils.dart" as responsive;

/// Widget for displaying categories in a horizontal scrollable layout
class CategoriesSection extends StatefulWidget {
  const CategoriesSection({
    required this.normalizeCategoryKey,
    super.key,
    this.horizontalPadding = 20,
    this.selectedCategories,
    this.onCategoryToggle,
    this.selectedCuisines,
    this.categories, // Optional pre-filtered categories list
    this.scaleFactor =
        1.0, // Scale factor for sizing (1.0 = 100%, 0.9 = 90%, etc.)
    this.showAllCategory =
        false, // Whether to show "All" category at the beginning
  });

  final double horizontalPadding;
  final Set<String>? selectedCategories;
  final void Function(String category)? onCategoryToggle;
  final Set<String>? selectedCuisines;
  final String Function(String input) normalizeCategoryKey;
  final List<String>? categories; // Optional pre-filtered categories list
  final double scaleFactor;
  final bool showAllCategory;

  @override
  State<CategoriesSection> createState() => _CategoriesSectionState();
}

class _CategoriesSectionState extends State<CategoriesSection> {
  late Future<List<String>> _future;

  // Real-time services
  late SocketService _socketService;

  // Real-time state
  List<String> _liveCategories = [];
  bool _hasLiveUpdates = false;

  // Subscriptions
  StreamSubscription? _categoryUpdatesSubscription;

  // Throttling for socket updates
  Timer? _updateThrottleTimer;
  Map<String, dynamic>? _pendingUpdateData;

  // Loading state management
  // bool _futureInitialized = false;

  // Track recently tapped categories to move them to top
  final List<String> _recentlyTappedCategories = [];

  // Smart category statistics: category -> {itemCount, reviewCount}
  final Map<String, Map<String, int>> _categoryStats = {};

  // Memoized layout calculations to avoid per-build computation
  Size? _cachedScreenSize;
  double? _cachedCardWidth;
  double? _cachedCardHeight;
  double? _cachedAdaptiveHeight;
  TextStyle? _cachedEmptyTextStyle;

  // Performance: Memoize image URLs to avoid recalculating in itemBuilder
  final Map<String, String> _imageUrlCache = {};

  @override
  void initState() {
    super.initState();
    _future = _loadCategories();
    // Performance: Lazy load stats only when needed
    // _loadCategoryStats();

    // Defer provider access until after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeRealTimeServices();
        // Performance: Load stats after UI is ready
        _loadCategoryStats();
      }
    });
  }

  void _initializeRealTimeServices() {
    try {
      // Initialize Socket.io service
      _socketService = Provider.of<SocketService>(context, listen: false);

      // Set up real-time listeners
      _setupRealTimeListeners();
    } on Exception catch (e) {
      debugPrint("❌ Error initializing categories section services: $e");
    }
  }

  void _setupRealTimeListeners() {
    // Listen for category updates
    _categoryUpdatesSubscription =
        _socketService.notificationStream.listen((data) {
      if (data["type"] == "category_update") {
        _handleCategoryUpdate(data);
      }
    });
  }

  void _handleCategoryUpdate(Map<String, dynamic> data) {
    // Store pending update data
    _pendingUpdateData = data;

    // Cancel existing timer
    _updateThrottleTimer?.cancel();

    // Set up throttled update (coalesce updates within 300ms)
    _updateThrottleTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || _pendingUpdateData == null) return;

      final updateData = _pendingUpdateData!;
      final categories = updateData["categories"] as List<dynamic>?;
      final popularity = updateData["popularity"] as Map<String, dynamic>?;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            if (categories != null) {
              _liveCategories = categories.cast<String>();
              _hasLiveUpdates = true;
            }
            if (popularity != null) {
              // Category popularity tracking removed
            }
          });
          debugPrint("🔄 Throttled category update applied");
        }
      });

      _pendingUpdateData = null;
    });
  }

  /// Calculate adaptive height based on screen size (42-50px range)
  /// Smaller screens get smaller heights, larger screens get larger heights
  double _getAdaptiveHeight(double screenHeight) {
    // Screen height ranges:
    // Small phones: < 700px -> 42px
    // Medium phones: 700-850px -> 44-48px
    // Large phones/tablets: > 850px -> 50px
    if (screenHeight < 700) {
      return 42.0;
    } else if (screenHeight < 750) {
      return 44.0;
    } else if (screenHeight < 800) {
      return 46.0;
    } else if (screenHeight < 850) {
      return 48.0;
    } else {
      return 50.0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Performance: Compute dimensions only when dependencies change
    final screenSize = MediaQuery.of(context).size;

    // Only recompute if screen size changed
    if (_cachedScreenSize != screenSize) {
      final gridConfig = context.gridConfig;
      final horizontalPadding = widget.horizontalPadding;
      final availableWidth = screenSize.width - horizontalPadding * 2;

      // Use device-specific category columns
      final targetCards = gridConfig.categoryColumns;
      const spacing = 8.0;
      final baseCardWidth =
          ((availableWidth - spacing * (targetCards - 1)) / targetCards)
              .clamp(60.0, gridConfig.maxCategoryWidth);
      const aspectRatio = 75.0 / 68.0;
      final computedCardHeight =
          (baseCardWidth / aspectRatio).clamp(54.0, 108.0);

      _cachedCardWidth = baseCardWidth * 0.7;
      _cachedCardHeight = computedCardHeight * 0.7;
      _cachedAdaptiveHeight = _getAdaptiveHeight(screenSize.height);
      _cachedScreenSize = screenSize;

      // Performance: Cache TextStyle for empty state
      _cachedEmptyTextStyle = GoogleFonts.inter(
        fontSize: 13 * widget.scaleFactor,
        color: Colors.grey[600],
        fontWeight: FontWeight.w500,
      );

      debugPrint(
          "📐 Cached dimensions: ${_cachedCardWidth}x$_cachedCardHeight, height: $_cachedAdaptiveHeight");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Performance: Use cached values instead of recalculating
    final reducedCardWidth = _cachedCardWidth ?? 60.0;
    final reducedCardHeight = _cachedCardHeight ?? 54.0;
    final adaptiveHeight = _cachedAdaptiveHeight ?? 47.5;

    // If pre-filtered categories are provided, use them directly
    if (widget.categories != null && widget.categories!.isNotEmpty) {
      final categories = List<String>.from(widget.categories!);

      // Add "All" category at the beginning if requested and not already present
      if (widget.showAllCategory && !categories.any((c) => _isAllCategory(c))) {
        final isRTL = Localizations.localeOf(context).languageCode == 'ar';
        categories.insert(0, isRTL ? "الكل" : "All");
      }

      return _buildCategoriesList(
          categories, reducedCardWidth, reducedCardHeight, adaptiveHeight);
    }

    return FutureBuilder<List<String>>(
      future: _future,
      builder: (context, snapshot) {
        // Simplified loading check using FutureBuilder"s connection state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildCategoriesShimmer(reducedCardHeight, adaptiveHeight);
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          // Calculate height for vertical layout
          final heightRatio = adaptiveHeight / 47.5;
          final imageSize = 50.0 * heightRatio;
          final textSpacing = 4.0 * heightRatio;
          final textHeight = 17.0; // Text height with line height (increased from 15)
          final calculatedHeight = imageSize + textSpacing + textHeight;

          // Performance: Use cached TextStyle
          return Container(
            height: calculatedHeight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Center(
              child: Text(
                "No categories available",
                style: _cachedEmptyTextStyle,
              ),
            ),
          );
        }

        // Use live categories if available, otherwise use snapshot data
        final categories = _hasLiveUpdates && _liveCategories.isNotEmpty
            ? _liveCategories
            : snapshot.data!;

        // Sort categories with recently tapped ones at the top
        final limited = _sortCategoriesWithRecentlyTapped(categories);

        // Ensure "All" category is always first if it exists
        if (widget.showAllCategory) {
          final allCategoryIndex = limited.indexWhere((c) => _isAllCategory(c));
          if (allCategoryIndex > 0) {
            // Move "All" to the beginning
            final allCategory = limited.removeAt(allCategoryIndex);
            limited.insert(0, allCategory);
          } else if (allCategoryIndex == -1) {
            // Add "All" if not present
            final isRTL = Localizations.localeOf(context).languageCode == 'ar';
            limited.insert(0, isRTL ? "الكل" : "All");
          }
        }

        // All categories are now scrollable (no pinning)
        final scrollableCategories = limited;

        // Performance: Precompute image URLs once
        _precomputeImageUrls(scrollableCategories);

        // Calculate height for vertical layout: image + spacing + text
        // Image: 50.0 * heightRatio, Spacing: 4.0 * heightRatio, Text: ~17px (with line height)
        final heightRatio = adaptiveHeight / 47.5;
        final imageSize = 50.0 * heightRatio;
        final textSpacing = 4.0 * heightRatio;
        final textHeight = 17.0; // Text height with line height (increased from 15)
        final calculatedHeight = imageSize + textSpacing + textHeight;

        return SizedBox(
          height: calculatedHeight,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              scrollbars: false,
              overscroll: false,
            ),
            child: Center(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                // Performance: Use platform default physics
                padding: const EdgeInsetsDirectional.only(
                  start: 12,
                  end: 12,
                ),
                clipBehavior: Clip.none,
                itemCount: scrollableCategories.length,
                // Performance: Reduce cache extent (chips are simple)
                cacheExtent: 200,
                // PERFORMANCE FIX: No itemExtent needed - category chips have variable widths
                // based on text content, but we limit cacheExtent for memory efficiency
                // Performance: Disable automatic keep alives for better memory
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
                itemBuilder: (context, index) {
                  final category = scrollableCategories[index];
                  final bool isSelected =
                      (widget.selectedCategories ?? const <String>{})
                              .contains(category) ||
                          (_isAllCategory(category) &&
                              widget.selectedCategories?.isEmpty == true);

                  // Performance: Use cached image URL
                  final imageUrl = _imageUrlCache[category] ?? "";

                  // Performance: Wrap in RepaintBoundary to isolate repaints
                  return RepaintBoundary(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: index == 0 ? 0 : 8,
                        end: index < scrollableCategories.length - 1 ? 8 : 0,
                      ),
                      child: _buildCategoryChip(
                        category: category,
                        isSelected: isSelected,
                        imageUrl: imageUrl,
                        chipHeight: adaptiveHeight,
                        onTap: () {
                          _onCategoryTapped(category);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// Performance: Precompute image URLs for all categories
  void _precomputeImageUrls(List<String> categories) {
    for (final category in categories) {
      if (_imageUrlCache.containsKey(category)) continue;

      if (_isAllCategory(category)) {
        _imageUrlCache[category] = "";
      } else {
        final urlSpaces =
            ServiceImagesService.getCategoryImageUrlWithSpaces(category);
        final urlUnderscore =
            ServiceImagesService.getCategoryImageUrlWithUnderscores(category);
        final urlNormalized =
            ServiceImagesService.getUniversalCategoryImageUrl(category);

        _imageUrlCache[category] = urlSpaces.isNotEmpty
            ? urlSpaces
            : (urlUnderscore.isNotEmpty ? urlUnderscore : urlNormalized);
      }
    }
  }

  /// Build a floating category chip with image and name
  Widget _buildCategoryChip({
    required String category,
    required bool isSelected,
    required String imageUrl,
    required double chipHeight,
    required VoidCallback onTap,
  }) {
    // Calculate proportional sizes based on chipHeight
    // Adjusted for vertical layout: image box + spacing + text
    final heightRatio = chipHeight / 47.5;
    // Reduce image size to fit better in vertical layout
    final imageSize = 50.0 * heightRatio; // Square image box (reduced from 60)
    final borderRadius = 10.0 * heightRatio; // Rounded corners for box
    final fontSize = 11.0 * heightRatio; // Slightly smaller font
    final iconSize = 20.0 * heightRatio; // Slightly smaller icon
    final textSpacing = 4.0 * heightRatio; // Space between image and text (reduced)

    // Performance: Derive image URL from cached value
    final categoryImageUrl = imageUrl.isNotEmpty ? imageUrl : null;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Image box with orange background when selected, light grey when not selected
          Container(
            width: imageSize,
            height: imageSize,
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.orange[600]!
                  : Colors.grey[200], // Orange when selected, light grey when not
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.0),
                  blurRadius: 8 * heightRatio,
                  offset: Offset(0, 2 * heightRatio),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: categoryImageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(borderRadius),
                    child: CachedNetworkImage(
                      imageUrl: categoryImageUrl,
                      width: imageSize,
                      height: imageSize,
                      fit: BoxFit.cover,
                      // Performance: Downscale to 2x display pixels for crisp @ 2x DPI
                      memCacheWidth: (imageSize * 2).toInt(),
                      memCacheHeight: (imageSize * 2).toInt(),
                      // Performance: Low quality filter for tiny images
                      filterQuality: FilterQuality.low,
                      // Performance: Disable fade animation (saves GPU work)
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      placeholder: (context, url) => Container(
                        width: imageSize,
                        height: imageSize,
                        color: isSelected
                            ? Colors.orange[600]!
                            : Colors.grey[300],
                      ),
                      errorWidget: (context, url, error) {
                        return Container(
                          width: imageSize,
                          height: imageSize,
                          color: isSelected
                              ? Colors.orange[600]!
                              : Colors.grey[300],
                          child: Icon(
                            Icons.restaurant,
                            size: iconSize,
                            color: isSelected
                                ? Colors.white
                                : Colors.black54,
                          ),
                        );
                      },
                    ),
                  )
                : Container(
                    width: imageSize,
                    height: imageSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(borderRadius),
                      color: isSelected
                          ? Colors.orange[600]!
                          : Colors.grey[300],
                    ),
                    child: Icon(
                      Icons.grid_view_rounded,
                      size: iconSize,
                      color: isSelected
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
          ),

          // Text below image
          SizedBox(height: textSpacing),
          Text(
            _localizeCategoryName(context, category),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? const Color(0xFFF57C00) : Colors.black87,
            ),
            textDirection: Directionality.of(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<List<String>> _loadCategories() async {
    // NOTE: Do NOT add "All" category here - it will be added in build() method
    // where we have proper access to context and current locale

    try {
      debugPrint("🏷️ Loading categories...");

      // OPTIMIZATION: Try loading from HomeCacheService first
      // This is faster than startup data and provides app-wide caching
      final cachedCategories = await HomeCacheService.loadCategories();
      if (cachedCategories.isNotEmpty) {
        debugPrint(
            "✅ Loaded ${cachedCategories.length} categories from HomeCacheService");
        return cachedCategories;
      }

      // Check if data was preloaded during splash screen
      final startupDataService = StartupDataService();
      if (startupDataService.isInitialized &&
          startupDataService.cachedCategories.isNotEmpty) {
        debugPrint(
            "🚀 CategoriesSection: Using preloaded categories from splash screen");

        try {
          // Convert cached data to category names
          final categories = startupDataService.cachedCategories
              .map((json) => json["name"] as String? ?? "")
              .where((name) => name.isNotEmpty)
              .toList();

          debugPrint(
              "✅ CategoriesSection: Loaded ${categories.length} categories from preloaded data");

          // OPTIMIZATION: Cache for faster future loads
          await HomeCacheService.saveCategories(categories);
          debugPrint("💾 Saved preloaded categories to cache");

          return categories;
        } on Exception catch (e) {
          debugPrint(
              "❌ CategoriesSection: Error loading preloaded categories: $e");
          // Fall through to normal loading
        }
      }

      debugPrint("🏷️ Selected cuisines: ${widget.selectedCuisines}");

      // If specific cuisines are selected, filter categories by those cuisines
      if (widget.selectedCuisines != null &&
          widget.selectedCuisines!.isNotEmpty) {
        debugPrint(
            "🏷️ Filtering categories by selected cuisines: ${widget.selectedCuisines}");

        // Get cuisine type IDs for the selected cuisine names
        final cuisineService = CuisineService();
        final cuisineTypes = await cuisineService.getActiveCuisineTypes();
        final selectedCuisineIds = <String>{};

        for (final cuisineName in widget.selectedCuisines!) {
          final normalizedCuisine = widget.normalizeCategoryKey(cuisineName);
          for (final cuisineType in cuisineTypes) {
            if (widget.normalizeCategoryKey(cuisineType.name) ==
                normalizedCuisine) {
              selectedCuisineIds.add(cuisineType.id);
              break;
            }
          }
        }

        debugPrint("🏷️ Selected cuisine IDs: $selectedCuisineIds");

        // Get categories that belong to these cuisine types
        // OPTIMIZATION: Use single batched query instead of N queries
        final allCategories = <String>{};
        if (selectedCuisineIds.isNotEmpty) {
          try {
            final categoryRows = await supa.Supabase.instance.client
                .from("categories")
                .select("name")
                .eq("is_active", "true")
                .inFilter("cuisine_type_id", selectedCuisineIds.toList())
                .order("display_order")
                .order("name") as List<dynamic>;

            for (final row in categoryRows) {
              final categoryName = (row["name"] as String?)?.trim();
              if (categoryName != null && categoryName.isNotEmpty) {
                allCategories.add(categoryName);
              }
            }
            debugPrint(
                "✅ Batched fetch: ${allCategories.length} categories for ${selectedCuisineIds.length} cuisines");
          } on Exception catch (e) {
            debugPrint("❌ Error fetching categories for cuisines: $e");
          }
        }

        if (allCategories.isNotEmpty) {
          final categoryNames = allCategories.toList()..sort();

          // OPTIMIZATION: Cache filtered categories for faster future loads
          await HomeCacheService.saveCategories(categoryNames);
          debugPrint(
              "💾 Saved ${categoryNames.length} filtered categories to cache");

          debugPrint("🏷️ Filtered categories: $categoryNames");
          return categoryNames;
        }
      }

      // If no specific cuisines selected, get all active categories
      final categoryRows = await supa.Supabase.instance.client
          .from("categories")
          .select("name")
          .eq("is_active", "true")
          .order("display_order")
          .order("name") as List<dynamic>;

      final categoryNames = categoryRows
          .map((row) => ((row["name"] as String?)?.trim() ?? ""))
          .where((name) => name.isNotEmpty)
          .where(
              (name) => !_isDrinksCategory(name)) // Filter out drinks/poissons
          .toSet()
          .toList()
        ..sort();

      debugPrint("🏷️ All categories: $categoryNames");

      if (categoryNames.isNotEmpty) {
        // OPTIMIZATION: Cache categories for faster future loads
        await HomeCacheService.saveCategories(categoryNames);
        debugPrint("💾 Saved ${categoryNames.length} categories to cache");

        return categoryNames;
      }

      // Fallback to MenuItemDisplayService
      debugPrint("🏷️ CategoryService empty, trying MenuItemDisplayService...");
      final menuItemService = MenuItemDisplayService();
      final fallbackCategories = await menuItemService.getCategories();
      debugPrint(
          "🏷️ MenuItemDisplayService returned ${fallbackCategories.length} categories: $fallbackCategories");

      if (fallbackCategories.isNotEmpty) {
        // OPTIMIZATION: Cache fallback categories
        await HomeCacheService.saveCategories(fallbackCategories);
        debugPrint("💾 Saved fallback categories to cache");

        return fallbackCategories;
      }

      // Final fallback - return some default categories
      debugPrint("🏷️ Both services empty, using default categories");
      return [
        "Fast Food",
        "Italian",
        "Grills",
        "Desserts",
        "Beverages",
        "Main Courses"
      ];
    } on Exception catch (e) {
      debugPrint("❌ Error loading categories: $e");
      // Return default categories on error
      return [
        "Fast Food",
        "Italian",
        "Grills",
        "Desserts",
        "Beverages",
        "Main Courses"
      ];
    }
  }

  /// Load category statistics (menu item count and review count) for smart sorting
  Future<void> _loadCategoryStats() async {
    try {
      debugPrint("📊 Loading category statistics...");

      // Query to get menu item count and total review count per category
      final supabase = supa.Supabase.instance.client;

      // Get menu items with their categories and review counts
      final menuItems = await supabase
          .from("menu_items")
          .select("category, review_count")
          .eq("is_available", "true") as List<dynamic>;

      // Calculate statistics per category
      final Map<String, Map<String, int>> stats = {};

      for (final item in menuItems) {
        final category = (item["category"] as String?)?.trim() ?? "";
        final reviewCount = (item["review_count"] as int?) ?? 0;

        if (category.isEmpty) continue;

        if (!stats.containsKey(category)) {
          stats[category] = {"itemCount": 0, "reviewCount": 0};
        }

        stats[category]!["itemCount"] =
            (stats[category]!["itemCount"] ?? 0) + 1;
        stats[category]!["reviewCount"] =
            (stats[category]!["reviewCount"] ?? 0) + reviewCount;
      }

      if (mounted) {
        setState(() {
          _categoryStats.clear();
          _categoryStats.addAll(stats);
        });

        debugPrint("📊 Category statistics loaded:");
        stats.forEach((category, data) {
          debugPrint(
              "  $category: ${data['itemCount']} items, ${data['reviewCount']} reviews");
        });
      }
    } catch (e) {
      debugPrint("❌ Error loading category statistics: $e");
    }
  }

  @override
  void dispose() {
    _categoryUpdatesSubscription?.cancel();
    _updateThrottleTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CategoriesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = widget.selectedCuisines ?? const <String>{};
    final previous = oldWidget.selectedCuisines ?? const <String>{};
    if (current.length != previous.length || !current.containsAll(previous)) {
      setState(() {
        _future = _loadCategories();
      });
    }
  }

  /// Check if a category is a drinks/beverages category that should be hidden
  bool _isDrinksCategory(String categoryName) {
    final lowerName = categoryName.toLowerCase();
    return lowerName.contains("poissons") ||
        lowerName.contains("drinks") ||
        lowerName.contains("beverages") ||
        lowerName.contains("boissons");
  }

  /// Check if a category is the "All" category (supports multiple languages)
  bool _isAllCategory(String category) {
    final lowerCategory = category.toLowerCase();
    return lowerCategory == "all" ||
        lowerCategory == "all categories" ||
        lowerCategory == "جميع الفئات" ||
        category == "All" ||
        category == "All Categories" ||
        category == "جميع الفئات" ||
        category == "الكل";
  }

  /// Localize category name - only "All" button needs localization, others use DB names directly
  String _localizeCategoryName(BuildContext context, String categoryName) {
    // Only localize the "All" button, keep other categories as-is from database
    if (_isAllCategory(categoryName)) {
      final isRTL = Localizations.localeOf(context).languageCode == 'ar';
      return isRTL ? "الكل" : "All";
    }

    // Return database category name as-is
    return categoryName;
  }

  /// Check if a category is a special packs category that should be pinned to top
  bool _isSpecialPacksCategory(String normalizedKey, String lowerName) {
    // Never treat "All" as a special packs category
    if (_isAllCategory(lowerName)) {
      return false;
    }

    // Check normalized key variations
    if (normalizedKey.contains("special_packs") ||
        normalizedKey.contains("specialpacks") ||
        normalizedKey.contains("special-packs")) {
      return true;
    }

    // Check name variations
    if (lowerName.contains("special packs") ||
        lowerName.contains("specialpacks") ||
        lowerName.contains("special-packs") ||
        lowerName.contains("packs spéciaux") ||
        lowerName.contains("paquets spéciaux") ||
        lowerName.contains("offres spéciales") ||
        lowerName.contains("promotions") ||
        lowerName.contains("deals") ||
        lowerName.contains("bundles")) {
      return true;
    }

    return false;
  }

  /// Handle category tap - move tapped category to top and call toggle
  void _onCategoryTapped(String category) {
    // Check if category is currently selected
    final isCurrentlySelected =
        (widget.selectedCategories ?? const <String>{}).contains(category);

    setState(() {
      if (!isCurrentlySelected) {
        // Category is being selected - move to top
        // Remove if already exists
        _recentlyTappedCategories.remove(category);
        // Add to the beginning
        _recentlyTappedCategories.insert(0, category);
        // Keep only the last 5 tapped categories
        if (_recentlyTappedCategories.length > 5) {
          _recentlyTappedCategories.removeLast();
        }
        debugPrint("📌 Category selected and moved to top: $category");
      } else {
        // Category is being unselected - remove from recently tapped
        _recentlyTappedCategories.remove(category);
        debugPrint(
            "📌 Category unselected and returned to original position: $category");
      }
      debugPrint("📌 Recently tapped order: $_recentlyTappedCategories");
    });

    // Call the original toggle callback
    widget.onCategoryToggle?.call(category);
  }

  /// Sort categories with recently tapped ones at the top
  List<String> _sortCategoriesWithRecentlyTapped(List<String> categories) {
    final List<String> selectedAndRecentlyTapped = [];
    final List<String> specialPacks = [];
    final List<String> others = [];

    final selectedCategories = widget.selectedCategories ?? const <String>{};

    for (final c in categories) {
      // Skip normalization for "All" category
      if (_isAllCategory(c)) {
        others.add(c);
        continue;
      }

      final normalizedKey = widget.normalizeCategoryKey(c);
      final lowerName = c.toLowerCase();

      // Check for special packs FIRST - it should always be at the top
      if (_isSpecialPacksCategory(normalizedKey, lowerName)) {
        specialPacks.add(c);
      }
      // Check if this category was recently tapped AND is currently selected
      // This ensures unselected categories return to their original position
      else if (_recentlyTappedCategories.contains(c) &&
          selectedCategories.contains(c)) {
        selectedAndRecentlyTapped.add(c);
      } else {
        others.add(c);
      }
    }

    // Sort selected and recently tapped by the order they were tapped (most recent first)
    selectedAndRecentlyTapped.sort((a, b) {
      final aIndex = _recentlyTappedCategories.indexOf(a);
      final bIndex = _recentlyTappedCategories.indexOf(b);
      return aIndex.compareTo(bIndex);
    });

    // Smart sort "others" based on menu item count and review count
    others.sort((a, b) {
      final aStats = _categoryStats[a];
      final bStats = _categoryStats[b];

      // If no stats available, maintain alphabetical order
      if (aStats == null && bStats == null) return a.compareTo(b);
      if (aStats == null) return 1; // b has priority
      if (bStats == null) return -1; // a has priority

      // Calculate score: (itemCount * 2) + reviewCount
      // Item count weighted more heavily than reviews
      final aScore =
          (aStats["itemCount"] ?? 0) * 2 + (aStats["reviewCount"] ?? 0);
      final bScore =
          (bStats["itemCount"] ?? 0) * 2 + (bStats["reviewCount"] ?? 0);

      // Higher score comes first (descending order)
      return bScore.compareTo(aScore);
    });

    // Combine: selected recently tapped, then smart-sorted others
    // Special packs are hidden - not included in the list
    return [...selectedAndRecentlyTapped, ...others];
  }

  /// Build categories list for pre-filtered categories
  Widget _buildCategoriesList(List<String> categories, double reducedCardWidth,
      double reducedCardHeight, double adaptiveHeight) {
    // Sort categories with recently tapped ones at the top
    final limited = _sortCategoriesWithRecentlyTapped(categories);

    // Ensure "All" category is always first if it exists
    if (widget.showAllCategory) {
      final allCategoryIndex = limited.indexWhere((c) => _isAllCategory(c));
      if (allCategoryIndex > 0) {
        final allCategory = limited.removeAt(allCategoryIndex);
        limited.insert(0, allCategory);
      } else if (allCategoryIndex == -1) {
        final isRTL = Localizations.localeOf(context).languageCode == 'ar';
        limited.insert(0, isRTL ? "الكل" : "All");
      }
    }

    final scrollableCategories = limited;

    // Performance: Precompute image URLs once
    _precomputeImageUrls(scrollableCategories);

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: adaptiveHeight,
        maxHeight: adaptiveHeight,
      ),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          scrollbars: false,
          overscroll: false,
        ),
        child: Center(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            // Performance: Use platform default physics
            padding: const EdgeInsetsDirectional.only(
              start: 12,
              end: 12,
            ),
            clipBehavior: Clip.none,
            itemCount: scrollableCategories.length,
            // Performance: Reduce cache extent
            cacheExtent: 200,
            // Note: No itemExtent - allow variable-width chips based on text content
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            itemBuilder: (context, index) {
              final category = scrollableCategories[index];
              final bool isSelected =
                  (widget.selectedCategories ?? const <String>{})
                          .contains(category) ||
                      (_isAllCategory(category) &&
                          widget.selectedCategories?.isEmpty == true);

              // Performance: Use cached image URL
              final imageUrl = _imageUrlCache[category] ?? "";

              return RepaintBoundary(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: index == 0 ? 0 : 8,
                    end: index < scrollableCategories.length - 1 ? 8 : 0,
                  ),
                  child: _buildCategoryChip(
                    category: category,
                    isSelected: isSelected,
                    imageUrl: imageUrl,
                    chipHeight: adaptiveHeight,
                    onTap: () {
                      _onCategoryTapped(category);
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesShimmer(double cardHeight, double adaptiveHeight) {
    // Calculate proportional sizes based on adaptiveHeight
    final heightRatio = adaptiveHeight / 47.5;
    final imageSize = 50.0 * heightRatio;
    final textSpacing = 4.0 * heightRatio;
    final textHeight = 17.0; // Text height with line height (increased from 15)
    final calculatedHeight = imageSize + textSpacing + textHeight;
    final horizontalPadding = 12 * heightRatio;
    final verticalPadding = 7 * heightRatio;
    final borderRadius = 20 * heightRatio;
    final itemSpacing = 8 * heightRatio;

    return SizedBox(
      height: calculatedHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding, vertical: verticalPadding),
        itemCount: 6, // Show 6 shimmer chips
        itemBuilder: (context, index) {
          return Container(
            width: index == 0
                ? 104.5 * heightRatio
                : 90.25 * heightRatio, // Variable width for chip-like look
            height: calculatedHeight - (verticalPadding * 2),
            margin:
                EdgeInsetsDirectional.only(end: index < 5 ? itemSpacing : 0),
            child: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
