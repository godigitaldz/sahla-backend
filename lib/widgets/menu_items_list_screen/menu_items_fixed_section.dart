import 'package:flutter/material.dart';

import '../../services/restaurant_search_service.dart';
import '../../widgets/filter_chips_section/filter_chips_section.dart';
import '../../widgets/simple_category_filter.dart';

/// Fixed section widget that contains category filter and filter chips
/// This section stays fixed at the top while the menu items scroll below
class MenuItemsFixedSection extends StatelessWidget {
  const MenuItemsFixedSection({
    required this.searchService,
    required this.selectedCategories,
    required this.onCategoryToggle,
    required this.onLocationTap,
    required this.onCuisineTap,
    required this.onCategoryTap,
    required this.onPriceTap,
    required this.onClearAllTap,
    required this.onDeliveryFeeToggle,
    super.key,
  });

  final RestaurantSearchService searchService;
  final Set<String> selectedCategories;
  final void Function(String category) onCategoryToggle;
  final VoidCallback onLocationTap;
  final VoidCallback onCuisineTap;
  final VoidCallback onCategoryTap;
  final VoidCallback onPriceTap;
  final VoidCallback onClearAllTap;
  final Function({bool isActive}) onDeliveryFeeToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Simple category filter section
          SimpleCategoryFilter(
            selectedCategories: selectedCategories,
            onCategoryToggle: onCategoryToggle,
          ),

          // Filter chips section (directly below categories, no gap)
          FilterChipsSection(
            searchService: searchService,
            onLocationTap: onLocationTap,
            onCuisineTap: onCuisineTap,
            onCategoryTap: onCategoryTap,
            onPriceTap: onPriceTap,
            onClearAllTap: onClearAllTap,
            onDeliveryFeeToggle: onDeliveryFeeToggle,
          ),
        ],
      ),
    );
  }
}
