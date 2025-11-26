import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../models/menu_item.dart';
import '../../../../utils/price_formatter.dart';
import 'menu_item_card_widget.dart';

/// Menu Items List Widget
/// Displays the list of menu items with loading states and empty states
class MenuItemsListWidget extends StatelessWidget {
  final List<MenuItem> filteredItems;
  final bool isLoading;
  final bool isLoadingMore;
  final ScrollController scrollController;
  final TextEditingController searchController;
  final String selectedCuisineTypeId;
  final String selectedCategoryId;
  final Set<String> selectedCategories;
  final bool showDrinks;
  final VoidCallback onRefresh;
  final Function(MenuItem) onShowDetails;
  final Function(MenuItem) onToggleAvailability;
  final Function(MenuItem) onDelete;

  const MenuItemsListWidget({
    required this.filteredItems,
    required this.isLoading,
    required this.isLoadingMore,
    required this.scrollController,
    required this.searchController,
    required this.selectedCuisineTypeId,
    required this.selectedCategoryId,
    required this.selectedCategories,
    required this.showDrinks,
    required this.onRefresh,
    required this.onShowDetails,
    required this.onToggleAvailability,
    required this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // PERF: Return SliverList instead of Expanded + ListView to work with CustomScrollView
    // This eliminates nested scrollable structure and improves performance
    if (filteredItems.isEmpty && !isLoading) {
      // PERF: Use SliverFillRemaining for empty state to maintain scrollability
      // This allows pull-to-refresh to work properly
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.restaurant_menu,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                searchController.text.trim().isNotEmpty ||
                        selectedCuisineTypeId.isNotEmpty ||
                        selectedCategoryId.isNotEmpty ||
                        selectedCategories.isNotEmpty ||
                        !showDrinks
                    ? AppLocalizations.of(context)!.noItemsFoundMatchingFilters
                    : AppLocalizations.of(context)!.noMenuItemsYet,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.tapPlusButtonToAddFirstItem,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // PERF: Use SliverList with fixed itemExtent for uniform row height
    // This allows Flutter to optimize scrolling by knowing exact item dimensions
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 72),
      sliver: SliverFixedExtentList(
        itemExtent: 82, // Fixed height for uniform rows
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            // Show loading indicator at the bottom
            if (index == filteredItems.length) {
              return _buildLoadingMoreIndicator(context);
            }

            final item = filteredItems[index];
            // PERF: Pre-compute formatted price outside itemBuilder to avoid recalculating
            // This is passed from parent but ensure it's computed once per item
            final formattedPrice = PriceFormatter.formatWithSettings(
              context,
              item.price.toString(),
            );

            // PERF: Wrap each item in RepaintBoundary to isolate repaints
            // This prevents repainting adjacent items when scrolling
            return RepaintBoundary(
              child: MenuItemCardWidget(
                key: ValueKey(item.id),
                item: item,
                formattedPrice: formattedPrice,
                onTap: () => onShowDetails(item),
                onToggleAvailability: () => onToggleAvailability(item),
                onDelete: () => onDelete(item),
              ),
            );
          },
          childCount: filteredItems.length + (isLoadingMore ? 1 : 0),
        ),
      ),
    );
  }

  Widget _buildLoadingMoreIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFd47b00)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.loadingMoreItems,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
