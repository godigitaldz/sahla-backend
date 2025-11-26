import 'dart:math';

import '../utils/safe_parse.dart';

class DeliveryLocation {
  final String id;
  final String deliveryPersonId;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final DateTime timestamp;
  final String? address;
  final bool isActive;

  DeliveryLocation({
    required this.id,
    required this.deliveryPersonId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
    this.speed,
    this.heading,
    this.address,
    this.isActive = true,
  });

  factory DeliveryLocation.fromJson(Map<String, dynamic> json) {
    return DeliveryLocation(
      id: safeStringRequired(json['id'], fieldName: 'id'),
      deliveryPersonId: safeStringRequired(json['delivery_person_id'],
          fieldName: 'delivery_person_id'),
      latitude: safeDoubleRequired(json['latitude'], fieldName: 'latitude'),
      longitude: safeDoubleRequired(json['longitude'], fieldName: 'longitude'),
      accuracy: safeDouble(json['accuracy']),
      speed: safeDouble(json['speed']),
      heading: safeDouble(json['heading']),
      timestamp: safeUtcRequired(json['timestamp'], fieldName: 'timestamp'),
      address: safeString(json['address']),
      isActive: safeBool(json['is_active'], defaultValue: true) ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'delivery_person_id': deliveryPersonId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'speed': speed,
      'heading': heading,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'address': address,
      'is_active': isActive,
    };
  }

  // Calculate distance between two locations using Haversine formula
  double distanceTo(DeliveryLocation other) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _degreesToRadians(other.latitude - latitude);
    final double dLon = _degreesToRadians(other.longitude - longitude);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(latitude) * cos(other.latitude) * sin(dLon / 2) * sin(dLon / 2);

    final double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }

  // Check if location is within a certain radius of another location
  bool isWithinRadius(DeliveryLocation other, double radiusKm) {
    return distanceTo(other) <= radiusKm;
  }

  // Get formatted address or coordinates
  String get displayLocation {
    if (address != null && address!.isNotEmpty) {
      return address!;
    }
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  // Get accuracy display
  String get accuracyDisplay {
    final acc = accuracy;
    if (acc == null) return 'Unknown';
    if (acc < 10) return 'High';
    if (acc < 50) return 'Medium';
    return 'Low';
  }

  // Get speed display
  String get speedDisplay {
    final spd = speed;
    if (spd == null) return 'Unknown';
    return '${spd.toStringAsFixed(1)} km/h';
  }

  DeliveryLocation copyWith({
    String? id,
    String? deliveryPersonId,
    double? latitude,
    double? longitude,
    double? accuracy,
    double? speed,
    double? heading,
    DateTime? timestamp,
    String? address,
    bool? isActive,
  }) {
    return DeliveryLocation(
      id: id ?? this.id,
      deliveryPersonId: deliveryPersonId ?? this.deliveryPersonId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      timestamp: timestamp ?? this.timestamp,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'DeliveryLocation(id: $id, deliveryPersonId: $deliveryPersonId, lat: $latitude, lng: $longitude)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeliveryLocation && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
