import 'user.dart' as app_user;

enum VehicleType {
  motorcycle,
  bicycle,
  car,
  scooter,
}

enum DeliveryStatus {
  available,
  busy,
  offline,
  onBreak,
}

class DeliveryPersonnel {
  final String id;
  final String userId;
  final String? licenseNumber;
  final VehicleType vehicleType;
  final String? vehiclePlate;
  final String? vehicleBrand;
  final String? vehicleModel;
  final int? vehicleYear;
  final String? vehicleColor;
  final String? deliveryName;
  final String? workPhone;
  final String? wilaya;
  final String? province;
  final bool isAvailable;
  final bool isOnline;
  final double? currentLatitude;
  final double? currentLongitude;
  final double rating;
  final int totalDeliveries;
  final DateTime createdAt;
  final DateTime updatedAt;
  final app_user.User? user;

  DeliveryPersonnel({
    required this.id,
    required this.userId,
    required this.vehicleType,
    required this.isAvailable,
    required this.isOnline,
    required this.rating,
    required this.totalDeliveries,
    required this.createdAt,
    required this.updatedAt,
    this.licenseNumber,
    this.vehiclePlate,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleYear,
    this.vehicleColor,
    this.deliveryName,
    this.workPhone,
    this.wilaya,
    this.province,
    this.currentLatitude,
    this.currentLongitude,
    this.user,
  });

  factory DeliveryPersonnel.fromJson(Map<String, dynamic> json) {
    return DeliveryPersonnel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      licenseNumber: json['license_number'],
      vehicleType: _parseVehicleType(json['vehicle_type']),
      vehiclePlate: json['vehicle_plate'],
      vehicleBrand: json['vehicle_brand'],
      vehicleModel: json['vehicle_model'],
      vehicleYear: json['vehicle_year'],
      vehicleColor: json['vehicle_color'],
      deliveryName: json['delivery_name'],
      workPhone: json['work_phone'],
      wilaya: json['wilaya'],
      province: json['province'],
      isAvailable: json['is_available'] ?? true,
      isOnline: json['is_online'] ?? false,
      currentLatitude: json['current_latitude']?.toDouble(),
      currentLongitude: json['current_longitude']?.toDouble(),
      rating: (json['rating'] ?? 0.0).toDouble(),
      totalDeliveries: json['total_deliveries'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      user:
          json['users'] != null ? app_user.User.fromJson(json['users']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'license_number': licenseNumber,
      'vehicle_type': vehicleType.name,
      'vehicle_plate': vehiclePlate,
      'vehicle_brand': vehicleBrand,
      'vehicle_model': vehicleModel,
      'vehicle_year': vehicleYear,
      'vehicle_color': vehicleColor,
      'delivery_name': deliveryName,
      'work_phone': workPhone,
      'wilaya': wilaya,
      'province': province,
      'is_available': isAvailable,
      'is_online': isOnline,
      'current_latitude': currentLatitude,
      'current_longitude': currentLongitude,
      'rating': rating,
      'total_deliveries': totalDeliveries,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static VehicleType _parseVehicleType(String? type) {
    switch (type) {
      case 'motorcycle':
        return VehicleType.motorcycle;
      case 'bicycle':
        return VehicleType.bicycle;
      case 'car':
        return VehicleType.car;
      case 'scooter':
        return VehicleType.scooter;
      default:
        return VehicleType.motorcycle;
    }
  }

  DeliveryStatus get deliveryStatus {
    if (!isOnline) return DeliveryStatus.offline;
    if (!isAvailable) return DeliveryStatus.busy;
    return DeliveryStatus.available;
  }

  String get vehicleTypeDisplay {
    switch (vehicleType) {
      case VehicleType.motorcycle:
        return 'Motorcycle';
      case VehicleType.bicycle:
        return 'Bicycle';
      case VehicleType.car:
        return 'Car';
      case VehicleType.scooter:
        return 'Scooter';
    }
  }

  String get statusDisplay {
    switch (deliveryStatus) {
      case DeliveryStatus.available:
        return 'Available';
      case DeliveryStatus.busy:
        return 'Busy';
      case DeliveryStatus.offline:
        return 'Offline';
      case DeliveryStatus.onBreak:
        return 'On Break';
    }
  }

  String get statusColor {
    switch (deliveryStatus) {
      case DeliveryStatus.available:
        return '#4CAF50'; // Green
      case DeliveryStatus.busy:
        return '#FF9800'; // Orange
      case DeliveryStatus.offline:
        return '#9E9E9E'; // Grey
      case DeliveryStatus.onBreak:
        return '#2196F3'; // Blue
    }
  }

  bool get hasLocation => currentLatitude != null && currentLongitude != null;

  DeliveryPersonnel copyWith({
    String? id,
    String? userId,
    String? licenseNumber,
    VehicleType? vehicleType,
    String? vehiclePlate,
    String? vehicleBrand,
    String? vehicleModel,
    int? vehicleYear,
    String? vehicleColor,
    String? deliveryName,
    String? workPhone,
    String? wilaya,
    String? province,
    bool? isAvailable,
    bool? isOnline,
    double? currentLatitude,
    double? currentLongitude,
    double? rating,
    int? totalDeliveries,
    DateTime? createdAt,
    DateTime? updatedAt,
    app_user.User? user,
  }) {
    return DeliveryPersonnel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      vehicleBrand: vehicleBrand ?? this.vehicleBrand,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleYear: vehicleYear ?? this.vehicleYear,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      deliveryName: deliveryName ?? this.deliveryName,
      workPhone: workPhone ?? this.workPhone,
      wilaya: wilaya ?? this.wilaya,
      province: province ?? this.province,
      isAvailable: isAvailable ?? this.isAvailable,
      isOnline: isOnline ?? this.isOnline,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      rating: rating ?? this.rating,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      user: user ?? this.user,
    );
  }

  @override
  String toString() {
    return 'DeliveryPersonnel(id: $id, userId: $userId, vehicleType: $vehicleType, isAvailable: $isAvailable)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeliveryPersonnel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
