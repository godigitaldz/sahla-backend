import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/input_sanitizer.dart';

class SecurityService {
  static const List<String> _blockedPatterns = [
    'javascript:',
    'data:',
    'vbscript:',
    '<script',
    '</script>',
    'onload=',
    'onerror=',
    'onclick=',
    'onmouseover=',
    'eval(',
    'expression(',
  ];

  static const List<String> _suspiciousPatterns = [
    'admin',
    'root',
    'password',
    'login',
    'sql',
    'union',
    'select',
    'drop',
    'delete',
    'insert',
    'update',
  ];

  /// Validate admin access
  static Future<bool> verifyAdminAccess(
      String userId, List<String> userRoles) async {
    try {
      // Check if user has admin role
      if (!userRoles.contains('admin')) {
        _logSecurityEvent('unauthorized_admin_access',
            'User $userId attempted admin access without proper role');
        return false;
      }

      // Additional security checks could be added here
      // - Check user permissions in database
      // - Verify session validity
      // - Check IP whitelist

      return true;
    } catch (e) {
      _logSecurityEvent(
          'admin_access_error', 'Error verifying admin access: $e');
      return false;
    }
  }

  /// Sanitize and validate form input
  static Map<String, dynamic> sanitizeFormData(Map<String, dynamic> formData) {
    final sanitizedData = <String, dynamic>{};

    for (final entry in formData.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is String) {
        // Sanitize text input
        sanitizedData[key] = InputSanitizer.sanitizeText(value);

        // Check for suspicious patterns
        if (_containsSuspiciousPattern(value)) {
          _logSecurityEvent('suspicious_input',
              'Suspicious input detected in field $key: $value');
        }
      } else if (value is Map) {
        // Recursively sanitize nested maps
        sanitizedData[key] = sanitizeFormData(Map<String, dynamic>.from(value));
      } else {
        sanitizedData[key] = value;
      }
    }

