import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'price_formatter.dart';

/// Utility class for consistent discount formatting across the app
class DiscountFormatter {
  /// Format discount amount with consistent styling
  static String formatDiscountAmount(BuildContext context, double amount) {
    return '-${PriceFormatter.formatWithSettings(context, amount.toString())}';
  }

  /// Create a discount display widget with consistent styling
  static Widget buildDiscountRow(
      BuildContext context, String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.green,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          formatDiscountAmount(context, amount),
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.green,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Create a discount validation warning widget
  static Widget buildDiscountWarning(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.warning,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.orange[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Create a discount success widget
  static Widget buildDiscountSuccess(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.green[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Validate if discount amount is reasonable
  static bool isDiscountValid(double discountAmount, double subtotal) {
    return discountAmount >= 0 && discountAmount <= subtotal;
  }

  /// Get discount validation message
  static String? getDiscountValidationMessage(
      double discountAmount, double subtotal) {
    if (discountAmount < 0) {
      return "Discount amount cannot be negative";
    }
    if (discountAmount > subtotal) {
      return "Discount amount cannot exceed order total";
    }
    return null;
  }
}
