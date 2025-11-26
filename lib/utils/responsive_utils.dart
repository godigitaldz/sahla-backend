import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Enhanced Responsive Utilities for High Performance Adaptive Design
class EnhancedResponsive {
  // Device breakpoints
  static const double tabletBreakpoint = 1024;
  static const double desktopBreakpoint = 1440;

  // Grid configurations for different screen sizes
  static const Map<DeviceType, GridConfig> gridConfigs = {
    DeviceType.mobile: GridConfig(
      restaurantColumns: 2,
      categoryColumns: 4,
      maxCategoryWidth: 80,
      restaurantAspectRatio: 0.75,
    ),
    DeviceType.tablet: GridConfig(
      restaurantColumns: 3,
      categoryColumns: 6,
      maxCategoryWidth: 100,
      restaurantAspectRatio: 0.8,
    ),
    DeviceType.desktop: GridConfig(
      restaurantColumns: 4,
      categoryColumns: 8,
      maxCategoryWidth: 120,
      restaurantAspectRatio: 0.85,
    ),
  };

  /// Get current device type based on screen width
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= desktopBreakpoint) return DeviceType.desktop;
    if (width >= tabletBreakpoint) return DeviceType.tablet;
    return DeviceType.mobile;
  }

  /// Get grid configuration for current device
  static GridConfig getGridConfig(BuildContext context) {
    return gridConfigs[getDeviceType(context)]!;
  }

  /// Get responsive border radius
  static BorderRadius getResponsiveBorderRadius(
      BuildContext context, double baseRadius) {
    final deviceType = getDeviceType(context);
    double radius;

    switch (deviceType) {
      case DeviceType.mobile:
        radius = baseRadius.r;
        break;
      case DeviceType.tablet:
        radius = (baseRadius * 1.2).r;
        break;
      case DeviceType.desktop:
        radius = (baseRadius * 1.4).r;
        break;
    }

    return BorderRadius.circular(radius);
  }
}

/// Device type enumeration
enum DeviceType { mobile, tablet, desktop }

/// Grid configuration class
class GridConfig {
  final int restaurantColumns;
  final int categoryColumns;
  final double maxCategoryWidth;
  final double restaurantAspectRatio;

  const GridConfig({
    required this.restaurantColumns,
    required this.categoryColumns,
    required this.maxCategoryWidth,
    required this.restaurantAspectRatio,
  });
}

/// Extension methods for easier usage
extension ResponsiveExtension on BuildContext {
  GridConfig get gridConfig => EnhancedResponsive.getGridConfig(this);

  BorderRadius responsiveBorderRadius(double baseRadius) =>
      EnhancedResponsive.getResponsiveBorderRadius(this, baseRadius);
}
