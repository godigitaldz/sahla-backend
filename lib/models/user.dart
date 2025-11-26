import 'package:equatable/equatable.dart';

import '../utils/preferences_utils.dart';
import '../utils/safe_parse.dart';
import 'location.dart';

enum UserRole { customer, restaurantOwner, deliveryMan, admin }

class User extends Equatable {
  final String id;
  final String? name;
  final String email;
  final String? phone;
  final String? profileImage;
  final UserRole role;
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final Map<String, dynamic> preferences;
  final RestaurantOwnerProfile? restaurantOwnerProfile;
  final DeliveryManProfile? deliveryManProfile;
  final Location? location; // Add location property
  final String? address;
  final String? wilaya;
  final DateTime? dateOfBirth;

  const User({
    required this.id,
    required this.email,
    required this.role,
    required this.createdAt,
    this.name,
    this.phone,
    this.profileImage,
    this.isEmailVerified = false,
    this.isPhoneVerified = false,
    this.lastLoginAt,
    this.preferences = const <String, dynamic>{},
    this.restaurantOwnerProfile,
    this.deliveryManProfile,
    this.location, // Add location parameter
    this.address,
    this.wilaya,
    this.dateOfBirth,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Parse role safely
    UserRole parseRole(dynamic roleValue) {
      if (roleValue == null) return UserRole.customer;
      final roleStr = roleValue.toString().toLowerCase();
      try {
        return UserRole.values.firstWhere(
          (role) =>
              role.toString().split('.').last.toLowerCase() == roleStr ||
              roleStr == 'restaurantowner' &&
                  role == UserRole.restaurantOwner ||
              roleStr == 'deliveryman' && role == UserRole.deliveryMan ||
              roleStr == 'delivery_man' && role == UserRole.deliveryMan,
          orElse: () => UserRole.customer,
        );
      } catch (e) {
        return UserRole.customer;
      }
    }

    return User(
      id: safeStringRequired(json['id'] ?? json['user_id'], fieldName: 'id'),
      name: safeString(json['full_name'] ?? json['name']),
      // Use safeString with default empty string to handle missing email gracefully
      email: safeString(json['email'], defaultValue: '') ?? '',
      phone: safeString(json['phone']),
      profileImage: safeString(
        json['avatar_url'] ?? json['profile_image'] ?? json['profileImage'],
      ),
      role: parseRole(json['role']),
      isEmailVerified: safeBool(
              json['is_email_verified'] ?? json['isEmailVerified'],
              defaultValue: false) ??
          false,
      isPhoneVerified: safeBool(
              json['is_phone_verified'] ?? json['isPhoneVerified'],
              defaultValue: false) ??
          false,
      createdAt: safeUtcRequired(
        json['created_at'] ?? json['createdAt'],
        fieldName: 'created_at',
      ),
      lastLoginAt: safeUtc(
        json['updated_at'] ?? json['last_login_at'] ?? json['lastLoginAt'],
      ),
      preferences: safeMap(json['preferences']),
      restaurantOwnerProfile: json['restaurantOwnerProfile'] != null &&
              json['restaurantOwnerProfile'] is Map
          ? RestaurantOwnerProfile.fromJson(
              Map<String, dynamic>.from(json['restaurantOwnerProfile']),
            )
          : null,
      deliveryManProfile: json['deliveryManProfile'] != null &&
              json['deliveryManProfile'] is Map
          ? DeliveryManProfile.fromJson(
              Map<String, dynamic>.from(json['deliveryManProfile']),
            )
          : null,
      location: json['location'] != null && json['location'] is Map
          ? Location.fromJson(Map<String, dynamic>.from(json['location']))
          : null,
      address: safeString(json['address']),
      wilaya: safeString(json['wilaya']),
      dateOfBirth: safeUtc(json['date_of_birth'] ?? json['dateOfBirth']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': name,
      'email': email,
      'phone': phone,
      'avatar_url': profileImage,
      'role': role.toString().split('.').last,
      'is_email_verified': isEmailVerified,
      'is_phone_verified': isPhoneVerified,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': lastLoginAt?.toUtc().toIso8601String(),
      'preferences': Map<String, dynamic>.from(preferences),
      'restaurantOwnerProfile': restaurantOwnerProfile?.toJson(),
      'deliveryManProfile': deliveryManProfile?.toJson(),
      'location': location?.toJson(),
      'address': address,
      'wilaya': wilaya,
      'date_of_birth': dateOfBirth?.toUtc().toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? profileImage,
    UserRole? role,
    bool? isEmailVerified,
    bool? isPhoneVerified,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    Map<String, dynamic>? preferences,
    RestaurantOwnerProfile? restaurantOwnerProfile,
    DeliveryManProfile? deliveryManProfile,
    Location? location,
    String? address,
    String? wilaya,
    DateTime? dateOfBirth,
  }) {
    return User(
      id: id ?? this.id,
      name: name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profileImage: profileImage ?? this.profileImage,
      role: role ?? this.role,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      preferences: preferences ?? this.preferences,
      restaurantOwnerProfile:
          restaurantOwnerProfile ?? this.restaurantOwnerProfile,
      deliveryManProfile: deliveryManProfile ?? this.deliveryManProfile,
      location: location ?? this.location,
      address: address ?? this.address,
      wilaya: wilaya ?? this.wilaya,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    );
  }

  // Role-based getters
  bool get isCustomer => role == UserRole.customer;
  bool get isRestaurantOwner => role == UserRole.restaurantOwner;
  bool get isDeliveryMan => role == UserRole.deliveryMan;
  bool get isAdmin => role == UserRole.admin;
  bool get canOwnRestaurant => isRestaurantOwner || isAdmin;
  bool get canOrder =>
      isCustomer || isRestaurantOwner || isDeliveryMan || isAdmin;

  // Profile data getters

  // Get verified phone number from preferences (set by verification system)
  String? get verifiedPhoneNumber {
    return PreferencesUtils.getStringPreference(
        preferences, 'verified_phone_number', '');
  }

  // Safe preference accessors using PreferencesUtils

  /// Get email notifications preference
  bool get emailNotifications {
    return PreferencesUtils.getBoolPreference(
        preferences, 'email_notifications', true);
  }

  /// Get SMS notifications preference
  bool get smsNotifications {
    return PreferencesUtils.getBoolPreference(
        preferences, 'sms_notifications', false);
  }

  /// Get push notifications preference
  bool get pushNotifications {
    return PreferencesUtils.getBoolPreference(
        preferences, 'push_notifications', true);
  }

  /// Get language preference
  String get language {
    return PreferencesUtils.getStringPreference(
        preferences, 'language', 'English');
  }

  /// Get currency preference
  String get currency {
    return PreferencesUtils.getStringPreference(preferences, 'currency', 'DZD');
  }

  /// Get any string preference with fallback
  String getStringPreference(String key, String defaultValue) {
    return PreferencesUtils.getStringPreference(preferences, key, defaultValue);
  }

  /// Get any boolean preference with fallback
  bool getBoolPreference(String key, {required bool defaultValue}) {
    return PreferencesUtils.getBoolPreference(preferences, key, defaultValue);
  }

  /// Get any DateTime preference with fallback
  DateTime? getDateTimePreference(String key) {
    return PreferencesUtils.getDateTimePreference(preferences, key);
  }

  /// Check if preferences are valid
  bool get hasValidPreferences {
    return PreferencesUtils.isValidPreferences(preferences);
  }

  @override
  String toString() {
    return 'User(id: $id, name: ${name ?? 'null'}, email: $email, role: $role)';
  }

  @override
  List<Object?> get props => [
        id,
        name,
        email,
        phone,
        profileImage,
        role,
        isEmailVerified,
        isPhoneVerified,
        createdAt,
        lastLoginAt,
        preferences,
        restaurantOwnerProfile,
        deliveryManProfile,
        location,
        address,
        wilaya,
        dateOfBirth,
      ];
}

// Supporting classes (if not already defined)
class RestaurantOwnerProfile {
  final String id;
  final String userId;
  final String businessName;
  final String businessDescription;
  final String? logoUrl; // Restaurant logo URL
  final bool isVerified;
  final DateTime createdAt;

  RestaurantOwnerProfile({
    required this.id,
    required this.userId,
    required this.businessName,
    required this.businessDescription,
    required this.createdAt,
    this.logoUrl,
    this.isVerified = false,
  });

  factory RestaurantOwnerProfile.fromJson(Map<String, dynamic> json) {
    return RestaurantOwnerProfile(
      id: safeStringRequired(json['id'], fieldName: 'id'),
      userId: safeStringRequired(json['user_id'], fieldName: 'user_id'),
      businessName:
          safeStringRequired(json['business_name'], fieldName: 'business_name'),
      businessDescription: safeStringRequired(
        json['business_description'],
        fieldName: 'business_description',
      ),
      logoUrl: safeString(json['logo_url'] ?? json['logoUrl']),
      isVerified: safeBool(json['is_verified'], defaultValue: false) ?? false,
      createdAt: safeUtcRequired(json['created_at'], fieldName: 'created_at'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'business_name': businessName,
      'business_description': businessDescription,
      'logo_url': logoUrl,
      'is_verified': isVerified,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}

// Delivery Man Profile class for role-based images
class DeliveryManProfile {
  final String id;
  final String userId;
  final String? profileImageUrl; // Delivery man profile image
  final String? vehicleType;
  final bool isVerified;
  final DateTime createdAt;

  DeliveryManProfile({
    required this.id,
    required this.userId,
    required this.createdAt,
    this.profileImageUrl,
    this.vehicleType,
    this.isVerified = false,
  });

  factory DeliveryManProfile.fromJson(Map<String, dynamic> json) {
    return DeliveryManProfile(
      id: safeStringRequired(json['id'], fieldName: 'id'),
      userId: safeStringRequired(json['user_id'], fieldName: 'user_id'),
      profileImageUrl:
          safeString(json['profile_image_url'] ?? json['profileImageUrl']),
      vehicleType: safeString(json['vehicle_type'] ?? json['vehicleType']),
      isVerified: safeBool(json['is_verified'], defaultValue: false) ?? false,
      createdAt: safeUtcRequired(json['created_at'], fieldName: 'created_at'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'profile_image_url': profileImageUrl,
      'vehicle_type': vehicleType,
      'is_verified': isVerified,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
