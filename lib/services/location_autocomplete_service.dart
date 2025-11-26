import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/maps_config.dart';

/// Location prediction model
class LocationPrediction {
  final String placeId;
  final String description;
  final String? mainText;
  final String? secondaryText;
  final double? latitude;
  final double? longitude;
  final String? type;

  LocationPrediction({
    required this.placeId,
    required this.description,
    this.mainText,
    this.secondaryText,
    this.latitude,
    this.longitude,
    this.type,
  });

  factory LocationPrediction.fromGooglePlaces(Map<String, dynamic> json) {
    final structuredFormatting = json['structured_formatting'] as Map<String, dynamic>?;
    return LocationPrediction(
      placeId: json['place_id'] as String,
      description: json['description'] as String,
      mainText: structuredFormatting?['main_text'] as String?,
      secondaryText: structuredFormatting?['secondary_text'] as String?,
      type: (json['types'] as List<dynamic>?)?.first as String?,
    );
  }

  factory LocationPrediction.fromNominatim(Map<String, dynamic> json) {
    // Handle lat/lon as either String or num
    double? lat;
    double? lon;

    final latValue = json['lat'];
    if (latValue != null) {
      if (latValue is num) {
        lat = latValue.toDouble();
      } else if (latValue is String) {
        lat = double.tryParse(latValue);
      }
    }

    final lonValue = json['lon'];
    if (lonValue != null) {
      if (lonValue is num) {
        lon = lonValue.toDouble();
      } else if (lonValue is String) {
        lon = double.tryParse(lonValue);
      }
    }

    final displayName = json['display_name'] as String? ?? '';

    // Parse display name to extract main and secondary text
    final parts = displayName.split(',');
    final mainText = parts.isNotEmpty ? parts[0].trim() : displayName;
    final secondaryText = parts.length > 1
        ? parts.sublist(1).join(', ').trim()
        : null;

    // Handle place_id as either String or num
    final placeIdValue = json['place_id'];
    final placeId = placeIdValue?.toString() ?? '';

    return LocationPrediction(
      placeId: placeId,
      description: displayName,
      mainText: mainText,
      secondaryText: secondaryText,
      latitude: lat,
      longitude: lon,
      type: json['type'] as String?,
    );
  }
}

/// Place details model
class PlaceDetails {
  final String placeId;
  final double latitude;
  final double longitude;
  final String formattedAddress;
  final String? streetNumber;
  final String? route;
  final String? locality;
  final String? administrativeArea;
  final String? country;
  final String? postalCode;

  PlaceDetails({
    required this.placeId,
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    this.streetNumber,
    this.route,
    this.locality,
    this.administrativeArea,
    this.country,
    this.postalCode,
  });

  factory PlaceDetails.fromGooglePlaces(Map<String, dynamic> json) {
    final result = json['result'] as Map<String, dynamic>;
    final geometry = result['geometry'] as Map<String, dynamic>;
    final location = geometry['location'] as Map<String, dynamic>;

    String? streetNumber;
    String? route;
    String? locality;
    String? administrativeArea;
    String? country;
    String? postalCode;

    final addressComponents = result['address_components'] as List<dynamic>?;
    if (addressComponents != null) {
      for (final component in addressComponents) {
        final types = (component['types'] as List<dynamic>?) ?? [];
        if (types.contains('street_number')) {
          streetNumber = component['long_name'] as String?;
        } else if (types.contains('route')) {
          route = component['long_name'] as String?;
        } else if (types.contains('locality')) {
          locality = component['long_name'] as String?;
        } else if (types.contains('administrative_area_level_1')) {
          administrativeArea = component['long_name'] as String?;
        } else if (types.contains('country')) {
          country = component['long_name'] as String?;
        } else if (types.contains('postal_code')) {
          postalCode = component['long_name'] as String?;
        }
      }
    }

    return PlaceDetails(
      placeId: result['place_id'] as String,
      latitude: (location['lat'] as num).toDouble(),
      longitude: (location['lng'] as num).toDouble(),
      formattedAddress: result['formatted_address'] as String? ?? '',
      streetNumber: streetNumber,
      route: route,
      locality: locality,
      administrativeArea: administrativeArea,
      country: country,
      postalCode: postalCode,
    );
  }

