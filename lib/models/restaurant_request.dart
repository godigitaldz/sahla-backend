enum RestaurantRequestStatus {
  pending,
  approved,
  rejected,
}

extension RestaurantRequestStatusExtension on RestaurantRequestStatus {
  String get name {
    switch (this) {
      case RestaurantRequestStatus.pending:
        return 'pending';
      case RestaurantRequestStatus.approved:
        return 'approved';
      case RestaurantRequestStatus.rejected:
        return 'rejected';
    }
  }

  static RestaurantRequestStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return RestaurantRequestStatus.approved;
      case 'rejected':
        return RestaurantRequestStatus.rejected;
      case 'pending':
      default:
        return RestaurantRequestStatus.pending;
    }
  }
}

class RestaurantRequest {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String restaurantName;
  final String restaurantDescription;
  final String restaurantAddress;
  final String restaurantPhone;
  final Map<String, dynamic> openingHours;
  final Map<String, dynamic> closingHours;
  final String? wilaya;
  final String? logoUrl;
  final double? latitude;
  final double? longitude;
  // Social media fields
  final String? instagram;
  final String? facebook;
  final String? tiktok;
  // Additional restaurant fields
  final String? email;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? coverImageUrl;
  final RestaurantRequestStatus status;
  final String? rejectionReason;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  RestaurantRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.restaurantName,
    required this.restaurantDescription,
    required this.restaurantAddress,
    required this.restaurantPhone,
    required this.openingHours,
    required this.closingHours,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.wilaya,
    this.logoUrl,
    this.latitude,
    this.longitude,
    this.instagram,
    this.facebook,
    this.tiktok,
    this.email,
    this.addressLine2,
    this.city,
    this.state,
    this.postalCode,
    this.coverImageUrl,
    this.rejectionReason,
    this.reviewedBy,
    this.reviewedAt,
  });

  factory RestaurantRequest.fromMap(Map<String, dynamic> map) {
    return RestaurantRequest(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      userName: map['user_name'] as String,
      userEmail: map['user_email'] as String,
      restaurantName: map['restaurant_name'] as String,
      restaurantDescription: map['restaurant_description'] as String,
      restaurantAddress: map['restaurant_address'] as String,
      restaurantPhone: map['restaurant_phone'] as String,
      openingHours: map['opening_hours'] as Map<String, dynamic>? ?? {},
      closingHours: map['closing_hours'] as Map<String, dynamic>? ?? {},
      wilaya: map['wilaya'] as String?,
      logoUrl: map['logo_url'] as String?,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      instagram: map['instagram'] as String?,
      facebook: map['facebook'] as String?,
      tiktok: map['tiktok'] as String?,
      email: map['email'] as String?,
      addressLine2: map['address_line2'] as String?,
      city: map['city'] as String?,
      state: map['state'] as String?,
      postalCode: map['postal_code'] as String?,
      coverImageUrl: map['cover_image_url'] as String?,
      status: RestaurantRequestStatusExtension.fromString(
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
      'restaurant_name': restaurantName,
      'restaurant_description': restaurantDescription,
      'restaurant_address': restaurantAddress,
      'restaurant_phone': restaurantPhone,
      'opening_hours': openingHours,
      'closing_hours': closingHours,
      'wilaya': wilaya,
      'logo_url': logoUrl,
      'latitude': latitude,
      'longitude': longitude,
      'instagram': instagram,
      'facebook': facebook,
      'tiktok': tiktok,
      'email': email,
      'address_line2': addressLine2,
      'city': city,
      'state': state,
      'postal_code': postalCode,
      'cover_image_url': coverImageUrl,
      'status': status.name,
      'rejection_reason': rejectionReason,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isPending => status == RestaurantRequestStatus.pending;
  bool get isApproved => status == RestaurantRequestStatus.approved;
  bool get isRejected => status == RestaurantRequestStatus.rejected;
}
