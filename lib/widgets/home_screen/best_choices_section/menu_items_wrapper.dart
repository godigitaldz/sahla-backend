import 'package:flutter/material.dart';

import '../menu_items_section.dart';
import 'cached_menu_item_dimensions.dart';

/// Menu items section wrapper widget
///
/// PERFORMANCE OPTIMIZED: No Consumer! Props passed from parent to avoid rebuilds on scroll
/// This widget now only rebuilds when its actual data changes, not on every scroll event
class MenuItemsWrapper extends StatelessWidget {
  const MenuItemsWrapper({
    required this.selectedCategories,
    required this.selectedCuisines,
    required this.priceRange,
    this.allowedRestaurantIds,
    this.dimensions,
    this.searchQuery,
    super.key,
  });

  final Set<String> selectedCategories;
  final Set<String> selectedCuisines;
  final RangeValues? priceRange;
  final Set<String>? allowedRestaurantIds;
  final CachedMenuItemDimensions? dimensions;
  final String? searchQuery;

  @override
  Widget build(BuildContext context) {
    // NO Consumer - just build with provided props!
    return MenuItemsSection(
      title: '', // Empty title since we show it above
      showFeatured: false,
      selectedCategories: selectedCategories,
      selectedCuisines: selectedCuisines,
      searchQuery: searchQuery, // Pass search query for menu item filtering
      priceRange: priceRange,
      allowedRestaurantIds: allowedRestaurantIds,
      onViewAll: () async {
        await Navigator.of(context).pushNamed("/menu-items-list");
      },
      dimensions: dimensions, // Pass cached dimensions!
    );
  }
}
