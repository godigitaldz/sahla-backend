enum DeliveryManRequestStatus {
  pending,
  approved,
  rejected,
}

extension DeliveryManRequestStatusExtension on DeliveryManRequestStatus {
  String get name {
    switch (this) {
      case DeliveryManRequestStatus.pending:
        return 'pending';
      case DeliveryManRequestStatus.approved:
        return 'approved';
      case DeliveryManRequestStatus.rejected:
        return 'rejected';
    }
  }

  static DeliveryManRequestStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return DeliveryManRequestStatus.approved;
      case 'rejected':
        return DeliveryManRequestStatus.rejected;
      case 'pending':
      default:
        return DeliveryManRequestStatus.pending;
    }
  }
}

class DeliveryManRequest {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String fullName;
  final String phone;
  final String address;
  final String vehicleType;
  final String plateNumber;
  final String? vehicleModel;
  final String? vehicleYear;
  final String? vehicleColor;
  final String availability;
  final String? experience;
  final bool hasValidLicense;
  final bool hasVehicle;
  final bool isAvailableWeekends;
  final bool isAvailableEvenings;
  final DeliveryManRequestStatus status;
  final String? rejectionReason;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  DeliveryManRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.fullName,
    required this.phone,
    required this.address,
    required this.vehicleType,
    required this.plateNumber,
    required this.availability,
    required this.hasValidLicense,
    required this.hasVehicle,
    required this.isAvailableWeekends,
    required this.isAvailableEvenings,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.vehicleModel,
    this.vehicleYear,
    this.vehicleColor,
    this.experience,
    this.rejectionReason,
    this.reviewedBy,
    this.reviewedAt,
  });

  factory DeliveryManRequest.fromMap(Map<String, dynamic> map) {
    return DeliveryManRequest(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      userName: map['user_name'] as String,
      userEmail: map['user_email'] as String,
      fullName: map['full_name'] as String,
      phone: map['phone'] as String,
      address: map['address'] as String,
      vehicleType: map['vehicle_type'] as String,
      plateNumber: map['plate_number'] as String,
      vehicleModel: map['vehicle_model'] as String?,
      vehicleYear: map['vehicle_year'] as String?,
      vehicleColor: map['vehicle_color'] as String?,
      availability: map['availability'] as String,
      experience: map['experience'] as String?,
      hasValidLicense: map['has_valid_license'] as bool? ?? false,
      hasVehicle: map['has_vehicle'] as bool? ?? false,
      isAvailableWeekends: map['is_available_weekends'] as bool? ?? false,
      isAvailableEvenings: map['is_available_evenings'] as bool? ?? false,
      status: DeliveryManRequestStatusExtension.fromString(
          map['status'] as String? ?? 'pending'),
      rejectionReason: map['rejection_reason'] as String?,
      reviewedBy: map['reviewed_by'] as String?,
      reviewedAt: map['reviewed_at'] != null
          ? DateTime.parse(map['reviewed_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_email': userEmail,
      'full_name': fullName,
      'phone': phone,
      'address': address,
      'vehicle_type': vehicleType,
      'plate_number': plateNumber,
      'vehicle_model': vehicleModel,
      'vehicle_year': vehicleYear,
      'vehicle_color': vehicleColor,
      'availability': availability,
      'experience': experience,
      'has_valid_license': hasValidLicense,
      'has_vehicle': hasVehicle,
      'is_available_weekends': isAvailableWeekends,
      'is_available_evenings': isAvailableEvenings,
      'status': status.name,
      'rejection_reason': rejectionReason,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isPending => status == DeliveryManRequestStatus.pending;
  bool get isApproved => status == DeliveryManRequestStatus.approved;
  bool get isRejected => status == DeliveryManRequestStatus.rejected;
}
