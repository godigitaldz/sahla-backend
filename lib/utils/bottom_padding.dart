import 'dart:io';

import 'package:flutter/material.dart';

class BottomPaddingHelper {
  /// Returns the appropriate bottom padding based on device type and navigation mode
  ///
  /// Logic:
  /// 1. iOS devices: 6px (fixed padding)
  /// 2. Android with gesture nav: 12px (fixed padding)
  /// 3. Android with button nav bar: 0px (no additional padding)
  static double getBottomPadding(BuildContext context) {
    if (Platform.isIOS) {
      return _getIphoneBottomPadding();
    } else if (Platform.isAndroid) {
      return _getAndroidBottomPadding(context);
    }

    // Fallback: No additional padding
    return 0;
  }

  /// iPhone bottom padding logic
  static double _getIphoneBottomPadding() {
    // iOS devices: 6px padding
    return 6;
  }

  /// Android bottom padding logic
  static double _getAndroidBottomPadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomSafeArea = mediaQuery.padding.bottom;

    // Android with gesture navigation: Fixed 12px padding
    if (_hasAndroidGestureNavigation(bottomSafeArea)) {
      return 12;
    }

    // Android with button navigation bar: No additional padding
    return 0;
  }

  /// Android gesture navigation detection
  static bool _hasAndroidGestureNavigation(double bottomSafeArea) {
    // If bottomSafeArea > 0, device likely has gesture navigation (like iOS)
    return bottomSafeArea > 0;
  }

  /// Android button navigation detection
  static bool _hasAndroidButtonNavigation(double bottomSafeArea) {
    // If bottomSafeArea == 0, device likely has button navigation bar
    return bottomSafeArea == 0;
  }

  /// Returns EdgeInsets for bottom padding
  static EdgeInsets getBottomPaddingInsets(BuildContext context) {
    return EdgeInsets.only(bottom: getBottomPadding(context));
  }

  /// Checks if device has gesture navigation (no physical buttons)
  static bool hasGestureNavigation(BuildContext context) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    if (Platform.isIOS) {
      return true; // All modern iOS devices use gestures
    } else if (Platform.isAndroid) {
      return _hasAndroidGestureNavigation(bottomSafeArea);
    }

    return false;
  }

  /// Checks if device has button navigation bar
  static bool hasButtonNavigation(BuildContext context) {
    if (Platform.isIOS) {
      return false; // iOS doesn't have button navigation
    } else if (Platform.isAndroid) {
      final bottomSafeArea = MediaQuery.of(context).padding.bottom;
      return _hasAndroidButtonNavigation(bottomSafeArea);
    }

    return false;
  }
}
