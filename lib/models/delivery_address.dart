import 'package:equatable/equatable.dart';

import '../utils/safe_parse.dart';

class DeliveryAddress extends Equatable {
  final String street;
  final String city;
  final String postalCode;
  final String? apartment;
  final String? building;
  final String? floor;
  final String? instructions;
  final double? latitude;
  final double? longitude;

  const DeliveryAddress({
    required this.street,
    required this.city,
    required this.postalCode,
    this.apartment,
    this.building,
    this.floor,
    this.instructions,
    this.latitude,
    this.longitude,
  });

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) {
    // Support multiple shapes and legacy keys gracefully
    final latRaw = json['latitude'] ?? json['lat'];
    final lngRaw = json['longitude'] ?? json['lng'] ?? json['long'];

    // Handle fullAddress field from database JSON
    final fullAddressValue = safeString(json['fullAddress']);

    // If fullAddress is provided, use it as the street field
    // This ensures the fullAddress getter returns the complete address
    final street = fullAddressValue != null && fullAddressValue.isNotEmpty
        ? fullAddressValue
        : safeStringRequired(
            json['street'] ?? json['address'],
            fieldName: 'street',
          );

    return DeliveryAddress(
      street: street,
      // Use safeString with default instead of safeStringRequired to handle missing city gracefully
      city: safeString(
            json['city'] ?? json['wilaya'],
            defaultValue: '',
          ) ??
          '',
      // Use safeString with default instead of safeStringRequired to handle missing postalCode gracefully
      postalCode: safeString(
            json['postal_code'] ?? json['zip'],
            defaultValue: '',
          ) ??
          '',
      apartment: safeString(
        json['apartment'] ?? json['apartment_number'],
      ),
      building: safeString(
        json['building'] ?? json['building_name'],
      ),
      floor: safeString(json['floor']),
      instructions: safeString(json['instructions']),
      latitude: safeDouble(latRaw),
      longitude: safeDouble(lngRaw),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'street': street,
      'city': city,
      'postal_code': postalCode,
      'apartment': apartment,
      'building': building,
      'floor': floor,
      'instructions': instructions,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  // Add toMap method for backward compatibility
  Map<String, dynamic> toMap() {
    return {
      'street': street,
      'city': city,
      'postal_code': postalCode,
      'apartment_number': apartment,
      'building_name': building,
      'floor': floor,
      'instructions': instructions,
      'latitude': latitude,
      'longitude': longitude,
      'fullAddress': fullAddress,
      'address': fullAddress,
      'wilaya': city,
    };
  }

  DeliveryAddress copyWith({
    String? street,
    String? city,
    String? postalCode,
    String? apartment,
    String? building,
    String? floor,
    String? instructions,
    double? latitude,
    double? longitude,
  }) {
    return DeliveryAddress(
      street: street ?? this.street,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      apartment: apartment ?? this.apartment,
      building: building ?? this.building,
      floor: floor ?? this.floor,
      instructions: instructions ?? this.instructions,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  String get fullAddress {
    final parts = <String>[];
    if (street.isNotEmpty) parts.add(street);
    if (apartment != null && apartment!.isNotEmpty) {
      parts.add('Apt $apartment');
    }
    if (building != null && building!.isNotEmpty) {
      parts.add('Bldg $building');
    }
    if (floor != null && floor!.isNotEmpty) {
      parts.add('Floor $floor');
    }
    if (city.isNotEmpty) parts.add(city);
    if (postalCode.isNotEmpty) parts.add(postalCode);
    return parts.join(', ');
  }

  String get shortAddress {
    return '$city, $postalCode';
  }

  bool get hasCoordinates => latitude != null && longitude != null;

  // Add missing methods for compatibility
  bool get isEmpty => street.isEmpty && city.isEmpty && postalCode.isEmpty;
  bool get isNotEmpty => !isEmpty;

  // Add operator[] for backward compatibility
  dynamic operator [](String key) {
    switch (key) {
      case 'street':
        return street;
      case 'city':
        return city;
      case 'postal_code':
        return postalCode;
      case 'apartment_number':
        return apartment;
      case 'building_name':
        return building;
      case 'latitude':
        return latitude;
      case 'longitude':
        return longitude;
      case 'instructions':
        return instructions;
      case 'fullAddress':
        return fullAddress;
      case 'address':
        return fullAddress;
      case 'wilaya':
        return city; // Assuming wilaya maps to city
      default:
        return null;
    }
  }

  @override
  List<Object?> get props => [
        street,
        city,
        postalCode,
        apartment,
        building,
        floor,
        instructions,
        latitude,
        longitude,
      ];

  @override
  String toString() {
    return 'DeliveryAddress(street: $street, city: $city, postalCode: $postalCode)';
  }
}
