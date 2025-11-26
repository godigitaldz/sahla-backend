// ignore_for_file: avoid_positional_boolean_parameters

import 'package:flutter/foundation.dart';

/// Utility class for safely handling user preferences
class PreferencesUtils {
  /// Get a preference value with a safe fallback
  static T? getPreference<T>(
      Map<String, dynamic>? preferences, String key, T? defaultValue) {
    debugPrint(
        '⚙️ PreferencesUtils.getPreference() called for key: $key, type: $T');
    if (preferences == null) {
      debugPrint(
          '⚠️ Preferences is null, using default for $key: $defaultValue');
      return defaultValue;
    }

    final value = preferences[key];
    if (value == null) {
      debugPrint('⚠️ Preference $key not found, using default: $defaultValue');
      return defaultValue;
    }

    try {
      // Type-safe conversion
      if (T == String && value is String) return value as T;
      if (T == bool && value is bool) return value as T;
      if (T == int && value is int) return value as T;
      if (T == double && value is double) return value as T;
      if (T == DateTime && value is String) return DateTime.parse(value) as T;

      debugPrint(
          '⚠️ Type mismatch for preference $key: expected $T, got ${value.runtimeType}');
      return defaultValue;
    } catch (e) {
      debugPrint('❌ Error parsing preference $key: $e');
      return defaultValue;
    }
  }

  /// Get a string preference with fallback
  static String getStringPreference(
      Map<String, dynamic>? preferences, String key, String defaultValue) {
    return getPreference<String>(preferences, key, defaultValue) ??
        defaultValue;
  }

  /// Get a boolean preference with fallback
  static bool getBoolPreference(
      Map<String, dynamic>? preferences, String key, bool defaultValue) {
    return getPreference<bool>(preferences, key, defaultValue) ?? defaultValue;
  }

  /// Get a DateTime preference with fallback
  static DateTime? getDateTimePreference(
      Map<String, dynamic>? preferences, String key) {
    return getPreference<DateTime>(preferences, key, null);
  }

  /// Create default preferences map
  static Map<String, dynamic> getDefaultPreferences() {
    return {
      'email_notifications': true,
      'sms_notifications': false,
      'push_notifications': true,
      'language': 'English',
      'currency': 'DZD',
      'date_of_birth': null,
    };
  }

  /// Merge user preferences with defaults
  static Map<String, dynamic> mergeWithDefaults(
      Map<String, dynamic>? userPreferences) {
    debugPrint(
        '🔄 PreferencesUtils.mergeWithDefaults() called with ${userPreferences?.length ?? 0} user preferences');
    final defaults = getDefaultPreferences();
    if (userPreferences == null) return defaults;

    final merged = Map<String, dynamic>.from(defaults)..addAll(userPreferences);
    debugPrint(
        '✅ PreferencesUtils.mergeWithDefaults() completed - merged ${merged.length} preferences');
    return merged;
  }

  /// Check if preferences are valid
  static bool isValidPreferences(Map<String, dynamic>? preferences) {
    debugPrint('🔍 PreferencesUtils.isValidPreferences() called');
    if (preferences == null) {
      debugPrint(
          '❌ PreferencesUtils.isValidPreferences() - preferences is null');
      return false;
    }

    // Check if it's a valid JSON-like structure
    try {
      // Basic validation - preferences is already typed as Map<String, dynamic>

      // Check for required keys (optional)
      final requiredKeys = ['email_notifications', 'language', 'currency'];
      for (final key in requiredKeys) {
        if (!preferences.containsKey(key)) {
          debugPrint('⚠️ Missing required preference key: $key');
          return false;
        }
      }

      debugPrint(
          '✅ PreferencesUtils.isValidPreferences() - preferences are valid');
      return true;
    } catch (e) {
      debugPrint('❌ Error validating preferences: $e');
      return false;
    }
  }
}
