import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import '../config/maps_config.dart';

/// Enhanced location data with rich address information
class EnhancedLocationData {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final Placemark? placemark;
  final String? formattedAddress;
  final String? streetNumber;
  final String? route;
  final String? locality;
  final String? administrativeArea;
  final String? country;
  final String? postalCode;
  final String? neighborhood;
  final String? subLocality;
  final DateTime timestamp;

  const EnhancedLocationData({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
    this.altitude,
    this.speed,
    this.placemark,
    this.formattedAddress,
    this.streetNumber,
    this.route,
    this.locality,
    this.administrativeArea,
    this.country,
    this.postalCode,
    this.neighborhood,
    this.subLocality,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  /// Get a user-friendly address string
  String get displayAddress {
    if (formattedAddress != null && formattedAddress!.isNotEmpty) {
      return formattedAddress!;
    }

    // Build address from components
    final parts = <String>[];

    if (streetNumber != null && streetNumber!.isNotEmpty) {
      parts.add(streetNumber!);
    }
    if (route != null && route!.isNotEmpty) {
      parts.add(route!);
    }
    if (locality != null && locality!.isNotEmpty) {
      parts.add(locality!);
    }

    if (parts.isNotEmpty) {
      return parts.join(', ');
    }

    // Fallback to coordinates
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }

  /// Get short address (street + city)
  String get shortAddress {
    final parts = <String>[];

    if (route != null && route!.isNotEmpty) {
      parts.add(route!);
    }
    if (locality != null && locality!.isNotEmpty) {
      parts.add(locality!);
    }

    if (parts.isNotEmpty) {
      return parts.join(', ');
    }

    return displayAddress;
  }

  @override
  String toString() {
    return 'EnhancedLocationData(lat: $latitude, lng: $longitude, address: $displayAddress)';
  }
}

/// Google Maps Geocoding API response models
class GeocodingResult {
  final List<AddressComponent> addressComponents;
  final String formattedAddress;
  final Geometry geometry;
  final String placeId;
  final List<String> types;

  GeocodingResult({
    required this.addressComponents,
    required this.formattedAddress,
    required this.geometry,
    required this.placeId,
    required this.types,
  });

  factory GeocodingResult.fromJson(Map<String, dynamic> json) {
    return GeocodingResult(
      addressComponents: (json['address_components'] as List)
          .map((e) => AddressComponent.fromJson(e))
          .toList(),
      formattedAddress: json['formatted_address'] ?? '',
      geometry: Geometry.fromJson(json['geometry']),
      placeId: json['place_id'] ?? '',
      types: List<String>.from(json['types'] ?? []),
    );
  }
}

class AddressComponent {
  final String longName;
  final String shortName;
  final List<String> types;

  AddressComponent({
    required this.longName,
    required this.shortName,
    required this.types,
  });

  factory AddressComponent.fromJson(Map<String, dynamic> json) {
    return AddressComponent(
      longName: json['long_name'] ?? '',
      shortName: json['short_name'] ?? '',
      types: List<String>.from(json['types'] ?? []),
    );
  }
}

class Geometry {
  final Location location;
  final String locationType;
  final Viewport? viewport;

  Geometry({
    required this.location,
    required this.locationType,
    this.viewport,
  });

  factory Geometry.fromJson(Map<String, dynamic> json) {
    return Geometry(
      location: Location.fromJson(json['location']),
      locationType: json['location_type'] ?? '',
      viewport:
          json['viewport'] != null ? Viewport.fromJson(json['viewport']) : null,
    );
  }
}

class Location {
  final double lat;
  final double lng;

  Location({required this.lat, required this.lng});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      lat: (json['lat'] ?? 0.0).toDouble(),
      lng: (json['lng'] ?? 0.0).toDouble(),
    );
  }
}

class Viewport {
  final Location northeast;
  final Location southwest;

  Viewport({required this.northeast, required this.southwest});

  factory Viewport.fromJson(Map<String, dynamic> json) {
    return Viewport(
      northeast: Location.fromJson(json['northeast']),
      southwest: Location.fromJson(json['southwest']),
    );
  }
}

