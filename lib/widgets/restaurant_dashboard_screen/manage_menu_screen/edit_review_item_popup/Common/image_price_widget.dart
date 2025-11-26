import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../utils/price_formatter.dart';

/// LTO Image and Price Widget
/// Displays the image with edit button overlay and price overlay at bottom right
class LTOImagePriceWidget extends StatelessWidget {
  final String imageUrl;
  final double? discountedPrice;
  final double? originalPrice;
  final bool isUpdatingImage;
  final VoidCallback onEditImage;
  final VoidCallback onEditDiscountedPrice;
  final VoidCallback onEditOriginalPrice;

  const LTOImagePriceWidget({
    required this.imageUrl,
    required this.discountedPrice,
    required this.isUpdatingImage,
    required this.onEditImage,
    required this.onEditDiscountedPrice,
    required this.onEditOriginalPrice,
    this.originalPrice,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.network(
            imageUrl,
            width: double.infinity,
            fit: BoxFit.cover,
            // PERF: Optimize image caching based on device pixel ratio
            // 800x450 is appropriate for hero images on most devices
            cacheWidth: 800,
            cacheHeight: 450,
            // PERF: Use low filter quality for better performance during scroll
            // Medium quality is acceptable for hero images but low is faster
            filterQuality: FilterQuality.low,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 250,
              color: Colors.grey[200],
              child: Icon(
                Icons.restaurant_menu,
                size: 80,
                color: Colors.grey[400],
              ),
            ),
          ),
        ),
        // Edit image button overlay
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: isUpdatingImage
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 20,
                    ),
              onPressed: isUpdatingImage ? null : onEditImage,
              tooltip: 'Edit image',
            ),
          ),
        ),
        // Price overlay at bottom right
        Positioned(
          bottom: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Discounted price with edit button
                GestureDetector(
                  onTap: onEditDiscountedPrice,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        PriceFormatter.formatWithSettings(
                          context,
                          (discountedPrice ?? 0.0).toString(),
                        ),
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.edit,
                        size: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ],
                  ),
                ),
                // Original price with edit button
                if (originalPrice != null &&
                    discountedPrice != null &&
                    discountedPrice! > 0 &&
                    originalPrice! > discountedPrice!) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onEditOriginalPrice,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          PriceFormatter.formatWithSettings(
                            context,
                            originalPrice!.toString(),
                          ),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            decoration: TextDecoration.lineThrough,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.edit,
                          size: 12,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