  factory PlaceDetails.fromNominatim(Map<String, dynamic> json) {
    // Handle lat/lon as either String or num
    double? lat;
    double? lon;

    final latValue = json['lat'];
    if (latValue != null) {
      if (latValue is num) {
        lat = latValue.toDouble();
      } else if (latValue is String) {
        lat = double.tryParse(latValue);
      }
    }

    final lonValue = json['lon'];
    if (lonValue != null) {
      if (lonValue is num) {
        lon = lonValue.toDouble();
      } else if (lonValue is String) {
        lon = double.tryParse(lonValue);
      }
    }

    // Handle place_id as either String or num
    final placeIdValue = json['place_id'];
    final placeId = placeIdValue?.toString() ?? '';

    return PlaceDetails(
      placeId: placeId,
      latitude: lat ?? 0.0,
      longitude: lon ?? 0.0,
      formattedAddress: json['display_name'] as String? ?? '',
      locality: json['address']?['city'] as String? ?? json['address']?['town'] as String?,
      administrativeArea: json['address']?['state'] as String?,
      country: json['address']?['country'] as String?,
      postalCode: json['address']?['postcode'] as String?,
    );
  }
}

/// Location autocomplete service supporting Google Places and Nominatim
class LocationAutocompleteService {
  static const Duration _debounceDelay = Duration(milliseconds: 250);
  static const Duration _cacheTimeout = Duration(minutes: 60);
  static const int _maxCacheSize = 100;

  Timer? _debounceTimer;
  final Map<String, List<LocationPrediction>> _predictionsCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Map<String, PlaceDetails> _placeDetailsCache = {};

  /// Get predictions for a query
  Future<List<LocationPrediction>> getPredictions(
    String query, {
    double? latitude,
    double? longitude,
    bool useNominatim = true, // Default to Nominatim (OpenStreetMap)
  }) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final trimmedQuery = query.trim();
    final cacheKey = '$trimmedQuery|$latitude|$longitude|$useNominatim';

