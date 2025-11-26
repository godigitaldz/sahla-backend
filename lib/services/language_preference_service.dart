import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";

import "profile_service.dart";

/// Service to manage language preferences using the user_profiles table
class LanguagePreferenceService extends ChangeNotifier {
  factory LanguagePreferenceService() => _instance;

  LanguagePreferenceService._internal();

  static final LanguagePreferenceService _instance =
      LanguagePreferenceService._internal();

  final ProfileService _profileService = ProfileService();

  // Current language preference
  String _currentLanguage = "en";

  // Getters
  String get currentLanguage => _currentLanguage;

  // Supported languages matching the database constraint
  static const List<String> supportedLanguages = ["en", "ar", "fr"];

  // Key for first launch detection
  static const String _firstLaunchKey = "language_preference_first_launch";

  /// Initialize the service and load user's language preference
  Future<void> initialize() async {
    try {
      // Check if this is the first launch
      final prefs = await SharedPreferences.getInstance();
      final isFirstLaunch = prefs.getBool(_firstLaunchKey) ?? true;

      if (isFirstLaunch) {
        // First launch: detect and use phone's default language
        final systemLocale = PlatformDispatcher.instance.locale;
        final systemLanguage = systemLocale.languageCode;

        if (supportedLanguages.contains(systemLanguage)) {
          _currentLanguage = systemLanguage;
          debugPrint(
              "LanguagePreferenceService: First launch detected, using phone's default language: $systemLanguage");

          // Mark first launch as completed
          await prefs.setBool(_firstLaunchKey, false);

          // Save the language preference if user is logged in
          final userId = _profileService.currentUserId;
          if (userId != null) {
            await _profileService.updateLanguagePreference(systemLanguage);
          }
        } else {
          debugPrint(
              "LanguagePreferenceService: First launch detected, but phone's language '$systemLanguage' is not supported, using default: $_currentLanguage");

          // Mark first launch as completed even if language not supported
          await prefs.setBool(_firstLaunchKey, false);
        }
        notifyListeners();
        return;
      }

      // Not first launch: load user's language preference
      final userId = _profileService.currentUserId;
      if (userId == null) {
        // No user logged in, try to detect system language as fallback
        final systemLocale = PlatformDispatcher.instance.locale;
        final systemLanguage = systemLocale.languageCode;

        if (supportedLanguages.contains(systemLanguage)) {
          _currentLanguage = systemLanguage;
          debugPrint(
              "LanguagePreferenceService: No user logged in, using system language: $systemLanguage");
        } else {
          debugPrint(
              "LanguagePreferenceService: No user logged in, system language '$systemLanguage' not supported, using default: $_currentLanguage");
        }
        notifyListeners();
        return;
      }

      // Load user's language preference from database
      final languagePreference =
          await _profileService.getUserLanguagePreference();
      if (languagePreference != null &&
          supportedLanguages.contains(languagePreference)) {
        _currentLanguage = languagePreference;
        notifyListeners();
        debugPrint(
            "LanguagePreferenceService: Loaded language preference: $languagePreference");
      } else {
        debugPrint(
            "LanguagePreferenceService: No valid language preference found, using default: $_currentLanguage");
      }
    } on Exception catch (e) {
      debugPrint("LanguagePreferenceService: Error initializing: $e");
    }
  }

  /// Update language preference and save to user profile
  Future<bool> setLanguage(String languageCode) async {
    try {
      // Validate language code
      if (!supportedLanguages.contains(languageCode)) {
        debugPrint(
            "LanguagePreferenceService: Unsupported language code: $languageCode");
        return false;
      }

      // Update local state
      _currentLanguage = languageCode;
      notifyListeners();

      // Save to database
      final success =
          await _profileService.updateLanguagePreference(languageCode);

      if (success) {
        debugPrint(
            "LanguagePreferenceService: Language preference updated to: $languageCode");
      } else {
        debugPrint(
            "LanguagePreferenceService: Failed to update language preference in database");
        // Revert local state on failure
        _currentLanguage = "en";
        notifyListeners();
        return false;
      }

      return true;
    } on Exception catch (e) {
      debugPrint("LanguagePreferenceService: Error setting language: $e");
      // Revert local state on error
      _currentLanguage = "en";
      notifyListeners();
      return false;
    }
  }

  /// Get current language preference without triggering database call
  String getCurrentLanguage() {
    return _currentLanguage;
  }

  /// Check if a language is supported
  static bool isLanguageSupported(String languageCode) {
    return supportedLanguages.contains(languageCode);
  }

  /// Reset to default language
  Future<bool> resetToDefault() async {
    return setLanguage("en");
  }

  /// Set language without saving to database (for permission screen)
  void setLanguageForPermissionScreen(String languageCode) {
    if (supportedLanguages.contains(languageCode)) {
      _currentLanguage = languageCode;
      notifyListeners();
      debugPrint(
          "LanguagePreferenceService: Set language for permission screen: $languageCode");
    }
  }
}
