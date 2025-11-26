import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/maps_config.dart';

/// Service for getting real road routes using Google Maps Directions API
class DirectionsService {
  static const String _baseUrl = MapsConfig.directionsApiBaseUrl;
  static const String _apiKey = MapsConfig.googleMapsApiKey;

  /// Get route between two points
  static Future<List<LatLng>?> getRoute({
    required LatLng origin,
    required LatLng destination,
    LatLng? waypoint, // Optional waypoint (like delivery person location)
  }) async {
    try {
      // Build the URL with parameters
      final queryParams = <String, String>{
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'key': _apiKey,
        'mode': MapsConfig.defaultTravelMode,
        'alternatives': MapsConfig.enableAlternatives.toString(),
        'units': MapsConfig.defaultUnits,
      };

      // Add waypoint if provided
      if (waypoint != null) {
        queryParams['waypoints'] = '${waypoint.latitude},${waypoint.longitude}';
      }

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

      debugPrint('🗺️ Requesting route from Directions API...');
      debugPrint('   Origin: ${origin.latitude}, ${origin.longitude}');
      debugPrint(
          '   Destination: ${destination.latitude}, ${destination.longitude}');
      if (waypoint != null) {
        debugPrint('   Waypoint: ${waypoint.latitude}, ${waypoint.longitude}');
      }

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final legs = route['legs'] as List;

          final List<LatLng> points = [];

          for (final leg in legs) {
            final steps = leg['steps'] as List;
            for (final step in steps) {
              final polyline = step['polyline'];
              final encodedPolyline = polyline['points'] as String;

              // Decode the polyline
              final decodedPoints = _decodePolyline(encodedPolyline);
              points.addAll(decodedPoints);
            }
          }

          debugPrint('✅ Route received with ${points.length} points');
          return points;
        } else {
          debugPrint('❌ Directions API error: ${data['status']}');
          if (data['error_message'] != null) {
            debugPrint('   Error: ${data['error_message']}');
          }
          return null;
        }
      } else {
        debugPrint('❌ HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error getting route: $e');
      return null;
    }
  }

  /// Get route from restaurant to customer (static route)
  static Future<List<LatLng>?> getRestaurantToCustomerRoute({
    required LatLng restaurant,
    required LatLng customer,
  }) async {
    return getRoute(origin: restaurant, destination: customer);
  }

  /// Get route from restaurant to delivery person to customer (dynamic route)
  static Future<List<LatLng>?> getDeliveryRoute({
    required LatLng restaurant,
    required LatLng deliveryPerson,
    required LatLng customer,
  }) async {
    return getRoute(
      origin: restaurant,
      destination: customer,
      waypoint: deliveryPerson,
    );
  }

  /// Decode Google Maps polyline string to list of LatLng points
  static List<LatLng> _decodePolyline(String polyline) {
    final List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < polyline.length) {
      int b, shift = 0, result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  /// Get route information (distance, duration)
  static Future<RouteInfo?> getRouteInfo({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'key': _apiKey,
        'mode': MapsConfig.defaultTravelMode,
        'alternatives': MapsConfig.enableAlternatives.toString(),
        'units': MapsConfig.defaultUnits,
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          return RouteInfo(
            distance: leg['distance']['text'] as String,
            duration: leg['duration']['text'] as String,
            distanceValue: leg['distance']['value'] as int,
            durationValue: leg['duration']['value'] as int,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error getting route info: $e');
    }

    return null;
  }
}

/// Route information model
class RouteInfo {
  final String distance;
  final String duration;
  final int distanceValue; // in meters
  final int durationValue; // in seconds

  const RouteInfo({
    required this.distance,
    required this.duration,
    required this.distanceValue,
    required this.durationValue,
  });

  @override
  String toString() {
    return 'RouteInfo(distance: $distance, duration: $duration)';
  }
}
