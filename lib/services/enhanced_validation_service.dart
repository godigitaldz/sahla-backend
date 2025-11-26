import 'dart:async';

import 'package:flutter/material.dart';

import '../services/form_analytics_service.dart';
import '../utils/input_sanitizer.dart';

enum ValidationStatus {
  none,
  valid,
  error,
}

class EnhancedValidationService {
  static final Map<String, Timer?> _validationTimers = {};
  static final Map<String, String?> _validationResults = {};

  /// Validate field with debouncing
  static void validateFieldDebounced({
    required String fieldName,
    required String value,
    required String? Function(String) validator,
    required Function(String?) onResult,
    Duration debounceDelay = const Duration(milliseconds: 500),
  }) {
    // Cancel existing timer for this field
    _validationTimers[fieldName]?.cancel();

    // Set new timer
    _validationTimers[fieldName] = Timer(debounceDelay, () {
      try {
        final result = validator(value);
        _validationResults[fieldName] = result;
        onResult(result);

        // Track validation result
        if (result != null) {
          FormAnalytics.trackValidationError(fieldName, 'validation_failed');
        } else {
          FormAnalytics.trackValidationError(fieldName, 'validation_passed');
        }
      } catch (e) {
        FormAnalytics.trackError(
            'validation_error', 'Error validating $fieldName: $e');
        onResult('Validation error occurred');
      }
    });
  }

  /// Get cached validation result
  static String? getValidationResult(String fieldName) {
    return _validationResults[fieldName];
  }

  /// Clear validation result for field
  static void clearValidationResult(String fieldName) {
    _validationResults.remove(fieldName);
    _validationTimers[fieldName]?.cancel();
    _validationTimers.remove(fieldName);
  }

  /// Clear all validation results
  static void clearAllValidationResults() {
    _validationResults.clear();
    for (final timer in _validationTimers.values) {
      timer?.cancel();
    }
    _validationTimers.clear();
  }

  /// Validate restaurant name with enhanced feedback
  static String? validateRestaurantName(String value) {
    if (value.isEmpty) {
      return 'Restaurant name is required';
    }

    if (!InputSanitizer.isValidRestaurantName(value)) {
      return 'Name must be 2-100 characters long';
    }

    // Check for suspicious patterns
    if (_containsSuspiciousPattern(value)) {
      return 'Name contains invalid characters';
    }

    return null;
  }

  /// Validate phone number with enhanced feedback
  static String? validatePhoneNumber(String value) {
    if (value.isEmpty) {
      return 'Phone number is required';
    }

    if (!InputSanitizer.isValidPhoneNumber(value)) {
      return 'Please enter a valid phone number (10-15 digits)';
    }

    return null;
  }

  /// Validate address with enhanced feedback
  static String? validateAddress(String value) {
    if (value.isEmpty) {
      return 'Address is required';
    }

    if (!InputSanitizer.isValidAddress(value)) {
      return 'Please enter a complete address (minimum 10 characters)';
    }

    return null;
  }

  /// Validate URL with enhanced feedback
  static String? validateUrl(String value, {bool required = false}) {
    if (value.isEmpty) {
      return required ? 'URL is required' : null;
    }

    if (!InputSanitizer.isValidUrl(value)) {
      return 'Please enter a valid URL (starting with http:// or https://)';
    }

    return null;
  }

  /// Validate working hours
  static String? validateWorkingHours(Map<String, dynamic> workingHours) {
    if (workingHours.isEmpty) {
      return 'Please configure working hours';
    }

    bool hasOpenDays = false;
    for (final dayData in workingHours.values) {
      if (dayData['isOpen'] == true || dayData['isOpen'] == 'true') {
        hasOpenDays = true;

        final openTime = dayData['open'];
        final closeTime = dayData['close'];

        if (openTime == null || closeTime == null) {
          return 'Please set opening and closing times for all open days';
        }

        // Check if open time is before close time
        if (!_isTimeBefore(openTime, closeTime)) {
          return 'Opening time must be before closing time';
        }
      }
    }

    if (!hasOpenDays) {
      return 'Please select at least one working day';
    }

    return null;
  }

  /// Validate coordinates
  static String? validateCoordinates(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) {
      return 'Location coordinates are required';
    }

    // Check Algeria bounds
    if (latitude < 18.0 ||
        latitude > 38.0 ||
        longitude < -9.0 ||
        longitude > 12.0) {
      return 'Please select a location within Algeria';
    }

    return null;
  }

  /// Validate form completeness
  static Map<String, dynamic> validateFormCompleteness(
      Map<String, dynamic> formData) {
    final errors = <String, String>{};
    final warnings = <String, String>{};

    // Required fields
    final requiredFields = {
      'restaurantName': 'Restaurant name',
      'phone': 'Phone number',
      'address': 'Address',
      'wilaya': 'Wilaya',
      'workingHours': 'Working hours',
      'latitude': 'Location',
      'longitude': 'Location',
    };

    for (final entry in requiredFields.entries) {
      final field = entry.key;
      final label = entry.value;

      if (formData[field] == null || formData[field].toString().isEmpty) {
        errors[field] = '$label is required';
      }
    }

    // Optional fields warnings
    if (formData['description'] == null ||
        formData['description'].toString().isEmpty) {
      warnings['description'] =
          'Adding a description helps customers understand your business';
    }

    if (formData['logoUrl'] == null || formData['logoUrl'].toString().isEmpty) {
      warnings['logoUrl'] = 'A logo helps customers recognize your business';
    }

    return {
      'errors': errors,
      'warnings': warnings,
      'isComplete': errors.isEmpty,
      'completionPercentage': _calculateCompletionPercentage(formData),
    };
  }

  /// Get validation status for a field (for UI components to use)
  static ValidationStatus getValidationStatus(String fieldName) {
    final validationResult = getValidationResult(fieldName);

    if (validationResult == null) {
      return ValidationStatus.none;
    }

    return validationResult.isEmpty
        ? ValidationStatus.valid
        : ValidationStatus.error;
  }

  /// Check for suspicious patterns
  static bool _containsSuspiciousPattern(String input) {
    final suspiciousPatterns = [
      RegExp('<script', caseSensitive: false),
      RegExp('javascript:', caseSensitive: false),
      RegExp('data:', caseSensitive: false),
      RegExp('vbscript:', caseSensitive: false),
    ];

    for (final pattern in suspiciousPatterns) {
      if (pattern.hasMatch(input)) {
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

  /// Parse time string
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

  /// Calculate completion percentage
  static double _calculateCompletionPercentage(Map<String, dynamic> formData) {
    int completedFields = 0;
    int totalFields = 0;

    // Required fields
    final requiredFields = [
      'restaurantName',
      'address',
      'phone',
      'wilaya',
      'workingHours',
      'latitude',
      'longitude',
    ];

    totalFields += requiredFields.length;

    for (final field in requiredFields) {
      if (formData[field] != null && formData[field].toString().isNotEmpty) {
        completedFields++;
      }
    }

    // Optional fields
    final optionalFields = [
      'description',
      'logoUrl',
      'facebook',
      'instagram',
      'tiktok',
    ];

    totalFields += optionalFields.length;

    for (final field in optionalFields) {
      if (formData[field] != null && formData[field].toString().isNotEmpty) {
        completedFields++;
      }
    }

    return totalFields > 0 ? (completedFields / totalFields) * 100 : 0;
  }
}
