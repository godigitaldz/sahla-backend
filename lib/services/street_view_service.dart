import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/maps_config.dart';

/// Service for Google Street View Static API integration
class StreetViewService {
  static const String _baseUrl = MapsConfig.streetViewApiBaseUrl;
  static const String _apiKey = MapsConfig.googleMapsApiKey;

  /// Generate Street View image URL
  static String generateStreetViewUrl({
    required LatLng location,
    int width = 400,
    int height = 300,
    int heading = 0,
    int pitch = 0,
    int fov = 90,
    String? panoramaId,
  }) {
    final params = <String, String>{
      'size': '${width}x$height',
      'heading': heading.toString(),
      'pitch': pitch.toString(),
      'fov': fov.toString(),
      'key': _apiKey,
    };

    if (panoramaId != null) {
      params['pano'] = panoramaId;
    } else {
      params['location'] = '${location.latitude},${location.longitude}';
    }

    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
    return uri.toString();
  }

  /// Get Street View metadata
  static Future<StreetViewMetadata?> getStreetViewMetadata({
    required LatLng location,
    int heading = 0,
    int pitch = 0,
    int fov = 90,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/metadata').replace(queryParameters: {
        'location': '${location.latitude},${location.longitude}',
        'heading': heading.toString(),
        'pitch': pitch.toString(),
        'fov': fov.toString(),
        'key': _apiKey,
      });

      debugPrint(
          '🏠 Getting Street View metadata for ${location.latitude}, ${location.longitude}');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          debugPrint('✅ Street View metadata retrieved');
          return StreetViewMetadata.fromJson(data);
        } else {
          debugPrint('❌ Street View metadata error: ${data['status']}');
          return null;
        }
      } else {
        debugPrint('❌ HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error getting Street View metadata: $e');
      return null;
    }
  }

  /// Check if Street View is available at location
  static Future<bool> isStreetViewAvailable(LatLng location) async {
    try {
      final metadata = await getStreetViewMetadata(location: location);
      return metadata?.status == 'OK';
    } catch (e) {
      debugPrint('❌ Error checking Street View availability: $e');
      return false;
    }
  }

  /// Generate restaurant Street View image
  static String generateRestaurantStreetView({
    required LatLng restaurantLocation,
    required String restaurantName,
    int width = 400,
    int height = 300,
  }) {
    // Try different headings to get the best view
    final headings = [0, 90, 180, 270]; // North, East, South, West
    final bestHeading = headings[0]; // Default to North

    return generateStreetViewUrl(
      location: restaurantLocation,
      width: width,
      height: height,
      heading: bestHeading,
      pitch: 10, // Slight downward angle
      fov: 90,
    );
  }

  /// Generate delivery location Street View image
  static String generateDeliveryLocationStreetView({
    required LatLng deliveryLocation,
    int width = 400,
    int height = 300,
  }) {
    return generateStreetViewUrl(
      location: deliveryLocation,
      width: width,
      height: height,
      heading: 0,
      pitch: 0,
      fov: 90,
    );
  }

  /// Generate Street View for order verification
  static String generateOrderVerificationStreetView({
    required LatLng location,
    int width = 300,
    int height = 200,
  }) {
    return generateStreetViewUrl(
      location: location,
      width: width,
      height: height,
      heading: 0,
      pitch: 0,
      fov: 90,
    );
  }
}

/// Street View metadata model
class StreetViewMetadata {
  final String status;
  final String? panoramaId;
  final LatLng? location;
  final String? copyright;
  final String? date;
  final String? panoId;

  const StreetViewMetadata({
    required this.status,
    this.panoramaId,
    this.location,
    this.copyright,
    this.date,
    this.panoId,
  });

  factory StreetViewMetadata.fromJson(Map<String, dynamic> json) {
    LatLng? location;
    if (json['location'] != null) {
      final loc = json['location'] as Map<String, dynamic>;
      location = LatLng(
        (loc['lat'] as num).toDouble(),
        (loc['lng'] as num).toDouble(),
      );
    }

    return StreetViewMetadata(
      status: json['status'] as String,
      panoramaId: json['pano_id'] as String?,
      location: location,
      copyright: json['copyright'] as String?,
      date: json['date'] as String?,
      panoId: json['pano_id'] as String?,
    );
  }

  bool get isAvailable => status == 'OK';
}
