// ignore_for_file: join_return_with_assignment

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'error_logging_service.dart';

class LocationData {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final Placemark? placemark;

  const LocationData({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    this.speed,
    this.placemark,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  @override
  String toString() {
    return 'LocationData(lat: $latitude, lng: $longitude, accuracy: $accuracy)';
  }
}

class GeolocationService {
  static final GeolocationService _instance = GeolocationService._internal();
  factory GeolocationService() => _instance;
  GeolocationService._internal();

  // Error logging service
  final ErrorLoggingService _errorLogger = ErrorLoggingService();

  StreamSubscription<Position>? _positionStream;
  final StreamController<LocationData> _locationController =
      StreamController<LocationData>.broadcast();

  // Geocoding cache to avoid repeated API calls
  final Map<String, LatLng> _geocodingCache = {};
  final Map<String, String> _reverseGeocodingCache = {};
  static const Duration _cacheTimeout = Duration(hours: 24);
  final Map<String, DateTime> _cacheTimestamps = {};

  Stream<LocationData> get locationStream => _locationController.stream;

  /// Clear expired cache entries
  void _clearExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) > _cacheTimeout) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _geocodingCache.remove(key);
      _reverseGeocodingCache.remove(key);
      _cacheTimestamps.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      debugPrint(
          '🗑️ Cleared ${expiredKeys.length} expired geocoding cache entries');
    }
  }

  /// Get cache key for address
  String _getAddressCacheKey(String address) {
    return address.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Get cache key for coordinates
  String _getCoordinateCacheKey(double lat, double lng) {
    return '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  /// Request location permissions
  Future<PermissionStatus> requestLocationPermission() async {
    try {
      // Use Geolocator for consistent permission requesting
      final geolocatorPermission = await Geolocator.requestPermission();

      // Convert Geolocator permission to PermissionStatus
      switch (geolocatorPermission) {
        case LocationPermission.denied:
          return PermissionStatus.denied;
        case LocationPermission.deniedForever:
          return PermissionStatus.permanentlyDenied;
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          return PermissionStatus.granted;
        case LocationPermission.unableToDetermine:
          return PermissionStatus.denied;
      }
    } catch (e) {
      debugPrint('❌ Error requesting location permission: $e');
      // Fallback to permission_handler
      final status = await Permission.location.request();
      return status;
    }
  }

  /// Check current location permission status
  Future<PermissionStatus> checkLocationPermission() async {
    try {
      // Use Geolocator for consistent permission checking
      final geolocatorPermission = await Geolocator.checkPermission();

      // Convert Geolocator permission to PermissionStatus
      switch (geolocatorPermission) {
        case LocationPermission.denied:
          return PermissionStatus.denied;
        case LocationPermission.deniedForever:
          return PermissionStatus.permanentlyDenied;
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          return PermissionStatus.granted;
        case LocationPermission.unableToDetermine:
          return PermissionStatus.denied;
      }
    } catch (e) {
      debugPrint('❌ Error checking location permission: $e');
      // Fallback to permission_handler
      return Permission.location.status;
    }
  }

  /// Get last known location (very fast, may be null)
  Future<LocationData?> getLastKnownLocation() async {
    try {
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      final permission = await checkLocationPermission();
      if (permission == PermissionStatus.denied ||
          permission == PermissionStatus.permanentlyDenied) {
        return null;
      }

      final position = await Geolocator.getLastKnownPosition();
      if (position == null) {
        return null;
      }

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
        speed: position.speed,
        placemark: null, // do not block on geocoding here
      );
    } catch (_) {
      return null;
    }
  }

  /// Get current position with fast response and accuracy validation
  Future<LocationData?> getCurrentLocation() async {
    const int maxRetries = 3;
    const double minAccuracy = 100.0; // Minimum accuracy in meters

    final stopwatch = Stopwatch()..start();

    try {
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          // Check if location services are enabled
          final serviceEnabled = await isLocationServiceEnabled();
          if (!serviceEnabled) {
            throw Exception('Location services are disabled');
          }

          // Check permissions
          final permission = await checkLocationPermission();
          if (permission == PermissionStatus.denied ||
              permission == PermissionStatus.permanentlyDenied) {
            throw Exception('Location permission denied');
          }

          // Get current position with faster settings
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium, // Faster than high accuracy
              timeLimit: Duration(seconds: 8), // Reduced from 15 to 8 seconds
            ),
          );

          // Validate accuracy
          if (position.accuracy <= minAccuracy) {
            stopwatch.stop();
            debugPrint(
                '✅ Location accuracy acceptable: ${position.accuracy.toStringAsFixed(1)}m (${stopwatch.elapsedMilliseconds}ms)');

            // Log successful location retrieval
            _errorLogger.logInfo(
              'Location retrieved successfully',
              context: 'GeolocationService.getCurrentLocation',
              additionalData: {
                'accuracy': position.accuracy,
                'attempt': attempt,
                'duration_ms': stopwatch.elapsedMilliseconds,
              },
            );

            return LocationData(
              latitude: position.latitude,
              longitude: position.longitude,
              accuracy: position.accuracy,
              altitude: position.altitude,
              speed: position.speed,
              placemark: null,
            );
          } else {
            debugPrint(
                '⚠️ Location accuracy too low: ${position.accuracy.toStringAsFixed(1)}m (attempt $attempt/$maxRetries)');

            if (attempt < maxRetries) {
              // Wait before retry with exponential backoff
              await Future.delayed(Duration(seconds: attempt * 2));
              continue;
            } else {
              // Accept the location even if accuracy is not ideal
              stopwatch.stop();
              debugPrint(
                  '⚠️ Using location with suboptimal accuracy: ${position.accuracy.toStringAsFixed(1)}m (${stopwatch.elapsedMilliseconds}ms)');

              // Log suboptimal accuracy
              _errorLogger.logWarning(
                'Location accuracy suboptimal',
                context: 'GeolocationService.getCurrentLocation',
                additionalData: {
                  'accuracy': position.accuracy,
                  'attempt': attempt,
                  'duration_ms': stopwatch.elapsedMilliseconds,
                },
              );

              return LocationData(
                latitude: position.latitude,
                longitude: position.longitude,
                accuracy: position.accuracy,
                altitude: position.altitude,
                speed: position.speed,
                placemark: null,
              );
            }
          }
        } catch (e) {
          debugPrint('❌ Location attempt $attempt failed: $e');

          if (attempt < maxRetries) {
            // Wait before retry
            await Future.delayed(Duration(seconds: attempt));
            continue;
          } else {
            stopwatch.stop();
            // Log final failure
            _errorLogger.logError(
              'Failed to get current location after all attempts',
              context: 'GeolocationService.getCurrentLocation',
              additionalData: {
                'attempts': maxRetries,
                'duration_ms': stopwatch.elapsedMilliseconds,
                'error': e.toString(),
              },
            );
            throw Exception(
                'Failed to get current location after $maxRetries attempts: $e');
          }
        }
      }
    } catch (e) {
      stopwatch.stop();
      // Log critical error
      _errorLogger.logError(
        'Critical error in getCurrentLocation',
        context: 'GeolocationService.getCurrentLocation',
        additionalData: {
          'duration_ms': stopwatch.elapsedMilliseconds,
          'error': e.toString(),
        },
      );
      rethrow;
    }

    return null;
  }

  /// Get fast location with enhanced reliability and fallback methods
  Future<LocationData?> getFastLocation() async {
    const int maxRetries = 3;

    try {
      // First try last known location (fastest)
      final lastKnown = await getLastKnownLocation();
      if (lastKnown != null) {
        debugPrint('📍 Using last known location for fast response');
        return lastKnown;
      }

      // Check basic requirements
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('❌ Location services disabled');
        return null;
      }

      final permission = await checkLocationPermission();
      if (permission == PermissionStatus.denied ||
          permission == PermissionStatus.permanentlyDenied) {
        debugPrint('❌ Location permission denied');
        return null;
      }

      // Try progressive accuracy levels for better success rate
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          debugPrint('🔄 Fast location attempt $attempt/$maxRetries');

          LocationAccuracy accuracy;
          Duration timeLimit;

          switch (attempt) {
            case 1:
              accuracy = LocationAccuracy.lowest; // Fastest
              timeLimit = const Duration(seconds: 3);
              break;
            case 2:
              accuracy = LocationAccuracy.low;
              timeLimit = const Duration(seconds: 5);
              break;
            default:
              accuracy = LocationAccuracy.medium;
              timeLimit = const Duration(seconds: 8);
          }

          final position = await Geolocator.getCurrentPosition(
            locationSettings: LocationSettings(
              accuracy: accuracy,
              timeLimit: timeLimit,
              distanceFilter:
                  attempt == 1 ? 200 : 50, // More lenient for first attempt
            ),
          );

          debugPrint(
              '✅ Fast location success: ${position.accuracy.toStringAsFixed(1)}m accuracy');

          return LocationData(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
            altitude: position.altitude,
            speed: position.speed,
            placemark: null,
          );
        } catch (e) {
          debugPrint('❌ Fast location attempt $attempt failed: $e');

          if (attempt < maxRetries) {
            // Short delay before retry
            await Future.delayed(Duration(milliseconds: 500 * attempt));
            continue;
          } else {
            debugPrint('❌ All fast location attempts failed');
            return null;
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ Fast location completely failed: $e');
      return null;
    }
  }

  /// Get fresh current location with best accuracy (for critical operations like map initialization)
  Future<LocationData?> getFreshCurrentLocation() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      // Check permissions
      final permission = await checkLocationPermission();
      if (permission == PermissionStatus.denied ||
          permission == PermissionStatus.permanentlyDenied) {
        throw Exception('Location permission denied');
      }

      // Get fresh position with best accuracy settings
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy:
              LocationAccuracy.best, // Use best accuracy for map initialization
          timeLimit: Duration(seconds: 20), // Longer timeout for fresh location
        ),
      );

      // Validate accuracy - reject if too inaccurate
      if (position.accuracy > 100) {
        // More than 100 meters accuracy is not good enough
        throw Exception(
            'Location accuracy too low: ${position.accuracy.toStringAsFixed(1)}m');
      }

      // Return immediately; do not block on address
      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
        speed: position.speed,
        placemark: null,
      );
    } catch (e) {
      throw Exception('Failed to get fresh current location: $e');
    }
  }

  /// Start location updates
  Future<void> startLocationUpdates() async {
    try {
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      final permission = await checkLocationPermission();
      if (permission == PermissionStatus.denied ||
          permission == PermissionStatus.permanentlyDenied) {
        throw Exception('Location permission denied');
      }

      // Cancel existing stream if any
      await stopLocationUpdates();

      // Start listening to position updates
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // Update every 5 meters for better precision
          timeLimit: Duration(seconds: 15),
        ),
      ).listen(
        (Position position) async {
          Placemark? placemark;
          try {
            final placemarks = await placemarkFromCoordinates(
              position.latitude,
              position.longitude,
            );
            if (placemarks.isNotEmpty) {
              placemark = placemarks.first;
            }
          } catch (e) {
            // Address lookup failed
          }

          final locationData = LocationData(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
            altitude: position.altitude,
            speed: position.speed,
            placemark: placemark,
          );

          _locationController.add(locationData);
        },
        onError: (error) {
          _locationController.addError('Location update error: $error');
        },
      );
    } catch (e) {
      throw Exception('Failed to start location updates: $e');
    }
  }

  /// Stop location updates
  Future<void> stopLocationUpdates() async {
    await _positionStream?.cancel();
    _positionStream = null;
  }

  /// Get address from coordinates (with caching)
  Future<List<Placemark>> getAddressFromCoordinates(
      double latitude, double longitude) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Clear expired cache entries periodically
      _clearExpiredCache();

      final cacheKey = _getCoordinateCacheKey(latitude, longitude);

      // Check cache first
      if (_reverseGeocodingCache.containsKey(cacheKey)) {
        stopwatch.stop();
        debugPrint(
            '📋 Using cached address for coordinates: $cacheKey (${stopwatch.elapsedMilliseconds}ms)');

        // Log cache hit
        _errorLogger.logInfo(
          'Address geocoding cache hit',
          context: 'GeolocationService.getAddressFromCoordinates',
          additionalData: {
            'coordinates': '$latitude,$longitude',
            'duration_ms': stopwatch.elapsedMilliseconds,
            'cache_key': cacheKey,
          },
        );

        // Return a mock Placemark with cached address
        return [
          Placemark(
            street: _reverseGeocodingCache[cacheKey],
            locality: '',
            administrativeArea: '',
            country: '',
            postalCode: '',
            name: '',
            subLocality: '',
            subAdministrativeArea: '',
            thoroughfare: '',
            subThoroughfare: '',
          )
        ];
      }

      debugPrint('🌐 Geocoding coordinates: $latitude, $longitude');
      final placemarks = await placemarkFromCoordinates(latitude, longitude)
          .timeout(const Duration(
              seconds: 8)); // Reduced timeout for faster response

      stopwatch.stop();

      if (placemarks.isNotEmpty) {
        // Cache the result
        final address = placemarks.first.street ??
            placemarks.first.locality ??
            'Unknown Address';
        _reverseGeocodingCache[cacheKey] = address;
        _cacheTimestamps[cacheKey] = DateTime.now();
        debugPrint(
            '✅ Cached address: $address (${stopwatch.elapsedMilliseconds}ms)');

        // Log successful geocoding
        _errorLogger.logInfo(
          'Address geocoding successful',
          context: 'GeolocationService.getAddressFromCoordinates',
          additionalData: {
            'coordinates': '$latitude,$longitude',
            'duration_ms': stopwatch.elapsedMilliseconds,
            'address': address,
            'cache_key': cacheKey,
          },
        );
      }

      return placemarks;
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ Geocoding failed: $e (${stopwatch.elapsedMilliseconds}ms)');

      // Log geocoding error
      _errorLogger.logError(
        'Address geocoding failed',
        context: 'GeolocationService.getAddressFromCoordinates',
        additionalData: {
          'coordinates': '$latitude,$longitude',
          'duration_ms': stopwatch.elapsedMilliseconds,
          'error': e.toString(),
        },
      );

      throw Exception('Failed to get address: $e');
    }
  }

  /// Get coordinates from address (with caching and optimization)
  Future<List<Location>> getCoordinatesFromAddress(String address) async {
    try {
      // Clear expired cache entries periodically
      _clearExpiredCache();

      final cacheKey = _getAddressCacheKey(address);

      // Check cache first
      if (_geocodingCache.containsKey(cacheKey)) {
        debugPrint('📋 Using cached coordinates for address: $address');
        final cachedLocation = _geocodingCache[cacheKey]!;
        return [
          Location(
            latitude: cachedLocation.latitude,
            longitude: cachedLocation.longitude,
            timestamp: DateTime.now(),
          )
        ];
      }

      debugPrint('🌐 Geocoding address: $address');

      // Optimize address for better geocoding results
      final optimizedAddress = _optimizeAddressForGeocoding(address);

      final locations = await locationFromAddress(optimizedAddress)
          .timeout(const Duration(seconds: 10)); // Reasonable timeout

      if (locations.isNotEmpty) {
        // Cache the result
        final location = locations.first;
        _geocodingCache[cacheKey] =
            LatLng(location.latitude, location.longitude);
        _cacheTimestamps[cacheKey] = DateTime.now();
        debugPrint(
            '✅ Cached coordinates: ${location.latitude}, ${location.longitude}');
      }

      return locations;
    } catch (e) {
      debugPrint('❌ Reverse geocoding failed: $e');
      throw Exception('Failed to get coordinates: $e');
    }
  }

  /// Optimize address for better geocoding results
  String _optimizeAddressForGeocoding(String address) {
    // Remove extra whitespace and normalize
    String optimized = address.trim().replaceAll(RegExp(r'\s+'), ' ');

    // Add Algeria context if not present (for better geocoding accuracy)
    if (!optimized.toLowerCase().contains('algeria') &&
        !optimized.toLowerCase().contains('algérie')) {
      optimized += ', Algeria';
    }

    // Remove common abbreviations that might confuse geocoding
    optimized = optimized
        .replaceAll(RegExp(r'\bSt\.?\b', caseSensitive: false), 'Street')
        .replaceAll(RegExp(r'\bAve\.?\b', caseSensitive: false), 'Avenue')
        .replaceAll(RegExp(r'\bBlvd\.?\b', caseSensitive: false), 'Boulevard')
        .replaceAll(RegExp(r'\bRd\.?\b', caseSensitive: false), 'Road');

    return optimized;
  }

  /// Calculate distance between two points
  double calculateDistance(double startLatitude, double startLongitude,
      double endLatitude, double endLongitude) {
    return Geolocator.distanceBetween(
        startLatitude, startLongitude, endLatitude, endLongitude);
  }

  /// Open location settings
  Future<bool> openLocationSettings() async {
    return Geolocator.openLocationSettings();
  }

  /// Open app settings
  Future<bool> openAppSettings() async {
    return Geolocator.openAppSettings();
  }

  /// Fast geocoding for restaurant addresses (optimized for delivery app patterns)
  Future<LatLng?> getRestaurantCoordinates(String address) async {
    try {
      // Clear expired cache entries
      _clearExpiredCache();

      final cacheKey = _getAddressCacheKey(address);

      // Check cache first
      if (_geocodingCache.containsKey(cacheKey)) {
        debugPrint('📋 Using cached restaurant coordinates: $address');
        return _geocodingCache[cacheKey];
      }

      debugPrint('🏪 Fast geocoding restaurant: $address');

      // Optimize restaurant address specifically
      final optimizedAddress = _optimizeRestaurantAddress(address);

      final locations = await locationFromAddress(optimizedAddress).timeout(
          const Duration(seconds: 6)); // Faster timeout for restaurants

      if (locations.isNotEmpty) {
        final location = locations.first;
        final coordinates = LatLng(location.latitude, location.longitude);

        // Cache the result
        _geocodingCache[cacheKey] = coordinates;
        _cacheTimestamps[cacheKey] = DateTime.now();

        debugPrint(
            '✅ Restaurant coordinates cached: ${location.latitude}, ${location.longitude}');
        return coordinates;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Restaurant geocoding failed: $e');
      return null; // Return null instead of throwing for better UX
    }
  }

  /// Optimize restaurant address for better geocoding
  String _optimizeRestaurantAddress(String address) {
    String optimized = address.trim().replaceAll(RegExp(r'\s+'), ' ');

    // Add Algeria context if not present
    if (!optimized.toLowerCase().contains('algeria') &&
        !optimized.toLowerCase().contains('algérie')) {
      optimized += ', Algeria';
    }

    // Restaurant-specific optimizations
    optimized = optimized
        .replaceAll(RegExp(r'\bRestaurant\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bRest\.?\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bCafé\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bCafe\b', caseSensitive: false), '')
        .trim();

    return optimized;
  }

  /// Clear all geocoding cache
  void clearGeocodingCache() {
    _geocodingCache.clear();
    _reverseGeocodingCache.clear();
    _cacheTimestamps.clear();
    debugPrint('🗑️ Cleared all geocoding cache');
  }

  /// Get cache statistics
  Map<String, int> getCacheStats() {
    return {
      'address_cache': _geocodingCache.length,
      'reverse_cache': _reverseGeocodingCache.length,
      'total_entries': _cacheTimestamps.length,
    };
  }

  /// Dispose resources
  void dispose() {
    stopLocationUpdates();
    _locationController.close();
    clearGeocodingCache();

    // Log service disposal
    _errorLogger.logInfo(
      'GeolocationService disposed',
      context: 'GeolocationService.dispose',
      additionalData: {
        'cache_stats': getCacheStats(),
      },
    );
  }

  /// Get location accuracy status
  Future<LocationAccuracyStatus> getLocationAccuracy() async {
    return Geolocator.getLocationAccuracy();
  }

  /// Request temporary full accuracy
  Future<LocationAccuracyStatus> requestTemporaryFullAccuracy() async {
    return Geolocator.requestTemporaryFullAccuracy(
      purposeKey: "com.example.sahla_delivery.location",
    );
  }

  /// Get comprehensive performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    final cacheStats = getCacheStats();
    return {
      'cache_stats': cacheStats,
      'is_location_stream_active': _positionStream != null,
      'has_location_controller': !_locationController.isClosed,
      'service_status': 'active',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Log performance metrics
  void logPerformanceMetrics() {
    final metrics = getPerformanceMetrics();
    _errorLogger.logInfo(
      'GeolocationService performance metrics',
      context: 'GeolocationService.logPerformanceMetrics',
      additionalData: metrics,
    );
  }
}
