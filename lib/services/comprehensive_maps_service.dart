import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'directions_service.dart';
import 'distance_matrix_service.dart';
import 'maps_embed_service.dart';
import 'places_service.dart';
import 'roads_service.dart';
import 'static_maps_service.dart';
import 'street_view_service.dart';
import 'time_zone_service.dart';

/// Comprehensive Google Maps service integrating all APIs
class ComprehensiveMapsService {
  /// Get complete delivery information for an order
  static Future<DeliveryInfo?> getCompleteDeliveryInfo({
    required LatLng restaurantLocation,
    required LatLng customerLocation,
    LatLng? deliveryPersonLocation,
    String? restaurantName,
  }) async {
    try {
      debugPrint('🗺️ Getting complete delivery information...');

      // Get all information in parallel
      final results = await Future.wait([
        // Get route information
        DirectionsService.getRouteInfo(
          origin: restaurantLocation,
          destination: customerLocation,
        ),

        // Get distance matrix
        DistanceMatrixService.getDeliveryEstimate(
          restaurantLocation: restaurantLocation,
          customerLocation: customerLocation,
        ),

        // Get time zone information
        TimeZoneService.getTimeZone(location: restaurantLocation),
        TimeZoneService.getTimeZone(location: customerLocation),

        // Get road information for accuracy
        RoadsService.getRoadInfo(restaurantLocation),
        RoadsService.getRoadInfo(customerLocation),

        // Get nearby places
        PlacesService.getNearbyRestaurants(
          location: restaurantLocation,
          radius: 1000,
        ),
      ]);

      final routeInfo = results[0] as RouteInfo?;
      final deliveryEstimate = results[1] as DeliveryEstimate?;
      final restaurantTimeZone = results[2] as TimeZoneInfo?;
      final customerTimeZone = results[3] as TimeZoneInfo?;
      final restaurantRoadInfo = results[4] as RoadInfo?;
      final customerRoadInfo = results[5] as RoadInfo?;
      final nearbyRestaurants = results[6] as List<Place>?;

      // Generate static map
      final staticMapUrl = StaticMapsService.generateDeliveryRouteMap(
        restaurantLocation: restaurantLocation,
        customerLocation: customerLocation,
        deliveryPersonLocation: deliveryPersonLocation,
      );

      // Generate embed map
      final embedUrl = MapsEmbedService.generateDeliveryRouteEmbed(
        restaurantLocation: restaurantLocation,
        customerLocation: customerLocation,
      );

      // Check Street View availability
      final streetViewAvailable =
          await StreetViewService.isStreetViewAvailable(restaurantLocation);

      return DeliveryInfo(
        restaurantLocation: restaurantLocation,
        customerLocation: customerLocation,
        deliveryPersonLocation: deliveryPersonLocation,
        routeInfo: routeInfo,
        deliveryEstimate: deliveryEstimate,
        restaurantTimeZone: restaurantTimeZone,
        customerTimeZone: customerTimeZone,
        restaurantRoadInfo: restaurantRoadInfo,
        customerRoadInfo: customerRoadInfo,
        nearbyRestaurants: nearbyRestaurants ?? [],
        staticMapUrl: staticMapUrl,
        embedUrl: embedUrl,
        streetViewAvailable: streetViewAvailable,
        restaurantName: restaurantName,
      );
    } catch (e) {
      debugPrint('❌ Error getting complete delivery info: $e');
      return null;
    }
  }

