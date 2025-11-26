import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/location_provider.dart';
import 'geolocation_service.dart';

// Socket-based fee updates removed

// Re-export LocationData for use in this service
export 'geolocation_service.dart' show LocationData;

/// Real-time delivery fee service
///
/// - Streams high-frequency location updates
/// - Sends customer location to Node.js server via Socket.IO
/// - Receives delivery-fee-updated events and exposes a fee stream
class RealTimeDeliveryFeeService extends ChangeNotifier {
  RealTimeDeliveryFeeService();

  final GeolocationService _geolocationService = GeolocationService();
  // No socket dependency; compute fee client-side via Supabase endpoints if needed

  StreamSubscription<LocationData>? _locationSub;
  StreamSubscription<Map<String, dynamic>>? _feeSub;

  final StreamController<double> _feeController =
      StreamController<double>.broadcast();
  Stream<double> get feeStream => _feeController.stream;

  String? _restaurantId;
  void Function(double fee)? _onFeeUpdate;
  DateTime? _lastSentAt;
  LocationData? _lastSentLocation;
  LocationData?
      _referenceLocation; // The location to use for fee calculation (manual or GPS)

  bool _running = false;
  bool get isRunning => _running;

  /// Start real-time fee updates
  Future<void> start({
    required String restaurantId,
    Duration minInterval = const Duration(seconds: 2),
    double minDistanceMeters = 25,
    void Function(double fee)? onFeeUpdate,
  }) async {
    // This method needs context to access LocationProvider
    // It will be called from widget with context
  }

  /// Start real-time fee updates with context
  Future<void> startWithContext({
    required String restaurantId,
    required dynamic context, // Use dynamic to avoid import issues
    Duration minInterval = const Duration(seconds: 2),
    double minDistanceMeters = 25,
    void Function(double fee)? onFeeUpdate,
  }) async {
    if (_running) return;

    _restaurantId = restaurantId;
    _onFeeUpdate = onFeeUpdate;
    _running = true;

    // Get LocationProvider from context
    try {
      final locationProvider =
          Provider.of<LocationProvider>(context, listen: false);

      // Set initial reference location (manual location takes priority)
      _referenceLocation = _getReferenceLocation(locationProvider);

      // Listen to LocationProvider changes using addListener
      locationProvider.addListener(() {
        final newReference = _getReferenceLocation(locationProvider);
        if (_hasLocationChanged(_referenceLocation, newReference)) {
          _referenceLocation = newReference;
          debugPrint(
              '📍 Reference location updated: ${_referenceLocation?.latitude}, ${_referenceLocation?.longitude}');
          _calculateAndSendFee();
        }
      });
    } catch (e) {
      debugPrint('❌ Failed to get LocationProvider: $e');
    }

    // Calculate initial fee if we have a reference location
    if (_referenceLocation != null) {
      await _calculateAndSendFee();
    }

    // Socket fee updates removed; fee will be computed on demand below

    // Start GPS location updates (for real-time tracking, but not for fee calculation)
    await _geolocationService.startLocationUpdates();
    _locationSub = _geolocationService.locationStream.listen((location) async {
      // Only update reference location if no manual location is set
      if (_referenceLocation == null) {
        _referenceLocation = location;
        await _calculateAndSendFee();
      }

      // Throttle GPS location sending to server (for tracking purposes)
      final now = DateTime.now();
      if (_lastSentAt != null && now.difference(_lastSentAt!) < minInterval) {
        return;
      }

      // Throttle by distance
      if (_lastSentLocation != null) {
        final d = _distanceMeters(
          _lastSentLocation!.latitude,
          _lastSentLocation!.longitude,
          location.latitude,
          location.longitude,
        );
        if (d < minDistanceMeters) {
          return;
        }
      }

      _lastSentAt = now;
      _lastSentLocation = location;

      // No socket emission
    });
  }

  /// Stop real-time updates
  Future<void> stop() async {
    _running = false;
    await _locationSub?.cancel();
    await _feeSub?.cancel();
    _locationSub = null;
    _feeSub = null;
  }

  /// Calculate and send fee based on current reference location
  Future<void> _calculateAndSendFee() async {
    if (_referenceLocation == null || _restaurantId == null) {
      return;
    }
    // Compute fee client-side by fetching config and calculating distance
    try {
      final startup = Supabase.instance.client;
      // Fetch restaurant location
      final restaurantRow = await startup
          .from('restaurants')
          .select('id, latitude, longitude')
          .eq('id', _restaurantId!)
          .single();
      final lat = (restaurantRow['latitude'] as num?)?.toDouble();
      final lng = (restaurantRow['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return;

      final distanceKm = _distanceMeters(
            _referenceLocation!.latitude,
            _referenceLocation!.longitude,
            lat,
            lng,
          ) /
          1000.0;

      // Fetch fee config
      final cfgRow = await startup
          .from('system_config')
          .select('config_value')
          .eq('config_key', 'delivery_fee_config')
          .maybeSingle();
      final config = cfgRow != null ? cfgRow['config_value'] : null;
      double fee = 0;
      if (config is Map && config['ranges'] is List) {
        final ranges = List.from(config['ranges']);
        ranges.sort((a, b) => (a['maxDistance'] as num)
            .toDouble()
            .compareTo((b['maxDistance'] as num).toDouble()));
        for (final r in ranges) {
          final maxD = (r['maxDistance'] as num).toDouble();
          if (distanceKm <= maxD) {
            fee = (r['fee'] as num).toDouble();
            break;
          }
        }
        if (fee == 0 && ranges.isNotEmpty) {
          final last = ranges.last;
          final base = (last['fee'] as num).toDouble();
          final maxD = (last['maxDistance'] as num).toDouble();
          final extra = (config['extraRangeFee'] as num?)?.toDouble() ?? 5.0;
          final extraKm = (distanceKm - maxD).clamp(0, double.infinity);
          fee = base + (extraKm * 10 * extra);
        }
      }
      fee = fee.clamp(0, 1000).toDouble();
      _feeController.add(fee);
      _onFeeUpdate?.call(fee);
    } catch (e) {
      debugPrint('❌ Fee compute failed: $e');
    }
  }

  /// Get reference location from LocationProvider (manual location takes priority)
  LocationData? _getReferenceLocation(dynamic locationProvider) {
    try {
      // Manual location takes priority over GPS location
      if (locationProvider.currentLocation != null) {
        return LocationData(
          latitude: locationProvider.currentLocation.latitude,
          longitude: locationProvider.currentLocation.longitude,
          accuracy: locationProvider.currentLocation.accuracy,
          altitude: locationProvider.currentLocation.altitude,
          speed: locationProvider.currentLocation.speed,
          placemark: locationProvider.currentLocation.placemark,
        );
      }
    } catch (e) {
      debugPrint('❌ Error getting reference location: $e');
    }
    return null;
  }

  /// Check if two locations are significantly different
  bool _hasLocationChanged(
      LocationData? oldLocation, LocationData? newLocation) {
    if (oldLocation == null || newLocation == null) {
      return oldLocation != newLocation;
    }

    const threshold = 0.001; // About 100 meters
    return (oldLocation.latitude - newLocation.latitude).abs() > threshold ||
        (oldLocation.longitude - newLocation.longitude).abs() > threshold;
  }

  @override
  void dispose() {
    stop();
    _feeController.close();
    super.dispose();
  }

  // Lightweight distance in meters (Haversine)
  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c * 1000.0;
  }

  double _toRad(double deg) => deg * (3.141592653589793 / 180.0);
}
