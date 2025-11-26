import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared drink quantity selector widget used in drink cards
/// Displays a horizontal row with decrease, quantity display, and increase buttons
class DrinkQuantitySelector extends StatelessWidget {
  final int quantity;
  final Function(int newQuantity) onQuantityChanged;
  final bool canDecrease;
  final bool canIncrease;
  final Color? activeColor;
  final double fontSize;
  final double iconSize;
  final Color? textColor;

  const DrinkQuantitySelector({
    required this.quantity,
    required this.onQuantityChanged,
    required this.canDecrease,
    required this.canIncrease,
    this.activeColor,
    this.fontSize = 10,
    this.iconSize = 10,
    this.textColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveActiveColor = activeColor ?? const Color(0xFFfc9d2d);
    final effectiveTextColor = textColor ?? Colors.black87;

    // Calculate container and button sizes based on iconSize
    // For larger icons (iconSize > 12), use larger containers for better touch targets
    final buttonSize = iconSize > 12 ? 28.0 : 24.0;
    final containerHeight = iconSize > 12 ? 28.0 : 24.0;
    // Reduce padding when buttons are larger to prevent overflow
    final horizontalPadding = iconSize > 12 ? 2.0 : 4.0;
    // Reduce quantity display width when buttons are larger to prevent overflow
    // Calculation: 72px container - 4px padding = 68px available
    // 28px + 28px buttons = 56px, so 68px - 56px = 12px for quantity
    final quantityWidth = iconSize > 12 ? 12.0 : 20.0;

    return Container(
      height: containerHeight,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          // Decrease button
          InkWell(
            onTap: canDecrease
                ? () {
                    onQuantityChanged(quantity - 1);
                  }
                : null,
            child: Container(
              width: buttonSize,
              height: buttonSize,
              alignment: Alignment.center,
              child: Icon(
                Icons.remove,
                size: iconSize,
                color: canDecrease ? effectiveActiveColor : Colors.grey[400],
              ),
            ),
          ),

          // Quantity display
          // PERFORMANCE FIX: Replace Expanded with fixed width to avoid relayout in lists
          // Expanded causes measure storms when used inside list items
          SizedBox(
            width: quantityWidth, // Fixed width for quantity number (0-99 fits)
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: effectiveTextColor,
              ),
            ),
          ),

          // Increase button
          InkWell(
            onTap: canIncrease
                ? () {
                    onQuantityChanged(quantity + 1);
                  }
                : null,
            child: Container(
              width: buttonSize,
              height: buttonSize,
              alignment: Alignment.center,
              child: Icon(
                Icons.add,
                size: iconSize,
                color: canIncrease ? effectiveActiveColor : Colors.grey[400],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