    // Check cache
    if (_predictionsCache.containsKey(cacheKey)) {
      final timestamp = _cacheTimestamps[cacheKey];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < _cacheTimeout) {
        debugPrint('📋 Using cached predictions for: $trimmedQuery');
        return _predictionsCache[cacheKey]!;
      }
    }

    try {
      List<LocationPrediction> predictions;

      if (useNominatim) {
        // Use Nominatim (OpenStreetMap) as primary source
        predictions = await _getNominatimPredictions(
          trimmedQuery,
          latitude: latitude,
          longitude: longitude,
        );
      } else {
        // Fallback to Google Places if Nominatim is disabled
        predictions = await _getGooglePlacesPredictions(
          trimmedQuery,
          latitude: latitude,
          longitude: longitude,
        );
      }

      // Cache results
      _predictionsCache[cacheKey] = predictions;
      _cacheTimestamps[cacheKey] = DateTime.now();

      // Limit cache size
      if (_predictionsCache.length > _maxCacheSize) {
        final oldestKey = _cacheTimestamps.entries
            .toList()
            ..sort((a, b) => a.value.compareTo(b.value));
        if (oldestKey.isNotEmpty) {
          _predictionsCache.remove(oldestKey.first.key);
          _cacheTimestamps.remove(oldestKey.first.key);
        }
      }

      return predictions;
    } catch (e) {
      debugPrint('❌ Error getting predictions: $e');
      return [];
    }
  }

  /// Get predictions from Google Places Autocomplete API
  Future<List<LocationPrediction>> _getGooglePlacesPredictions(
    String query, {
    double? latitude,
    double? longitude,
  }) async {
    try {
      final url = Uri.parse(
        '${MapsConfig.placesApiBaseUrl}/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&key=${MapsConfig.googleMapsApiKey}'
        '&language=en'
        '&region=dz'
        '${latitude != null && longitude != null ? '&location=$latitude,$longitude&radius=50000' : ''}',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final status = data['status'] as String?;

        // Check for API errors that should trigger fallback
        if (status == 'REQUEST_DENIED' ||
            status == 'OVER_QUERY_LIMIT' ||
            status == 'INVALID_REQUEST' ||
            status == 'UNKNOWN_ERROR') {
          debugPrint('⚠️ Google Places API error: $status - Falling back to Nominatim');
          // Fallback to Nominatim
          return _getNominatimPredictions(query, latitude: latitude, longitude: longitude);
        }

        if (status == 'OK' || status == 'ZERO_RESULTS') {
          final predictions = (data['predictions'] as List<dynamic>?)
                  ?.map((p) => LocationPrediction.fromGooglePlaces(
                      p as Map<String, dynamic>))
                  .toList() ??
              [];
          debugPrint('✅ Got ${predictions.length} Google Places predictions');
          return predictions;
        } else {
          debugPrint('⚠️ Google Places API status: $status - Falling back to Nominatim');
          // Fallback to Nominatim for other statuses
          return _getNominatimPredictions(query, latitude: latitude, longitude: longitude);
        }
      } else {
        debugPrint('⚠️ Google Places API HTTP error: ${response.statusCode} - Falling back to Nominatim');
        // Fallback to Nominatim
        return _getNominatimPredictions(query, latitude: latitude, longitude: longitude);
      }
    } catch (e) {
      debugPrint('❌ Google Places autocomplete error: $e - Falling back to Nominatim');
      // Fallback to Nominatim
      return _getNominatimPredictions(query, latitude: latitude, longitude: longitude);
    }
  }

  /// Get predictions from Nominatim (OpenStreetMap)
  Future<List<LocationPrediction>> _getNominatimPredictions(
    String query, {
    double? latitude,
    double? longitude,
  }) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json'
        '&limit=10'
        '&addressdetails=1'
        '${latitude != null && longitude != null ? '&lat=$latitude&lon=$longitude' : ''}',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'SahlaFoodDelivery/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        final predictions = data
            .map((item) => LocationPrediction.fromNominatim(
                item as Map<String, dynamic>))
            .toList();
        debugPrint('✅ Got ${predictions.length} Nominatim predictions');
        return predictions;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Nominatim autocomplete error: $e');
      return [];
    }
  }

  /// Get place details by place ID
  Future<PlaceDetails?> getPlaceDetails(
    String placeId, {
    bool useNominatim = true, // Default to Nominatim (OpenStreetMap)
  }) async {
    // Check cache
    if (_placeDetailsCache.containsKey(placeId)) {
      debugPrint('📋 Using cached place details for: $placeId');
      return _placeDetailsCache[placeId];
    }

    try {
      PlaceDetails? details;

      if (useNominatim) {
        details = await _getNominatimPlaceDetails(placeId);
      } else {
        details = await _getGooglePlacesDetails(placeId);
      }

      if (details != null) {
        _placeDetailsCache[placeId] = details;
      }

      return details;
    } catch (e) {
      debugPrint('❌ Error getting place details: $e');
      return null;
    }
  }

  /// Get place details from Google Places API
  Future<PlaceDetails?> _getGooglePlacesDetails(String placeId) async {
    try {
      final url = Uri.parse(
        '${MapsConfig.placesApiBaseUrl}/details/json'
        '?place_id=$placeId'
        '&key=${MapsConfig.googleMapsApiKey}'
        '&fields=place_id,geometry,formatted_address,address_components',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final status = data['status'] as String?;

        // Check for API errors
        if (status == 'REQUEST_DENIED' ||
            status == 'OVER_QUERY_LIMIT' ||
            status == 'INVALID_REQUEST' ||
            status == 'UNKNOWN_ERROR') {
          debugPrint('⚠️ Google Places details error: $status');
          return null;
        }

        if (status == 'OK') {
          return PlaceDetails.fromGooglePlaces(data);
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Google Places details error: $e');
      return null;
    }
  }

  /// Get place details from Nominatim
  Future<PlaceDetails?> _getNominatimPlaceDetails(String placeId) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/lookup'
        '?place_ids=$placeId'
        '&format=json'
        '&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'SahlaFoodDelivery/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        if (data.isNotEmpty) {
          return PlaceDetails.fromNominatim(data.first as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Nominatim details error: $e');
      return null;
    }
  }

  /// Debounced search - returns a future that completes after debounce delay
  Future<List<LocationPrediction>> debouncedSearch(
    String query, {
    double? latitude,
    double? longitude,
    bool useNominatim = false,
  }) async {
    _debounceTimer?.cancel();

    final completer = Completer<List<LocationPrediction>>();

    _debounceTimer = Timer(_debounceDelay, () async {
      final results = await getPredictions(
        query,
        latitude: latitude,
        longitude: longitude,
        useNominatim: useNominatim,
      );
      if (!completer.isCompleted) {
        completer.complete(results);
      }
    });

    return completer.future;
  }

  /// Clear cache
  void clearCache() {
    _predictionsCache.clear();
    _cacheTimestamps.clear();
    _placeDetailsCache.clear();
  }

  /// Reverse geocode using Nominatim (convert coordinates to address)
  Future<Map<String, dynamic>?> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$latitude'
        '&lon=$longitude'
        '&format=json'
        '&addressdetails=1'
        '&zoom=18',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'SahlaFoodDelivery/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        debugPrint('✅ Got Nominatim reverse geocode result');
        return data;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Nominatim reverse geocode error: $e');
      return null;
    }
  }

  /// Dispose
  void dispose() {
    _debounceTimer?.cancel();
    clearCache();
  }
}
