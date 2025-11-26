import 'package:flutter/material.dart';

/// Restaurant panel widget with 3 image cards for manage menu screen
/// Displays: Drinks, Supplements, and Limited Time Offers
class RestaurantPanelWidget extends StatelessWidget {
  final VoidCallback? onDrinksTap;
  final VoidCallback? onSupplementsTap;
  final VoidCallback? onLTOTap;

  const RestaurantPanelWidget({
    this.onDrinksTap,
    this.onSupplementsTap,
    this.onLTOTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isRTL = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Drinks card
          Expanded(
            child: _buildImageCard(
              context,
              imagePath: isRTL
                  ? 'assets/manage_menu/drinks_ar.png'
                  : 'assets/manage_menu/drinks_en.png',
              onTap: onDrinksTap ??
                  () {
                    debugPrint('Drinks tapped');
                  },
            ),
          ),
          const SizedBox(width: 12),
          // Supplements card
          Expanded(
            child: _buildImageCard(
              context,
              imagePath: isRTL
                  ? 'assets/manage_menu/supp_ar.png'
                  : 'assets/manage_menu/supp_en.png',
              onTap: onSupplementsTap ??
                  () {
                    debugPrint('Supplements tapped');
                  },
            ),
          ),
          const SizedBox(width: 12),
          // Limited Time Offers card
          Expanded(
            child: _buildImageCard(
              context,
              imagePath: isRTL
                  ? 'assets/manage_menu/lto_ar.png'
                  : 'assets/manage_menu/lto_en.png',
              onTap: onLTOTap ??
                  () {
                    debugPrint('Limited Time Offers tapped');
                  },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCard(
    BuildContext context, {
    required String imagePath,
    required VoidCallback onTap,
  }) {
    // PERF: Remove LayoutBuilder to avoid unnecessary rebuilds
    // Calculate aspect ratio based on screen width instead
    // This prevents rebuilds when constraints change during scroll
    return Builder(
      builder: (context) {
        // Get screen width for consistent sizing
        final screenWidth = MediaQuery.of(context).size.width;
        final cardWidth =
            (screenWidth - 48) / 3; // 3 cards with 12px spacing each
        final cardHeight = cardWidth * 0.75; // 4:3 aspect ratio

        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: cardWidth,
            height: cardHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                imagePath,
                width: cardWidth,
                height: cardHeight,
                fit: BoxFit.cover,
                // PERF: Use low filter quality for thumbnails to improve performance
                filterQuality: FilterQuality.low,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: cardWidth,
                    height: cardHeight,
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.image_not_supported,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
