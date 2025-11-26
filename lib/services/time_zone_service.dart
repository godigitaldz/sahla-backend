import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/maps_config.dart';

/// Service for Google Time Zone API integration
class TimeZoneService {
  static const String _baseUrl = MapsConfig.timeZoneApiBaseUrl;
  static const String _apiKey = MapsConfig.googleMapsApiKey;

  /// Get time zone information for a location
  static Future<TimeZoneInfo?> getTimeZone({
    required LatLng location,
    DateTime? timestamp,
  }) async {
    try {
      final timestampMs =
          (timestamp ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;

      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'location': '${location.latitude},${location.longitude}',
        'timestamp': timestampMs.toString(),
        'key': _apiKey,
      });

      debugPrint(
          '🕐 Getting time zone for ${location.latitude}, ${location.longitude}');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          debugPrint('✅ Time zone information retrieved');
          return TimeZoneInfo.fromJson(data);
        } else {
          debugPrint('❌ Time Zone API error: ${data['status']}');
          return null;
        }
      } else {
        debugPrint('❌ HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error getting time zone: $e');
      return null;
    }
  }

  /// Get current time for a location
  static Future<DateTime?> getCurrentTime(LatLng location) async {
    try {
      final timeZoneInfo = await getTimeZone(location: location);

      if (timeZoneInfo != null) {
        final now = DateTime.now();
        final offsetSeconds = timeZoneInfo.rawOffset + timeZoneInfo.dstOffset;
        final localTime = now.add(Duration(seconds: offsetSeconds));

        debugPrint('🕐 Current time at location: $localTime');
        return localTime;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error getting current time: $e');
      return null;
    }
  }

  /// Get delivery time in restaurant's time zone
  static Future<DateTime?> getDeliveryTimeInRestaurantZone({
    required LatLng restaurantLocation,
    required LatLng customerLocation,
    required DateTime deliveryTime,
  }) async {
    try {
      // Get restaurant time zone
      final restaurantTimeZone =
          await getTimeZone(location: restaurantLocation);

      if (restaurantTimeZone != null) {
        // Convert delivery time to restaurant's time zone
        final offsetSeconds =
            restaurantTimeZone.rawOffset + restaurantTimeZone.dstOffset;
        final restaurantDeliveryTime =
            deliveryTime.add(Duration(seconds: offsetSeconds));

        debugPrint(
            '🕐 Delivery time in restaurant zone: $restaurantDeliveryTime');
        return restaurantDeliveryTime;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error getting delivery time in restaurant zone: $e');
      return null;
    }
  }

  /// Get time difference between two locations
  static Future<Duration?> getTimeDifference({
    required LatLng location1,
    required LatLng location2,
  }) async {
    try {
      final timeZone1 = await getTimeZone(location: location1);
      final timeZone2 = await getTimeZone(location: location2);

      if (timeZone1 != null && timeZone2 != null) {
        final offset1 = timeZone1.rawOffset + timeZone1.dstOffset;
        final offset2 = timeZone2.rawOffset + timeZone2.dstOffset;
        final difference = offset2 - offset1;

        debugPrint('🕐 Time difference: $difference seconds');
        return Duration(seconds: difference);
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error getting time difference: $e');
      return null;
    }
  }

  /// Check if location is in business hours
  static Future<bool> isInBusinessHours({
    required LatLng location,
    required int openHour,
    required int closeHour,
  }) async {
    try {
      final currentTime = await getCurrentTime(location);

      if (currentTime != null) {
        final hour = currentTime.hour;
        final isInHours = hour >= openHour && hour < closeHour;

        debugPrint(
            '🕐 Is in business hours ($openHour-$closeHour): $isInHours (current: $hour)');
        return isInHours;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error checking business hours: $e');
      return false;
    }
  }

  /// Get formatted time string for location
  static Future<String?> getFormattedTime({
    required LatLng location,
    DateTime? timestamp,
  }) async {
    try {
      final timeZoneInfo =
          await getTimeZone(location: location, timestamp: timestamp);

      if (timeZoneInfo != null) {
        final now = timestamp ?? DateTime.now();
        final offsetSeconds = timeZoneInfo.rawOffset + timeZoneInfo.dstOffset;
        final localTime = now.add(Duration(seconds: offsetSeconds));

        final formattedTime =
            '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
        debugPrint('🕐 Formatted time: $formattedTime');
        return formattedTime;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error getting formatted time: $e');
      return null;
    }
  }
}

/// Time zone information model
class TimeZoneInfo {
  final String status;
  final String timeZoneId;
  final String timeZoneName;
  final int rawOffset; // in seconds
  final int dstOffset; // in seconds

  const TimeZoneInfo({
    required this.status,
    required this.timeZoneId,
    required this.timeZoneName,
    required this.rawOffset,
    required this.dstOffset,
  });

  factory TimeZoneInfo.fromJson(Map<String, dynamic> json) {
    return TimeZoneInfo(
      status: json['status'] as String,
      timeZoneId: json['timeZoneId'] as String,
      timeZoneName: json['timeZoneName'] as String,
      rawOffset: json['rawOffset'] as int,
      dstOffset: json['dstOffset'] as int,
    );
  }

  bool get isAvailable => status == 'OK';

  /// Get total offset in seconds (raw + DST)
  int get totalOffset => rawOffset + dstOffset;

  /// Get total offset as Duration
  Duration get offsetDuration => Duration(seconds: totalOffset);

  /// Get time zone abbreviation
  String get abbreviation {
    // Extract abbreviation from timeZoneName (e.g., "Central European Time" -> "CET")
    final parts = timeZoneName.split(' ');
    if (parts.length >= 3) {
      return parts.map((part) => part[0]).join('');
    }
    return timeZoneId.split('/').last; // Fallback to last part of timeZoneId
  }

  @override
  String toString() {
    return 'TimeZoneInfo(id: $timeZoneId, name: $timeZoneName, offset: ${totalOffset}s)';
  }
}
