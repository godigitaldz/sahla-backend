import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reusable dropdown item builders for add new menu item screen.
///
/// This file contains helper methods to build consistent dropdown menu items
/// with various styles (simple text, icon+text, loading states, etc.).
///
/// All builders use shared constants and styles for consistency.
class DropdownItemBuilders {
  DropdownItemBuilders._(); // Private constructor to prevent instantiation

  // ========== Constants ==========
  static const double iconSize = 20.0;
  static const double spacing = 12.0;
  static const Color primaryColor = Color(0xFFd47b00);

  // ========== Text Styles ==========
  static final TextStyle textStyle = GoogleFonts.poppins(
    color: Colors.black,
    fontWeight: FontWeight.w500,
  );

  static final TextStyle secondaryTextStyle = GoogleFonts.poppins(
    color: Colors.grey[600],
    fontWeight: FontWeight.w500,
  );

  static final TextStyle highlightTextStyle = GoogleFonts.poppins(
    color: Colors.orange[600],
    fontWeight: FontWeight.w600,
  );

  static final TextStyle infoTextStyle = GoogleFonts.poppins(
    color: Colors.grey[600],
    fontWeight: FontWeight.w500,
    fontSize: 13,
  );

  // ========== Builder Methods ==========

  /// Builds a simple dropdown menu item with text only
  static DropdownMenuItem<String> buildSimple({
    required String? value,
    required String text,
    TextStyle? style,
    bool enabled = true,
  }) {
    return DropdownMenuItem<String>(
      value: value,
      enabled: enabled,
      child: Text(text, style: style ?? secondaryTextStyle),
    );
  }

  /// Builds a dropdown menu item with icon and text
  static DropdownMenuItem<String> buildWithIcon({
    required String value,
    required String text,
    IconData? icon,
    Color? iconColor,
    TextStyle? textStyle,
  }) {
    return DropdownMenuItem<String>(
      value: value,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: iconColor ?? primaryColor, size: iconSize),
            const SizedBox(width: spacing),
          ],
          Expanded(
            child: Text(text, style: textStyle ?? DropdownItemBuilders.textStyle),
          ),
        ],
      ),
    );
  }

  /// Builds a dropdown item with icon from icon name and color hex
  ///
  /// Uses [getIconData] to convert icon name string to IconData
  /// and [getColorFromHex] to convert hex color string to Color
  static DropdownMenuItem<String> buildStyledIcon({
    required String value,
    required String text,
    required IconData Function(String) getIconData, required Color Function(String?) getColorFromHex, String? iconName,
    String? colorHex,
  }) {
    return DropdownMenuItem<String>(
      value: value,
      child: Row(
        children: [
          if (iconName != null) ...[
            Icon(
              getIconData(iconName),
              color: getColorFromHex(colorHex),
              size: iconSize,
            ),
            const SizedBox(width: spacing),
          ],
          Expanded(
            child: Text(text, style: textStyle),
          ),
        ],
      ),
    );
  }

  /// Builds a loading dropdown item with spinner
  static DropdownMenuItem<String> buildLoading(String message) {
    return DropdownMenuItem<String>(
      value: null,
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: spacing),
          Text(message, style: secondaryTextStyle),
        ],
      ),
    );
  }
}
