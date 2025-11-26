import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/enhanced_location_service.dart';
import '../services/geolocation_service.dart';
import '../services/settings_service.dart';

class LocationProvider with ChangeNotifier {
  final GeolocationService _geolocationService = GeolocationService();
  final EnhancedLocationService _enhancedLocationService =
      EnhancedLocationService();

  LocationData? _currentLocation;
  EnhancedLocationData? _enhancedLocation;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isLocationEnabled = false;
  bool _hasPermission = false;
  DateTime? _lastLocationUpdate;
  static const Duration _locationCacheTimeout =
      Duration(minutes: 5); // Cache location for 5 minutes

  // Getters
  LocationData? get currentLocation => _currentLocation;
  EnhancedLocationData? get enhancedLocation => _enhancedLocation;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLocationEnabled => _isLocationEnabled;
  bool get hasPermission => _hasPermission;

  // Position getter for smart search compatibility
  Position? get currentPosition {
    if (_currentLocation != null) {
      return Position(
        longitude: _currentLocation!.longitude,
        latitude: _currentLocation!.latitude,
        timestamp: DateTime.now(),
        accuracy: _currentLocation!.accuracy ?? 0.0,
        altitude: _currentLocation!.altitude ?? 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0, // LocationData doesn't have heading field
        headingAccuracy: 0.0,
        speed: _currentLocation!.speed ?? 0.0,
        speedAccuracy: 0.0,
      );
    }
    return null;
  }

  // Stream subscription
  StreamSubscription<LocationData>? _locationSubscription;

  // Race condition prevention: Track in-flight requests
  Completer<bool>? _pendingLocationRequest;

  LocationProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    await checkLocationStatus();
  }

  /// Check location service and permission status
  Future<void> checkLocationStatus() async {
    try {
      _isLocationEnabled = await _geolocationService.isLocationServiceEnabled();
      final permission = await _geolocationService.checkLocationPermission();
      _hasPermission = permission == PermissionStatus.granted;

      // Persist preference in DB to act on it later
      try {
        await SettingsService().setLocationEnabled(_hasPermission);
      } catch (e) {
        debugPrint(
            '⚠️ LocationProvider: Failed to persist location preference: $e');
      }

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to check location status: $e';
      notifyListeners();
    }
  }

  /// Request location permission
  Future<bool> requestPermission() async {
    try {
      final status = await _geolocationService.requestLocationPermission();
      _hasPermission = status == PermissionStatus.granted;

      if (_hasPermission) {
        await checkLocationStatus();
      }

      // Persist preference regardless of result
      try {
        await SettingsService().setLocationEnabled(_hasPermission);
      } catch (e) {
        debugPrint(
            '⚠️ LocationProvider: Failed to persist location preference: $e');
      }

      notifyListeners();
      return _hasPermission;
    } catch (e) {
      _errorMessage = 'Failed to request permission: $e';
      notifyListeners();
      return false;
    }
  }

  /// Try last known location (non-blocking, no loading state)
  Future<bool> getLastKnownLocation() async {
    try {
      final last = await _geolocationService.getLastKnownLocation();
      if (last != null) {
        _currentLocation = last;
        _lastLocationUpdate = DateTime.now();
        notifyListeners();
        // Try to enrich with address without blocking UI
        await _getAddressAsync(last.latitude, last.longitude);
        return true;
      }
      return false;
    } catch (e) {
      // ignore failures silently; it's just an optimization
      return false;
    }
  }

  /// Get current location with caching
  Future<bool> getCurrentLocation() async {
    // RACE CONDITION FIX: Return existing request if in-flight
    if (_pendingLocationRequest != null) {
      debugPrint('⚠️ LocationProvider: Location request already in-flight, returning existing');
      return _pendingLocationRequest!.future;
    }

    // Check if we have a recent cached location
    if (_currentLocation != null && _lastLocationUpdate != null) {
      final timeSinceUpdate = DateTime.now().difference(_lastLocationUpdate!);
      if (timeSinceUpdate < _locationCacheTimeout) {
        // Use cached location
        return true;
      }
    }

    // Create new request completer
    _pendingLocationRequest = Completer<bool>();

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final location = await _geolocationService.getCurrentLocation();
      if (location != null) {
        // Store the previous enhanced location to preserve address data
        final previousEnhancedLocation = _enhancedLocation;

        _currentLocation = location;
        _lastLocationUpdate = DateTime.now();
        _isLoading = false;
        notifyListeners();

        // Enrich with address asynchronously, but preserve existing enhanced data
        await _getAddressAsync(location.latitude, location.longitude);

        // If address lookup fails, restore the previous enhanced location
        Future.delayed(const Duration(seconds: 3), () {
          if (_enhancedLocation == null && previousEnhancedLocation != null) {
            _enhancedLocation = previousEnhancedLocation;
            notifyListeners();
          }
        });

        _pendingLocationRequest?.complete(true);
        return true;
      } else {
        _errorMessage = 'Unable to get current location';
        _isLoading = false;
        notifyListeners();
        _pendingLocationRequest?.complete(false);
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      _pendingLocationRequest?.complete(false);
      return false;
    } finally {
      _pendingLocationRequest = null; // Clear completer
    }
  }

  /// Get fast location with enhanced error handling and user guidance
  Future<bool> getFastLocation() async {
    // RACE CONDITION FIX: Return existing request if in-flight
    if (_pendingLocationRequest != null) {
      debugPrint('⚠️ LocationProvider: Fast location request already in-flight, returning existing');
      return _pendingLocationRequest!.future;
    }

    // Check if we have a recent cached location
    if (_currentLocation != null && _lastLocationUpdate != null) {
      final timeSinceUpdate = DateTime.now().difference(_lastLocationUpdate!);
      if (timeSinceUpdate < _locationCacheTimeout) {
        // Use cached location
        return true;
      }
    }

    // Create new request completer
    _pendingLocationRequest = Completer<bool>();

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // First check permissions and services
      await checkLocationStatus();

      if (!_hasPermission) {
        _errorMessage =
            'Location permission required. Please grant location access in settings.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (!_isLocationEnabled) {
        _errorMessage =
            'Location services disabled. Please enable GPS in device settings.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Try to get location with retry logic
      final location = await _geolocationService.getFastLocation();
      if (location != null) {
        // Store the previous enhanced location to preserve address data
        final previousEnhancedLocation = _enhancedLocation;

        _currentLocation = location;
        _lastLocationUpdate = DateTime.now();
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();

        // Get address asynchronously without blocking, but preserve existing enhanced data
        await _getAddressAsync(location.latitude, location.longitude);

        // If address lookup fails, restore the previous enhanced location
        Future.delayed(const Duration(seconds: 3), () {
          if (_enhancedLocation == null && previousEnhancedLocation != null) {
            _enhancedLocation = previousEnhancedLocation;
            notifyListeners();
          }
        });

        _pendingLocationRequest?.complete(true);
        return true;
      } else {
        _errorMessage =
            'Unable to detect location. Please check GPS signal and try again.';
        _isLoading = false;
        notifyListeners();
        _pendingLocationRequest?.complete(false);
        return false;
      }
    } catch (e) {
      debugPrint('❌ Fast location error: $e');

      // Provide user-friendly error messages
      String userMessage;
      if (e.toString().contains('permission')) {
        userMessage =
            'Location permission denied. Please grant access in app settings.';
      } else if (e.toString().contains('disabled') ||
          e.toString().contains('GPS')) {
        userMessage =
            'Location services disabled. Please enable GPS in device settings.';
      } else if (e.toString().contains('timeout')) {
        userMessage =
            'Location detection timed out. Please try again in a better signal area.';
      } else if (e.toString().contains('network')) {
        userMessage = 'Network error. Please check your internet connection.';
      } else {
        userMessage =
            'Location detection failed. Please try again or select location manually.';
      }

      _errorMessage = userMessage;
      _isLoading = false;
      notifyListeners();
      _pendingLocationRequest?.complete(false);
      return false;
    } finally {
      _pendingLocationRequest = null; // Clear completer
    }
  }

  /// Get address asynchronously using enhanced location service
  Future<void> _getAddressAsync(double latitude, double longitude) async {
    try {
      final enhancedLocation =
          await _enhancedLocationService.reverseGeocode(latitude, longitude);

      // Only update if we got valid enhanced location data
      if (enhancedLocation.displayAddress.isNotEmpty) {
        _enhancedLocation = enhancedLocation;
        notifyListeners();
      }
    } catch (e) {
      // Address lookup failed silently - keep existing enhanced location
      debugPrint('Enhanced address lookup failed: $e');
      // Don't clear _enhancedLocation on failure to preserve existing data
    }
  }

  /// Get fresh current location with best accuracy (for critical operations)
  Future<bool> getFreshCurrentLocation() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final location = await _geolocationService.getFreshCurrentLocation();
      if (location != null) {
        _currentLocation = location;
        _lastLocationUpdate = DateTime.now();
        _isLoading = false;
        notifyListeners();
        // Enrich with address asynchronously
        await _getAddressAsync(location.latitude, location.longitude);
        return true;
      } else {
        _errorMessage = 'Unable to get fresh current location';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Start location updates
  Future<bool> startLocationUpdates() async {
    try {
      await _geolocationService.startLocationUpdates();

      _locationSubscription = _geolocationService.locationStream.listen(
        (locationData) {
          _currentLocation = locationData;
          notifyListeners();
        },
        onError: (error) {
          _errorMessage = 'Location update error: $error';
          notifyListeners();
        },
      );

      return true;
    } catch (e) {
      _errorMessage = 'Failed to start location updates: $e';
      notifyListeners();
      return false;
    }
  }

  /// Stop location updates
  Future<void> stopLocationUpdates() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    await _geolocationService.stopLocationUpdates();
  }

  /// Open location settings
  Future<void> openLocationSettings() async {
    await _geolocationService.openLocationSettings();
  }

  /// Open app settings
  Future<void> openAppSettings() async {
    await _geolocationService.openAppSettings();
  }

  /// Calculate distance to a point
  double? calculateDistance(double latitude, double longitude) {
    if (_currentLocation == null) return null;

    return _geolocationService.calculateDistance(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      latitude,
      longitude,
    );
  }

  /// Get formatted address using enhanced location service
  String? getFormattedAddress() {
    // Prefer enhanced location data
    if (_enhancedLocation != null) {
      return _enhancedLocation!.displayAddress;
    }

    // Fallback to legacy placemark
    if (_currentLocation?.placemark == null) return null;

    final placemark = _currentLocation!.placemark!;
    final addressParts = [
      placemark.street,
      placemark.locality,
      placemark.administrativeArea,
      placemark.country,
    ].where((part) => part != null && part.isNotEmpty);

    return addressParts.join(', ');
  }

  /// Get enhanced current location with rich address information
  Future<bool> getEnhancedCurrentLocation() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final enhancedLocation =
          await _enhancedLocationService.getCurrentLocationWithAddress();
      if (enhancedLocation != null) {
        _enhancedLocation = enhancedLocation;
        _currentLocation = LocationData(
          latitude: enhancedLocation.latitude,
          longitude: enhancedLocation.longitude,
          accuracy: enhancedLocation.accuracy,
          altitude: enhancedLocation.altitude,
          speed: enhancedLocation.speed,
          placemark: enhancedLocation.placemark,
        );
        _lastLocationUpdate = DateTime.now();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Unable to get enhanced current location';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Search for places using enhanced location service
  Future<List<EnhancedLocationData>> searchPlaces(String query) async {
    try {
      if (_enhancedLocation != null) {
        return await _enhancedLocationService.searchPlaces(
          query,
          latitude: _enhancedLocation!.latitude,
          longitude: _enhancedLocation!.longitude,
        );
      } else {
        return await _enhancedLocationService.searchPlaces(query);
      }
    } catch (e) {
      debugPrint('Place search failed: $e');
      return [];
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Get cache statistics
  Map<String, int> getCacheStats() {
    return _enhancedLocationService.getCacheStats();
  }

  /// Clear location caches
  void clearLocationCache() {
    _enhancedLocationService.clearCache();
    notifyListeners();
  }

  /// Update location with enhanced data (for address search)
  void updateLocationWithEnhancedData(EnhancedLocationData enhancedLocation) {
    _enhancedLocation = enhancedLocation;
    _currentLocation = LocationData(
      latitude: enhancedLocation.latitude,
      longitude: enhancedLocation.longitude,
      accuracy: enhancedLocation.accuracy,
      altitude: enhancedLocation.altitude,
      speed: enhancedLocation.speed,
      placemark: enhancedLocation.placemark,
    );
    _lastLocationUpdate = DateTime.now();
    _errorMessage = null; // Clear any previous errors
    notifyListeners();
  }

  /// Get current location with enhanced address information in one call
  Future<bool> getCurrentLocationWithAddress() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Get current location first
      final location = await _geolocationService.getCurrentLocation();
      if (location == null) {
        throw Exception('Failed to get current location');
      }

      _currentLocation = location;
      _lastLocationUpdate = DateTime.now();

      // Get enhanced address information
      _enhancedLocation = await _enhancedLocationService.reverseGeocode(
        location.latitude,
        location.longitude,
      );

      debugPrint(
          '✅ Current location with address: ${_enhancedLocation?.displayAddress}');

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Failed to get current location with address: $e');
      _errorMessage = 'Failed to get location: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    stopLocationUpdates();
    _geolocationService.dispose();
    super.dispose();
  }
}
