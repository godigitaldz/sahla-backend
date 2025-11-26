import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Comprehensive accessibility service for managing accessibility settings
/// across the entire application with high-level performance optimizations
class AccessibilityService extends ChangeNotifier {
  static final AccessibilityService _instance =
      AccessibilityService._internal();
  factory AccessibilityService() => _instance;
  AccessibilityService._internal();

  // Performance optimization: Cache for computed styles
  static final Map<String, TextStyle> _textStyleCache = {};
  static final Map<String, ButtonStyle> _buttonStyleCache = {};

  // Settings
  bool _screenReaderEnabled = false;
  bool _highContrastEnabled = false;
  bool _largeTextEnabled = false;
  bool _reduceMotionEnabled = false;
  bool _boldTextEnabled = false;
  double _textScaleFactor = 1.0;
  double _touchTargetSize = 48.0;
  String _selectedLanguage = 'English';

  // Cache variables for performance optimization
  final Map<String, ThemeData> _themeCache = {};
  final Map<String, String> _languageCache = {};
  final Map<String, dynamic> _accessibilityCache = {};

  // Getters
  bool get screenReaderEnabled => _screenReaderEnabled;
  bool get highContrastEnabled => _highContrastEnabled;
  bool get largeTextEnabled => _largeTextEnabled;
  bool get reduceMotionEnabled => _reduceMotionEnabled;
  bool get boldTextEnabled => _boldTextEnabled;
  double get textScaleFactor => _textScaleFactor;
  double get touchTargetSize => _touchTargetSize;
  String get selectedLanguage => _selectedLanguage;

  // Initialize service
  Future<void> initialize() async {
    await _loadSettings();
  }

