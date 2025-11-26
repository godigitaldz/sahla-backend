import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../l10n/app_localizations.dart';
import '../../services/restaurant_search_service.dart';

class CategorySelectorModal extends StatefulWidget {
  final RestaurantSearchService searchService;

  const CategorySelectorModal({
    required this.searchService,
    super.key,
  });

  @override
  State<CategorySelectorModal> createState() => _CategorySelectorModalState();
}

class _CategorySelectorModalState extends State<CategorySelectorModal> {
  // Static cache for categories to avoid repeated database calls
  static List<String>? _cachedCategories;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheDuration =
      Duration(minutes: 10); // Increased cache duration

  // Performance optimizations
  late final Future<List<String>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Text(
                    l10n?.selectCategories ?? 'Select Categories',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          widget.searchService.setCategoryFilter({});
                          Navigator.pop(context);
                        },
                        child: Text(
                          l10n?.clear ?? 'Clear',
                          style: GoogleFonts.inter(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          l10n?.done ?? 'Done',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFB8C00),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Category list with optimized loading and caching
            Expanded(
              child: FutureBuilder<List<String>>(
                future: _categoriesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Text(l10n?.noCategoriesAvailable ?? 'No categories available'),
                    );
                  }

                  final categories = snapshot.data!;

                  return RepaintBoundary(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: categories.length,
                      // Maximum performance optimizations
                      cacheExtent: 500, // Increased cache for better scrolling
                      addAutomaticKeepAlives:
                          false, // Don't keep items alive when scrolled out
                      addRepaintBoundaries:
                          true, // Add repaint boundaries for better performance
                      physics:
                          const BouncingScrollPhysics(), // Better scroll physics
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final isSelected = widget
                            .searchService.selectedCategories
                            .contains(category);

                        return RepaintBoundary(
                          key: ValueKey('category_$index'),
                          child: _CategoryItem(
                            category: category,
                            isSelected: isSelected,
                            onTap: () => _toggleCategory(category),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleCategory(String category) {
    setState(() {
      if (widget.searchService.selectedCategories.contains(category)) {
        widget.searchService.setCategoryFilter(
            {...widget.searchService.selectedCategories}..remove(category));
      } else {
        widget.searchService.setCategoryFilter(
            {...widget.searchService.selectedCategories, category});
      }
    });
  }

  Future<List<String>> _loadCategories() async {
    // Check cache first
    if (_cachedCategories != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      debugPrint(
          '🏷️ CategorySelectorModal: Using cached categories (${_cachedCategories!.length} items)');
      return _cachedCategories!;
    }

    return _loadCategoriesForSelectedCuisines();
  }

  Future<List<String>> _loadCategoriesForSelectedCuisines() async {
    try {
      final client = supa.Supabase.instance.client;

      // If specific cuisines are selected, filter categories by those cuisines
      if (widget.searchService.selectedCuisines.isNotEmpty) {
        // Get cuisine type IDs for the selected cuisine names
        final cuisineRows = await client
            .from('cuisine_types')
            .select('id,name')
            .eq('is_active', true)
            .order('name') as List<dynamic>;

        final selectedCuisineIds = <String>{};
        for (final cuisineName in widget.searchService.selectedCuisines) {
          for (final cuisineRow in cuisineRows) {
            if ((cuisineRow['name'] as String).toLowerCase() ==
                cuisineName.toLowerCase()) {
              selectedCuisineIds.add(cuisineRow['id'] as String);
              break;
            }
          }
        }

        // Get categories that belong to these cuisine types
        final allCategories = <String>{};
        for (final cuisineId in selectedCuisineIds) {
          final categoryRows = await client
              .from('categories')
              .select('id,name')
              .eq('is_active', true)
              .eq('cuisine_type_id', cuisineId)
              .order('name') as List<dynamic>;

          for (final categoryRow in categoryRows) {
            final categoryName = (categoryRow['name'] as String).trim();
            if (!_isDrinksCategory(categoryName)) {
              allCategories.add(categoryName);
            }
          }
        }

        return allCategories.toList()..sort();
      }

      // If no specific cuisines selected, get all active categories
      final categoryRows = await client
          .from('categories')
          .select('id,name')
          .eq('is_active', true)
          .order('name') as List<dynamic>;

      final categories = categoryRows
          .map((row) => (row['name'] as String).trim())
          .where((name) => !_isDrinksCategory(name)) // Filter out drinks
          .toList()
        ..sort();

      // Cache the results
      _cachedCategories = categories;
      _cacheTimestamp = DateTime.now();

      debugPrint(
          '🏷️ CategorySelectorModal: Loaded ${categories.length} categories from database (drinks filtered)');
      return categories;
    } catch (e) {
      debugPrint('❌ CategorySelectorModal: Error loading categories: $e');

      // Return cached data if available, even if expired
      if (_cachedCategories != null) {
        debugPrint(
            '🏷️ CategorySelectorModal: Using expired cache due to error');
        return _cachedCategories!;
      }

      return [];
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
}

// Optimized category item widget for maximum performance
class _CategoryItem extends StatelessWidget {
  final String category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryItem({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected
                  ? const Color(0xFFFB8C00).withValues(alpha: 0.1)
                  : Colors.transparent,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    category,
                    style: GoogleFonts.inter(
                      color:
                          isSelected ? const Color(0xFFFB8C00) : Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isSelected
                      ? const Icon(
                          Icons.check_circle,
                          key: ValueKey('selected'),
                          color: Color(0xFFFB8C00),
                          size: 24,
                        )
                      : const Icon(
                          Icons.circle_outlined,
                          key: ValueKey('unselected'),
                          color: Colors.grey,
                          size: 24,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
