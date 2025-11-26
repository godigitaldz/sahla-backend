import 'package:flutter/material.dart';

import 'config/app_config.dart';

/// SAHLA Delivery App Theme
/// Optimized for performance and consistent branding

/// Main light theme for SAHLA Delivery
final ThemeData sahlaLightTheme = ThemeData(
  // Basic theme configuration
  brightness: Brightness.light,
  primaryColor: AppColors.primary,
  scaffoldBackgroundColor: AppColors.background,
  fontFamily: AppTypography.primaryFont,
  visualDensity: VisualDensity.adaptivePlatformDensity,

  // Color scheme - SAHLA 3-color system
  colorScheme: const ColorScheme.light(
    primary: AppColors.primary, // SAHLA Orange
    secondary: AppColors.textPrimary, // Black
    surface: AppColors.surface,
    background: AppColors.background,
    onPrimary: AppColors.textOnPrimary, // White on orange
    onSecondary: AppColors.textOnPrimary, // White on black
    onSurface: AppColors.textPrimary, // Black on white
    onBackground: AppColors.textPrimary, // Black on white
  ),

  // Typography - Inter font family
  textTheme: _buildSahlaTextTheme(),

  // App bar theme
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.textOnPrimary,
    elevation: 8,
    shadowColor: AppColors.shadow,
    centerTitle: true,
    titleTextStyle: AppTypography.headlineMedium.copyWith(
      color: AppColors.textOnPrimary,
      fontWeight: AppTypography.bold,
    ),
  ),

  // Card theme
  cardTheme: CardThemeData(
    color: AppColors.cardBackground,
    elevation: 12,
    shadowColor: AppColors.shadow,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    margin: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
  ),

  // Elevated button theme
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textOnPrimary,
      elevation: 8,
      shadowColor: AppColors.primary.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      textStyle: AppTypography.labelLarge.copyWith(
        fontWeight: AppTypography.semiBold,
      ),
    ),
  ),

  // Input decoration theme
  inputDecorationTheme: InputDecorationTheme(
    filled: false,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.md,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      borderSide: const BorderSide(color: AppColors.error, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      borderSide: const BorderSide(color: AppColors.error, width: 2),
    ),
    labelStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7)),
    hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
  ),

  // Bottom navigation theme
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.background,
    selectedItemColor: AppColors.primary,
    unselectedItemColor: AppColors.textSecondary,
    elevation: 20,
    type: BottomNavigationBarType.fixed,
    showUnselectedLabels: true,
  ),

  // Floating action button theme
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.textOnPrimary,
    elevation: 16,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    ),
  ),

  // Dialog theme
  dialogTheme: DialogThemeData(
    backgroundColor: AppColors.background,
    elevation: 16,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    ),
  ),

  // Chip theme
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.surface,
    selectedColor: AppColors.primary,
    labelStyle: AppTypography.bodyMedium.copyWith(
      color: AppColors.textPrimary,
    ),
  ),

  // Global page transitions theme for platform consistency
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: _SahlaDefaultTransitionsBuilder(),
      TargetPlatform.iOS: _SahlaDefaultTransitionsBuilder(),
      TargetPlatform.linux: _SahlaDefaultTransitionsBuilder(),
      TargetPlatform.macOS: _SahlaDefaultTransitionsBuilder(),
      TargetPlatform.windows: _SahlaDefaultTransitionsBuilder(),
    },
  ),
);

/// SAHLA text theme with Inter font
TextTheme _buildSahlaTextTheme() {
  return TextTheme(
    displayLarge: AppTypography.displayLarge.copyWith(
      fontFamily: AppTypography.primaryFont,
      color: AppColors.textPrimary,
    ),
    displayMedium: AppTypography.displayMedium.copyWith(
      fontFamily: AppTypography.primaryFont,
      color: AppColors.textPrimary,
    ),
    displaySmall: AppTypography.displaySmall.copyWith(
      fontFamily: AppTypography.primaryFont,
      color: AppColors.textPrimary,
    ),
    headlineLarge: AppTypography.headlineLarge.copyWith(
      fontFamily: AppTypography.primaryFont,
      color: AppColors.textPrimary,
    ),
    headlineMedium: AppTypography.headlineMedium.copyWith(
      fontFamily: AppTypography.primaryFont,
      color: AppColors.textPrimary,
    ),
    headlineSmall: AppTypography.headlineSmall.copyWith(
      fontFamily: AppTypography.primaryFont,
      color: AppColors.textPrimary,
    ),
    titleLarge: AppTypography.titleLarge.copyWith(
      fontFamily: AppTypography.primaryFont,
      color: AppColors.textPrimary,
    ),
    titleMedium: AppTypography.titleMedium.copyWith(
      fontFamily: AppTypography.primaryFont,
      color: AppColors.textPrimary,
    ),
    titleSmall: AppTypography.titleSmall.copyWith(
      fontFamily: AppTypography.primaryFont,
      color: AppColors.textSecondary,
    ),
    bodyLarge: AppTypography.bodyLarge.copyWith(
      fontFamily: AppTypography.primaryFont,
      color: AppColors.textPrimary,
    ),
    bodyMedium: AppTypography.bodyMedium.copyWith(
      fontFamily: AppTypography.primaryFont,
      color: AppColors.textPrimary,
    ),
    bodySmall: AppTypography.bodySmall.copyWith(
      fontFamily: AppTypography.primaryFont,
      color: AppColors.textSecondary,
    ),
    labelLarge: AppTypography.labelLarge.copyWith(
      fontFamily: AppTypography.primaryFont,
      color: AppColors.textPrimary,
    ),
    labelMedium: AppTypography.labelMedium.copyWith(
      fontFamily: AppTypography.primaryFont,
      color: AppColors.textPrimary,
    ),
    labelSmall: AppTypography.labelSmall.copyWith(
      fontFamily: AppTypography.primaryFont,
      color: AppColors.textSecondary,
    ),
  );
}

// Extensions for typography
extension SahlaTextStyleExtensions on TextStyle {
  TextStyle get sahlaOrange => copyWith(color: AppColors.primary);
  TextStyle get sahlaBold => copyWith(fontWeight: AppTypography.bold);
  TextStyle get sahlaSemiBold => copyWith(fontWeight: AppTypography.semiBold);
  TextStyle get sahlaMedium => copyWith(fontWeight: AppTypography.medium);
}

// Default transitions builder that aligns with AppAnimations (easeInOut, 250–400ms)
class _SahlaDefaultTransitionsBuilder extends PageTransitionsBuilder {
  const _SahlaDefaultTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Use fade + slide from right as subtle default
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
          .animate(curved),
      child: FadeTransition(opacity: curved, child: child),
    );
  }
}
