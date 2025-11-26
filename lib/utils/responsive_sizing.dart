import 'package:flutter/material.dart';

/// Responsive Sizing Utility
/// Converts fixed pixel values to screen-based percentages for better cross-device compatibility
class ResponsiveSizing {
  static const double _designWidth = 375.0; // iPhone 6/7/8 width as reference
  static const double _designHeight = 812.0; // iPhone X height as reference

  /// Get screen width
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Get screen height
  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Convert width from pixels to screen percentage
  static double width(double pixels, BuildContext context) {
    return (pixels / _designWidth) * screenWidth(context);
  }

  /// Convert height from pixels to screen percentage
  static double height(double pixels, BuildContext context) {
    return (pixels / _designHeight) * screenHeight(context);
  }

  /// Convert font size from pixels to responsive size
  static double fontSize(double pixels, BuildContext context) {
    final double scaleFactor = screenWidth(context) / _designWidth;
    return pixels *
        scaleFactor.clamp(0.8, 1.4); // Limit scaling to prevent extreme sizes
  }

  /// Get responsive padding
  static EdgeInsets padding(
    BuildContext context, {
    double horizontal = 0,
    double vertical = 0,
    double all = 0,
  }) {
    if (all > 0) {
      return EdgeInsets.all(width(all, context));
    }
    return EdgeInsets.symmetric(
      horizontal: width(horizontal, context),
      vertical: height(vertical, context),
    );
  }

  /// Get responsive margin
  static EdgeInsets margin(
    BuildContext context, {
    double horizontal = 0,
    double vertical = 0,
    double all = 0,
  }) {
    if (all > 0) {
      return EdgeInsets.all(width(all, context));
    }
    return EdgeInsets.symmetric(
      horizontal: width(horizontal, context),
      vertical: height(vertical, context),
    );
  }

  /// Get responsive sized box
  static SizedBox sizedBox(
    BuildContext context, {
    double width = 0,
    double height = 0,
  }) {
    return SizedBox(
      width: width > 0 ? ResponsiveSizing.width(width, context) : null,
      height: height > 0 ? ResponsiveSizing.height(height, context) : null,
    );
  }

  /// Get responsive border radius
  static BorderRadius borderRadius(BuildContext context, double radius) {
    return BorderRadius.circular(width(radius, context));
  }

  /// Get responsive box shadow
  static BoxShadow boxShadow(
    BuildContext context, {
    Color color = Colors.black,
    double blurRadius = 8,
    Offset offset = Offset.zero,
    double spreadRadius = 0,
  }) {
    return BoxShadow(
      color: color,
      blurRadius: width(blurRadius, context),
      offset: Offset(width(offset.dx, context), height(offset.dy, context)),
      spreadRadius: width(spreadRadius, context),
    );
  }

  /// Get responsive container size
  static BoxConstraints constraints(
    BuildContext context, {
    double? minWidth,
    double? maxWidth,
    double? minHeight,
    double? maxHeight,
  }) {
    return BoxConstraints(
      minWidth: minWidth != null ? width(minWidth, context) : 0,
      maxWidth: maxWidth != null ? width(maxWidth, context) : double.infinity,
      minHeight: minHeight != null ? height(minHeight, context) : 0,
      maxHeight:
          maxHeight != null ? height(maxHeight, context) : double.infinity,
    );
  }
}

/// Extension methods for easier usage
extension ResponsiveExtension on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  double responsiveWidth(double pixels) => ResponsiveSizing.width(pixels, this);
  double responsiveHeight(double pixels) =>
      ResponsiveSizing.height(pixels, this);
  double responsiveFontSize(double pixels) =>
      ResponsiveSizing.fontSize(pixels, this);

  EdgeInsets responsivePadding({
    double horizontal = 0,
    double vertical = 0,
    double all = 0,
  }) =>
      ResponsiveSizing.padding(this,
          horizontal: horizontal, vertical: vertical, all: all);

  EdgeInsets responsiveMargin({
    double horizontal = 0,
    double vertical = 0,
    double all = 0,
  }) =>
      ResponsiveSizing.margin(this,
          horizontal: horizontal, vertical: vertical, all: all);

  SizedBox responsiveSizedBox({
    double width = 0,
    double height = 0,
  }) =>
      ResponsiveSizing.sizedBox(this, width: width, height: height);

  BorderRadius responsiveBorderRadius(double radius) =>
      ResponsiveSizing.borderRadius(this, radius);
}
