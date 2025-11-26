import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Service for managing user location and location permissions
class LocationService extends ChangeNotifier {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Current location
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;

  // Location permission status
  LocationPermission _permissionStatus = LocationPermission.denied;

  // Location accuracy settings
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10, // Update every 10 meters
  );

  // Getters
  Position? get currentPosition => _currentPosition;
  LocationPermission get permissionStatus => _permissionStatus;
  bool get hasLocation => _currentPosition != null;
  double? get latitude => _currentPosition?.latitude;
  double? get longitude => _currentPosition?.longitude;

  /// Initialize the location service
  Future<void> initialize() async {
    debugPrint('🚀 LocationService initializing...');

    // Check and request permissions
    await _checkPermissions();

    // Get initial location if permission granted
    if (_permissionStatus == LocationPermission.whileInUse ||
        _permissionStatus == LocationPermission.always) {
      await getCurrentLocation();
    }

    debugPrint('✅ LocationService initialized');
  }

  /// Check location permissions (without requesting)
  Future<void> _checkPermissions() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('❌ Location services are disabled');
        _permissionStatus = LocationPermission.denied;
        return;
      }

      // Only check current permission status, do NOT request automatically
      _permissionStatus = await Geolocator.checkPermission();

      if (_permissionStatus == LocationPermission.deniedForever) {
        debugPrint('❌ Location permissions are permanently denied');
        return;
      }

      debugPrint('✅ Location permission status: $_permissionStatus');
    } catch (e) {
      debugPrint('❌ Error checking location permissions: $e');
    }
  }

  /// Get current location
  Future<Position?> getCurrentLocation() async {
    try {
      if (_permissionStatus != LocationPermission.whileInUse &&
          _permissionStatus != LocationPermission.always) {
        debugPrint('❌ Location permission not granted');
        return null;
      }

      debugPrint('📍 Getting current location...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _currentPosition = position;
      notifyListeners();

      debugPrint(
          '✅ Current location: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      debugPrint('❌ Error getting current location: $e');
      return null;
    }
  }

  /// Start listening to location updates
  Future<void> startLocationUpdates() async {
    try {
      if (_permissionStatus != LocationPermission.whileInUse &&
          _permissionStatus != LocationPermission.always) {
        debugPrint('❌ Location permission not granted for continuous updates');
        return;
      }

      debugPrint('📍 Starting location updates...');

      _positionStream = Geolocator.getPositionStream(
        locationSettings: _locationSettings,
      ).listen(
        (Position position) {
          _currentPosition = position;
          notifyListeners();
          debugPrint(
              '📍 Location updated: ${position.latitude}, ${position.longitude}');
        },
        onError: (error) {
          debugPrint('❌ Error in location stream: $error');
        },
      );
    } catch (e) {
      debugPrint('❌ Error starting location updates: $e');
    }
  }

  /// Stop listening to location updates
  void stopLocationUpdates() {
    _positionStream?.cancel();
    _positionStream = null;
    debugPrint('📍 Location updates stopped');
  }

  /// Calculate distance between current location and target coordinates
  Future<double?> calculateDistanceTo({
    required double targetLatitude,
    required double targetLongitude,
  }) async {
    if (_currentPosition == null) {
      debugPrint('❌ No current location available');
      return null;
    }

    try {
      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        targetLatitude,
        targetLongitude,
      );

      // Convert from meters to kilometers
      return distance / 1000.0;
    } catch (e) {
      debugPrint('❌ Error calculating distance: $e');
      return null;
    }
  }

  /// Check if location permission is granted
  bool get hasPermission {
    return _permissionStatus == LocationPermission.whileInUse ||
        _permissionStatus == LocationPermission.always;
  }

  /// Request location permission
  Future<bool> requestPermission() async {
    try {
      _permissionStatus = await Geolocator.requestPermission();

      if (_permissionStatus == LocationPermission.whileInUse ||
          _permissionStatus == LocationPermission.always) {
        await getCurrentLocation();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error requesting location permission: $e');
      return false;
    }
  }

  /// Open app settings for location permission
  Future<void> openAppSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      debugPrint('❌ Error opening app settings: $e');
    }
  }

  /// Get location permission status as string
  String get permissionStatusString {
    switch (_permissionStatus) {
      case LocationPermission.denied:
        return 'denied';
      case LocationPermission.deniedForever:
        return 'denied_forever';
      case LocationPermission.whileInUse:
        return 'while_in_use';
      case LocationPermission.always:
        return 'always';
      case LocationPermission.unableToDetermine:
        return 'unable_to_determine';
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    stopLocationUpdates();
    super.dispose();
  }
}