/// Enhanced location service using Google Maps API
class EnhancedLocationService {
  static final EnhancedLocationService _instance =
      EnhancedLocationService._internal();
  factory EnhancedLocationService() => _instance;
  EnhancedLocationService._internal();

  // Cache for geocoding results
  final Map<String, EnhancedLocationData> _locationCache = {};
  final Map<String, GeocodingResult> _geocodingCache = {};
  static const Duration _cacheTimeout = Duration(hours: 24);
  final Map<String, DateTime> _cacheTimestamps = {};

  // Offline fallback cache for when API is unavailable
  final Map<String, EnhancedLocationData> _offlineCache = {};
  static const Duration _offlineCacheTimeout =
      Duration(days: 7); // Keep offline cache longer

  /// Clear expired cache entries
  void _clearExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    final expiredOfflineKeys = <String>[];

    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) > _cacheTimeout) {
        expiredKeys.add(entry.key);
      }
    }

    // Check offline cache expiration
    for (final entry in _offlineCache.entries) {
      final cacheKey = entry.key;
      if (_cacheTimestamps.containsKey(cacheKey)) {
        if (now.difference(_cacheTimestamps[cacheKey]!) >
            _offlineCacheTimeout) {
          expiredOfflineKeys.add(cacheKey);
        }
      }
    }

    for (final key in expiredKeys) {
      _locationCache.remove(key);
      _geocodingCache.remove(key);
      _cacheTimestamps.remove(key);
    }

    expiredOfflineKeys.forEach(_offlineCache.remove);

    if (expiredKeys.isNotEmpty || expiredOfflineKeys.isNotEmpty) {
      debugPrint(
          '🗑️ Cleared ${expiredKeys.length} expired cache entries and ${expiredOfflineKeys.length} offline entries');
    }
  }

  /// Get cache key for coordinates
  String _getCoordinateCacheKey(double lat, double lng) {
    return '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
  }

  /// Get cache key for address
  String _getAddressCacheKey(String address) {
    return address.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Reverse geocoding using Google Maps API with offline fallback
  Future<EnhancedLocationData> reverseGeocode(
      double latitude, double longitude) async {
    try {
      _clearExpiredCache();

      final cacheKey = _getCoordinateCacheKey(latitude, longitude);

      // Check cache first
      if (_locationCache.containsKey(cacheKey)) {
        debugPrint('📋 Using cached location data for: $latitude, $longitude');
        return _locationCache[cacheKey]!;
      }

      // Check offline cache as fallback
      if (_offlineCache.containsKey(cacheKey)) {
        debugPrint(
            '📱 Using offline cached location data for: $latitude, $longitude');
        return _offlineCache[cacheKey]!;
      }

      debugPrint(
          '🌐 Reverse geocoding with Google Maps API: $latitude, $longitude');

      final url = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json'
          '?latlng=$latitude,$longitude'
          '&key=${MapsConfig.googleMapsApiKey}'
          '&language=en'
          '&region=dz' // Algeria region
          );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = GeocodingResult.fromJson(data['results'][0]);

          // Extract address components
          String? streetNumber;
          String? route;
          String? locality;
          String? administrativeArea;
          String? country;
          String? postalCode;
          String? neighborhood;
          String? subLocality;

          for (final component in result.addressComponents) {
            if (component.types.contains('street_number')) {
              streetNumber = component.longName;
            } else if (component.types.contains('route')) {
              route = component.longName;
            } else if (component.types.contains('locality')) {
              locality = component.longName;
            } else if (component.types
                .contains('administrative_area_level_1')) {
              administrativeArea = component.longName;
            } else if (component.types.contains('country')) {
              country = component.longName;
            } else if (component.types.contains('postal_code')) {
              postalCode = component.longName;
            } else if (component.types.contains('neighborhood')) {
              neighborhood = component.longName;
            } else if (component.types.contains('sublocality')) {
              subLocality = component.longName;
            }
          }

          // Create enhanced location data
          final enhancedLocation = EnhancedLocationData(
            latitude: latitude,
            longitude: longitude,
            formattedAddress: result.formattedAddress,
            streetNumber: streetNumber,
            route: route,
            locality: locality,
            administrativeArea: administrativeArea,
            country: country,
            postalCode: postalCode,
            neighborhood: neighborhood,
            subLocality: subLocality,
            timestamp: DateTime.now(),
          );

          // Cache the result in both online and offline caches
          _locationCache[cacheKey] = enhancedLocation;
          _offlineCache[cacheKey] = enhancedLocation;
          _cacheTimestamps[cacheKey] = DateTime.now();

          debugPrint(
              '✅ Enhanced location cached: ${enhancedLocation.displayAddress}');
          return enhancedLocation;
        } else {
          throw Exception('Geocoding failed: ${data['status']}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Reverse geocoding failed: $e');

      // Try to find a nearby cached location as fallback
      final nearbyLocation = _findNearbyCachedLocation(latitude, longitude);
      if (nearbyLocation != null) {
        debugPrint(
            '📍 Using nearby cached location: ${nearbyLocation.displayAddress}');
        return nearbyLocation;
      }

      // Final fallback to basic location data
      return EnhancedLocationData(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
      );
    }
  }

  /// Find a nearby cached location within reasonable distance
  EnhancedLocationData? _findNearbyCachedLocation(
      double latitude, double longitude) {
    const double maxDistance = 0.01; // ~1km radius

    for (final entry in _offlineCache.entries) {
      final cachedLocation = entry.value;
      final distance = _calculateDistance(
        latitude,
        longitude,
        cachedLocation.latitude,
        cachedLocation.longitude,
      );

      if (distance <= maxDistance) {
        return cachedLocation;
      }
    }

    return null;
  }

  /// Calculate distance between two coordinates (simple approximation)
  double _calculateDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    final double dLat = (lat2 - lat1) * (pi / 180);
    final double dLng = (lng2 - lng1) * (pi / 180);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final double c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  /// Forward geocoding using Google Maps API
  Future<List<EnhancedLocationData>> forwardGeocode(String address) async {
    try {
      _clearExpiredCache();

      final cacheKey = _getAddressCacheKey(address);

      // Check cache first
      if (_geocodingCache.containsKey(cacheKey)) {
        debugPrint('📋 Using cached geocoding result for: $address');
        final cachedResult = _geocodingCache[cacheKey]!;
        return [_createEnhancedLocationFromGeocodingResult(cachedResult)];
      }

      debugPrint('🌐 Forward geocoding with Google Maps API: $address');

      final encodedAddress = Uri.encodeComponent(address);
      final url = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json'
          '?address=$encodedAddress'
          '&key=${MapsConfig.googleMapsApiKey}'
          '&language=en'
          '&region=dz' // Algeria region
          );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final results = <EnhancedLocationData>[];

          for (final resultData in data['results']) {
            final result = GeocodingResult.fromJson(resultData);
            final enhancedLocation =
                _createEnhancedLocationFromGeocodingResult(result);
            results.add(enhancedLocation);
          }

          // Cache the first result
          if (results.isNotEmpty) {
            _geocodingCache[cacheKey] =
                GeocodingResult.fromJson(data['results'][0]);
            _cacheTimestamps[cacheKey] = DateTime.now();
          }

          debugPrint(
              '✅ Forward geocoding successful: ${results.length} results');
          return results;
        } else {
          throw Exception('Geocoding failed: ${data['status']}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Forward geocoding failed: $e');
      return [];
    }
  }

  /// Create enhanced location from geocoding result
  EnhancedLocationData _createEnhancedLocationFromGeocodingResult(
      GeocodingResult result) {
    String? streetNumber;
    String? route;
    String? locality;
    String? administrativeArea;
    String? country;
    String? postalCode;
    String? neighborhood;
    String? subLocality;

    for (final component in result.addressComponents) {
      if (component.types.contains('street_number')) {
        streetNumber = component.longName;
      } else if (component.types.contains('route')) {
        route = component.longName;
      } else if (component.types.contains('locality')) {
        locality = component.longName;
      } else if (component.types.contains('administrative_area_level_1')) {
        administrativeArea = component.longName;
      } else if (component.types.contains('country')) {
        country = component.longName;
      } else if (component.types.contains('postal_code')) {
        postalCode = component.longName;
      } else if (component.types.contains('neighborhood')) {
        neighborhood = component.longName;
      } else if (component.types.contains('sublocality')) {
        subLocality = component.longName;
      }
    }

    return EnhancedLocationData(
      latitude: result.geometry.location.lat,
      longitude: result.geometry.location.lng,
      formattedAddress: result.formattedAddress,
      streetNumber: streetNumber,
      route: route,
      locality: locality,
      administrativeArea: administrativeArea,
      country: country,
      postalCode: postalCode,
      neighborhood: neighborhood,
      subLocality: subLocality,
      timestamp: DateTime.now(),
    );
  }

  /// Get current location with enhanced address information
  Future<EnhancedLocationData?> getCurrentLocationWithAddress() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      // Check permissions
      final permission = await Permission.location.status;
      if (permission == PermissionStatus.denied ||
          permission == PermissionStatus.permanentlyDenied) {
        throw Exception('Location permission denied');
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      // Get enhanced address information
      final enhancedLocation =
          await reverseGeocode(position.latitude, position.longitude);

      return EnhancedLocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
        speed: position.speed,
        formattedAddress: enhancedLocation.formattedAddress,
        streetNumber: enhancedLocation.streetNumber,
        route: enhancedLocation.route,
        locality: enhancedLocation.locality,
        administrativeArea: enhancedLocation.administrativeArea,
        country: enhancedLocation.country,
        postalCode: enhancedLocation.postalCode,
        neighborhood: enhancedLocation.neighborhood,
        subLocality: enhancedLocation.subLocality,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ Failed to get current location with address: $e');
      return null;
    }
  }

  /// Search for places using Google Places API
  Future<List<EnhancedLocationData>> searchPlaces(String query,
      {double? latitude, double? longitude}) async {
    try {
      debugPrint('🔍 Searching places: $query');

      String url = 'https://maps.googleapis.com/maps/api/place/textsearch/json'
          '?query=${Uri.encodeComponent(query)}'
          '&key=${MapsConfig.googleMapsApiKey}'
          '&language=en'
          '&region=dz';

      // Add location bias if provided
      if (latitude != null && longitude != null) {
        url += '&location=$latitude,$longitude&radius=50000'; // 50km radius
      }

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final results = <EnhancedLocationData>[];

          for (final placeData in data['results']) {
            final location =
                Location.fromJson(placeData['geometry']['location']);

            // Get detailed address information
            final enhancedLocation =
                await reverseGeocode(location.lat, location.lng);

            results.add(EnhancedLocationData(
              latitude: location.lat,
              longitude: location.lng,
              formattedAddress: placeData['formatted_address'] ??
                  enhancedLocation.formattedAddress,
              locality: enhancedLocation.locality,
              administrativeArea: enhancedLocation.administrativeArea,
              country: enhancedLocation.country,
              timestamp: DateTime.now(),
            ));
          }

          debugPrint('✅ Places search successful: ${results.length} results');
          return results;
        } else {
          throw Exception('Places search failed: ${data['status']}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Places search failed: $e');
      return [];
    }
  }

  /// Clear all caches
  void clearCache() {
    _locationCache.clear();
    _geocodingCache.clear();
    _offlineCache.clear();
    _cacheTimestamps.clear();
    debugPrint('🗑️ Cleared all enhanced location caches');
  }

  /// Get cache statistics
  Map<String, int> getCacheStats() {
    return {
      'location_cache': _locationCache.length,
      'geocoding_cache': _geocodingCache.length,
      'offline_cache': _offlineCache.length,
      'total_entries': _cacheTimestamps.length,
    };
  }
}