  /// Get real-time order tracking information
  static Future<OrderTrackingInfo?> getRealTimeOrderTracking({
    required LatLng restaurantLocation,
    required LatLng customerLocation,
    required LatLng deliveryPersonLocation,
    required String orderId,
  }) async {
    try {
      debugPrint('📍 Getting real-time order tracking for order: $orderId');

      // Get current delivery route
      final deliveryRoute = await DirectionsService.getDeliveryRoute(
        restaurant: restaurantLocation,
        deliveryPerson: deliveryPersonLocation,
        customer: customerLocation,
      );

      // Get real-time delivery estimate
      final realTimeEstimate =
          await DistanceMatrixService.getRealTimeDeliveryEstimate(
        restaurantLocation: restaurantLocation,
        customerLocation: customerLocation,
      );

      // Improve location accuracy
      final accurateDeliveryLocation =
          await RoadsService.improveLocationAccuracy(deliveryPersonLocation);

      // Get current time in both locations
      final restaurantTime =
          await TimeZoneService.getCurrentTime(restaurantLocation);
      final customerTime =
          await TimeZoneService.getCurrentTime(customerLocation);

      // Generate tracking map
      final trackingMapUrl = StaticMapsService.generateOrderTrackingMap(
        restaurantLocation: restaurantLocation,
        customerLocation: customerLocation,
        deliveryPersonLocation:
            accurateDeliveryLocation ?? deliveryPersonLocation,
      );

      // Generate embed tracking map
      final embedTrackingUrl = MapsEmbedService.generateOrderTrackingEmbed(
        restaurantLocation: restaurantLocation,
        customerLocation: customerLocation,
        deliveryPersonLocation:
            accurateDeliveryLocation ?? deliveryPersonLocation,
      );

      return OrderTrackingInfo(
        orderId: orderId,
        restaurantLocation: restaurantLocation,
        customerLocation: customerLocation,
        deliveryPersonLocation:
            accurateDeliveryLocation ?? deliveryPersonLocation,
        deliveryRoute: deliveryRoute,
        realTimeEstimate: realTimeEstimate,
        restaurantTime: restaurantTime,
        customerTime: customerTime,
        trackingMapUrl: trackingMapUrl,
        embedTrackingUrl: embedTrackingUrl,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ Error getting real-time order tracking: $e');
      return null;
    }
  }

  /// Get restaurant information with all location data
  static Future<RestaurantLocationInfo?> getRestaurantLocationInfo({
    required LatLng restaurantLocation,
    required String restaurantName,
  }) async {
    try {
      debugPrint('🏪 Getting restaurant location info for: $restaurantName');

      // Get all information in parallel
      final results = await Future.wait([
        // Get place details
        PlacesService.searchPlaces(
          query: restaurantName,
          location: restaurantLocation,
          radius: 500,
        ),

        // Get time zone
        TimeZoneService.getTimeZone(location: restaurantLocation),

        // Get road information
        RoadsService.getRoadInfo(restaurantLocation),

        // Check Street View availability
        StreetViewService.isStreetViewAvailable(restaurantLocation),

        // Get nearby restaurants
        PlacesService.getNearbyRestaurants(
          location: restaurantLocation,
          radius: 2000,
        ),
      ]);

      final places = results[0] as List<Place>?;
      final timeZone = results[1] as TimeZoneInfo?;
      final roadInfo = results[2] as RoadInfo?;
      final streetViewAvailable = results[3] as bool;
      final nearbyRestaurants = results[4] as List<Place>?;

      // Generate static map
      final staticMapUrl = StaticMapsService.generateRestaurantMap(
        restaurantLocation: restaurantLocation,
        restaurantName: restaurantName,
      );

      // Generate embed map
      final embedUrl = MapsEmbedService.generateRestaurantEmbed(
        restaurantLocation: restaurantLocation,
        restaurantName: restaurantName,
      );

      // Generate Street View URL if available
      String? streetViewUrl;
      if (streetViewAvailable) {
        streetViewUrl = StreetViewService.generateRestaurantStreetView(
          restaurantLocation: restaurantLocation,
          restaurantName: restaurantName,
        );
      }

      return RestaurantLocationInfo(
        restaurantLocation: restaurantLocation,
        restaurantName: restaurantName,
        places: places ?? [],
        timeZone: timeZone,
        roadInfo: roadInfo,
        streetViewAvailable: streetViewAvailable,
        streetViewUrl: streetViewUrl,
        nearbyRestaurants: nearbyRestaurants ?? [],
        staticMapUrl: staticMapUrl,
        embedUrl: embedUrl,
      );
    } catch (e) {
      debugPrint('❌ Error getting restaurant location info: $e');
      return null;
    }
  }

  /// Get delivery area information
  static Future<DeliveryAreaInfo?> getDeliveryAreaInfo({
    required LatLng center,
    required double radiusKm,
  }) async {
    try {
      debugPrint('🚚 Getting delivery area info for radius: ${radiusKm}km');

      // Get time zone information
      final timeZone = await TimeZoneService.getTimeZone(location: center);

      // Get nearby restaurants in the area
      final nearbyRestaurants = await PlacesService.getNearbyRestaurants(
        location: center,
        radius: (radiusKm * 1000).round().toDouble(),
      );

      // Generate delivery area map
      final staticMapUrl = StaticMapsService.generateDeliveryAreaMap(
        center: center,
        radiusKm: radiusKm,
      );

      // Generate embed map
      final embedUrl = MapsEmbedService.generateDeliveryAreaEmbed(
        center: center,
        radiusKm: radiusKm,
      );

      return DeliveryAreaInfo(
        center: center,
        radiusKm: radiusKm,
        timeZone: timeZone,
        nearbyRestaurants: nearbyRestaurants ?? [],
        staticMapUrl: staticMapUrl,
        embedUrl: embedUrl,
      );
    } catch (e) {
      debugPrint('❌ Error getting delivery area info: $e');
      return null;
    }
  }
}

/// Comprehensive delivery information model
class DeliveryInfo {
  final LatLng restaurantLocation;
  final LatLng customerLocation;
  final LatLng? deliveryPersonLocation;
  final RouteInfo? routeInfo;
  final DeliveryEstimate? deliveryEstimate;
  final TimeZoneInfo? restaurantTimeZone;
  final TimeZoneInfo? customerTimeZone;
  final RoadInfo? restaurantRoadInfo;
  final RoadInfo? customerRoadInfo;
  final List<Place> nearbyRestaurants;
  final String staticMapUrl;
  final String embedUrl;
  final bool streetViewAvailable;
  final String? restaurantName;

