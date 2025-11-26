import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Utility class for JWT token operations without external dependencies
/// Safely decodes JWT tokens to extract expiry information
class TokenUtils {
  /// Get expiry timestamp from JWT access token
  /// Returns null if token is invalid or cannot be decoded
  static DateTime? getExpiryFromAccessToken(String accessToken) {
    try {
      final parts = accessToken.split('.');
      if (parts.length != 3) {
        debugPrint('⚠️ TokenUtils: Invalid JWT format - expected 3 parts');
        return null;
      }

      // Decode the payload (second part)
      final payload = _decodeBase64Url(parts[1]);
      if (payload == null) {
        debugPrint('⚠️ TokenUtils: Failed to decode JWT payload');
        return null;
      }

      final payloadMap = jsonDecode(payload) as Map<String, dynamic>;

      // Extract expiry timestamp (exp claim)
      final exp = payloadMap['exp'];
      if (exp == null) {
        debugPrint('⚠️ TokenUtils: No expiry claim found in token');
        return null;
      }

      // Convert Unix timestamp to DateTime
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    } catch (e) {
      debugPrint('❌ TokenUtils: Error parsing token expiry: $e');
      return null;
    }
  }

  /// Calculate seconds until token expiry
  /// Returns negative value if token is already expired
  static int secondsUntilExpiry(String accessToken) {
    try {
      final expiry = getExpiryFromAccessToken(accessToken);
      if (expiry == null) {
        debugPrint('⚠️ TokenUtils: Could not determine token expiry');
        return -1; // Consider as expired
      }

      final now = DateTime.now();
      final difference = expiry.difference(now);

      if (kDebugMode) {
        debugPrint(
            '🔍 TokenUtils: Token expires in ${difference.inSeconds} seconds');
      }

      return difference.inSeconds;
    } catch (e) {
      debugPrint('❌ TokenUtils: Error calculating seconds until expiry: $e');
      return -1; // Consider as expired
    }
  }

  /// Check if token is expired
  static bool isTokenExpired(String accessToken) {
    return secondsUntilExpiry(accessToken) <= 0;
  }

  /// Check if token will expire soon (within threshold seconds)
  static bool willExpireSoon(String accessToken, {int thresholdSeconds = 600}) {
    final secondsLeft = secondsUntilExpiry(accessToken);
    return secondsLeft > 0 && secondsLeft <= thresholdSeconds;
  }

  /// Safely decode base64url string
  static String? _decodeBase64Url(String encoded) {
    try {
      // Add padding if needed
      final padded = encoded.length % 4 != 0
          ? encoded + '=' * (4 - encoded.length % 4)
          : encoded;

      // Replace base64url chars with standard base64
      final standardBase64 = padded.replaceAll('-', '+').replaceAll('_', '/');

      return utf8.decode(base64Decode(standardBase64));
    } catch (e) {
      debugPrint('❌ TokenUtils: Failed to decode base64url: $e');
      return null;
    }
  }

  /// Extract user ID from JWT token (if available)
  static String? getUserIdFromToken(String accessToken) {
    try {
      final parts = accessToken.split('.');
      if (parts.length != 3) {
        return null;
      }

      final payload = _decodeBase64Url(parts[1]);
      if (payload == null) {
        return null;
      }

      final payloadMap = jsonDecode(payload) as Map<String, dynamic>;

      // Try common user ID claims
      return payloadMap['sub'] as String? ??
          payloadMap['user_id'] as String? ??
          payloadMap['uid'] as String?;
    } catch (e) {
      debugPrint('❌ TokenUtils: Error extracting user ID from token: $e');
      return null;
    }
  }

  /// Validate JWT token format (basic validation)
  static bool isValidTokenFormat(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return false;
      }

      // Check if all parts are valid base64url
      for (final part in parts) {
        if (part.isEmpty) {
          return false;
        }

        // Basic base64url character validation
        final validChars = RegExp(r'^[A-Za-z0-9_-]+$');
        if (!validChars.hasMatch(part)) {
          return false;
        }
      }

      // Try to decode payload to ensure it's valid JSON
      final payload = _decodeBase64Url(parts[1]);
      if (payload == null) {
        return false;
      }

      // Try to parse as JSON
      jsonDecode(payload);

      return true;
    } catch (e) {
      debugPrint('❌ TokenUtils: Token format validation failed: $e');
      return false;
    }
  }

  /// Get token information for debugging (without exposing sensitive data)
  static Map<String, dynamic> getTokenInfo(String accessToken) {
    try {
      final expiry = getExpiryFromAccessToken(accessToken);
      final userId = getUserIdFromToken(accessToken);

      return {
        'isValidFormat': isValidTokenFormat(accessToken),
        'isExpired': isTokenExpired(accessToken),
        'secondsUntilExpiry': secondsUntilExpiry(accessToken),
        'expiryDateTime': expiry?.toIso8601String(),
        'userId': userId,
        'tokenLength': accessToken.length,
      };
    } catch (e) {
      debugPrint('❌ TokenUtils: Error getting token info: $e');
      return {
        'error': e.toString(),
        'isValidFormat': false,
        'isExpired': true,
      };
    }
  }

  /// Mask token for logging (show first and last few characters only)
  static String maskToken(String token) {
    if (token.length <= 16) return '***';

    final start = token.substring(0, 8);
    final end = token.substring(token.length - 8);
    return '$start...$end';
  }
}

/// Example usage and testing
class TokenUtilsExamples {
  /// Example JWT token for testing (this is a fake token)
  static const String exampleToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjE2NzI1MzkwMjJ9.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';

  /// Test token expiry calculation
  static void testTokenExpiry() {
    if (kDebugMode) {
      debugPrint('🧪 TokenUtils: Testing token expiry calculation');

      final secondsUntilExpiry = TokenUtils.secondsUntilExpiry(exampleToken);
      final isExpired = TokenUtils.isTokenExpired(exampleToken);
      final willExpireSoon =
          TokenUtils.willExpireSoon(exampleToken, thresholdSeconds: 600);
      final tokenInfo = TokenUtils.getTokenInfo(exampleToken);

      debugPrint('🔍 Token expiry test results:');
      debugPrint('  - Seconds until expiry: $secondsUntilExpiry');
      debugPrint('  - Is expired: $isExpired');
      debugPrint('  - Will expire soon (10 min): $willExpireSoon');
      debugPrint('  - Token info: $tokenInfo');

      // Test with current timestamp
      final currentSeconds = TokenUtils.secondsUntilExpiry(exampleToken);
      debugPrint('🔍 Current token status: $currentSeconds seconds remaining');
    }
  }
}
