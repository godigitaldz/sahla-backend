import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../utils/price_formatter.dart';

/// Shared supplement chip widget used by all supplement selectors
class SupplementChipWidget extends StatelessWidget {
  final String supplementName;
  final double supplementPrice;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? selectedColor;
  final Color? unselectedColor;
  final double fontSize;
  final double iconSize;
  final EdgeInsets padding;

  const SupplementChipWidget({
    required this.supplementName,
    required this.supplementPrice,
    required this.isSelected,
    required this.onTap,
    this.selectedColor,
    this.unselectedColor,
    this.fontSize = 12,
    this.iconSize = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveSelectedColor = selectedColor ?? const Color(0xFFd47b00);
    final effectiveUnselectedColor = unselectedColor ?? Colors.grey[100];

    // PERFORMANCE FIX: Memoize price formatting - format once per build
    // PriceFormatter.formatWithSettings is expensive and should not be called repeatedly
    final formattedPrice = supplementPrice > 0
        ? PriceFormatter.formatWithSettings(context, supplementPrice.toString())
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: isSelected ? effectiveSelectedColor : effectiveUnselectedColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? effectiveSelectedColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.add_circle_outline,
              size: iconSize,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              supplementName,
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
            if (formattedPrice != null) ...[
              const SizedBox(width: 6),
              Text(
                '+$formattedPrice',
                style: GoogleFonts.poppins(
                  fontSize: fontSize - 1,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFFfc9d2d),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
