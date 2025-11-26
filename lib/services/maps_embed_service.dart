import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/maps_config.dart';
import 'logging_service.dart';

/// Service for Google Maps Embed API integration
class MapsEmbedService {
  static const String _baseUrl = MapsConfig.mapsEmbedApiBaseUrl;
  static const String _apiKey = MapsConfig.googleMapsApiKey;

  // Logging service for business metrics
  static final LoggingService _logger = LoggingService();

  /// Generate Maps Embed URL for place
  static String generatePlaceEmbedUrl({
    required String placeId,
    int zoom = 15,
    String mode = 'place',
  }) {
    final uri = Uri.parse('$_baseUrl/$mode').replace(queryParameters: {
      'key': _apiKey,
      'q': 'place_id:$placeId',
      'zoom': zoom.toString(),
    });

    debugPrint('🗺️ Generated place embed URL for: $placeId');
    return uri.toString();
  }

  /// Generate Maps Embed URL for directions
  static String generateDirectionsEmbedUrl({
    required LatLng origin,
    required LatLng destination,
    String mode = 'driving',
    int zoom = 13,
  }) {
    final originStr = '${origin.latitude},${origin.longitude}';
    final destinationStr = '${destination.latitude},${destination.longitude}';

    final uri = Uri.parse('$_baseUrl/directions').replace(queryParameters: {
      'key': _apiKey,
      'origin': originStr,
      'destination': destinationStr,
      'mode': mode,
      'zoom': zoom.toString(),
    });

    debugPrint(
        '🗺️ Generated directions embed URL from $originStr to $destinationStr');
    return uri.toString();
  }

  /// Generate Maps Embed URL for search
  static String generateSearchEmbedUrl({
    required String query,
    LatLng? center,
    int zoom = 13,
  }) {
    final params = <String, String>{
      'key': _apiKey,
      'q': query,
      'zoom': zoom.toString(),
    };

    if (center != null) {
      params['center'] = '${center.latitude},${center.longitude}';
    }

    final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: params);