  const DeliveryInfo({
    required this.restaurantLocation,
    required this.customerLocation,
    required this.nearbyRestaurants,
    required this.staticMapUrl,
    required this.embedUrl,
    required this.streetViewAvailable,
    this.deliveryPersonLocation,
    this.routeInfo,
    this.deliveryEstimate,
    this.restaurantTimeZone,
    this.customerTimeZone,
    this.restaurantRoadInfo,
    this.customerRoadInfo,
    this.restaurantName,
  });

  /// Get estimated delivery time in minutes
  int get estimatedDeliveryMinutes {
    return deliveryEstimate?.estimatedDeliveryMinutes ??
        (routeInfo?.durationValue ?? 0) ~/ 60;
  }

  /// Get distance in kilometers
  double get distanceKm {
    return deliveryEstimate?.distanceInKm ??
        (routeInfo?.distanceValue ?? 0) / 1000.0;
  }

  /// Get formatted delivery time
  String get formattedDeliveryTime {
    return deliveryEstimate?.formattedDeliveryTime ??
        routeInfo?.duration ??
        '30 min';
  }

  /// Get formatted distance
  String get formattedDistance {
    return deliveryEstimate?.distanceText ??
        '${distanceKm.toStringAsFixed(1)} km';
  }
}

/// Real-time order tracking information model
class OrderTrackingInfo {
  final String orderId;
  final LatLng restaurantLocation;
  final LatLng customerLocation;
  final LatLng deliveryPersonLocation;
  final List<LatLng>? deliveryRoute;
  final DeliveryEstimate? realTimeEstimate;
  final DateTime? restaurantTime;
  final DateTime? customerTime;
  final String trackingMapUrl;
  final String embedTrackingUrl;
  final DateTime lastUpdated;

  const OrderTrackingInfo({
    required this.orderId,
    required this.restaurantLocation,
    required this.customerLocation,
    required this.deliveryPersonLocation,
    required this.trackingMapUrl,
    required this.embedTrackingUrl,
    required this.lastUpdated,
    this.deliveryRoute,
    this.realTimeEstimate,
    this.restaurantTime,
    this.customerTime,
  });

  /// Get real-time ETA in minutes
  int get realTimeETA {
    return realTimeEstimate?.estimatedDeliveryMinutes ?? 15;
  }

  /// Get formatted real-time ETA
  String get formattedRealTimeETA {
    return realTimeEstimate?.formattedDeliveryTime ?? '15 min';
  }
}

/// Restaurant location information model
class RestaurantLocationInfo {
  final LatLng restaurantLocation;
  final String restaurantName;
  final List<Place> places;
  final TimeZoneInfo? timeZone;
  final RoadInfo? roadInfo;
  final bool streetViewAvailable;
  final String? streetViewUrl;
  final List<Place> nearbyRestaurants;
  final String staticMapUrl;
  final String embedUrl;

  const RestaurantLocationInfo({
    required this.restaurantLocation,
    required this.restaurantName,
    required this.places,
    required this.streetViewAvailable,
    required this.nearbyRestaurants,
    required this.staticMapUrl,
    required this.embedUrl,
    this.timeZone,
    this.roadInfo,
    this.streetViewUrl,
  });

  /// Get current time at restaurant
  DateTime? get currentTime =>
      timeZone != null ? DateTime.now().add(timeZone!.offsetDuration) : null;

  /// Get formatted current time
  String? get formattedCurrentTime {
    final time = currentTime;
    return time != null
        ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
        : null;
  }
}

/// Delivery area information model
class DeliveryAreaInfo {
  final LatLng center;
  final double radiusKm;
  final TimeZoneInfo? timeZone;
  final List<Place> nearbyRestaurants;
  final String staticMapUrl;
  final String embedUrl;

  const DeliveryAreaInfo({
    required this.center,
    required this.radiusKm,
    required this.nearbyRestaurants,
    required this.staticMapUrl,
    required this.embedUrl,
    this.timeZone,
  });

  /// Get delivery area in square kilometers
  double get areaKm2 => 3.14159 * radiusKm * radiusKm;

  /// Get current time in delivery area
  DateTime? get currentTime =>
      timeZone != null ? DateTime.now().add(timeZone!.offsetDuration) : null;
}
