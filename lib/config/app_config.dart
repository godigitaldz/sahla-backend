/// SAHLA Delivery App Configuration
/// Contains all app-wide constants and configuration values
library;

import "package:flutter/material.dart";

/// App-wide color constants
class AppColors {
  // Primary color scheme
  static const Color primary = Color(0xFFFB8C00); // SAHLA Orange
  static const Color primaryDark = Color(0xFFE65100);
  static const Color primaryLight = Color(0xFFFFC107);

  // Background colors
  static const Color background = Color(0xFFFFFFFF); // White
  static const Color surface = Color(0xFFF5F5F5);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // Text colors
  static const Color textPrimary = Color(0xFF000000); // Black
  static const Color textSecondary = Color(0xFF666666);
  static const Color textOnPrimary = Color(0xFFFFFFFF); // White

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFF44336);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);

  // Neutral colors
  static const Color divider = Color(0xFFE0E0E0);
  static const Color shadow = Color(0x1F000000);

  // Gradient colors for special UI elements
  static const List<Color> primaryGradient = [
    Color(0xFFFB8C00),
    Color(0xFFFFC107),
  ];
}

/// Typography configuration
class AppTypography {
  // Font families
  static const String primaryFont = "Inter";
  static const String secondaryFont = "Poppins";

  // Font weights
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  // Font sizes
  static const double fontSizeXs = 12;
  static const double fontSizeSm = 14;
  static const double fontSizeMd = 16;
  static const double fontSizeLg = 18;
  static const double fontSizeXl = 20;
  static const double fontSizeXxl = 24;
  static const double fontSizeXxxl = 32;

  // Text styles for consistent typography
  static const TextStyle displayLarge = TextStyle(
    fontSize: fontSizeXxxl,
    fontWeight: bold,
    height: 1.2,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: fontSizeXxl,
    fontWeight: bold,
    height: 1.2,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: fontSizeXl,
    fontWeight: bold,
    height: 1.3,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: fontSizeXxl,
    fontWeight: semiBold,
    height: 1.3,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: fontSizeXl,
    fontWeight: semiBold,
    height: 1.3,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: fontSizeLg,
    fontWeight: semiBold,
    height: 1.4,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: fontSizeLg,
    fontWeight: semiBold,
    height: 1.4,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: fontSizeMd,
    fontWeight: medium,
    height: 1.4,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: fontSizeSm,
    fontWeight: medium,
    height: 1.4,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: fontSizeMd,
    fontWeight: regular,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: fontSizeSm,
    fontWeight: regular,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: fontSizeXs,
    fontWeight: regular,
    height: 1.4,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: fontSizeSm,
    fontWeight: medium,
    height: 1.4,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: fontSizeXs,
    fontWeight: medium,
    height: 1.4,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: fontSizeXs,
    fontWeight: regular,
    height: 1.3,
  );
}

/// Spacing and sizing constants
class AppSpacing {
  // Padding and margin
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // Border radius
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusXxl = 32;

  // Button heights
  static const double buttonHeightSm = 36;
  static const double buttonHeightMd = 48;
  static const double buttonHeightLg = 56;

  // Icon sizes
  static const double iconSizeSm = 16;
  static const double iconSizeMd = 24;
  static const double iconSizeLg = 32;
  static const double iconSizeXl = 48;
}

/// Animation durations
class AppAnimations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);

  // Page transition durations
  static const Duration pageTransition = Duration(milliseconds: 400);
  static const Duration bottomSheetTransition = Duration(milliseconds: 250);
}

/// App-wide constants
class AppConstants {
  // App info
  static const String appName = "SAHLA Delivery";
  static const String appVersion = "1.0.0";
  static const String appBuildNumber = "1";

  // Supported locales
  static const List<String> supportedLocales = ["en", "ar", "fr"];

  // Phone number validation
  static const int minPhoneLength = 8;
  static const int maxPhoneLength = 15;

  // Pagination
  static const int defaultPageSize = 20;

  // Image quality settings
  static const int imageQuality = 85;
  static const int thumbnailQuality = 60;

  // Cache durations
  static const Duration cacheShort = Duration(minutes: 5);
  static const Duration cacheMedium = Duration(hours: 1);
  static const Duration cacheLong = Duration(days: 7);

  // Cache expiration (in minutes) - from constants.dart
  static const int cacheExpirationMinutes = 30;
  static const int userCacheExpirationMinutes = 60;