    debugPrint('🗺️ Generated search embed URL for: $query');
    return uri.toString();
  }

  /// Generate Maps Embed URL for view
  static String generateViewEmbedUrl({
    required LatLng center,
    int zoom = 15,
    String mapType = 'roadmap',
  }) {
    final uri = Uri.parse('$_baseUrl/view').replace(queryParameters: {
      'key': _apiKey,
      'center': '${center.latitude},${center.longitude}',
      'zoom': zoom.toString(),
      'maptype': mapType,
    });

    debugPrint(
        '🗺️ Generated view embed URL for: ${center.latitude}, ${center.longitude}');
    return uri.toString();
  }

  /// Generate Maps Embed URL for street view
  static String generateStreetViewEmbedUrl({
    required LatLng location,
    int heading = 0,
    int pitch = 0,
    int fov = 90,
  }) {
    final uri = Uri.parse('$_baseUrl/streetview').replace(queryParameters: {
      'key': _apiKey,
      'location': '${location.latitude},${location.longitude}',
      'heading': heading.toString(),
      'pitch': pitch.toString(),
      'fov': fov.toString(),
    });

    debugPrint(
        '🗺️ Generated street view embed URL for: ${location.latitude}, ${location.longitude}');
    return uri.toString();
  }

  /// Generate restaurant location embed
  static String generateRestaurantEmbed({
    required LatLng restaurantLocation,
    required String restaurantName,
    int zoom = 16,
  }) {
    // Log business metrics for restaurant map generation
    _logger.logUserAction(
      'restaurant_map_generated',
      data: {
        'restaurant_name': restaurantName,
        'latitude': restaurantLocation.latitude,
        'longitude': restaurantLocation.longitude,
        'zoom_level': zoom,
        'operation': 'restaurant_embed',
      },
    );

    _logger.info(
      'Generated restaurant embed map',
      tag: 'MAPS',
      additionalData: {
        'restaurant_name': restaurantName,
        'latitude': restaurantLocation.latitude,
        'longitude': restaurantLocation.longitude,
        'zoom_level': zoom,
      },
    );

    return generateSearchEmbedUrl(
      query: restaurantName,
      center: restaurantLocation,
      zoom: zoom,
    );
  }

  /// Generate delivery route embed
  static String generateDeliveryRouteEmbed({
    required LatLng restaurantLocation,
    required LatLng customerLocation,
    String mode = 'driving',
  }) {
    // Calculate distance for business metrics
    final distance = _calculateDistance(restaurantLocation, customerLocation);

    // Log business metrics for delivery route generation
    _logger.logUserAction(
      'delivery_route_generated',
      data: {
        'restaurant_latitude': restaurantLocation.latitude,
        'restaurant_longitude': restaurantLocation.longitude,
        'customer_latitude': customerLocation.latitude,
        'customer_longitude': customerLocation.longitude,
        'travel_mode': mode,
        'estimated_distance_km': distance,
        'operation': 'delivery_route_embed',
      },
    );

    _logger.info(
      'Generated delivery route embed map',
      tag: 'MAPS',
      additionalData: {
        'restaurant_location':
            '${restaurantLocation.latitude},${restaurantLocation.longitude}',
        'customer_location':
            '${customerLocation.latitude},${customerLocation.longitude}',
        'travel_mode': mode,
        'estimated_distance_km': distance,
      },
    );

    return generateDirectionsEmbedUrl(
      origin: restaurantLocation,
      destination: customerLocation,
      mode: mode,
    );
  }

  /// Generate order tracking embed
  static String generateOrderTrackingEmbed({
    required LatLng restaurantLocation,
    required LatLng customerLocation,
    required LatLng deliveryPersonLocation,
  }) {
    // Calculate distances for business metrics
    final restaurantToDeliveryPerson =
        _calculateDistance(restaurantLocation, deliveryPersonLocation);
    final deliveryPersonToCustomer =
        _calculateDistance(deliveryPersonLocation, customerLocation);
    final totalDistance =
        _calculateDistance(restaurantLocation, customerLocation);

    // Log business metrics for order tracking generation
    _logger.logUserAction(
      'order_tracking_map_generated',
      data: {
        'restaurant_latitude': restaurantLocation.latitude,
        'restaurant_longitude': restaurantLocation.longitude,
        'customer_latitude': customerLocation.latitude,
        'customer_longitude': customerLocation.longitude,
        'delivery_person_latitude': deliveryPersonLocation.latitude,
        'delivery_person_longitude': deliveryPersonLocation.longitude,
        'restaurant_to_delivery_person_km': restaurantToDeliveryPerson,
        'delivery_person_to_customer_km': deliveryPersonToCustomer,
        'total_route_distance_km': totalDistance,
        'operation': 'order_tracking_embed',
      },
    );

    _logger.info(
      'Generated order tracking embed map',
      tag: 'MAPS',
      additionalData: {
        'restaurant_location':
            '${restaurantLocation.latitude},${restaurantLocation.longitude}',
        'customer_location':
            '${customerLocation.latitude},${customerLocation.longitude}',
        'delivery_person_location':
            '${deliveryPersonLocation.latitude},${deliveryPersonLocation.longitude}',
        'restaurant_to_delivery_person_km': restaurantToDeliveryPerson,
        'delivery_person_to_customer_km': deliveryPersonToCustomer,
        'total_route_distance_km': totalDistance,
      },
    );

    // Use directions from restaurant to customer with delivery person as waypoint
    final originStr =
        '${restaurantLocation.latitude},${restaurantLocation.longitude}';
    final destinationStr =
        '${customerLocation.latitude},${customerLocation.longitude}';
    final waypointStr =
        '${deliveryPersonLocation.latitude},${deliveryPersonLocation.longitude}';

    final uri = Uri.parse('$_baseUrl/directions').replace(queryParameters: {
      'key': _apiKey,
      'origin': originStr,
      'destination': destinationStr,
      'waypoints': waypointStr,
      'mode': 'driving',
      'zoom': '13',
    });

    debugPrint('🗺️ Generated order tracking embed URL');
    return uri.toString();
  }

  /// Generate delivery area embed
  static String generateDeliveryAreaEmbed({
    required LatLng center,
    required double radiusKm,
    int zoom = 12,
  }) {
    // Log business metrics for delivery area generation
    _logger.logUserAction(
      'delivery_area_map_generated',
      data: {
        'center_latitude': center.latitude,
        'center_longitude': center.longitude,
        'radius_km': radiusKm,
        'zoom_level': zoom,
        'operation': 'delivery_area_embed',
      },
    );

    _logger.info(
      'Generated delivery area embed map',
      tag: 'MAPS',
      additionalData: {
        'center_location': '${center.latitude},${center.longitude}',
        'radius_km': radiusKm,
        'zoom_level': zoom,
      },
    );

    return generateViewEmbedUrl(
      center: center,
      zoom: zoom,
      mapType: 'roadmap',
    );
  }

  /// Calculate distance between two points using Haversine formula
  static double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final lat1Rad = point1.latitude * (3.14159265359 / 180);
    final lat2Rad = point2.latitude * (3.14159265359 / 180);
    final deltaLatRad =
        (point2.latitude - point1.latitude) * (3.14159265359 / 180);
    final deltaLngRad =
        (point2.longitude - point1.longitude) * (3.14159265359 / 180);

    final a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLngRad / 2) *
            sin(deltaLngRad / 2);
    final c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  /// Generate iframe HTML for embedding
  static String generateIframeHtml({
    required String embedUrl,
    int width = 400,
    int height = 300,
    bool allowFullscreen = true,
  }) {
    final fullscreenAttr = allowFullscreen ? ' allowfullscreen' : '';

    return '''
    <iframe
      width="$width"
      height="$height"
      style="border:0"
      loading="lazy"
      allowfullscreen$fullscreenAttr
      referrerpolicy="no-referrer-when-downgrade"
      src="$embedUrl">
    </iframe>
    ''';
  }

  /// Generate restaurant location iframe
  static String generateRestaurantLocationIframe({
    required LatLng restaurantLocation,
    required String restaurantName,
    int width = 400,
    int height = 300,
  }) {
    final embedUrl = generateRestaurantEmbed(
      restaurantLocation: restaurantLocation,
      restaurantName: restaurantName,
    );

    return generateIframeHtml(
      embedUrl: embedUrl,
      width: width,
      height: height,
    );
  }

  /// Generate delivery route iframe
  static String generateDeliveryRouteIframe({
    required LatLng restaurantLocation,
    required LatLng customerLocation,
    int width = 400,
    int height = 300,
  }) {
    final embedUrl = generateDeliveryRouteEmbed(
      restaurantLocation: restaurantLocation,
      customerLocation: customerLocation,
    );

    return generateIframeHtml(
      embedUrl: embedUrl,
      width: width,
      height: height,
    );
  }

  /// Generate order tracking iframe
  static String generateOrderTrackingIframe({
    required LatLng restaurantLocation,
    required LatLng customerLocation,
    required LatLng deliveryPersonLocation,
    int width = 400,
    int height = 300,
  }) {
    final embedUrl = generateOrderTrackingEmbed(
      restaurantLocation: restaurantLocation,
      customerLocation: customerLocation,
      deliveryPersonLocation: deliveryPersonLocation,
    );

    return generateIframeHtml(
      embedUrl: embedUrl,
      width: width,
      height: height,
    );
  }

  /// Generate delivery area iframe
  static String generateDeliveryAreaIframe({
    required LatLng center,
    required double radiusKm,
    int width = 400,
    int height = 300,
  }) {
    final embedUrl = generateDeliveryAreaEmbed(
      center: center,
      radiusKm: radiusKm,
    );

    return generateIframeHtml(
      embedUrl: embedUrl,
      width: width,
      height: height,
    );
  }

  /// Generate comprehensive delivery analytics embed
  static String generateDeliveryAnalyticsEmbed({
    required LatLng restaurantLocation,
    required List<LatLng> deliveryLocations,
    int zoom = 12,
  }) {
    if (deliveryLocations.isEmpty) {
      return generateViewEmbedUrl(center: restaurantLocation, zoom: zoom);
    }

    // Calculate center point of all delivery locations
    double totalLat = restaurantLocation.latitude;
    double totalLng = restaurantLocation.longitude;

    for (final location in deliveryLocations) {
      totalLat += location.latitude;
      totalLng += location.longitude;
    }

    final centerLat = totalLat / (deliveryLocations.length + 1);
    final centerLng = totalLng / (deliveryLocations.length + 1);
    final center = LatLng(centerLat, centerLng);

    // Log business metrics for analytics map generation
    _logger.logUserAction(
      'delivery_analytics_map_generated',
      data: {
        'restaurant_latitude': restaurantLocation.latitude,
        'restaurant_longitude': restaurantLocation.longitude,
        'center_latitude': centerLat,
        'center_longitude': centerLng,
        'delivery_locations_count': deliveryLocations.length,
        'zoom_level': zoom,
        'operation': 'delivery_analytics_embed',
      },
    );

    _logger.info(
      'Generated delivery analytics embed map',
      tag: 'MAPS',
      additionalData: {
        'restaurant_location':
            '${restaurantLocation.latitude},${restaurantLocation.longitude}',
        'center_location': '$centerLat,$centerLng',
        'delivery_locations_count': deliveryLocations.length,
        'zoom_level': zoom,
      },
    );

    return generateViewEmbedUrl(center: center, zoom: zoom);
  }

  /// Validate coordinates
  static bool isValidCoordinate(LatLng coordinate) {
    return coordinate.latitude >= -90 &&
        coordinate.latitude <= 90 &&
        coordinate.longitude >= -180 &&
        coordinate.longitude <= 180;
  }

  /// Get optimal zoom level based on distance
  static int getOptimalZoomLevel(double distanceKm) {
    if (distanceKm < 1) return 16;
    if (distanceKm < 5) return 14;
    if (distanceKm < 10) return 12;
    if (distanceKm < 25) return 10;
    if (distanceKm < 50) return 8;
    return 6;
  }
}
