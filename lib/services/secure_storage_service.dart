// ignore_for_file: avoid_positional_boolean_parameters

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage service wrapper for FlutterSecureStorage
/// Uses app prefix for all keys to avoid conflicts
class SecureStorageService {
  static const String _appPrefix = 'sahla_app_';

  // Flutter Secure Storage instance
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    // iOS options for enhanced security
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
      synchronizable: false,
    ),
    // Android options for enhanced security
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  /// Get a string value from secure storage
  Future<String?> getString(String key) async {
    try {
      final prefixedKey = _getPrefixedKey(key);
      final value = await _storage.read(key: prefixedKey);

      if (kDebugMode) {
        debugPrint(
            '🔐 SecureStorage: Read "$prefixedKey" = "${_maskSensitiveData(value)}"');
      }

      return value;
    } catch (e) {
      debugPrint('❌ SecureStorage: Error reading key "$key": $e');
      return null;
    }
  }

  /// Set a string value in secure storage
  Future<void> setString(String key, String value) async {
    try {
      final prefixedKey = _getPrefixedKey(key);

      if (kDebugMode) {
        debugPrint(
            '🔐 SecureStorage: Writing "$prefixedKey" = "${_maskSensitiveData(value)}"');
      }

      await _storage.write(key: prefixedKey, value: value);
    } catch (e) {
      debugPrint('❌ SecureStorage: Error writing key "$key": $e');
      throw Exception('Failed to store secure data: $e');
    }
  }

  /// Get an int value from secure storage
  Future<int?> getInt(String key) async {
    try {
      final value = await getString(key);
      return value != null ? int.tryParse(value) : null;
    } catch (e) {
      debugPrint('❌ SecureStorage: Error reading int key "$key": $e');
      return null;
    }
  }

  /// Set an int value in secure storage
  Future<void> setInt(String key, int value) async {
    await setString(key, value.toString());
  }

  /// Get a bool value from secure storage
  Future<bool?> getBool(String key) async {
    try {
      final value = await getString(key);
      return value != null ? value.toLowerCase() == 'true' : null;
    } catch (e) {
      debugPrint('❌ SecureStorage: Error reading bool key "$key": $e');
      return null;
    }
  }

  /// Set a bool value in secure storage
  Future<void> setBool(String key, bool value) async {
    await setString(key, value.toString());
  }

  /// Delete a key from secure storage
  Future<void> delete(String key) async {
    try {
      final prefixedKey = _getPrefixedKey(key);

      if (kDebugMode) {
        debugPrint('🔐 SecureStorage: Deleting key "$prefixedKey"');
      }

      await _storage.delete(key: prefixedKey);
    } catch (e) {
      debugPrint('❌ SecureStorage: Error deleting key "$key": $e');
      // Don't throw - deletion failure shouldn't break the app
    }
  }

  /// Check if a key exists in secure storage
  Future<bool> containsKey(String key) async {
    try {
      final prefixedKey = _getPrefixedKey(key);
      final value = await _storage.read(key: prefixedKey);
      return value != null;
    } catch (e) {
      debugPrint('❌ SecureStorage: Error checking key "$key": $e');
      return false;
    }
  }

  /// Clear all secure storage data for this app
  Future<void> clear() async {
    try {
      if (kDebugMode) {
        debugPrint('🧹 SecureStorage: Clearing all app data');
      }

      // Note: FlutterSecureStorage doesn't have a clear all method for security reasons
      // We'll need to implement a different approach for clearing all app data

      // For now, we'll clear known keys individually
      // In a real implementation, you might want to maintain a list of all keys used
      await _clearKnownKeys();
    } catch (e) {
      debugPrint('❌ SecureStorage: Error clearing data: $e');
      throw Exception('Failed to clear secure storage: $e');
    }
  }

  /// Clear known keys used by the session manager
  Future<void> _clearKnownKeys() async {
    final knownKeys = [
      'user_id',
      'last_refresh_at',
      // Add other keys as needed
    ];

    for (final key in knownKeys) {
      try {
        await delete(key);
      } catch (e) {
        debugPrint('⚠️ SecureStorage: Failed to delete key "$key": $e');
      }
    }
  }

  /// Get the prefixed key for internal storage
  String _getPrefixedKey(String key) {
    return '$_appPrefix$key';
  }

  /// Mask sensitive data for logging
  String _maskSensitiveData(String? data) {
    if (data == null) return 'null';
    if (data.length <= 8) return '***';

    // Show first 4 and last 4 characters, mask the middle
    final start = data.substring(0, 4);
    final end = data.substring(data.length - 4);
    return '$start***$end';
  }

  /// Get all keys (for debugging purposes only)
  Future<List<String>> getAllKeys() async {
    try {
      // Note: FlutterSecureStorage doesn't provide a way to get all keys
      // This is a security feature - keys should be managed explicitly
      return [];
    } catch (e) {
      debugPrint('❌ SecureStorage: Error getting all keys: $e');
      return [];
    }
  }

  /// Check if secure storage is available (for testing)
  Future<bool> isAvailable() async {
    try {
      await setString('test_key', 'test_value');
      final value = await getString('test_key');
      await delete('test_key');

      return value == 'test_value';
    } catch (e) {
      debugPrint('❌ SecureStorage: Availability check failed: $e');
      return false;
    }
  }
}