  // Default values - from constants.dart
  static const String defaultUserId = 'current_user_id';
  static const String defaultUserName = 'Guest User';

  // Storage keys - from constants.dart
  static const String authTokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String userDataKey = 'user_data';
  static const String viewHistoryKey = 'view_history';
  static const String favoritesKey = 'favorites';
  static const String offlineDataKey = 'offline_data';
  static const String lastSyncKey = 'last_sync';

  // Cache keys - from constants.dart
  static const String favoritesCacheKey = 'favorites_cache';
  static const String userCacheKey = 'user_cache';

  // Offline sync settings - from constants.dart
  static const int maxOfflineItems = 1000;
  static const Duration syncRetryDelay = Duration(minutes: 5);
  static const int maxSyncRetries = 3;

  // App dimensions - from constants.dart
  static const double defaultPadding = 16.0;
  static const double defaultRadius = 12.0;

  // Currency and locale - from constants.dart
  static const String currencySymbol = 'DA';
}

/// API constants
class ApiConstants {
  // Real API base URL for food delivery service
  static const String baseUrl = 'https://api.fooddelivery.com/v1';

  // API endpoints
  static const String authEndpoint = '/auth';
  static const String usersEndpoint = '/users';
  static const String notificationsEndpoint = '/notifications';
  static const String viewHistoryEndpoint = '/view-history';
  static const String favoritesEndpoint = '/favorites';
  static const String reviewsEndpoint = '/reviews';
  static const String locationsEndpoint = '/locations';
  static const String availabilityEndpoint = '/availability';
  static const String restaurantsEndpoint = '/restaurants';
  static const String menuItemsEndpoint = '/menu-items';
  static const String ordersEndpoint = '/orders';
  static const String deliveryEndpoint = '/delivery';

  // API timeout
  static const Duration timeout = Duration(seconds: 30);
  static const Duration shortTimeout = Duration(seconds: 10);

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // HTTP Status Codes
  static const int success = 200;
  static const int created = 201;
  static const int noContent = 204;
  static const int badRequest = 400;
  static const int unauthorized = 401;
  static const int forbidden = 403;
  static const int notFound = 404;
  static const int conflict = 409;
  static const int unprocessableEntity = 422;
  static const int internalServerError = 500;
  static const int serviceUnavailable = 503;

  // Error Messages
  static const String networkError = 'Network connection error';
  static const String serverError = 'Server error occurred';
  static const String unauthorizedError = 'Unauthorized access';
  static const String notFoundError = 'Resource not found';
  static const String validationError = 'Validation error';
  static const String timeoutError = 'Request timeout';
  static const String unknownError = 'Unknown error occurred';
}

/// Responsive sizing constants
class AppSizes {
  // Screen dimensions - Fixed GlobalKey issue
  static double get screenWidth {
    final context = _getCurrentContext();
    if (context != null) {
      return MediaQuery.of(context).size.width;
    }
    return 375.0; // Default width for mobile
  }

  static double get screenHeight {
    final context = _getCurrentContext();
    if (context != null) {
      return MediaQuery.of(context).size.height;
    }
    return 812.0; // Default height for mobile
  }

  // Helper method to get current context safely
  static BuildContext? _getCurrentContext() {
    try {
      // Try to get context from the current navigator
      return Navigator.maybeOf(WidgetsBinding.instance.rootElement!)?.context;
    } catch (e) {
      return null;
    }
  }

  // Header dimensions
  static const double headerHeight = 80.0;
  static const double logoHeight = 48.0;
  static const double logoWidth = 120.0;
  static const double headerPadding = 16.0;

  // Search bar dimensions
  static const double searchBarHeight = 44.0;
  static const double searchBarBorderRadius = 22.0;
  static const double searchBarWidthPercentage = 0.9;

  // Card dimensions
  static const double cardBorderRadius = 16.0;
  static const double cardPadding = 16.0;
  static const double cardSpacing = 12.0;

  // Icon sizes
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;

  // Text sizes
  static const double textSizeSmall = 12.0;
  static const double textSizeMedium = 14.0;
  static const double textSizeLarge = 16.0;
  static const double textSizeXLarge = 18.0;

  // Button dimensions
  static const double buttonHeight = 48.0;
  static const double buttonBorderRadius = 24.0;

  // Spacing
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;

  // Responsive helpers
  static double get responsiveWidth => screenWidth * 0.9;
  static double get cardWidth => screenWidth * 0.88;
  static double get cardHeight => cardWidth * 0.8;
}
