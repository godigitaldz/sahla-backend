import 'package:flutter/material.dart';

/// Isolated rating stars widget
/// Const widget with pre-calculated stars
class RatingStarsDisplay extends StatelessWidget {
  const RatingStarsDisplay({
    required this.rating,
    required this.starSize,
    super.key,
  });

  final double rating;
  final double starSize;

  static const _starColor = Color(0xFFFFA726); // amber[600]

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;

        if (rating >= starValue) {
          // Full star
          return Icon(
            Icons.star,
            size: starSize,
            color: _starColor,
          );
        } else if (rating >= starValue - 0.5) {
          // Half star
          return Icon(
            Icons.star_half,
            size: starSize,
            color: _starColor,
          );
        } else {
          // Empty star
          return Icon(
            Icons.star_border,
            size: starSize,
            color: _starColor,
          );
        }
      }),
    );
  }
}

