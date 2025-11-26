import 'package:flutter/material.dart';

/// Pinned header containing category chips
/// This widget sticks under the app bar while content scrolls beneath
class PinnedSearchAndCategories extends StatelessWidget {
  const PinnedSearchAndCategories({
    required this.categories,
    required this.selectedCategory,
    required this.onCategoryToggle,
    required this.normalizeCategoryKey,
    super.key,
  });

  final List<String> categories;
  final String selectedCategory;
  final Function(String) onCategoryToggle;
  final String Function(String) normalizeCategoryKey;

  /// Localize category name - only "All" button needs localization, others use DB names directly
  String _localizeCategoryName(BuildContext context, String categoryName) {
    // Only localize the "All" button, keep other categories as-is from database
    if (categoryName.toLowerCase() == "all" ||
        categoryName.toLowerCase() == "all categories" ||
        categoryName == "جميع الفئات" ||
        categoryName == "All" ||
        categoryName == "All Categories" ||
        categoryName == "الكل") {
      final isRTL = Localizations.localeOf(context).languageCode == 'ar';
      return isRTL ? "الكل" : "All";
    }

    // Return database category name as-is
    return categoryName;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top spacing
          const SizedBox(height: 0),

          // Category chips with horizontal scroll (centered horizontally and vertically)
          SizedBox(
            height: 45,
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int index = 0; index < categories.length; index++)
                      Padding(
                        padding: EdgeInsets.only(
                          right: index < categories.length - 1 ? 12 : 0,
                        ),
                        child: _buildCategoryChip(
                          context: context,
                          category: categories[index],
                          isSelected: selectedCategory == categories[index],
                          onTap: () => onCategoryToggle(categories[index]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom spacing
          const SizedBox(height: 0),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required BuildContext context,
    required String category,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(left: 8, right: 8, top: 0, bottom: 0),
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
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: Colors.grey[800],
            ),
            textDirection: Directionality.of(context),
          ),
        ),
      ),
    );
  }
}

/// Persistent header delegate for the pinned categories section
class PinnedSearchAndCategoriesDelegate extends SliverPersistentHeaderDelegate {
  PinnedSearchAndCategoriesDelegate({
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
  bool shouldRebuild(covariant PinnedSearchAndCategoriesDelegate oldDelegate) {
    return child != oldDelegate.child || height != oldDelegate.height;
  }
}
