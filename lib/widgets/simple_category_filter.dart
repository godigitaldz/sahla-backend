import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:supabase_flutter/supabase_flutter.dart" as supa;

import "../services/home/home_cache_service.dart";
import "../services/menu_item_display_service.dart";
import "../services/startup_data_service.dart";

/// Simple text-based category filter for menu items list screen
class SimpleCategoryFilter extends StatefulWidget {
  const SimpleCategoryFilter({
    required this.selectedCategories,
    required this.onCategoryToggle,
    this.categories,
    super.key,
  });

  final Set<String> selectedCategories;
  final void Function(String category) onCategoryToggle;
  final List<String>?
      categories; // Optional: if provided, use these instead of loading

  @override
  State<SimpleCategoryFilter> createState() => _SimpleCategoryFilterState();
}

class _SimpleCategoryFilterState extends State<SimpleCategoryFilter> {
  late Future<List<String>> _categoriesFuture;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Use provided categories if available, otherwise load from database
    if (widget.categories != null && widget.categories!.isNotEmpty) {
      _categoriesFuture = Future.value(_organizeCategories(widget.categories!));
    } else {
      _categoriesFuture = _loadCategories();
    }
  }

  @override
  void didUpdateWidget(SimpleCategoryFilter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update categories if the categories prop changed
    if (widget.categories != oldWidget.categories) {
      if (widget.categories != null && widget.categories!.isNotEmpty) {
        _categoriesFuture =
            Future.value(_organizeCategories(widget.categories!));
      } else if (oldWidget.categories != null &&
          oldWidget.categories!.isNotEmpty) {
        // Categories were removed, fall back to loading from database
        _categoriesFuture = _loadCategories();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<String>> _loadCategories() async {
    try {
      debugPrint("🏷️ Loading categories for simple filter...");

      // Try loading from HomeCacheService first
      final cachedCategories = await HomeCacheService.loadCategories();
      if (cachedCategories.isNotEmpty) {
        debugPrint("✅ Loaded ${cachedCategories.length} categories from cache");
        return _organizeCategories(cachedCategories);
      }

      // Check if data was preloaded during splash screen
      final startupDataService = StartupDataService();
      if (startupDataService.isInitialized &&
          startupDataService.cachedCategories.isNotEmpty) {
        debugPrint("🚀 Using preloaded categories from splash screen");

        try {
          final categories = startupDataService.cachedCategories
              .map((json) => json["name"] as String? ?? "")
              .where((name) => name.isNotEmpty)
              .toList();

          debugPrint(
              "✅ Loaded ${categories.length} categories from preloaded data");

          await HomeCacheService.saveCategories(categories);
          return _organizeCategories(categories);
        } on Exception catch (e) {
          debugPrint("❌ Error loading preloaded categories: $e");
        }
      }

      // Load from database
      final categoryRows = await supa.Supabase.instance.client
          .from("categories")
          .select("name")
          .eq("is_active", "true")
          .order("display_order")
          .order("name") as List<dynamic>;

      final categoryNames = categoryRows
          .map((row) => ((row["name"] as String?)?.trim() ?? ""))
          .where((name) => name.isNotEmpty)
          .where((name) => !_isDrinksCategory(name))
          .toSet()
          .toList()
        ..sort();

      if (categoryNames.isNotEmpty) {
        await HomeCacheService.saveCategories(categoryNames);
        debugPrint("💾 Saved ${categoryNames.length} categories to cache");
        return _organizeCategories(categoryNames);
      }

      // Fallback to MenuItemDisplayService
      final menuItemService = MenuItemDisplayService();
      final fallbackCategories = await menuItemService.getCategories();

      if (fallbackCategories.isNotEmpty) {
        await HomeCacheService.saveCategories(fallbackCategories);
        return _organizeCategories(fallbackCategories);
      }

      return [];
    } on Exception catch (e) {
      debugPrint("❌ Error loading categories: $e");
      return [];
    }
  }

  /// Smart organization: remove "All" and "Special Packs" from list since they'll be added at the top
  List<String> _organizeCategories(List<String> categories) {
    final organized = <String>[];

    for (final category in categories) {
      // Skip "All" and "Special Packs" - they'll be added separately
      if (!_isAllCategory(category) && !_isSpecialPacksCategory(category)) {
        organized.add(category);
      }
    }

    return organized;
  }

  bool _isDrinksCategory(String categoryName) {
    final lowerName = categoryName.toLowerCase();
    return lowerName.contains("poissons") ||
        lowerName.contains("drinks") ||
        lowerName.contains("beverages") ||
        lowerName.contains("boissons");
  }

  bool _isAllCategory(String category) {
    final lowerCategory = category.toLowerCase();
    return lowerCategory == "all" ||
        lowerCategory == "all categories" ||
        lowerCategory == "جميع الفئات" ||
        lowerCategory == "(all)" ||
        lowerCategory == "(tout)" ||
        category == "All" ||
        category == "All Categories" ||
        category == "جميع الفئات" ||
        category == "الكل" ||
        category == "(All)" ||
        category == "(Tout)";
  }

  bool _isSpecialPacksCategory(String category) {
    final lowerCategory = category.toLowerCase();
    final normalizedKey = category
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r"[\s-]+"), "_")
        .replaceAll(RegExp("[^a-z0-9_]+"), "");

    // Check normalized key variations
    if (normalizedKey.contains("special_packs") ||
        normalizedKey.contains("specialpacks") ||
        normalizedKey.contains("special_pack") ||
        normalizedKey.contains("specialpack")) {
      return true;
    }

    // Check name variations
    if (lowerCategory.contains("special packs") ||
        lowerCategory.contains("special pack") ||
        lowerCategory == "special packs" ||
        lowerCategory == "special pack" ||
        lowerCategory.contains("packs spéciaux") ||
        lowerCategory.contains("حزم خاصة") ||
        lowerCategory.contains("عروض خاصة")) {
      return true;
    }

    return false;
  }

  String _localizeCategoryName(BuildContext context, String categoryName) {
    if (_isAllCategory(categoryName)) {
      final locale = Localizations.localeOf(context).languageCode;
      final isRTL = locale == 'ar';
      return isRTL ? "الكل" : locale == 'fr' ? "(Tout)" : "(All)";
    }
    if (_isSpecialPacksCategory(categoryName)) {
      // Keep Special Packs in English to match database entries
      return "Special Packs";
    }
    return categoryName;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmer();
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final categories = snapshot.data!;
        final isRTL = Localizations.localeOf(context).languageCode == 'ar';

        // Smart organization: Always put "All" and "Special Packs" at the top
        final locale = Localizations.localeOf(context).languageCode;
        final allCategoryText = isRTL
            ? "الكل"
            : locale == 'fr'
                ? "(Tout)"
                : "(All)";
        final allCategories = [
          // 1. All category (always first)
          allCategoryText,
          // 2. Special Packs (always second) - kept in English to match database
          "Special Packs",
          // 3. All other categories
          ...categories,
        ];

        return SizedBox(
          height: 48,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            // Smooth scrolling physics
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: allCategories.length,
            itemBuilder: (context, index) {
              final category = allCategories[index];
              final isSelected = _isAllCategory(category)
                  ? widget.selectedCategories.isEmpty
                  : widget.selectedCategories.contains(category);

              return Padding(
                padding: EdgeInsets.only(
                  right: isRTL ? 0 : 12,
                  left: isRTL ? 12 : 0,
                ),
                child: _buildCategoryItem(
                  context,
                  category,
                  isSelected,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCategoryItem(
    BuildContext context,
    String category,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () => widget.onCategoryToggle(category),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.grey[800]! : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Center(
          child: Text(
            _localizeCategoryName(context, category),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        // Smooth scrolling physics
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              width: 60,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        },
      ),
    );
  }
}
