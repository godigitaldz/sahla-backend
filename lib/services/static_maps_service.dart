import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/maps_config.dart';

/// Service for Google Static Maps API integration
class StaticMapsService {
  static const String _baseUrl = MapsConfig.staticMapsApiBaseUrl;
  static const String _apiKey = MapsConfig.googleMapsApiKey;

  /// Generate static map image URL
  static String generateStaticMapUrl({
    required LatLng center,
    int zoom = 15,
    int width = 400,
    int height = 400,
    String mapType = 'roadmap',
    List<StaticMapMarker>? markers,
    List<StaticMapPath>? paths,
    String? style,
  }) {
    final params = <String, String>{
      'center': '${center.latitude},${center.longitude}',
      'zoom': zoom.toString(),
      'size': '${width}x$height',
      'maptype': mapType,
      'key': _apiKey,
    };

    // Add markers
    if (markers != null && markers.isNotEmpty) {
      final markerParams = markers.map((marker) => marker.toString()).join('|');
      params['markers'] = markerParams;
    }

    // Add paths
    if (paths != null && paths.isNotEmpty) {
      final pathParams = paths.map((path) => path.toString()).join('|');
      params['path'] = pathParams;
    }

    // Add style
    if (style != null) {
      params['style'] = style;
    }

    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
    return uri.toString();
  }

  /// Generate delivery route map for order receipt
  static String generateDeliveryRouteMap({
    required LatLng restaurantLocation,
    required LatLng customerLocation,
    LatLng? deliveryPersonLocation,
    int width = 400,
    int height = 300,
  }) {
    final markers = <StaticMapMarker>[
      StaticMapMarker(
        location: restaurantLocation,
        icon: 'https://maps.google.com/mapfiles/ms/icons/restaurant.png',
        size: 'normal',
      ),
      StaticMapMarker(
        location: customerLocation,
        color: 'green',
        label: 'C',
        size: 'normal',
      ),
    ];

    if (deliveryPersonLocation != null) {
      markers.add(StaticMapMarker(
        location: deliveryPersonLocation,
        icon: 'https://maps.google.com/mapfiles/ms/icons/motorcycling.png',
        size: 'normal',
      ));
    }

    // Create path from restaurant to customer
    final path = StaticMapPath(
      points: [restaurantLocation, customerLocation],
      color: '0xFFd47b00',
      weight: 4,
    );

    // Calculate center point
    final centerLat =
        (restaurantLocation.latitude + customerLocation.latitude) / 2;
    final centerLng =
        (restaurantLocation.longitude + customerLocation.longitude) / 2;
    final center = LatLng(centerLat, centerLng);

    return generateStaticMapUrl(
      center: center,
      zoom: 13,
      width: width,
      height: height,
      markers: markers,
      paths: [path],
    );
  }

  /// Generate restaurant location map
  static String generateRestaurantMap({
    required LatLng restaurantLocation,
    required String restaurantName,
    int width = 300,
    int height = 200,
  }) {
    final marker = StaticMapMarker(
      location: restaurantLocation,
      icon: 'https://maps.google.com/mapfiles/ms/icons/restaurant.png',
      size: 'normal',
    );

    return generateStaticMapUrl(
      center: restaurantLocation,
      zoom: 16,
      width: width,
      height: height,
      markers: [marker],
    );
  }

  /// Generate delivery area map
  static String generateDeliveryAreaMap({
    required LatLng center,
    required double radiusKm,
    int width = 400,
    int height = 400,
  }) {
    // Create a circle path to show delivery area
    final circlePoints = _generateCirclePoints(center, radiusKm);
    final path = StaticMapPath(
      points: circlePoints,
      color: '0xFFd47b00',
      weight: 2,
      fillColor: '0xFFd47b00',
      fillOpacity: 0.2,
    );

    return generateStaticMapUrl(
      center: center,
      zoom: 12,
      width: width,
      height: height,
      paths: [path],
    );
  }

  /// Generate order tracking map
  static String generateOrderTrackingMap({
    required LatLng restaurantLocation,
    required LatLng customerLocation,
    required LatLng deliveryPersonLocation,
    int width = 400,
    int height = 300,
  }) {
    final markers = <StaticMapMarker>[
      StaticMapMarker(
        location: restaurantLocation,
        icon: 'https://maps.google.com/mapfiles/ms/icons/restaurant.png',
        size: 'normal',
      ),
      StaticMapMarker(
        location: customerLocation,
        color: 'green',
        label: 'C',
        size: 'normal',
      ),
      StaticMapMarker(
        location: deliveryPersonLocation,
        icon: 'https://maps.google.com/mapfiles/ms/icons/motorcycling.png',
        size: 'normal',
      ),
    ];

    // Create delivery path
    final path = StaticMapPath(
      points: [restaurantLocation, deliveryPersonLocation, customerLocation],
      color: '0xFFd47b00',
      weight: 5,
    );

    // Calculate center point
    final centerLat = (restaurantLocation.latitude +
            customerLocation.latitude +
            deliveryPersonLocation.latitude) /
        3;
    final centerLng = (restaurantLocation.longitude +
            customerLocation.longitude +
            deliveryPersonLocation.longitude) /
        3;
    final center = LatLng(centerLat, centerLng);

    return generateStaticMapUrl(
      center: center,
      zoom: 13,
      width: width,
      height: height,
      markers: markers,
      paths: [path],
    );
  }

  /// Generate circle points for delivery area
  static List<LatLng> _generateCirclePoints(LatLng center, double radiusKm) {
    const int points = 64;
    const double earthRadius = 6371; // km
    final List<LatLng> circlePoints = [];

    for (int i = 0; i <= points; i++) {
      final double angle = (i * 360.0 / points) * (pi / 180.0);
      final double lat = center.latitude +
          (radiusKm / earthRadius) * (180.0 / pi) * cos(angle);
      final double lng = center.longitude +
          (radiusKm / earthRadius) *
              (180.0 / pi) *
              sin(angle) /
              cos(center.latitude * pi / 180.0);
      circlePoints.add(LatLng(lat, lng));
    }

    return circlePoints;
  }
}

/// Static map marker model
class StaticMapMarker {
  final LatLng location;
  final String? color;
  final String? label;
  final String? size;
  final String? icon;

  const StaticMapMarker({
    required this.location,
    this.color,
    this.label,
    this.size,
    this.icon,
  });

  @override
  String toString() {
    final parts = <String>[];

    if (color != null) parts.add('color:$color');
    if (label != null) parts.add('label:$label');
    if (size != null) parts.add('size:$size');
    if (icon != null) parts.add('icon:$icon');

    parts.add('${location.latitude},${location.longitude}');

    return parts.join('|');
  }
}

/// Static map path model
class StaticMapPath {
  final List<LatLng> points;
  final String? color;
  final int? weight;
  final String? fillColor;
  final double? fillOpacity;

  const StaticMapPath({
    required this.points,
    this.color,
    this.weight,
    this.fillColor,
    this.fillOpacity,
  });

  @override
  String toString() {
    final parts = <String>[];

    if (color != null) parts.add('color:$color');
    if (weight != null) parts.add('weight:$weight');
    if (fillColor != null) parts.add('fillcolor:$fillColor');
    if (fillOpacity != null) parts.add('fillopacity:$fillOpacity');

    final pointsStr =
        points.map((point) => '${point.latitude},${point.longitude}').join('|');
    parts.add(pointsStr);

    return parts.join('|');
  }
}
