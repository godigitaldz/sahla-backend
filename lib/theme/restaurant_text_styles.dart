import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized text styles for restaurant details screen
/// Reduces repeated GoogleFonts.poppins() calls for better performance
class RestaurantTextStyles {
  RestaurantTextStyles._();

  // Menu item card styles
  static final menuItemName = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
  );

  static final menuItemPrice = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: Colors.grey[800],
  );

  static final menuItemReviewCount = GoogleFonts.poppins(
    fontSize: 11,
    color: Colors.grey[600],
  );

  static final menuItemPreparationTime = GoogleFonts.poppins(
    fontSize: 11,
    color: Colors.grey[600],
  );

  // Info card styles
  static final infoCardLabel = GoogleFonts.poppins(
    fontSize: 7.2,
    color: Colors.grey[700],
    fontWeight: FontWeight.w600,
  );

  static final infoCardValue = GoogleFonts.poppins(
    fontSize: 8.5,
    color: Colors.grey[800],
    fontWeight: FontWeight.bold,
  );

  static final infoCardIcon = GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: Colors.orange[600],
  );

  // Error and loading styles
  static final errorMessage = GoogleFonts.poppins(
    fontSize: 16,
    color: Colors.grey[600],
  );

  static final noItemsMessage = GoogleFonts.poppins(
    fontSize: 16,
    color: Colors.grey[600],
  );

  // Drink card styles
  static final drinkPrice = GoogleFonts.poppins(
    fontSize: 8,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static final drinkSize = GoogleFonts.poppins(
    fontSize: 8,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
  );

  static final drinkQuantity = GoogleFonts.poppins(
    fontSize: 9,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
  );

  static final drinkAddButton = GoogleFonts.poppins(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  // Category chip styles
  static TextStyle categoryChipText({required bool isSelected}) =>
      GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        color: isSelected ? Colors.white : Colors.black87,
      );

  // Rating styles for header
  static TextStyle ratingText(double fontSize) => GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      );

  static TextStyle restaurantName(double fontSize) => GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
        height: 1.2,
      );

  static TextStyle addReviewText(double fontSize) => GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        color: Colors.grey[600],
        decoration: TextDecoration.underline,
        decorationColor: Colors.grey[600],
      );
}
