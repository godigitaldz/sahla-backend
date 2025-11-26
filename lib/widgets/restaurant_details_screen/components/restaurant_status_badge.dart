import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

/// Status badge showing opening/closing time for restaurants
///
/// Features:
/// - Color-coded badges (amber for closing soon, red for closed)
/// - RTL support
/// - Localized text
/// - Compact design
class RestaurantStatusBadge extends StatelessWidget {
  final bool isOpen;
  final String? time;
  final bool isRTL;

  const RestaurantStatusBadge({
    required this.isOpen,
    super.key,
    this.time,
    this.isRTL = false,
  });

  @override
  Widget build(BuildContext context) {
    if (time == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Match delivery fee container sizing
        final containerWidth = constraints.maxWidth;

        // Calculate responsive font size to match delivery fee container
        final fontSize = _getResponsiveFontSize(
          containerWidth,
          baseFontSize: 10,
          minFontSize: 8,
        );

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: containerWidth < 150 ? 6 : 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: isOpen ? const Color(0xFFFFDB58) : Colors.red[600],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            _getTimeText(),
            style: GoogleFonts.poppins(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }

  /// Calculate responsive font size to match delivery fee container
  double _getResponsiveFontSize(double width,
      {required double baseFontSize, required double minFontSize}) {
    if (width < 130) {
      return minFontSize;
    } else if (width < 160) {
      final scale = (width - 130) / 30;
      return minFontSize + (baseFontSize - minFontSize) * scale * 0.5;
    } else if (width < 200) {
      final scale = (width - 160) / 40;
      return minFontSize + (baseFontSize - minFontSize) * (0.5 + scale * 0.5);
    }
    return baseFontSize;
  }

  /// Get localized time text based on open status
  String _getTimeText() {
    if (isOpen) {
      return isRTL ? 'يغلق على $time' : 'Closes at $time';
    } else {
      return isRTL ? 'يفتح على $time' : 'Opens at $time';
    }
  }
}
