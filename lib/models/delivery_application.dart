import 'user.dart' as app_user;

enum ApplicationStatus {
  pending,
  approved,
  rejected,
  underReview,
}

class DeliveryApplication {
  final String id;
  final String userId;
  final ApplicationStatus status;
  final String vehicleType;
  final String? licenseNumber;
  final String? vehiclePlate;
  final String? address;
  final String? phoneNumber;
  final String? experience;
  final bool hasValidLicense;
  final bool hasVehicle;
  final bool isAvailableWeekends;
  final bool isAvailableEvenings;
  final String? availabilityType;
  final Map<String, dynamic>? applicationData;
  final DateTime createdAt;
  final DateTime updatedAt;
  final app_user.User? user;

  DeliveryApplication({
    required this.id,
    required this.userId,
    required this.status,
    required this.vehicleType,
    required this.hasValidLicense,
    required this.hasVehicle,
    required this.isAvailableWeekends,
    required this.isAvailableEvenings,
    required this.createdAt,
    required this.updatedAt,
    this.licenseNumber,
    this.vehiclePlate,
    this.address,
    this.phoneNumber,
    this.experience,
    this.availabilityType,
    this.applicationData,
    this.user,
  });

  factory DeliveryApplication.fromJson(Map<String, dynamic> json) {
    return DeliveryApplication(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      status: _parseApplicationStatus(json['status']),
      vehicleType: json['vehicle_type'] ?? '',
      licenseNumber: json['license_number'],
      vehiclePlate: json['vehicle_plate'],
      address: json['address'],
      phoneNumber: json['phone_number'],
      experience: json['experience'],
      hasValidLicense: json['has_valid_license'] ?? false,
      hasVehicle: json['has_vehicle'] ?? false,
      isAvailableWeekends: json['is_available_weekends'] ?? false,
      isAvailableEvenings: json['is_available_evenings'] ?? false,
      availabilityType: json['availability_type'],
      applicationData: json['application_data'],
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
      'status': status.name,
      'vehicle_type': vehicleType,
      'license_number': licenseNumber,
      'vehicle_plate': vehiclePlate,
      'address': address,
      'phone_number': phoneNumber,
      'experience': experience,
      'has_valid_license': hasValidLicense,
      'has_vehicle': hasVehicle,
      'is_available_weekends': isAvailableWeekends,
      'is_available_evenings': isAvailableEvenings,
      'availability_type': availabilityType,
      'application_data': applicationData,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static ApplicationStatus _parseApplicationStatus(String? status) {
    switch (status) {
      case 'pending':
        return ApplicationStatus.pending;
      case 'approved':
        return ApplicationStatus.approved;
      case 'rejected':
        return ApplicationStatus.rejected;
      case 'under_review':
        return ApplicationStatus.underReview;
      default:
        return ApplicationStatus.pending;
    }
  }

  String get statusDisplay {
    switch (status) {
      case ApplicationStatus.pending:
        return 'Pending Review';
      case ApplicationStatus.approved:
        return 'Approved';
      case ApplicationStatus.rejected:
        return 'Rejected';
      case ApplicationStatus.underReview:
        return 'Under Review';
    }
  }

  String get statusColor {
    switch (status) {
      case ApplicationStatus.pending:
        return '#FF9800'; // Orange
      case ApplicationStatus.approved:
        return '#4CAF50'; // Green
      case ApplicationStatus.rejected:
        return '#F44336'; // Red
      case ApplicationStatus.underReview:
        return '#2196F3'; // Blue
    }
  }

  bool get isPending => status == ApplicationStatus.pending;
  bool get isApproved => status == ApplicationStatus.approved;
  bool get isRejected => status == ApplicationStatus.rejected;
  bool get isUnderReview => status == ApplicationStatus.underReview;

  DeliveryApplication copyWith({
    String? id,
    String? userId,
    ApplicationStatus? status,
    String? vehicleType,
    String? licenseNumber,
    String? vehiclePlate,
    String? address,
    String? phoneNumber,
    String? experience,
    bool? hasValidLicense,
    bool? hasVehicle,
    bool? isAvailableWeekends,
    bool? isAvailableEvenings,
    String? availabilityType,
    Map<String, dynamic>? applicationData,
    DateTime? createdAt,
    DateTime? updatedAt,
    app_user.User? user,
  }) {
    return DeliveryApplication(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      vehicleType: vehicleType ?? this.vehicleType,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      experience: experience ?? this.experience,
      hasValidLicense: hasValidLicense ?? this.hasValidLicense,
      hasVehicle: hasVehicle ?? this.hasVehicle,
      isAvailableWeekends: isAvailableWeekends ?? this.isAvailableWeekends,
      isAvailableEvenings: isAvailableEvenings ?? this.isAvailableEvenings,
      availabilityType: availabilityType ?? this.availabilityType,
      applicationData: applicationData ?? this.applicationData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      user: user ?? this.user,
    );
  }

  @override
  String toString() {
    return 'DeliveryApplication(id: $id, userId: $userId, status: $status, vehicleType: $vehicleType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeliveryApplication && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
