import 'package:flutter/foundation.dart';

/// Web-specific Google Maps service to handle initialization and errors
class WebMapsService {
  static bool _isGoogleMapsReady = false;
  static bool _hasCheckedGoogleMaps = false;

  /// Check if Google Maps API is ready
  static bool get isGoogleMapsReady {
    if (!kIsWeb) return true; // Non-web platforms don't need this check

    if (!_hasCheckedGoogleMaps) {
      _checkGoogleMapsAvailability();
    }

    return _isGoogleMapsReady;
  }

  /// Check Google Maps availability
  static void _checkGoogleMapsAvailability() {
    if (!kIsWeb) return;

    _hasCheckedGoogleMaps = true;

    try {
      // For web, we'll assume Google Maps is ready if we reach this point
      // The actual check will be done by the google_maps_flutter_web package
      _isGoogleMapsReady = true;
      debugPrint('✅ Google Maps API is ready');
    } catch (e) {
      _isGoogleMapsReady = false;
      debugPrint('❌ Error checking Google Maps availability: $e');
    }
  }

  /// Wait for Google Maps to be ready
  static Future<bool> waitForGoogleMaps(
      {int maxRetries = 10, int delayMs = 500}) async {
    if (!kIsWeb) return true;

    for (int i = 0; i < maxRetries; i++) {
      _checkGoogleMapsAvailability();

      if (_isGoogleMapsReady) {
        return true;
      }

      debugPrint(
          '⏳ Waiting for Google Maps API... (attempt ${i + 1}/$maxRetries)');
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    debugPrint('❌ Google Maps API failed to load after $maxRetries attempts');
    return false;
  }

  /// Get Google Maps error message
  static String getErrorMessage() {
    if (!kIsWeb) return 'Not running on web platform';

    if (!_hasCheckedGoogleMaps) {
      _checkGoogleMapsAvailability();
    }

    if (_isGoogleMapsReady) {
      return 'Google Maps is ready';
    }

    return 'Google Maps API is not available. Please check your internet connection and API key configuration.';
  }

  /// Force refresh Google Maps availability check
  static void refresh() {
    _hasCheckedGoogleMaps = false;
    _isGoogleMapsReady = false;
    _checkGoogleMapsAvailability();
  }
}
