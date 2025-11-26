import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/maps_config.dart';

/// Service for Google Roads API integration
class RoadsService {
  static const String _baseUrl = MapsConfig.roadsApiBaseUrl;
  static const String _apiKey = MapsConfig.googleMapsApiKey;

  /// Snap GPS coordinates to actual roads
  static Future<List<SnappedPoint>?> snapToRoads({
    required List<LatLng> path,
    bool interpolate = true,
  }) async {
    try {
      // Convert path to string format
      final pathStr = path
          .map((latLng) => '${latLng.latitude},${latLng.longitude}')
          .join('|');

      final uri = Uri.parse('$_baseUrl/snapToRoads').replace(queryParameters: {
        'path': pathStr,
        'interpolate': interpolate.toString(),
        'key': _apiKey,
      });

      debugPrint('🛣️ Snapping ${path.length} points to roads...');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['snappedPoints'] != null) {
          final snappedPoints = (data['snappedPoints'] as List)
              .map((point) => SnappedPoint.fromJson(point))
              .toList();

          debugPrint('✅ Snapped ${snappedPoints.length} points to roads');
          return snappedPoints;
        } else {
          debugPrint('❌ No snapped points returned');
          return null;
        }
      } else {
        debugPrint('❌ HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error snapping to roads: $e');
      return null;
    }
  }

  /// Get speed limits for a road segment
  static Future<List<SpeedLimit>?> getSpeedLimits({
    required List<String> placeIds,
  }) async {
    try {
      final placeIdsStr = placeIds.join('|');

      final uri = Uri.parse('$_baseUrl/speedLimits').replace(queryParameters: {
        'placeId': placeIdsStr,
        'key': _apiKey,
      });

      debugPrint(
          '🚦 Getting speed limits for ${placeIds.length} road segments...');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['speedLimits'] != null) {
          final speedLimits = (data['speedLimits'] as List)
              .map((limit) => SpeedLimit.fromJson(limit))
              .toList();

          debugPrint('✅ Retrieved ${speedLimits.length} speed limits');
          return speedLimits;
        } else {
          debugPrint('❌ No speed limits returned');
          return null;
        }
      } else {
        debugPrint('❌ HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error getting speed limits: $e');
      return null;
    }
  }

  /// Get speed limits for a path
  static Future<List<SpeedLimit>?> getSpeedLimitsForPath({
    required List<LatLng> path,
  }) async {
    try {
      // First snap the path to roads
      final snappedPoints = await snapToRoads(path: path);

      if (snappedPoints == null || snappedPoints.isEmpty) {
        return null;
      }

      // Extract place IDs from snapped points
      final placeIds = snappedPoints
          .where((point) => point.placeId != null)
          .map((point) => point.placeId!)
          .toList();

      if (placeIds.isEmpty) {
        debugPrint('❌ No place IDs found in snapped points');
        return null;
      }

      // Get speed limits for the place IDs
      return await getSpeedLimits(placeIds: placeIds);
    } catch (e) {
      debugPrint('❌ Error getting speed limits for path: $e');
      return null;
    }
  }

  /// Improve delivery person location accuracy
  static Future<LatLng?> improveLocationAccuracy(LatLng location) async {
    try {
      final snappedPoints = await snapToRoads(path: [location]);

      if (snappedPoints != null && snappedPoints.isNotEmpty) {
        final snappedPoint = snappedPoints.first;
        debugPrint(
            '📍 Improved location accuracy: ${location.latitude}, ${location.longitude} -> ${snappedPoint.location.latitude}, ${snappedPoint.location.longitude}');
        return snappedPoint.location;
      }

      return location; // Return original if snapping fails
    } catch (e) {
      debugPrint('❌ Error improving location accuracy: $e');
      return location;
    }
  }

  /// Get road information for a location
  static Future<RoadInfo?> getRoadInfo(LatLng location) async {
    try {
      final snappedPoints = await snapToRoads(path: [location]);

      if (snappedPoints != null && snappedPoints.isNotEmpty) {
        final snappedPoint = snappedPoints.first;

        // Get speed limits if place ID is available
        List<SpeedLimit>? speedLimits;
        if (snappedPoint.placeId != null) {
          speedLimits = await getSpeedLimits(placeIds: [snappedPoint.placeId!]);
        }

        return RoadInfo(
          location: snappedPoint.location,
          originalLocation: location,
          placeId: snappedPoint.placeId,
          speedLimit: speedLimits?.isNotEmpty == true
              ? speedLimits!.first.speedLimit
              : null,
          roadName: snappedPoint.roadName,
        );
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error getting road info: $e');
      return null;
    }
  }
}

/// Snapped point model
class SnappedPoint {
  final LatLng location;
  final int? originalIndex;
  final String? placeId;
  final String? roadName;

  const SnappedPoint({
    required this.location,
    this.originalIndex,
    this.placeId,
    this.roadName,
  });

  factory SnappedPoint.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>;

    return SnappedPoint(
      location: LatLng(
        (location['latitude'] as num).toDouble(),
        (location['longitude'] as num).toDouble(),
      ),
      originalIndex: json['originalIndex'] as int?,
      placeId: json['placeId'] as String?,
      roadName: json['roadName'] as String?,
    );
  }
}

/// Speed limit model
class SpeedLimit {
  final String placeId;
  final int speedLimit; // in km/h
  final String units;

  const SpeedLimit({
    required this.placeId,
    required this.speedLimit,
    required this.units,
  });

  factory SpeedLimit.fromJson(Map<String, dynamic> json) {
    return SpeedLimit(
      placeId: json['placeId'] as String,
      speedLimit: json['speedLimit'] as int,
      units: json['units'] as String,
    );
  }
}

/// Road information model
class RoadInfo {
  final LatLng location;
  final LatLng originalLocation;
  final String? placeId;
  final int? speedLimit;
  final String? roadName;

  const RoadInfo({
    required this.location,
    required this.originalLocation,
    this.placeId,
    this.speedLimit,
    this.roadName,
  });

  /// Get accuracy improvement in meters
  double get accuracyImprovement {
    const double earthRadius = 6371000; // meters
    final double dLat =
        _degreesToRadians(location.latitude - originalLocation.latitude);
    final double dLng =
        _degreesToRadians(location.longitude - originalLocation.longitude);

    final double a = (dLat / 2) * (dLat / 2) +
        (dLng / 2) *
            (dLng / 2) *
            cos(originalLocation.latitude * pi / 180) *
            cos(location.latitude * pi / 180);

    final double c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) => degrees * (pi / 180.0);

  @override
  String toString() {
    return 'RoadInfo(location: ${location.latitude}, ${location.longitude}, roadName: $roadName, speedLimit: ${speedLimit}km/h)';
  }
}
