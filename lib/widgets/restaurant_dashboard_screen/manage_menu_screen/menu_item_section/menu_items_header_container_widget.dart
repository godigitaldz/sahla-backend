import 'package:flutter/material.dart';

import '../../../../widgets/simple_category_filter.dart';
import '../manage_menu_header_widget.dart';
import '../restaurant_panel_widget.dart';

/// Menu Items Header Container Widget
/// Displays the white container with header, panel, and category filter
class MenuItemsHeaderContainerWidget extends StatelessWidget {
  final double statusBarHeight;
  final double screenWidth;
  final TextEditingController searchController;
  final VoidCallback onBack;
  final Function(String) onSearchChanged;
  final VoidCallback onDrinksTap;
  final VoidCallback onSupplementsTap;
  final VoidCallback onLTOTap;
  final Set<String> selectedCategories;
  final List<String> categories;
  final Function(String) onCategoryToggle;

  const MenuItemsHeaderContainerWidget({
    required this.statusBarHeight,
    required this.screenWidth,
    required this.searchController,
    required this.onBack,
    required this.onSearchChanged,
    required this.onDrinksTap,
    required this.onSupplementsTap,
    required this.onLTOTap,
    required this.selectedCategories,
    required this.categories,
    required this.onCategoryToggle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    const headerTop = 0.0;
    const headerHeight = 43.2;

    // Calculate total height needed for white container
    const panelTopPadding = 8.0;
    const panelBottomPadding = 8.0;
    final panelCardHeight = ((screenWidth - 48) / 3) * 0.75;
    final panelHeight = panelTopPadding + panelCardHeight + panelBottomPadding;

    const categoryHeight = 48;
    const headerPanelSpacing = 8.0;

    final whiteContainerHeight = statusBarHeight +
        headerHeight +
        headerPanelSpacing +
        panelHeight +
        categoryHeight;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: whiteContainerHeight,
      child: Container(
        color: Colors.white,
        child: Stack(
          children: [
            // Status bar area (white background)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: statusBarHeight,
              child: Container(
                color: Colors.white,
              ),
            ),
            // Header positioned immediately below status bar
            ManageMenuHeaderWidget(
              statusBarHeight: statusBarHeight,
              onBack: onBack,
              searchController: searchController,
              onSearchChanged: onSearchChanged,
            ),
            // Panel and categories positioned below header
            Positioned(
              top: statusBarHeight + headerTop + headerHeight + 8,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RestaurantPanelWidget(
                    onDrinksTap: onDrinksTap,
                    onSupplementsTap: onSupplementsTap,
                    onLTOTap: onLTOTap,
                  ),
                  _buildSimpleCategoryFilter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleCategoryFilter() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/icon/edge.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: SimpleCategoryFilter(
        selectedCategories: selectedCategories,
        categories: categories,
        onCategoryToggle: onCategoryToggle,
      ),
    );
  }
}
