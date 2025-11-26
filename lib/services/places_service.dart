import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/maps_config.dart';

/// Service for Google Places API integration
class PlacesService {
  static const String _baseUrl = MapsConfig.placesApiBaseUrl;
  static const String _apiKey = MapsConfig.googleMapsApiKey;

  /// Search for places (restaurants, etc.)
  static Future<List<Place>?> searchPlaces({
    required String query,
    required LatLng location,
    double radius = 5000, // 5km radius
    String type = 'restaurant',
  }) async {
    try {
      final uri =
          Uri.parse('$_baseUrl/textsearch/json').replace(queryParameters: {
        'query': query,
        'location': '${location.latitude},${location.longitude}',
        'radius': radius.toString(),
        'type': type,
        'key': _apiKey,
      });

      debugPrint(
          '🔍 Searching places: $query near ${location.latitude}, ${location.longitude}');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          final places = results.map((place) => Place.fromJson(place)).toList();

          debugPrint('✅ Found ${places.length} places');
          return places;
        } else {
          debugPrint('❌ Places API error: ${data['status']}');
          return null;
        }
      } else {
        debugPrint('❌ HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error searching places: $e');
      return null;
    }
  }

  /// Get place details by place ID
  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    try {
      final uri = Uri.parse('$_baseUrl/details/json').replace(queryParameters: {
        'place_id': placeId,
        'fields':
            'name,rating,formatted_phone_number,formatted_address,geometry,photos,reviews,opening_hours,website,price_level',
        'key': _apiKey,
      });

      debugPrint('📍 Getting place details for: $placeId');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final result = data['result'];
          debugPrint('✅ Place details retrieved');
          return PlaceDetails.fromJson(result);
        } else {
          debugPrint('❌ Place details error: ${data['status']}');
          return null;
        }
      } else {
        debugPrint('❌ HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error getting place details: $e');
      return null;
    }
  }

  /// Get nearby restaurants
  static Future<List<Place>?> getNearbyRestaurants({
    required LatLng location,
    double radius = 2000, // 2km radius
  }) async {
    return searchPlaces(
      query: 'restaurant',
      location: location,
      radius: radius,
      type: 'restaurant',
    );
  }

  /// Get place photos
  static Future<String?> getPlacePhotoUrl({
    required String photoReference,
    int maxWidth = 400,
    int maxHeight = 400,
  }) async {
    return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=$maxWidth&maxheight=$maxHeight&photo_reference=$photoReference&key=$_apiKey';
  }
}

/// Place model
class Place {
  final String placeId;
  final String name;
  final double rating;
  final int userRatingsTotal;
  final String? formattedAddress;
  final LatLng location;
  final List<String> types;
  final String? priceLevel;
  final bool isOpen;
  final List<PlacePhoto> photos;

  const Place({
    required this.placeId,
    required this.name,
    required this.rating,
    required this.userRatingsTotal,
    required this.location,
    required this.types,
    required this.isOpen,
    required this.photos,
    this.formattedAddress,
    this.priceLevel,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>;
    final location = geometry['location'] as Map<String, dynamic>;

    return Place(
      placeId: json['place_id'] as String,
      name: json['name'] as String,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      userRatingsTotal: json['user_ratings_total'] as int? ?? 0,
      formattedAddress: json['formatted_address'] as String?,
      location: LatLng(
        (location['lat'] as num).toDouble(),
        (location['lng'] as num).toDouble(),
      ),
      types: List<String>.from(json['types'] as List? ?? []),
      priceLevel: json['price_level']?.toString(),
      isOpen: json['opening_hours']?['open_now'] as bool? ?? false,
      photos: (json['photos'] as List?)
              ?.map((photo) => PlacePhoto.fromJson(photo))
              .toList() ??
          [],
    );
  }
}

/// Place details model
class PlaceDetails {
  final String placeId;
  final String name;
  final double rating;
  final int userRatingsTotal;
  final String? formattedPhoneNumber;
  final String? formattedAddress;
  final LatLng location;
  final List<PlacePhoto> photos;
  final List<PlaceReview> reviews;
  final PlaceOpeningHours? openingHours;
  final String? website;
  final String? priceLevel;

  const PlaceDetails({
    required this.placeId,
    required this.name,
    required this.rating,
    required this.userRatingsTotal,
    required this.location,
    required this.photos,
    required this.reviews,
    this.formattedPhoneNumber,
    this.formattedAddress,
    this.openingHours,
    this.website,
    this.priceLevel,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>;
    final location = geometry['location'] as Map<String, dynamic>;

    return PlaceDetails(
      placeId: json['place_id'] as String,
      name: json['name'] as String,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      userRatingsTotal: json['user_ratings_total'] as int? ?? 0,
      formattedPhoneNumber: json['formatted_phone_number'] as String?,
      formattedAddress: json['formatted_address'] as String?,
      location: LatLng(
        (location['lat'] as num).toDouble(),
        (location['lng'] as num).toDouble(),
      ),
      photos: (json['photos'] as List?)
              ?.map((photo) => PlacePhoto.fromJson(photo))
              .toList() ??
          [],
      reviews: (json['reviews'] as List?)
              ?.map((review) => PlaceReview.fromJson(review))
              .toList() ??
          [],
      openingHours: json['opening_hours'] != null
          ? PlaceOpeningHours.fromJson(json['opening_hours'])
          : null,
      website: json['website'] as String?,
      priceLevel: json['price_level']?.toString(),
    );
  }
}

/// Place photo model
class PlacePhoto {
  final String photoReference;
  final int height;
  final int width;

  const PlacePhoto({
    required this.photoReference,
    required this.height,
    required this.width,
  });

  factory PlacePhoto.fromJson(Map<String, dynamic> json) {
    return PlacePhoto(
      photoReference: json['photo_reference'] as String,
      height: json['height'] as int,
      width: json['width'] as int,
    );
  }
}

/// Place review model
class PlaceReview {
  final String authorName;
  final double rating;
  final String text;
  final DateTime time;

  const PlaceReview({
    required this.authorName,
    required this.rating,
    required this.text,
    required this.time,
  });

  factory PlaceReview.fromJson(Map<String, dynamic> json) {
    return PlaceReview(
      authorName: json['author_name'] as String,
      rating: (json['rating'] as num).toDouble(),
      text: json['text'] as String,
      time: DateTime.fromMillisecondsSinceEpoch((json['time'] as int) * 1000),
    );
  }
}

/// Place opening hours model
class PlaceOpeningHours {
  final bool openNow;
  final List<String> weekdayText;

  const PlaceOpeningHours({
    required this.openNow,
    required this.weekdayText,
  });

  factory PlaceOpeningHours.fromJson(Map<String, dynamic> json) {
    return PlaceOpeningHours(
      openNow: json['open_now'] as bool,
      weekdayText: List<String>.from(json['weekday_text'] as List? ?? []),
    );
  }
}
