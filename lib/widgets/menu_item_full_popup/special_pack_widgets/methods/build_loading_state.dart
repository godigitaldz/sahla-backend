import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../utils/bottom_padding.dart';
import '../skeleton_widget.dart';

// ============================================================================
// Error State Builder
// ============================================================================

/// Build error state widget for menu item popups
/// Supports optional cancel button for regular/LTO popups
Widget buildErrorState({
  required BuildContext context,
  required String? loadingError,
  required VoidCallback onRetry,
  required Color textPrimary,
  required Color textSecondary,
  required Color primaryOrange,
  VoidCallback? onCancel,
  double borderRadius = 12,
}) {
  return Column(
    children: [
      // Error content
      Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load menu item',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  loadingError ?? 'An unexpected error occurred',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: onRetry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                      ),
                      child: Text(
                        'Retry',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (onCancel != null) ...[
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: onCancel,
                        style: TextButton.styleFrom(
                          foregroundColor: textSecondary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

// ============================================================================
// Skeleton Builders
// ============================================================================

/// Build item header skeleton
Widget buildItemHeaderSkeleton() {
  return SpecialPackSkeletonWidget(
    showTitle: false,
    contentConfig: SkeletonContentConfig.custom(
      content: Row(
        children: [
          SpecialPackSkeletonWidget(
            showTitle: false,
            contentConfig: SkeletonContentConfig.single(
              itemConfig: SkeletonItemConfig(
                width: 80,
                height: 80,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SpecialPackSkeletonWidget(
                  showTitle: false,
                  contentConfig: SkeletonContentConfig.single(
                    itemConfig: SkeletonItemConfig(
                      width: double.infinity,
                      height: 20,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SpecialPackSkeletonWidget(
                  showTitle: false,
                  contentConfig: SkeletonContentConfig.single(
                    itemConfig: SkeletonItemConfig(
                      width: 120,
                      height: 16,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SpecialPackSkeletonWidget(
                      showTitle: false,
                      contentConfig: SkeletonContentConfig.single(
                        itemConfig: SkeletonItemConfig(
                          width: 60,
                          height: 14,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SpecialPackSkeletonWidget(
                      showTitle: false,
                      contentConfig: SkeletonContentConfig.single(
                        itemConfig: SkeletonItemConfig(
                          width: 80,
                          height: 14,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Build variants skeleton
Widget buildVariantsSkeleton() {
  return SpecialPackSkeletonWidget(
    titleWidth: 100,
    contentConfig: SkeletonContentConfig.row(
      itemCount: 3,
      itemConfig: SkeletonItemConfig(
        width: 80,
        height: 40,
        borderRadius: BorderRadius.circular(8),
      ),
      spacing: 12,
    ),
  );
}

/// Build size skeleton
Widget buildSizeSkeleton() {
  return SpecialPackSkeletonWidget(
    titleWidth: 80,
    contentConfig: SkeletonContentConfig.row(
      itemCount: 3,
      itemConfig: SkeletonItemConfig(
        width: 100,
        height: 50,
        borderRadius: BorderRadius.circular(12),
      ),
      spacing: 12,
    ),
  );
}

/// Build ingredients skeleton
Widget buildIngredientsSkeleton() {
  return SpecialPackSkeletonWidget(
    titleWidth: 120,
    contentConfig: SkeletonContentConfig.wrap(
      itemCount: 8,
      baseConfig: SkeletonItemConfig(
        width: 80,
        height: 36,
        borderRadius: BorderRadius.circular(18),
      ),
      spacing: 8,
    ),
  );
}

/// Build supplements skeleton
Widget buildSupplementsSkeleton() {
  return SpecialPackSkeletonWidget(
    titleWidth: 140,
    contentConfig: SkeletonContentConfig.wrap(
      itemCount: 6,
      baseConfig: SkeletonItemConfig(
        width: 100,
        height: 44,
        borderRadius: BorderRadius.circular(12),
      ),
      spacing: 8,
    ),
  );
}

/// Build drinks skeleton
Widget buildDrinksSkeleton() {
  return SpecialPackSkeletonWidget(
    titleWidth: 100,
    contentConfig: SkeletonContentConfig.listViewHorizontal(
      itemCount: 5,
      itemConfig: SkeletonItemConfig(
        width: 100,
        height: 126,
        borderRadius: BorderRadius.circular(12),
      ),
      height: 126,
      spacing: 12,
    ),
  );
}

/// Build special instructions skeleton
Widget buildSpecialInstructionsSkeleton() {
  return SpecialPackSkeletonWidget(
    titleWidth: 150,
    contentConfig: SkeletonContentConfig.single(
      itemConfig: SkeletonItemConfig(
        width: double.infinity,
        height: 80,
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}

/// Build quantity skeleton
Widget buildQuantitySkeleton() {
  return SpecialPackSkeletonWidget(
    showTitle: false,
    contentConfig: SkeletonContentConfig.row(
      itemCount: 3,
      itemConfig: SkeletonItemConfig(
        width: 40,
        height: 40,
        borderRadius: BorderRadius.circular(20),
      ),
      spacing: 12,
    ),
    rowMainAxisAlignment: MainAxisAlignment.end,
  );
}

/// Build pricing skeleton
Widget buildPricingSkeleton() {
  return SpecialPackSkeletonWidget(
    showTitle: false,
    contentConfig: SkeletonContentConfig.single(
      itemConfig: SkeletonItemConfig(
        width: double.infinity,
        height: 80,
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
}

/// Build action buttons skeleton
Widget buildActionButtonsSkeleton() {
  return SpecialPackSkeletonWidget(
    showTitle: false,
    contentConfig: SkeletonContentConfig.row(
      itemCount: 2,
      itemConfig: SkeletonItemConfig(
        width: 150,
        height: 50,
        borderRadius: BorderRadius.circular(16),
      ),
      spacing: 12,
    ),
  );
}

// ============================================================================
// Loading State Builder
// ============================================================================

/// Build loading state widget for special pack popup
Widget buildLoadingState({
  required BuildContext context,
  required String? loadingError,
  required bool isLoadingVariants,
  required bool isLoadingSupplements,
  required bool isLoadingDrinks,
  required VoidCallback onRetry,
  required Color textPrimary,
  required Color textSecondary,
  required Color primaryOrange,
}) {
  if (loadingError != null) {
    return buildErrorState(
      context: context,
      loadingError: loadingError,
      onRetry: onRetry,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      primaryOrange: primaryOrange,
    );
  }

  final screenWidth = MediaQuery.of(context).size.width;
  final horizontalPadding = screenWidth * 0.04;

  // PERFORMANCE FIX: Remove nested SingleChildScrollView and Flexible
  // The parent CustomScrollView handles scrolling, so we just return a Column
  // This prevents nested scrollables which cause measure storms and jank
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Item header skeleton (no padding)
      buildItemHeaderSkeleton(),

      // Content with horizontal padding
      Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),

            // Variants skeleton (only if loading variants)
            if (isLoadingVariants) ...[
              buildVariantsSkeleton(),
              const SizedBox(height: 8),
            ],

            // Size section skeleton
            buildSizeSkeleton(),

            const SizedBox(height: 8),

            // Ingredients skeleton
            buildIngredientsSkeleton(),

            const SizedBox(height: 8),

            // Supplements skeleton (only if loading supplements)
            if (isLoadingSupplements) ...[
              buildSupplementsSkeleton(),
              const SizedBox(height: 8),
            ],

            // Drinks skeleton (only if loading drinks)
            if (isLoadingDrinks) ...[
              buildDrinksSkeleton(),
              const SizedBox(height: 8),
            ],

            // Special instructions skeleton
            buildSpecialInstructionsSkeleton(),

            const SizedBox(height: 8),

            // Quantity skeleton
            buildQuantitySkeleton(),

            const SizedBox(height: 20),

            // Pricing skeleton
            buildPricingSkeleton(),

            const SizedBox(height: 20),

            // Action buttons skeleton
            buildActionButtonsSkeleton(),

            // Bottom padding for safe area (moved here from SingleChildScrollView)
            Padding(
              padding: BottomPaddingHelper.getBottomPaddingInsets(context),
              child: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    ],
  );
}
