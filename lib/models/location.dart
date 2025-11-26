import 'dart:math' as math;

enum LocationType {
  pickupPoint,
  returnPoint,
  airport,
  trainStation,
  hotel,
  shoppingCenter,
  residential,
  businessDistrict
}

enum LocationStatus { active, inactive, temporaryClosed, permanentlyClosed }

class Location {
  final String id;
  final String name;
  final String description;
  final LocationType type;
  final LocationStatus status;
  final double latitude;
  final double longitude;
  final String address;
  final String city;
  final String state;
  final String country;
  final String postalCode;
  final String? phoneNumber;
  final String? email;
  final String? website;
  final List<String> images;
  final Map<String, dynamic> operatingHours;
  final Map<String, dynamic> amenities;
  final Map<String, dynamic> restrictions;
  final double averageRating;
  final int totalReviews;
  final List<String> acceptedPaymentMethods;
  final Map<String, dynamic>? coordinates; // Additional coordinate data
  final String? timezone;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  Location({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.city,
    required this.state,
    required this.country,
    required this.postalCode,
    required this.createdAt,
    this.status = LocationStatus.active,
    this.phoneNumber,
    this.email,
    this.website,
    this.images = const [],
    this.operatingHours = const {},
    this.amenities = const {},
    this.restrictions = const {},
    this.averageRating = 0.0,
    this.totalReviews = 0,
    this.acceptedPaymentMethods = const [],
    this.coordinates,
    this.timezone,
    this.updatedAt,
    this.metadata,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      type: LocationType.values.firstWhere(
        (type) =>
            type.toString() == 'LocationType.${json['type'] ?? 'pickupPoint'}',
        orElse: () => LocationType.pickupPoint,
      ),
      status: LocationStatus.values.firstWhere(
        (status) =>
            status.toString() == 'LocationStatus.${json['status'] ?? 'active'}',
        orElse: () => LocationStatus.active,
      ),
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      country: json['country'] ?? '',
      postalCode: json['postalCode'] ?? '',
      phoneNumber: json['phoneNumber'],
      email: json['email'],
      website: json['website'],
      images: List<String>.from(json['images'] ?? []),
      operatingHours: Map<String, dynamic>.from(json['operatingHours'] ?? {}),
      amenities: Map<String, dynamic>.from(json['amenities'] ?? {}),
      restrictions: Map<String, dynamic>.from(json['restrictions'] ?? {}),
      averageRating: (json['averageRating'] ?? 0.0).toDouble(),
      totalReviews: json['totalReviews'] ?? 0,
      acceptedPaymentMethods:
          List<String>.from(json['acceptedPaymentMethods'] ?? []),
      coordinates: json['coordinates'] != null
          ? Map<String, dynamic>.from(json['coordinates'])
          : null,
      timezone: json['timezone'],
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'postalCode': postalCode,
      'phoneNumber': phoneNumber,
      'email': email,
      'website': website,
      'images': images,
      'operatingHours': operatingHours,
      'amenities': amenities,
      'restrictions': restrictions,
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'acceptedPaymentMethods': acceptedPaymentMethods,
      'coordinates': coordinates,
      'timezone': timezone,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  Location copyWith({
    String? id,
    String? name,
    String? description,
    LocationType? type,
    LocationStatus? status,
    double? latitude,
    double? longitude,
    String? address,
    String? city,
    String? state,
    String? country,
    String? postalCode,
    String? phoneNumber,
    String? email,
    String? website,
    List<String>? images,
    Map<String, dynamic>? operatingHours,
    Map<String, dynamic>? amenities,
    Map<String, dynamic>? restrictions,
    double? averageRating,
    int? totalReviews,
    List<String>? acceptedPaymentMethods,
    Map<String, dynamic>? coordinates,
    String? timezone,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Location(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      postalCode: postalCode ?? this.postalCode,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      website: website ?? this.website,
      images: images ?? this.images,
      operatingHours: operatingHours ?? this.operatingHours,
      amenities: amenities ?? this.amenities,
      restrictions: restrictions ?? this.restrictions,
      averageRating: averageRating ?? this.averageRating,
      totalReviews: totalReviews ?? this.totalReviews,
      acceptedPaymentMethods:
          acceptedPaymentMethods ?? this.acceptedPaymentMethods,
      coordinates: coordinates ?? this.coordinates,
      timezone: timezone ?? this.timezone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  // Check if location is active
  bool get isActive {
    return status == LocationStatus.active;
  }

  // Check if location is closed
  bool get isClosed {
    return status == LocationStatus.permanentlyClosed ||
        status == LocationStatus.temporaryClosed;
  }

  // Get full address string
  String get fullAddress {
    return '$address, $city, $state $postalCode, $country';
  }

  // Get short address (city, state)
  String get shortAddress {
    return '$city, $state';
  }

  // Get location type display name
  String get typeDisplayName {
    switch (type) {
      case LocationType.pickupPoint:
        return 'Pickup Point';
      case LocationType.returnPoint:
        return 'Return Point';
      case LocationType.airport:
        return 'Airport';
      case LocationType.trainStation:
        return 'Train Station';
      case LocationType.hotel:
        return 'Hotel';
      case LocationType.shoppingCenter:
        return 'Shopping Center';
      case LocationType.residential:
        return 'Residential';
      case LocationType.businessDistrict:
        return 'Business District';
    }
  }

  // Get location type emoji
  String get typeEmoji {
    switch (type) {
      case LocationType.pickupPoint:
        return '🚗';
      case LocationType.returnPoint:
        return '🔄';
      case LocationType.airport:
        return '✈️';
      case LocationType.trainStation:
        return '🚆';
      case LocationType.hotel:
        return '🏨';
      case LocationType.shoppingCenter:
        return '🛍️';
      case LocationType.residential:
        return '🏠';
      case LocationType.businessDistrict:
        return '🏢';
    }
  }

  // Get display name with emoji
  String get displayName {
    return '$typeEmoji $name';
  }

  // Calculate distance to another location (in kilometers)
  double distanceTo(Location other) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double lat1Rad = latitude * math.pi / 180;
    final double lat2Rad = other.latitude * math.pi / 180;
    final double deltaLatRad = (other.latitude - latitude) * math.pi / 180;
    final double deltaLonRad = (other.longitude - longitude) * math.pi / 180;

    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLonRad / 2) *
            math.sin(deltaLonRad / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  // Calculate distance to coordinates
  double distanceToCoordinates(double lat, double lon) {
    const double earthRadius = 6371;

    final double lat1Rad = latitude * math.pi / 180;
    final double lat2Rad = lat * math.pi / 180;
    final double deltaLatRad = (lat - latitude) * math.pi / 180;
    final double deltaLonRad = (lon - longitude) * math.pi / 180;

    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLonRad / 2) *
            math.sin(deltaLonRad / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  // Check if location is well-rated
  bool get isWellRated {
    return averageRating >= 4.0;
  }

  // Check if location has images
  bool get hasImages {
    return images.isNotEmpty;
  }

  // Get primary image or placeholder
  String get primaryImage {
    return hasImages ? images.first : '';
  }

  // Check if location is a transportation hub
  bool get isTransportationHub {
    return type == LocationType.airport || type == LocationType.trainStation;
  }

  // Check if location is commercial
  bool get isCommercial {
    return type == LocationType.shoppingCenter ||
        type == LocationType.businessDistrict ||
        type == LocationType.hotel;
  }

  // Check if location is residential
  bool get isResidential {
    return type == LocationType.residential;
  }

  // Get location status display
  String get statusDisplay {
    switch (status) {
      case LocationStatus.active:
        return 'Open';
      case LocationStatus.inactive:
        return 'Closed';
      case LocationStatus.temporaryClosed:
        return 'Temporarily Closed';
      case LocationStatus.permanentlyClosed:
        return 'Permanently Closed';
    }
  }

  // Check if location is within specified radius (in km)
  bool isWithinRadius(Location center, double radiusKm) {
    return distanceTo(center) <= radiusKm;
  }

  // Check if location is within specified radius of coordinates
  bool isWithinRadiusOfCoordinates(double lat, double lon, double radiusKm) {
    return distanceToCoordinates(lat, lon) <= radiusKm;
  }

  // Get location rating display
  String get ratingDisplay {
    if (totalReviews == 0) return 'No reviews';
    return '${averageRating.toStringAsFixed(1)} ($totalReviews reviews)';
  }

  // Check if location has amenities
  bool get hasAmenities {
    return amenities.isNotEmpty;
  }

  // Check if location has restrictions
  bool get hasRestrictions {
    return restrictions.isNotEmpty;
  }

  // Get location coordinates as string
  String get coordinatesString {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  // Check if location is popular (high rating and reviews)
  bool get isPopular {
    return averageRating >= 4.0 && totalReviews >= 10;
  }

  // Get location quality score
  double get qualityScore {
    double score = 0.0;

    // Rating score
    score += averageRating * 2;

    // Review count score
    if (totalReviews >= 50) {
      score += 2.0;
    } else if (totalReviews >= 20) {
      score += 1.0;
    } else if (totalReviews >= 5) {
      score += 0.5;
    }

    // Amenities score
    if (hasAmenities) score += 1.0;

    // Image score
    if (hasImages) score += 0.5;

    return score;
  }

  // Check if location is high quality
  bool get isHighQuality {
    return qualityScore >= 8.0;
  }
}
