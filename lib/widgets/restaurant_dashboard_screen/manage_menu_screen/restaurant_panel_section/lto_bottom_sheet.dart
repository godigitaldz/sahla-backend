import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/menu_item.dart';
import '../../add_new_menu_item_screen.dart';
import '../menu_item_section/menu_item_card_widget.dart';

/// Bottom sheet widget for displaying restaurant's Limited Time Offer items
/// Opens at 80% screen height with LTO items list and Add LTO button
class LTOBottomSheet extends StatelessWidget {
  final List<MenuItem> ltoItems;
  final VoidCallback? onRefresh;
  final Function(MenuItem)? onToggleAvailability;
  final Function(MenuItem)? onDelete;
  final Function(MenuItem, DateTime, DateTime)? onReactivate;

  const LTOBottomSheet({
    required this.ltoItems,
    this.onRefresh,
    this.onToggleAvailability,
    this.onDelete,
    this.onReactivate,
    super.key,
  });

  /// Helper method to check if a menu item is an LTO item
  static bool isLTOItem(MenuItem item) {
    return item.isOfferActive || item.hasExpiredLTOOffer;
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

          // Header with Add LTO button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Limited Time Offers',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _navigateToAddLTO(context),
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  label: Text(
                    'Add LTO',
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

          // LTO items list
          Expanded(
            child: ltoItems.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: ltoItems.length,
                    // PERF: Set reasonable cache extent for smooth scrolling
                    cacheExtent: 500,
                    itemBuilder: (context, index) {
                      // PERF: Wrap each item in RepaintBoundary to isolate repaints
                      return RepaintBoundary(
                        child: MenuItemCardWidget(
                          key: ValueKey(ltoItems[index].id),
                          item: ltoItems[index],
                          onToggleAvailability: onToggleAvailability != null
                              ? () => onToggleAvailability!(ltoItems[index])
                              : null,
                          onDelete: onDelete != null
                              ? () => onDelete!(ltoItems[index])
                              : null,
                          onReactivate: onReactivate != null
                              ? (startDate, endDate) => onReactivate!(
                                  ltoItems[index], startDate, endDate)
                              : null,
                        ),
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
            Icons.local_offer,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Limited Time Offers yet',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Add LTO" button to add your first limited time offer',
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

  void _navigateToAddLTO(BuildContext context) {
    Navigator.of(context).pop(); // Close bottom sheet first
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => const AddNewMenuItemScreen(),
      ),
    )
        .then((_) {
      // Refresh LTO items list if needed
      if (onRefresh != null) {
        onRefresh!();
      }
    });
  }
}
