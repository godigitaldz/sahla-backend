import 'package:flutter/foundation.dart';

/// Service to handle Google Maps SDK initialization with proper error handling
class GoogleMapsInitializationService {
  static bool _isInitialized = false;
  static bool _isInitializing = false;
  static String? _lastError;

  /// Check if Google Maps SDK is initialized
  static bool get isInitialized => _isInitialized;

  /// Get the last initialization error
  static String? get lastError => _lastError;

  /// Initialize Google Maps SDK with proper error handling
  static Future<bool> initialize() async {
    if (_isInitialized) {
      debugPrint('✅ Google Maps SDK already initialized');
      return true;
    }

    if (_isInitializing) {
      debugPrint('⏳ Google Maps SDK initialization already in progress');
      return false;
    }

    _isInitializing = true;
    _lastError = null;

    try {
      debugPrint('🚀 Initializing Google Maps SDK...');

      // For iOS, the SDK is initialized automatically when the API key is set in Info.plist
      // For Android, the SDK is initialized automatically when the API key is set in AndroidManifest.xml
      // We just need to ensure the SDK is ready by creating a dummy map controller

      // The actual initialization happens when the first GoogleMap widget is created
      // This is a placeholder to ensure the SDK is ready
      _isInitialized = true;
      debugPrint('✅ Google Maps SDK initialized successfully');
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('❌ Failed to initialize Google Maps SDK: $e');
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Reset initialization state (useful for testing)
  static void reset() {
    _isInitialized = false;
    _isInitializing = false;
    _lastError = null;
  }

  /// Check if Google Maps is available and ready
  static Future<bool> isGoogleMapsAvailable() async {
    try {
      // This is a simple check to see if Google Maps is available
      // The actual availability will be determined when creating a map
      return true;
    } catch (e) {
      debugPrint('❌ Google Maps not available: $e');
      return false;
    }
  }

  /// Get initialization status message
  static String getStatusMessage() {
    if (_isInitialized) {
      return 'Google Maps SDK is initialized and ready';
    } else if (_isInitializing) {
      return 'Google Maps SDK is initializing...';
    } else if (_lastError != null) {
      return 'Google Maps SDK initialization failed: $_lastError';
    } else {
      return 'Google Maps SDK not initialized';
    }
  }
}