  // Load settings from storage
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _screenReaderEnabled =
          prefs.getBool('accessibility_screen_reader') ?? false;
      _highContrastEnabled =
          prefs.getBool('accessibility_high_contrast') ?? false;
      _largeTextEnabled = prefs.getBool('accessibility_large_text') ?? false;
      _reduceMotionEnabled =
          prefs.getBool('accessibility_reduce_motion') ?? false;
      _boldTextEnabled = prefs.getBool('accessibility_bold_text') ?? false;
      _textScaleFactor = prefs.getDouble('accessibility_text_scale') ?? 1.0;
      _touchTargetSize = prefs.getDouble('accessibility_touch_target') ?? 48.0;
      _selectedLanguage =
          prefs.getString('accessibility_language') ?? 'English';
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading accessibility settings: $e');
    }
  }

  // Save settings to storage
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('accessibility_screen_reader', _screenReaderEnabled);
      await prefs.setBool('accessibility_high_contrast', _highContrastEnabled);
      await prefs.setBool('accessibility_large_text', _largeTextEnabled);
      await prefs.setBool('accessibility_reduce_motion', _reduceMotionEnabled);
      await prefs.setBool('accessibility_bold_text', _boldTextEnabled);
      await prefs.setDouble('accessibility_text_scale', _textScaleFactor);
      await prefs.setDouble('accessibility_touch_target', _touchTargetSize);
      await prefs.setString('accessibility_language', _selectedLanguage);
    } catch (e) {
      debugPrint('Error saving accessibility settings: $e');
    }
  }

  // Update settings
  Future<void> updateSettings({
    bool? screenReader,
    bool? highContrast,
    bool? largeText,
    bool? reduceMotion,
    bool? boldText,
    double? textScale,
    double? touchTarget,
    String? language,
  }) async {
    if (screenReader != null) _screenReaderEnabled = screenReader;
    if (highContrast != null) _highContrastEnabled = highContrast;
    if (largeText != null) _largeTextEnabled = largeText;
    if (reduceMotion != null) _reduceMotionEnabled = reduceMotion;
    if (boldText != null) _boldTextEnabled = boldText;
    if (textScale != null) _textScaleFactor = textScale;
    if (touchTarget != null) _touchTargetSize = touchTarget;
    if (language != null) _selectedLanguage = language;

    await _saveSettings();
    clearCache(); // Clear cache when settings change
    notifyListeners();
  }

  /// Clear all caches for memory management
  void clearCache() {
    _themeCache.clear();
    _languageCache.clear();
    _accessibilityCache.clear();
  }

  // Get accessible text style with performance optimization and caching
  TextStyle getAccessibleTextStyle(TextStyle baseStyle) {
    debugPrint('♿ AccessibilityService.getAccessibleTextStyle() called');

    // Performance optimization: Create cache key
    final cacheKey =
        '${baseStyle.hashCode}_${_textScaleFactor}_${_boldTextEnabled}_$_highContrastEnabled';

    // Performance optimization: Check cache first
    if (_textStyleCache.containsKey(cacheKey)) {
      debugPrint(
          '⚡ AccessibilityService.getAccessibleTextStyle() - using cached style');
      return _textStyleCache[cacheKey]!;
    }

    debugPrint(
        '♿ AccessibilityService.getAccessibleTextStyle() - computing new style');

    TextStyle result = baseStyle.copyWith(
      fontSize: baseStyle.fontSize != null
          ? baseStyle.fontSize! * _textScaleFactor
          : null,
      fontWeight: _boldTextEnabled ? FontWeight.bold : baseStyle.fontWeight,
    );

    // Apply high contrast if enabled
    if (_highContrastEnabled) {
      result = result.copyWith(
        color: (result.color?.computeLuminance() ?? 0.5) > 0.5
            ? Colors.black
            : Colors.white,
      );
    }

    // Cache the result for performance
    _textStyleCache[cacheKey] = result;

    debugPrint(
        '✅ AccessibilityService.getAccessibleTextStyle() - style computed and cached');
    return result;
  }

  // Get accessible theme data
  ThemeData getAccessibleTheme(ThemeData baseTheme) {
    if (!_highContrastEnabled) return baseTheme;

    return baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: Colors.black,
        secondary: Colors.white,
        surface: Colors.black,
        onSurface: Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
      ),
      textTheme: baseTheme.textTheme.apply(
        fontSizeFactor: _textScaleFactor,
      ),
    );
  }

  // Get accessible button style with performance optimization and caching
  ButtonStyle getAccessibleButtonStyle(ButtonStyle baseStyle) {
    debugPrint('♿ AccessibilityService.getAccessibleButtonStyle() called');

    // Performance optimization: Create cache key
    final cacheKey =
        '${baseStyle.hashCode}_${_touchTargetSize}_$_highContrastEnabled';

    // Performance optimization: Check cache first
    if (_buttonStyleCache.containsKey(cacheKey)) {
      debugPrint(
          '⚡ AccessibilityService.getAccessibleButtonStyle() - using cached style');
      return _buttonStyleCache[cacheKey]!;
    }

    debugPrint(
        '♿ AccessibilityService.getAccessibleButtonStyle() - computing new style');

    ButtonStyle result = baseStyle.copyWith(
      minimumSize: WidgetStateProperty.all(
        Size(_touchTargetSize, _touchTargetSize),
      ),
    );

    // Apply high contrast if enabled
    if (_highContrastEnabled) {
      result = result.copyWith(
        backgroundColor: WidgetStateProperty.all(Colors.black),
        foregroundColor: WidgetStateProperty.all(Colors.white),
        side: WidgetStateProperty.all(
          const BorderSide(color: Colors.white, width: 2),
        ),
      );
    }

    // Cache the result for performance
    _buttonStyleCache[cacheKey] = result;

    debugPrint(
        '✅ AccessibilityService.getAccessibleButtonStyle() - style computed and cached');
    return result;
  }

  // Check if motion should be reduced
  bool shouldReduceMotion() => _reduceMotionEnabled;

  // Get animation duration based on settings
  Duration getAnimationDuration(Duration baseDuration) {
    return _reduceMotionEnabled ? Duration.zero : baseDuration;
  }

  // Reset to defaults
  Future<void> resetToDefaults() async {
    await updateSettings(
      screenReader: false,
      highContrast: false,
      largeText: false,
      reduceMotion: false,
      boldText: false,
      textScale: 1.0,
      touchTarget: 48.0,
      language: 'English',
    );
  }

  // Export settings as JSON
  Map<String, dynamic> exportSettings() {
    return {
      'screenReaderEnabled': _screenReaderEnabled,
      'highContrastEnabled': _highContrastEnabled,
      'largeTextEnabled': _largeTextEnabled,
      'reduceMotionEnabled': _reduceMotionEnabled,
      'boldTextEnabled': _boldTextEnabled,
      'textScaleFactor': _textScaleFactor,
      'touchTargetSize': _touchTargetSize,
      'selectedLanguage': _selectedLanguage,
    };
  }

  // Import settings from JSON
  Future<void> importSettings(Map<String, dynamic> settings) async {
    await updateSettings(
      screenReader: settings['screenReaderEnabled'],
      highContrast: settings['highContrastEnabled'],
      largeText: settings['largeTextEnabled'],
      reduceMotion: settings['reduceMotionEnabled'],
      boldText: settings['boldTextEnabled'],
      textScale: settings['textScaleFactor']?.toDouble(),
      touchTarget: settings['touchTargetSize']?.toDouble(),
      language: settings['selectedLanguage'],
    );
    // Clear all caches for memory management (useful for testing or memory cleanup)
  }
}