    return sanitizedData;
  }

  /// Validate file upload security
  static Future<bool> validateFileUpload(File file, String fileName) async {
    try {
      // Check file extension
      final extension = fileName.split('.').last.toLowerCase();
      if (!InputSanitizer.isValidImageFile(file)) {
        _logSecurityEvent(
            'invalid_file_type', 'Invalid file type attempted: $extension');
        return false;
      }

      // Check file size
      if (!InputSanitizer.isValidFileSize(file, 5 * 1024 * 1024)) {
        // 5MB
        _logSecurityEvent(
            'file_too_large', 'File too large: ${file.lengthSync()} bytes');
        return false;
      }

      // Check for suspicious file names
      if (_containsSuspiciousPattern(fileName)) {
        _logSecurityEvent(
            'suspicious_filename', 'Suspicious filename detected: $fileName');
        return false;
      }

      // Additional file validation could be added here
      // - Check file headers/magic numbers
      // - Scan for malware
      // - Validate image metadata

      return true;
    } catch (e) {
      _logSecurityEvent('file_validation_error', 'Error validating file: $e');
      return false;
    }
  }

  /// Validate location coordinates
  static bool validateLocationCoordinates(double latitude, double longitude) {
    // Algeria bounds: lat 18.0-38.0, lng -9.0-12.0
    const double minLat = 18.0;
    const double maxLat = 38.0;
    const double minLng = -9.0;
    const double maxLng = 12.0;

    final isValid = latitude >= minLat &&
        latitude <= maxLat &&
        longitude >= minLng &&
        longitude <= maxLng;

    if (!isValid) {
      _logSecurityEvent('invalid_coordinates',
          'Coordinates outside Algeria bounds: $latitude, $longitude');
    }

    return isValid;
  }

  /// Rate limiting for form submissions
  static final Map<String, List<DateTime>> _submissionAttempts = {};

  static bool checkRateLimit(String userId,
      {int maxAttempts = 5, Duration window = const Duration(minutes: 15)}) {
    final now = DateTime.now();
    final attempts = _submissionAttempts[userId] ?? [];

    // Remove old attempts outside the window
    attempts.removeWhere((attempt) => now.difference(attempt) > window);

    if (attempts.length >= maxAttempts) {
      _logSecurityEvent(
          'rate_limit_exceeded', 'Rate limit exceeded for user $userId');
      return false;
    }

    // Add current attempt
    attempts.add(now);
    _submissionAttempts[userId] = attempts;

    return true;
  }

  /// Validate working hours for conflicts
  static bool validateWorkingHours(Map<String, dynamic> workingHours) {
    try {
      for (final dayEntry in workingHours.entries) {
        final day = dayEntry.key;
        final dayData = dayEntry.value as Map<String, dynamic>;

        if (dayData['isOpen'] == true) {
          final openTime = dayData['open'] as String?;
          final closeTime = dayData['close'] as String?;

          if (openTime == null || closeTime == null) {
            _logSecurityEvent(
                'invalid_working_hours', 'Missing open/close times for $day');
            return false;
          }

          // Check if open time is before close time
          if (!_isTimeBefore(openTime, closeTime)) {
            _logSecurityEvent(
                'invalid_working_hours', 'Open time after close time for $day');
            return false;
          }
        }
      }

      return true;
    } catch (e) {
      _logSecurityEvent('working_hours_validation_error',
          'Error validating working hours: $e');
      return false;
    }
  }

  /// Check for suspicious patterns in input
  static bool _containsSuspiciousPattern(String input) {
    final lowerInput = input.toLowerCase();

    // Check for blocked patterns
    for (final pattern in _blockedPatterns) {
      if (lowerInput.contains(pattern.toLowerCase())) {
        return true;
      }
    }

    // Check for suspicious patterns (case-insensitive)
    for (final pattern in _suspiciousPatterns) {
      if (lowerInput.contains(pattern)) {
        return true;
      }
    }

    return false;
  }

  /// Check if time1 is before time2
  static bool _isTimeBefore(String time1, String time2) {
    try {
      final t1 = _parseTime(time1);
      final t2 = _parseTime(time2);

      if (t1 == null || t2 == null) return false;

      final minutes1 = t1.hour * 60 + t1.minute;
      final minutes2 = t2.hour * 60 + t2.minute;

      return minutes1 < minutes2;
    } catch (e) {
      return false;
    }
  }

  /// Parse time string to TimeOfDay
  static TimeOfDay? _parseTime(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      // Error parsing time
    }
    return null;
  }

  /// Log security events
  static void _logSecurityEvent(String eventType, String description) {
    // In a real implementation, this would send to a security monitoring service
    debugPrint('🔒 Security Event: $eventType - $description');

    // Example integrations:
    // - Send to Firebase Crashlytics
    // - Send to security monitoring service
    // - Store in audit log database
    // - Send alerts to security team
  }

  /// Generate secure file name
  static String generateSecureFileName(String originalName, String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = originalName.split('.').last.toLowerCase();

    // Generate secure filename with user ID and timestamp
    return '${userId}_$timestamp.$extension';
  }

  /// Validate session security
  static bool validateSession(String sessionId, DateTime lastActivity) {
    const maxInactivityDuration = Duration(hours: 2);
    final now = DateTime.now();

    if (now.difference(lastActivity) > maxInactivityDuration) {
      _logSecurityEvent('session_expired', 'Session expired: $sessionId');
      return false;
    }

    return true;
  }

  /// Check for potential SQL injection
  static bool containsSQLInjection(String input) {
    final sqlPatterns = [
      'union select',
      'drop table',
      'delete from',
      'insert into',
      'update set',
      'or 1=1',
      'and 1=1',
      '--',
      '/*',
      '*/',
    ];

    final lowerInput = input.toLowerCase();
    for (final pattern in sqlPatterns) {
      if (lowerInput.contains(pattern)) {
        _logSecurityEvent('sql_injection_attempt',
            'Potential SQL injection detected: $input');
        return true;
      }
    }

    return false;
  }

  /// Validate API request security
  static bool validateAPIRequest(
      Map<String, String> headers, String requestBody) {
    try {
      // Check for required headers
      if (!headers.containsKey('content-type')) {
        _logSecurityEvent(
            'missing_content_type', 'Missing content-type header');
        return false;
      }

      // Check for suspicious request body
      if (containsSQLInjection(requestBody)) {
        return false;
      }

      // Additional API security checks could be added here
      // - Validate API key
      // - Check request signature
      // - Validate request size limits

      return true;
    } catch (e) {
      _logSecurityEvent(
          'api_validation_error', 'Error validating API request: $e');
      return false;
    }
  }
}
