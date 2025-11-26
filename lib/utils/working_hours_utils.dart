import 'package:flutter/material.dart';

class WorkingHoursUtils {
  // Performance optimization: Cache parsed times to avoid repeated parsing
  static final Map<String, TimeOfDay> _timeCache = {};
  static final Map<String, Map<String, dynamic>> _parsedHoursCache = {};

  // Performance optimization: Cache current day name
  static String? _cachedTodayName;
  static DateTime? _lastCacheUpdate;

  /// Parse working hours from JSON string or Map with performance optimization
  static Map<String, dynamic>? parseWorkingHours(dynamic workingHours) {
    if (workingHours == null) {
      return null;
    }

    // Performance optimization: Check cache first
    final cacheKey = workingHours.toString();
    if (_parsedHoursCache.containsKey(cacheKey)) {
      return _parsedHoursCache[cacheKey];
    }

    Map<String, dynamic>? result;

    if (workingHours is String) {
      try {
        // Try to parse as JSON string
        // For now, we'll return null and let the calling code handle it
        // In a real implementation, you'd use dart:convert to parse JSON
        result = null;
      } catch (e) {
        result = null;
      }
    } else if (workingHours is Map<String, dynamic>) {
      result = workingHours;
    } else {
      result = null;
    }

    // Cache the result for performance
    if (result != null) {
      _parsedHoursCache[cacheKey] = result;
    }

    return result;
  }

  /// Get today's working hours with performance optimization
  static Map<String, dynamic>? getTodayHours(
      Map<String, dynamic>? workingHours) {
    if (workingHours == null) {
      return null;
    }

    final today = _getTodayName();
    final result = workingHours[today];

    return result;
  }

  /// Check if restaurant is currently open with performance optimization
  static bool isCurrentlyOpen(Map<String, dynamic>? workingHours) {
    if (workingHours == null) {
      return false;
    }

    final todayHours = getTodayHours(workingHours);
    if (todayHours == null) {
      return false;
    }

    final isOpen = todayHours['isOpen'] as bool? ?? false;

    if (!isOpen) {
      return false;
    }

    final openTime = todayHours['open'] as String?;
    final closeTime = todayHours['close'] as String?;

    if (openTime == null || closeTime == null) {
      return false;
    }

    final currentTime = TimeOfDay.now();
    final result = _isTimeInRange(openTime, closeTime, currentTime);

    return result;
  }

  /// Get current status text with performance optimization (e.g., "Open • 09:00 - 22:00" or "Closed • Opens at 09:00")
  static String getStatusText(Map<String, dynamic>? workingHours) {
    if (workingHours == null) {
      return 'Hours not available';
    }

    final todayHours = getTodayHours(workingHours);
    if (todayHours == null) {
      return 'Hours not available';
    }

    final isOpen = todayHours['isOpen'] as bool? ?? false;
    final openTime = todayHours['open'] as String?;
    final closeTime = todayHours['close'] as String?;

    if (!isOpen) {
      // Find next open time
      final nextOpenTime = _getNextOpenTime(workingHours);
      if (nextOpenTime != null) {
        return 'Closed • Opens at $nextOpenTime';
      }
      return 'Closed';
    }

    if (openTime != null && closeTime != null) {
      final currentTime = TimeOfDay.now();
      final isCurrentlyOpen = _isTimeInRange(openTime, closeTime, currentTime);

      if (isCurrentlyOpen) {
        return 'Open • $openTime - $closeTime';
      } else {
        return 'Closed • $openTime - $closeTime';
      }
    }

    return 'Hours not available';
  }

  /// Get next opening time
  static String? _getNextOpenTime(Map<String, dynamic> workingHours) {
    final days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];
    final currentDayIndex =
        DateTime.now().weekday - 1; // Convert to 0-based index

    // Check today first (in case it opens later today)
    final today = days[currentDayIndex];
    if (workingHours.containsKey(today)) {
      final dayHours = workingHours[today];
      if (dayHours is Map && dayHours.containsKey('open')) {
        final openTime = dayHours['open'] as String?;
        if (openTime != null) {
          final current = TimeOfDay.now();
          final open = _parseTime(openTime);
          if (open != null) {
            final currentMinutes = current.hour * 60 + current.minute;
            final openMinutes = open.hour * 60 + open.minute;

            // If it opens later today
            if (currentMinutes < openMinutes) {
              return openTime;
            }
          }
        }
      }
    }

