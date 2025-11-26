import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/menu_item_supplement.dart';
import '../../../../utils/price_formatter.dart';
import '../../add_new_menu_item_screen.dart';

/// Bottom sheet widget for displaying restaurant's supplements
/// Opens at 80% screen height with supplements list and Add Supplement button
class ManageSupplementsPopupWidget extends StatelessWidget {
  final List<MenuItemSupplement> supplements;
  final VoidCallback? onRefresh;
  final Function(MenuItemSupplement)? onToggleAvailability;
  final Function(MenuItemSupplement)? onDelete;

  const ManageSupplementsPopupWidget({
    required this.supplements,
    this.onRefresh,
    this.onToggleAvailability,
    this.onDelete,
    super.key,
  });

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

          // Header with Add Supplement button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Supplements',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _navigateToAddSupplement(context),
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  label: Text(
                    'Add Supplement',
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

          // Supplements list
          Expanded(
            child: supplements.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: supplements.length,
                    itemBuilder: (context, index) {
                      return _buildSupplementCard(context, supplements[index]);
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
            Icons.fastfood,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No supplements yet',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Add Supplement" button to add your first supplement',
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

  Widget _buildSupplementCard(
      BuildContext context, MenuItemSupplement supplement) {
    final formattedPrice = PriceFormatter.formatWithSettings(
      context,
      supplement.price.toString(),
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
          // Supplement icon (supplements don't have images in the table)
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_box, color: Colors.grey, size: 32),
          ),
          const SizedBox(width: 12),

          // Supplement info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  supplement.name,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (supplement.description != null &&
                    supplement.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    supplement.description!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
                  supplement.isAvailable ? 'Available' : 'Unavailable',
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
                  onTap: () => onToggleAvailability!(supplement),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      supplement.isAvailable
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
                  onTap: () => onDelete!(supplement),
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

  void _navigateToAddSupplement(BuildContext context) {
    Navigator.of(context).pop(); // Close bottom sheet first
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => const AddNewMenuItemScreen(
          initialCategory: 'Supplements', // Pre-select supplements category
          showOnlySupplements: true, // Show only supplements section
        ),
      ),
    )
        .then((_) {
      // Refresh supplements list if needed
      if (onRefresh != null) {
        onRefresh!();
      }
    });
  }
}
