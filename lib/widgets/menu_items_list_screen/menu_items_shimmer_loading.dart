import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Fast shimmer loading widget for individual menu item cards
class MenuItemCardShimmer extends StatelessWidget {
  const MenuItemCardShimmer({
    required this.width,
    required this.height,
    super.key,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final imageHeight = width; // Image height = card width

    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      period: const Duration(milliseconds: 1200), // Faster shimmer
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Integrated card with image and info (matches SquareMenuItemCard)
            Container(
              width: width,
              decoration: BoxDecoration(
                color: Colors.grey[100], // Light grey background
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image section shimmer
                  SizedBox(
                    width: width,
                    height: imageHeight,
                    child: Stack(
                      children: [
                        // Main image area
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                        ),
                        // Review chip shimmer overlay
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.grey[400]!,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[400],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  width: 24,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[400],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Info section shimmer (integrated with image)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Menu item name shimmer
                        Container(
                          height: 16,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Restaurant name shimmer
                        Container(
                          height: 12,
                          width: width * 0.7, // 70% of card width
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Price shimmer (aligned right)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            height: 14,
                            width: width * 0.4, // 40% of card width
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MenuItemsShimmerLoading extends StatelessWidget {
  const MenuItemsShimmerLoading({super.key});

  @override
  Widget build(BuildContext context) {
    // Calculate card size for 3-column grid (same logic as main screen)
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 20.0; // Left and right padding
    const cardSpacing = 12.0; // Space between cards
    final availableWidth = screenWidth -
        horizontalPadding -
        (2 * cardSpacing); // Space for 3 cards
    final cardSize = (availableWidth / 3).clamp(100.0, 150.0);

    // PERFORMANCE FIX: Convert shrinkWrap GridView to SliverGrid when used in CustomScrollView
    // This eliminates O(N) layout calculations on every frame
    // Note: This widget should be used inside a CustomScrollView's slivers array
    // If used in SingleChildScrollView, wrap with SliverToBoxAdapter
    return GridView.builder(
      shrinkWrap: true, // Size to content when inside SingleChildScrollView
      physics: const NeverScrollableScrollPhysics(), // Parent handles scrolling
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: cardSize /
            (cardSize +
                (cardSize * 0.8) +
                12), // Match actual card aspect ratio
        crossAxisSpacing: cardSpacing,
        mainAxisSpacing: cardSpacing,
      ),
      itemBuilder: (context, index) {
        return MenuItemCardShimmer(
          width: cardSize,
          height: cardSize + (cardSize * 0.8) + 12,
        );
      },
      itemCount: 9, // 9 shimmer cards (3 rows)
    );
  }
}