    // Check next 7 days for next opening time
    for (int i = 1; i <= 7; i++) {
      final nextDayIndex = (currentDayIndex + i) % 7;
      final nextDay = days[nextDayIndex];

      if (workingHours.containsKey(nextDay)) {
        final dayHours = workingHours[nextDay];
        if (dayHours is Map && dayHours.containsKey('open')) {
          final openTime = dayHours['open'] as String?;
          if (openTime != null) {
            return openTime;
          }
        }
      }
    }

    return null;
  }

  /// Check if current time is within the given range
  static bool _isTimeInRange(
      String openTime, String closeTime, TimeOfDay currentTime) {
    try {
      final open = _parseTime(openTime);
      final close = _parseTime(closeTime);

      if (open == null || close == null) return false;

      final current = currentTime.hour * 60 + currentTime.minute;
      final openMinutes = open.hour * 60 + open.minute;
      final closeMinutes = close.hour * 60 + close.minute;

      // Handle case where close time is next day (e.g., 23:00 - 02:00)
      if (closeMinutes < openMinutes) {
        return current >= openMinutes || current < closeMinutes;
      } else {
        return current >= openMinutes && current < closeMinutes;
      }
    } catch (e) {
      return false;
    }
  }

  /// Parse time string to TimeOfDay with performance optimization and caching
  static TimeOfDay? _parseTime(String timeString) {
    // Performance optimization: Check cache first
    if (_timeCache.containsKey(timeString)) {
      return _timeCache[timeString];
    }

    try {
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final result = TimeOfDay(hour: hour, minute: minute);

        // Cache the result for performance
        _timeCache[timeString] = result;
        return result;
      }
    } catch (e) {
      // Silent error handling
    }

    return null;
  }

  /// Get today's day name in lowercase with performance optimization and caching
  static String _getTodayName() {
    final now = DateTime.now();

    // Performance optimization: Cache today's name and only update when day changes
    if (_cachedTodayName != null && _lastCacheUpdate != null) {
      final daysSinceUpdate = now.difference(_lastCacheUpdate!).inDays;
      if (daysSinceUpdate == 0) {
        return _cachedTodayName!;
      }
    }

    final weekday = now.weekday;
    String result;

    switch (weekday) {
      case DateTime.monday:
        result = 'monday';
        break;
      case DateTime.tuesday:
        result = 'tuesday';
        break;
      case DateTime.wednesday:
        result = 'wednesday';
        break;
      case DateTime.thursday:
        result = 'thursday';
        break;
      case DateTime.friday:
        result = 'friday';
        break;
      case DateTime.saturday:
        result = 'saturday';
        break;
      case DateTime.sunday:
        result = 'sunday';
        break;
      default:
        result = 'monday';
    }

    // Cache the result
    _cachedTodayName = result;
    _lastCacheUpdate = now;

    return result;
  }

  /// Format working hours for display with performance optimization
  static String formatWorkingHours(Map<String, dynamic>? workingHours) {
    if (workingHours == null) {
      return 'Hours not available';
    }

    final days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final List<String> formattedDays = [];

    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      final dayName = dayNames[i];

      if (workingHours.containsKey(day)) {
        final dayHours = workingHours[day];
        if (dayHours is Map) {
          final isOpen = dayHours['isOpen'] as bool? ?? false;
          final openTime = dayHours['open'] as String?;
          final closeTime = dayHours['close'] as String?;

          if (isOpen && openTime != null && closeTime != null) {
            formattedDays.add('$dayName: $openTime - $closeTime');
          } else {
            formattedDays.add('$dayName: Closed');
          }
        }
      }
    }

    return formattedDays.join('\n');
  }

  /// Clear all caches for memory management (useful for testing or memory cleanup)
  static void clearCache() {
    _timeCache.clear();
    _parsedHoursCache.clear();
    _cachedTodayName = null;
    _lastCacheUpdate = null;
  }

  /// Get cache statistics for performance monitoring
  static Map<String, int> getCacheStats() {
    return {
      'timeCache': _timeCache.length,
      'parsedHoursCache': _parsedHoursCache.length,
      'hasCachedTodayName': _cachedTodayName != null ? 1 : 0,
    };
  }
}
