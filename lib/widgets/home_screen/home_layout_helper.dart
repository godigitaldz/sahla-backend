import 'dart:io';

import 'package:flutter/material.dart';

/// Comprehensive layout helper for home screen
/// Handles all spacing, safe areas, and responsive logic across devices
class HomeLayoutHelper {
  /// SearchFab height constant
  static const double searchFabHeight = 44.0;

  /// Language switcher and profile icon height
  static const double iconsHeight = 32.0;

  /// Horizontal padding for header
  static const double headerHorizontalPadding = 14.0;

  /// Calculate device-specific safe area top
  static double getSafeAreaTop(BuildContext context) {
    return MediaQuery.of(context).padding.top;
  }

  /// Calculate device-specific safe area bottom
  static double getSafeAreaBottom(BuildContext context) {
    return MediaQuery.of(context).padding.bottom;
  }

  /// Get header content height (the taller of SearchFab or icons)
  static double getHeaderContentHeight() {
    return searchFabHeight; // SearchFab is taller, so use its height
  }

  /// Calculate total header height (safe area + content + spacing)
  static double getHeaderHeight(BuildContext context) {
    final safeAreaTop = getSafeAreaTop(context);
    final contentHeight = getHeaderContentHeight();

    // Add small spacing below content for breathing room
    final bottomSpacing = Platform.isIOS ? 6.0 : 8.0;

    return safeAreaTop + contentHeight + bottomSpacing;
  }

  /// Calculate header top position for Positioned widget
  static double getHeaderTopPosition(BuildContext context) {
    final safeAreaTop = getSafeAreaTop(context);

    // Add small offset to position header nicely within safe area
    return safeAreaTop + (Platform.isIOS ? 4.0 : 6.0);
  }

  /// Calculate content start height (where white container begins)
  /// Responsive based on screen size
  static double getContentStartHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive percentage based on screen size
    if (screenHeight <= 667) {
      // Small devices (iPhone SE, iPhone 6/7/8)
      return screenHeight * 0.22; // 22% for small screens
    } else if (screenHeight <= 736) {
      // Medium devices (iPhone 6/7/8 Plus)
      return screenHeight * 0.23; // 23% for medium screens
    } else if (screenHeight <= 812) {
      // iPhone X/XS/11 Pro
      return screenHeight * 0.24; // 24%
    } else {
      // Large devices (iPhone XS Max, 11 Pro Max, etc.)
      return screenHeight * 0.25; // 25%
    }
  }

  /// Calculate image height (background image extends beyond content start)
  static double getImageHeight(BuildContext context) {
    final contentStartHeight = getContentStartHeight(context);
    // Image extends 20% more than content start for nice overlap
    return contentStartHeight * 1.20;
  }

  /// Calculate maximum scroll offset (stop point)
  ///
  /// Visual layout when container reaches stop point:
  /// ┌─────────────────────────┐
  /// │   Status Bar (safe)     │ ← Safe area top
  /// ├─────────────────────────┤
  /// │   Header Top Position   │ ← Small offset (4-6px)
  /// ├─────────────────────────┤
  /// │   🔍 SearchFab (44px)   │ ← Fully visible search bar
  /// ├─────────────────────────┤
  /// │   Gap (12-18px)         │ ← Breathing room
  /// ╔═════════════════════════╗
  /// ║   Container (rounded)   ║ ← Container stops here
  /// ║   Filter chips...       ║
  ///
  static double getMaxScrollOffset(BuildContext context) {
    final contentStartHeight = getContentStartHeight(context);
    final headerTopPosition = getHeaderTopPosition(context);
    final headerContainerGap = getHeaderContainerGap(context);

    // Calculate stop point: container should stop below SearchFab with proper gap
    // Container top position when stopped = headerTop + SearchFabHeight + gap
    final containerStopPosition =
        headerTopPosition + searchFabHeight + headerContainerGap;

    // Max scroll = how far container needs to move up
    // From contentStartHeight down to containerStopPosition
    final maxScroll = contentStartHeight - containerStopPosition;

    return maxScroll.clamp(50.0, double.infinity);
  }

  /// Calculate spacing for filter chips section
  /// This is the top padding inside the white container
  /// Should account for filter chips height + minimal gap to categories
  ///
  /// Filter chips anatomy:
  /// - FilterChipsSection top padding: 8px
  /// - Chip height: ~34px (7px + ~20px + 7px)
  /// - FilterChipsSection bottom padding: 0px
  /// Total filter section: ~42px
  static double getFilterChipsSpacing(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    // Tight, responsive spacing: filter height (42px) + gap (6-10px)
    if (screenHeight <= 667) {
      return 48.0; // Small screens: 42px chips + 6px gap
    } else if (screenHeight <= 736) {
      return 50.0; // Medium screens: 42px chips + 8px gap
    } else if (screenHeight <= 844) {
      return 52.0; // iPhone 13: 42px chips + 10px gap
    } else if (screenHeight <= 926) {
      return 54.0; // Large screens: 42px chips + 12px gap
    } else {
      return 56.0; // Extra large: 42px chips + 14px gap
    }
  }

  /// Calculate padding between SearchFab bottom and container top
  /// This ensures proper spacing when container reaches stop point
  static double getHeaderContainerGap(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive gap - needs to be visible and prevent overlap
    if (screenHeight <= 667) {
      return 12.0; // Small screens need adequate space
    } else if (screenHeight <= 736) {
      return 14.0; // Medium screens
    } else if (screenHeight <= 812) {
      return 16.0; // iPhone X size
    } else {
      return 18.0; // Large screens get more breathing room
    }
  }

  /// Calculate bottom extension to prevent orange gap
  static double getBottomExtension(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxScrollOffset = getMaxScrollOffset(context);

    // Extend bottom by max scroll + buffer
    return -(maxScrollOffset + screenHeight * 0.3);
  }

  /// Calculate bottom padding for content
  /// Ensures content is fully scrollable
  static double getContentBottomPadding(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final contentStartHeight = getContentStartHeight(context);
    final maxScrollOffset = getMaxScrollOffset(context);
    final safeAreaBottom = getSafeAreaBottom(context);

    return contentStartHeight + // Initial visual position offset
        maxScrollOffset + // Phase 1 scroll distance
        screenHeight *
            0.25 + // Viewing buffer (reduced from 0.3 for small screens)
        safeAreaBottom; // Bottom safe area
  }

  /// Get responsive header horizontal padding
  static double getHeaderHorizontalPadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth <= 375) {
      return 12.0; // Tight on small screens
    } else if (screenWidth <= 414) {
      return 14.0; // Standard
    } else {
      return 16.0; // Generous on large screens
    }
  }

  /// Debug info for layout troubleshooting
  static Map<String, dynamic> getDebugInfo(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return {
      'screenWidth': screenSize.width,
      'screenHeight': screenSize.height,
      'safeAreaTop': getSafeAreaTop(context),
      'safeAreaBottom': getSafeAreaBottom(context),
      'headerHeight': getHeaderHeight(context),
      'headerTopPosition': getHeaderTopPosition(context),
      'contentStartHeight': getContentStartHeight(context),
      'maxScrollOffset': getMaxScrollOffset(context),
      'filterChipsSpacing': getFilterChipsSpacing(context),
      'headerContainerGap': getHeaderContainerGap(context),
    };
  }
}
