import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/menu_item.dart';
import '../../../../utils/price_formatter.dart';
import '../../add_new_menu_item_screen.dart';

/// Bottom sheet widget for displaying restaurant's drinks
/// Opens at 80% screen height with drinks list and Add Drink button
class DrinksBottomSheet extends StatelessWidget {
  final List<MenuItem> drinks;
  final VoidCallback? onRefresh;
  final Function(MenuItem)? onToggleAvailability;
  final Function(MenuItem)? onDelete;

  const DrinksBottomSheet({
    required this.drinks,
    this.onRefresh,
    this.onToggleAvailability,
    this.onDelete,
    super.key,
  });

  /// Helper method to check if a menu item is a drink
  static bool isDrink(MenuItem item) {
    final categoryLower = item.category.toLowerCase();
    final categoryObjLower = item.categoryObj?.name.toLowerCase() ?? '';
    final nameLower = item.name.toLowerCase();

    return categoryLower.contains('drink') ||
        categoryLower.contains('beverage') ||
        categoryLower.contains('boissons') ||
        categoryLower.contains('مشروب') || // Arabic for drink
        categoryObjLower.contains('drink') ||
        categoryObjLower.contains('beverage') ||
        categoryObjLower.contains('boissons') ||
        categoryObjLower.contains('مشروب') ||
        nameLower.contains('drink') ||
        nameLower.contains('juice') ||
        nameLower.contains('soda') ||
        nameLower.contains('coffee') ||
        nameLower.contains('tea') ||
        nameLower.contains('water');
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomSheetHeight = screenHeight * 0.8;

    return Container(
      height: bottomSheetHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header with Add Drink button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Drinks',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _navigateToAddDrink(context),
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  label: Text(
                    'Add Drink',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFd47b00),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Drinks list
          Expanded(
            child: drinks.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: drinks.length,
                    // PERF: Set reasonable cache extent for smooth scrolling
                    cacheExtent: 500,
                    itemBuilder: (context, index) {
                      // PERF: Wrap each item in RepaintBoundary to isolate repaints
                      return RepaintBoundary(
                        child: _buildDrinkCard(context, drinks[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_drink,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No drinks yet',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Add Drink" button to add your first drink',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDrinkCard(BuildContext context, MenuItem drink) {
    final formattedPrice = PriceFormatter.formatWithSettings(
      context,
      drink.price.toString(),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFf8eded),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Drink image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              drink.image,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              // PERF: Add cache dimensions for thumbnail optimization
              cacheWidth: 120, // 2x for retina displays
              cacheHeight: 120,
              // PERF: Use low filter quality for thumbnails
              filterQuality: FilterQuality.low,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 60,
                height: 60,
                color: Colors.grey[300],
                child: const Icon(Icons.local_drink, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Drink info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  drink.name,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  formattedPrice,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFd47b00),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  drink.isAvailable ? 'Available' : 'Unavailable',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hide/Show button
              if (onToggleAvailability != null)
                GestureDetector(
                  onTap: () => onToggleAvailability!(drink),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      drink.isAvailable
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              // Delete button
              if (onDelete != null)
                GestureDetector(
                  onTap: () => onDelete!(drink),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.delete,
                      size: 16,
                      color: Colors.red,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _navigateToAddDrink(BuildContext context) {
    Navigator.of(context).pop(); // Close bottom sheet first
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => const AddNewMenuItemScreen(
          initialCategory: 'Drinks', // Pre-select drinks category
        ),
      ),
    )
        .then((_) {
      // Refresh drinks list if needed
      if (onRefresh != null) {
        onRefresh!();
      }
    });
  }
}
