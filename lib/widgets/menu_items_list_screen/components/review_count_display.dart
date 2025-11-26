import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';

/// Isolated review count and link widget
/// Rebuilds only when review count changes
class ReviewCountDisplay extends StatelessWidget {
  const ReviewCountDisplay({
    required this.reviewCount,
    required this.fontSize,
    required this.onViewReviews,
    super.key,
  });

  final int reviewCount;
  final double fontSize;
  final VoidCallback? onViewReviews;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Review count
        Text(
          '($reviewCount)',
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(width: 4),
        // View all reviews link
        if (onViewReviews != null)
          Flexible(
            child: GestureDetector(
              onTap: onViewReviews,
              child: Text(
                '(${l10n.viewAllReviews})',
                style: GoogleFonts.poppins(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
  }
}

