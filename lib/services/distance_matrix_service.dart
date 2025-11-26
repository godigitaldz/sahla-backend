import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/maps_config.dart';

/// Service for Google Distance Matrix API integration
class DistanceMatrixService {
  static const String _baseUrl = MapsConfig.distanceMatrixApiBaseUrl;
  static const String _apiKey = MapsConfig.googleMapsApiKey;

  /// Get distance and duration between multiple origins and destinations
  static Future<DistanceMatrixResult?> getDistanceMatrix({
    required List<LatLng> origins,
    required List<LatLng> destinations,
    String mode = 'driving',
    String units = 'metric',
    String language = 'en',
  }) async {
    try {
      // Convert LatLng to string format
      final originsStr = origins
          .map((latLng) => '${latLng.latitude},${latLng.longitude}')
          .join('|');
      final destinationsStr = destinations
          .map((latLng) => '${latLng.latitude},${latLng.longitude}')
          .join('|');

      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'origins': originsStr,
        'destinations': destinationsStr,
        'mode': mode,
        'units': units,
        'language': language,
        'key': _apiKey,
      });

      debugPrint(
          '📏 Getting distance matrix for ${origins.length} origins to ${destinations.length} destinations');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          debugPrint('✅ Distance matrix retrieved successfully');
          return DistanceMatrixResult.fromJson(data);
        } else {
          debugPrint('❌ Distance Matrix API error: ${data['status']}');
          return null;
        }
      } else {
        debugPrint('❌ HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error getting distance matrix: $e');
      return null;
    }
  }

  /// Get delivery time estimate from restaurant to customer
  static Future<DeliveryEstimate?> getDeliveryEstimate({
    required LatLng restaurantLocation,
    required LatLng customerLocation,
    String mode = 'driving',
  }) async {
    try {
      final result = await getDistanceMatrix(
        origins: [restaurantLocation],
        destinations: [customerLocation],
        mode: mode,
      );

      if (result != null &&
          result.rows.isNotEmpty &&
          result.rows.first.elements.isNotEmpty) {
        final element = result.rows.first.elements.first;

        if (element.status == 'OK') {
          return DeliveryEstimate(
            distance: element.distance,
            duration: element.duration,
            distanceText: element.distanceText,
            durationText: element.durationText,
          );
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error getting delivery estimate: $e');
      return null;
    }
  }

  /// Get multiple delivery estimates for route optimization
  static Future<List<DeliveryEstimate>?> getMultipleDeliveryEstimates({
    required LatLng restaurantLocation,
    required List<LatLng> customerLocations,
    String mode = 'driving',
  }) async {
    try {
      final result = await getDistanceMatrix(
        origins: [restaurantLocation],
        destinations: customerLocations,
        mode: mode,
      );

      if (result != null && result.rows.isNotEmpty) {
        final estimates = <DeliveryEstimate>[];
        final elements = result.rows.first.elements;

        for (int i = 0; i < elements.length; i++) {
          final element = elements[i];

          if (element.status == 'OK') {
            estimates.add(DeliveryEstimate(
              distance: element.distance,
              duration: element.duration,
              distanceText: element.distanceText,
              durationText: element.durationText,
              customerIndex: i,
            ));
          }
        }

        return estimates;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error getting multiple delivery estimates: $e');
      return null;
    }
  }

  /// Get real-time delivery estimate with traffic
  static Future<DeliveryEstimate?> getRealTimeDeliveryEstimate({
    required LatLng restaurantLocation,
    required LatLng customerLocation,
  }) async {
    try {
      final result = await getDistanceMatrix(
        origins: [restaurantLocation],
        destinations: [customerLocation],
        mode: 'driving',
      );

      if (result != null &&
          result.rows.isNotEmpty &&
          result.rows.first.elements.isNotEmpty) {
        final element = result.rows.first.elements.first;

        if (element.status == 'OK') {
          return DeliveryEstimate(
            distance: element.distance,
            duration: element.duration,
            distanceText: element.distanceText,
            durationText: element.durationText,
            durationInTraffic: element.durationInTraffic,
            durationInTrafficText: element.durationInTrafficText,
            isRealTime: true,
          );
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error getting real-time delivery estimate: $e');
      return null;
    }
  }
}

/// Distance matrix result model
class DistanceMatrixResult {
  final List<String> originAddresses;
  final List<String> destinationAddresses;
  final List<DistanceMatrixRow> rows;
  final String status;

  const DistanceMatrixResult({
    required this.originAddresses,
    required this.destinationAddresses,
    required this.rows,
    required this.status,
  });

  factory DistanceMatrixResult.fromJson(Map<String, dynamic> json) {
    return DistanceMatrixResult(
      originAddresses:
          List<String>.from(json['origin_addresses'] as List? ?? []),
      destinationAddresses:
          List<String>.from(json['destination_addresses'] as List? ?? []),
      rows: (json['rows'] as List?)
              ?.map((row) => DistanceMatrixRow.fromJson(row))
              .toList() ??
          [],
      status: json['status'] as String,
    );
  }
}

/// Distance matrix row model
class DistanceMatrixRow {
  final List<DistanceMatrixElement> elements;

  const DistanceMatrixRow({
    required this.elements,
  });

  factory DistanceMatrixRow.fromJson(Map<String, dynamic> json) {
    return DistanceMatrixRow(
      elements: (json['elements'] as List?)
              ?.map((element) => DistanceMatrixElement.fromJson(element))
              .toList() ??
          [],
    );
  }
}

/// Distance matrix element model
class DistanceMatrixElement {
  final String status;
  final int distance;
  final String distanceText;
  final int duration;
  final String durationText;
  final int? durationInTraffic;
  final String? durationInTrafficText;

  const DistanceMatrixElement({
    required this.status,
    required this.distance,
    required this.distanceText,
    required this.duration,
    required this.durationText,
    this.durationInTraffic,
    this.durationInTrafficText,
  });

  factory DistanceMatrixElement.fromJson(Map<String, dynamic> json) {
    final distance = json['distance'] as Map<String, dynamic>?;
    final duration = json['duration'] as Map<String, dynamic>?;
    final durationInTraffic =
        json['duration_in_traffic'] as Map<String, dynamic>?;

    return DistanceMatrixElement(
      status: json['status'] as String,
      distance: distance?['value'] as int? ?? 0,
      distanceText: distance?['text'] as String? ?? '',
      duration: duration?['value'] as int? ?? 0,
      durationText: duration?['text'] as String? ?? '',
      durationInTraffic: durationInTraffic?['value'] as int?,
      durationInTrafficText: durationInTraffic?['text'] as String?,
    );
  }
}

/// Delivery estimate model
class DeliveryEstimate {
  final int distance; // in meters
  final int duration; // in seconds
  final String distanceText;
  final String durationText;
  final int? durationInTraffic; // in seconds
  final String? durationInTrafficText;
  final bool isRealTime;
  final int? customerIndex;

  const DeliveryEstimate({
    required this.distance,
    required this.duration,
    required this.distanceText,
    required this.durationText,
    this.durationInTraffic,
    this.durationInTrafficText,
    this.isRealTime = false,
    this.customerIndex,
  });

  /// Get estimated delivery time in minutes
  int get estimatedDeliveryMinutes {
    final trafficDuration = durationInTraffic ?? duration;
    return (trafficDuration / 60).round();
  }

  /// Get distance in kilometers
  double get distanceInKm => distance / 1000.0;

  /// Get formatted delivery time
  String get formattedDeliveryTime {
    final minutes = estimatedDeliveryMinutes;
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return remainingMinutes > 0
          ? '${hours}h $remainingMinutes m'
          : '${hours}h';
    }
  }

  @override
  String toString() {
    return 'DeliveryEstimate(distance: $distanceText, duration: $durationText, realTime: $isRealTime)';
  }
}
