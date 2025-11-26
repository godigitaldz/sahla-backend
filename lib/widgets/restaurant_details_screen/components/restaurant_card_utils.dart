import "package:flutter/material.dart";

import "../../../utils/working_hours_utils.dart";

/// Utility functions for restaurant card operations
///
/// Contains:
/// - Working hours checking (open/closed status)
/// - Opening/closing time calculations
/// - Time parsing and formatting
class RestaurantCardUtils {
  /// Check if restaurant is currently open based on working hours
  static bool isRestaurantOpen({
    required bool fallbackIsOpen,
    required dynamic openingHours,
  }) {
    // Use WorkingHoursUtils for accurate real-time status
    if (openingHours != null && openingHours is Map<String, dynamic>) {
      return WorkingHoursUtils.isCurrentlyOpen(openingHours);
    }
    // Fallback to database field if working hours not available
    return fallbackIsOpen;
  }

  /// Get opening time text for closed restaurants
  static String? getOpeningTime(dynamic openingHours) {
    if (openingHours == null) {
      return null;
    }

    try {
      final workingHours = openingHours;
      if (workingHours is! Map<String, dynamic>) {
        return null;
      }

      const days = [
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

      // Get today's hours first to check if it opens later today
      final todayHours = WorkingHoursUtils.getTodayHours(workingHours);
      if (todayHours != null) {
        final isOpen = todayHours['isOpen'] as bool? ?? false;
        final openTime = todayHours['open'] as String?;

        // If restaurant is marked as open for today, check if it opens later
        if (isOpen && openTime != null) {
          final currentTime = TimeOfDay.now();
          final open = parseTime(openTime);

          if (open != null) {
            final currentMinutes = currentTime.hour * 60 + currentTime.minute;
            final openMinutes = open.hour * 60 + open.minute;

            // If it opens later today, show today's opening time
            if (currentMinutes < openMinutes) {
              return openTime;
            }
          }
        }
      }

      // Restaurant is closed now, find next opening day
      // Check next 7 days for next opening time
      for (int i = 1; i <= 7; i++) {
        final nextDayIndex = (currentDayIndex + i) % 7;
        final nextDay = days[nextDayIndex];

        if (workingHours.containsKey(nextDay)) {
          final dayHours = workingHours[nextDay];
          if (dayHours is Map) {
            final isOpen = dayHours['isOpen'] as bool? ?? false;
            final openTime = dayHours['open'] as String?;

            if (isOpen && openTime != null) {
              return openTime;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting opening time: $e');
    }

    return null;
  }

  /// Get closing time for currently open restaurants
  static String? getClosingTime(dynamic openingHours) {
    if (openingHours == null) {
      return null;
    }

    try {
      final workingHours = openingHours;
      if (workingHours is! Map<String, dynamic>) {
        return null;
      }

      // Get today's hours
      final todayHours = WorkingHoursUtils.getTodayHours(workingHours);
      if (todayHours != null) {
        final isOpen = todayHours['isOpen'] as bool? ?? false;
        final closeTime = todayHours['close'] as String?;

        // Return closing time if available and marked as open
        if (isOpen && closeTime != null) {
          return closeTime;
        }
      }
    } catch (e) {
      debugPrint('Error getting closing time: $e');
    }

    return null;
  }

  /// Parse time string to TimeOfDay
  static TimeOfDay? parseTime(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      // Silent error handling
    }
    return null;
  }
}
