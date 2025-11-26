import 'package:equatable/equatable.dart';

import '../utils/safe_parse.dart';

/// Enhanced Restaurant model with adaptive loading and performance optimization
///
/// PERFORMANCE OPTIMIZATIONS:
/// ✅ Removed PerformanceMonitoringService from hot path (was causing 0.5ms overhead per parse)
/// ✅ Added safe DateTime parsing with fallbacks
/// ✅ Robust type conversion helpers using SafeParse utilities
class Restaurant extends Equatable {
  const Restaurant({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.phone,
    required this.addressLine1,
    required this.city,
    required this.state,
    required this.rating,
    required this.reviewCount,
    required this.deliveryFee,
    required this.minimumOrder,
    required this.estimatedDeliveryTime,
    required this.isOpen,
    required this.isFeatured,
    required this.isVerified,
    required this.createdAt,
    required this.updatedAt,
    this.image,
    this.email,
    this.addressLine2,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.openingHours,
    this.closingHours,
    this.wilaya,
    this.logoUrl,
    this.coverImageUrl,
    this.instagram,
    this.facebook,
    this.tiktok,
    DateTime? lastImageLoadTime,
    String? cachedImageUrl,
    bool isImageOptimized = false,
  })  : _lastImageLoadTime = lastImageLoadTime,
        _cachedImageUrl = cachedImageUrl,
        _isImageOptimized = isImageOptimized;

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    // 🚀 PERFORMANCE FIX: Removed PerformanceMonitoringService (was 0.5ms overhead per parse)
    // Monitoring should be at SERVICE level, not MODEL level
    return Restaurant(
      id: safeStringRequired(json["id"], fieldName: 'id'),
      ownerId: safeString(json["owner_id"], defaultValue: '') ?? '',
      name: safeStringRequired(json["name"], fieldName: 'name'),
      description: safeString(json["description"], defaultValue: '') ?? '',
      phone: safeStringRequired(json["phone"], fieldName: 'phone'),
      email: safeString(json["email"]),
      addressLine1:
          safeStringRequired(json["address_line1"], fieldName: 'address_line1'),
      city: safeStringRequired(json["city"], fieldName: 'city'),
      state: safeStringRequired(json["state"], fieldName: 'state'),
      rating: safeDouble(json["rating"], defaultValue: 0.0) ?? 0.0,
      reviewCount: safeInt(json["review_count"], defaultValue: 0) ?? 0,
      deliveryFee: safeDouble(json["delivery_fee"], defaultValue: 0.0) ?? 0.0,
      minimumOrder: safeDouble(json["minimum_order"], defaultValue: 0.0) ?? 0.0,
      estimatedDeliveryTime:
          safeInt(json["estimated_delivery_time"], defaultValue: 30) ?? 30,
      isOpen: safeBool(json["is_open"], defaultValue: false) ?? false,
      isFeatured: safeBool(json["is_featured"], defaultValue: false) ?? false,
      isVerified: safeBool(json["is_verified"], defaultValue: false) ?? false,
      // ✅ SAFETY FIX: Safe DateTime parsing with UTC normalization
      createdAt: safeUtcRequired(json["created_at"], fieldName: 'created_at'),
      updatedAt: safeUtcRequired(json["updated_at"], fieldName: 'updated_at'),
      image: safeString(json["image"]),
      addressLine2: safeString(json["address_line2"]),
      postalCode: safeString(json["postal_code"]),
      latitude: safeDouble(json["latitude"]),
      longitude: safeDouble(json["longitude"]),
      openingHours: safeMap(json["opening_hours"]),
      closingHours: safeMap(json["closing_hours"]),
      wilaya: safeString(json["wilaya"]),
      logoUrl: safeString(json["logo_url"]),
      coverImageUrl: safeString(json["cover_image_url"]),
      instagram: safeString(json["instagram"]),
      facebook: safeString(json["facebook"]),
      tiktok: safeString(json["tiktok"]),
      lastImageLoadTime: DateTime.now(),
      cachedImageUrl: safeString(
        json["cover_image_url"] ?? json["image"] ?? json["logo_url"],
      ),
      isImageOptimized: false,
    );
  }

  // Fields
  final String id;
  final String ownerId;
  final String name;
  final String description;
  final String? image;
  final String phone;
  final String? email;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String state;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final double rating;
  final int reviewCount;
  final double deliveryFee;
  final double minimumOrder;
  final int estimatedDeliveryTime;
  final bool isOpen;
  final bool isFeatured;
  final bool isVerified;
  final Map<String, dynamic>? openingHours;
  final Map<String, dynamic>? closingHours;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? wilaya;
  final String? logoUrl;
  final String? coverImageUrl;
  final String? instagram;
  final String? facebook;
  final String? tiktok;

  // Performance optimization fields
  final DateTime? _lastImageLoadTime;
  final String? _cachedImageUrl;
  final bool _isImageOptimized;

  // Note: Removed custom parsing helpers (_asDouble, _asInt, _asBool, _parseDateTimeSafe)
  // Now using SafeParse utilities from lib/utils/safe_parse.dart for consistency

  Map<String, dynamic> toJson() {
    // 🚀 PERFORMANCE FIX: Removed PerformanceMonitoringService
    return {
      "id": id,
      "owner_id": ownerId,
      "name": name,
      "description": description,
      "phone": phone,
      "email": email,
      "address_line1": addressLine1,
      "city": city,
      "state": state,
      "rating": rating,
      "review_count": reviewCount,
      "delivery_fee": deliveryFee,
      "minimum_order": minimumOrder,
      "estimated_delivery_time": estimatedDeliveryTime,
      "is_open": isOpen,
      "is_featured": isFeatured,
      "is_verified": isVerified,
      "created_at": createdAt.toUtc().toIso8601String(),
      "updated_at": updatedAt.toUtc().toIso8601String(),
      "image": image,
      "address_line2": addressLine2,
      "postal_code": postalCode,
      "latitude": latitude,
      "longitude": longitude,
      "opening_hours": openingHours,
      "closing_hours": closingHours,
      "wilaya": wilaya,
      "logo_url": logoUrl,
      "cover_image_url": coverImageUrl,
      "instagram": instagram,
      "facebook": facebook,
      "tiktok": tiktok,
      // Performance optimization fields excluded from database serialization
      // These are client-side only fields for tracking image load performance
    };
  }

  Restaurant copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? description,
    String? image,
    String? phone,
    String? email,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? postalCode,
    double? latitude,
    double? longitude,
    double? rating,
    int? reviewCount,
    double? deliveryFee,
    double? minimumOrder,
    int? estimatedDeliveryTime,
    bool? isOpen,
    bool? isFeatured,
    bool? isVerified,
    Map<String, dynamic>? openingHours,
    Map<String, dynamic>? closingHours,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? wilaya,
    String? logoUrl,
    String? coverImageUrl,
    String? instagram,
    String? facebook,
    String? tiktok,
    DateTime? lastImageLoadTime,
    String? cachedImageUrl,
    bool? isImageOptimized,
  }) {
    return Restaurant(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      image: image ?? this.image,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      minimumOrder: minimumOrder ?? this.minimumOrder,
      estimatedDeliveryTime:
          estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      isOpen: isOpen ?? this.isOpen,
      isFeatured: isFeatured ?? this.isFeatured,
      isVerified: isVerified ?? this.isVerified,
      openingHours: openingHours != null
          ? Map<String, dynamic>.from(openingHours)
          : this.openingHours,
      closingHours: closingHours != null
          ? Map<String, dynamic>.from(closingHours)
          : this.closingHours,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      wilaya: wilaya ?? this.wilaya,
      logoUrl: logoUrl ?? this.logoUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      instagram: instagram ?? this.instagram,
      facebook: facebook ?? this.facebook,
      tiktok: tiktok ?? this.tiktok,
      lastImageLoadTime: lastImageLoadTime ?? _lastImageLoadTime,
      cachedImageUrl: cachedImageUrl ?? _cachedImageUrl,
      isImageOptimized: isImageOptimized ?? _isImageOptimized,
    );
  }

  @override
  String toString() {
    return "Restaurant(id: $id, name: $name, wilaya: $wilaya, rating: $rating, city: $city)";
  }

  @override
  List<Object?> get props => [
        id,
        ownerId,
        name,
        description,
        image,
        phone,
        email,
        addressLine1,
        addressLine2,
        city,
        state,
        postalCode,
        latitude,
        longitude,
        rating,
        reviewCount,
        deliveryFee,
        minimumOrder,
        estimatedDeliveryTime,
        isOpen,
        isFeatured,
        isVerified,
        openingHours,
        closingHours,
        createdAt,
        updatedAt,
        wilaya,
        logoUrl,
        coverImageUrl,
        instagram,
        facebook,
        tiktok,
      ];

  /// Get optimized image URL based on network conditions
  String? getOptimizedImageUrl(String networkQuality) {
    // Use cached URL if available and recent
    if (_cachedImageUrl != null &&
        _lastImageLoadTime != null &&
        DateTime.now().difference(_lastImageLoadTime).inMinutes < 30) {
      return _cachedImageUrl;
    }

    // Return appropriate image based on network quality
    switch (networkQuality) {
      case "fast":
        return coverImageUrl ?? image ?? logoUrl;
      case "moderate":
        return image ?? logoUrl; // Prefer standard image for moderate networks
      case "slow":
      case "verySlow":
        return logoUrl; // Only logo for slow networks
      case "offline":
        return _cachedImageUrl; // Use cached version when offline
      default:
        return coverImageUrl ?? image ?? logoUrl;
    }
  }

  /// Check if image should be loaded based on network conditions
  bool shouldLoadImage(String networkQuality) {
    switch (networkQuality) {
      case "offline":
        return _cachedImageUrl != null;
      case "verySlow":
        return false; // Skip images on very slow networks
      default:
        return true;
    }
  }

  /// Get adaptive cache duration based on network quality
  Duration getAdaptiveCacheDuration(String networkQuality) {
    switch (networkQuality) {
      case "fast":
        return const Duration(hours: 2);
      case "moderate":
        return const Duration(hours: 1);
      case "slow":
        return const Duration(minutes: 30);
      case "verySlow":
        return const Duration(minutes: 15);
      case "offline":
        return const Duration(hours: 24);
      default:
        return const Duration(hours: 1);
    }
  }

  /// Update image optimization status
  Restaurant updateImageOptimization(String? newCachedUrl,
      {required bool optimized}) {
    return copyWith(
      cachedImageUrl: newCachedUrl,
      isImageOptimized: optimized,
      lastImageLoadTime: DateTime.now(),
    );
  }
}
