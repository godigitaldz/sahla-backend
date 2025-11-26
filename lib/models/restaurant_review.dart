import "package:flutter/foundation.dart";

import "../services/performance_monitoring_service.dart";
import "user.dart" as app_user;

/// Enhanced RestaurantReview model with adaptive loading and performance optimization
class RestaurantReview {
  final String id;
  final String restaurantId;
  final String userId;
  final int rating; // 1-5 stars
  final String? comment;
  final String? image;
  final List<String>? photos;
  final bool isVerifiedPurchase;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Related data
  final app_user.User? user;
  final String? restaurantName;

  // Performance optimization fields
  final DateTime? _lastLoadTime;
  final bool _isImageOptimized;
  final int _imageLoadCount;
  final double _averageLoadTime;

  const RestaurantReview({
    required this.id,
    required this.restaurantId,
    required this.userId,
    required this.rating,
    required this.createdAt,
    required this.updatedAt,
    this.comment,
    this.image,
    this.photos,
    this.isVerifiedPurchase = false,
    this.user,
    this.restaurantName,
    DateTime? lastLoadTime,
    bool isImageOptimized = false,
    int imageLoadCount = 0,
    double averageLoadTime = 0.0,
  })  : _lastLoadTime = lastLoadTime,
        _isImageOptimized = isImageOptimized,
        _imageLoadCount = imageLoadCount,
        _averageLoadTime = averageLoadTime;

  factory RestaurantReview.fromJson(Map<String, dynamic> json) {
    // Start performance monitoring for review parsing
    final performanceService = PerformanceMonitoringService();
    performanceService.startOperation("restaurant_review_parsing");

    try {
      final review = RestaurantReview(
        id: json["id"] ?? "",
        restaurantId: json["restaurant_id"] ?? "",
        userId: json["user_id"] ?? "",
        rating: json["rating"] ?? 5,
        createdAt: json["created_at"] != null
            ? DateTime.parse(json["created_at"])
            : DateTime.now(),
        updatedAt: json["updated_at"] != null
            ? DateTime.parse(json["updated_at"])
            : DateTime.now(),
        comment: json["comment"],
        image: json["image"],
        photos:
            json["photos"] != null ? List<String>.from(json["photos"]) : null,
        isVerifiedPurchase: json["is_verified_purchase"] ?? false,
        user: json["user_profiles"] != null
            ? _parseUserFromProfile(
                json["user_profiles"],
                json["customer_id"] ?? json["user_id"],
              )
            : null,
        restaurantName: json["restaurant_name"],
        lastLoadTime: DateTime.now(),
        isImageOptimized: false,
        imageLoadCount: 0,
        averageLoadTime: 0,
      );

      performanceService.endOperation("restaurant_review_parsing");
      return review;
    } catch (e) {
      performanceService.endOperation("restaurant_review_parsing");
      rethrow;
    }
  }

  /// Helper method to safely parse user profile with missing id field
  static app_user.User? _parseUserFromProfile(
    dynamic userProfileData,
    dynamic userId,
  ) {
    try {
      if (userProfileData == null) return null;

      // Convert to Map if needed
      final userProfile = userProfileData is Map<String, dynamic>
          ? Map<String, dynamic>.from(userProfileData)
          : <String, dynamic>{};

      // Add id field if missing (use customer_id/user_id from review)
      if (!userProfile.containsKey('id') &&
          !userProfile.containsKey('user_id')) {
        final userIdStr = userId?.toString();
        if (userIdStr != null && userIdStr.isNotEmpty) {
          userProfile['id'] = userIdStr;
          userProfile['user_id'] = userIdStr;
        } else {
          // If no user id available, return null
          return null;
        }
      }

      return app_user.User.fromJson(userProfile);
    } catch (e) {
      // If parsing fails, return null instead of throwing
      debugPrint('⚠️ RestaurantReview: Error parsing user profile: $e');
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    // Start performance monitoring for review serialization
    final performanceService = PerformanceMonitoringService();
    performanceService.startOperation("restaurant_review_serialization");

    try {
      final json = {
        "id": id,
        "restaurant_id": restaurantId,
        "user_id": userId,
        "rating": rating,
        "comment": comment,
        "image": image,
        "photos": photos,
        "is_verified_purchase": isVerifiedPurchase,
        "created_at": createdAt.toIso8601String(),
        "updated_at": updatedAt.toIso8601String(),
        "user_profiles": user?.toJson(),
        "restaurant_name": restaurantName,
        // Performance optimization fields excluded from database serialization
        // These are client-side only fields for tracking review performance
      };

      performanceService.endOperation("restaurant_review_serialization");
      return json;
    } catch (e) {
      performanceService.endOperation("restaurant_review_serialization");
      rethrow;
    }
  }

  RestaurantReview copyWith({
    String? id,
    String? restaurantId,
    String? userId,
    int? rating,
    String? comment,
    String? image,
    List<String>? photos,
    bool? isVerifiedPurchase,
    DateTime? createdAt,
    DateTime? updatedAt,
    app_user.User? user,
    String? restaurantName,
    DateTime? lastLoadTime,
    bool? isImageOptimized,
    int? imageLoadCount,
    double? averageLoadTime,
  }) {
    return RestaurantReview(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      userId: userId ?? this.userId,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      comment: comment ?? this.comment,
      image: image ?? this.image,
      photos: photos ?? this.photos,
      isVerifiedPurchase: isVerifiedPurchase ?? this.isVerifiedPurchase,
      user: user ?? this.user,
      restaurantName: restaurantName ?? this.restaurantName,
      lastLoadTime: lastLoadTime ?? _lastLoadTime,
      isImageOptimized: isImageOptimized ?? _isImageOptimized,
      imageLoadCount: imageLoadCount ?? _imageLoadCount,
      averageLoadTime: averageLoadTime ?? _averageLoadTime,
    );
  }

  @override
  String toString() {
    return "RestaurantReview(id: $id, restaurantId: $restaurantId, rating: $rating, comment: ${comment?.substring(0, (comment?.length ?? 0) > 50 ? 50 : (comment?.length ?? 0))}...)";
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is RestaurantReview && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Helper methods
  bool get hasComment => comment?.isNotEmpty ?? false;
  bool get hasImage => image?.isNotEmpty ?? false;
  bool get hasPhotos => photos?.isNotEmpty ?? false;
  bool get hasMedia => hasImage || hasPhotos;

  String get ratingText {
    switch (rating) {
      case 1:
        return "Poor";
      case 2:
        return "Fair";
      case 3:
        return "Good";
      case 4:
        return "Very Good";
      case 5:
        return "Excellent";
      default:
        return "Unknown";
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return "$years year${years > 1 ? "s" : ""} ago";
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return "$months month${months > 1 ? "s" : ""} ago";
    } else if (difference.inDays > 0) {
      return "${difference.inDays} day${difference.inDays > 1 ? "s" : ""} ago";
    } else if (difference.inHours > 0) {
      return "${difference.inHours} hour${difference.inHours > 1 ? "s" : ""} ago";
    } else if (difference.inMinutes > 0) {
      return "${difference.inMinutes} minute${difference.inMinutes > 1 ? "s" : ""} ago";
    } else {
      return "Just now";
    }
  }

  /// Get optimized image URL based on network conditions
  String? getOptimizedImageUrl(String networkQuality) {
    // Use cached URL if available and recent
    if (_lastLoadTime != null &&
        DateTime.now().difference(_lastLoadTime).inMinutes < 30) {
      return image;
    }

    // Return appropriate image based on network quality
    switch (networkQuality) {
      case "fast":
        return image?.isNotEmpty == true ? image : null;
      case "moderate":
        return image?.isNotEmpty == true
            ? image
            : null; // Still load images on moderate
      case "slow":
        return null; // Skip images on slow networks
      case "verySlow":
        return null; // Skip images on very slow networks
      case "offline":
        return null; // No images when offline
      default:
        return image?.isNotEmpty == true ? image : null;
    }
  }

  /// Check if image should be loaded based on network conditions
  bool shouldLoadImage(String networkQuality) {
    switch (networkQuality) {
      case "offline":
        return false;
      case "slow":
      case "verySlow":
        return false; // Skip images on slow networks
      default:
        return image?.isNotEmpty == true;
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
  RestaurantReview updateImageOptimization(String? newImageUrl,
      {required bool optimized, required double loadTime}) {
    final newLoadCount = _imageLoadCount + 1;
    final newAverageTime =
        (_averageLoadTime * _imageLoadCount + loadTime) / newLoadCount;

    return copyWith(
      image: newImageUrl ?? image,
      isImageOptimized: optimized,
      lastLoadTime: DateTime.now(),
      imageLoadCount: newLoadCount,
      averageLoadTime: newAverageTime,
    );
  }

  /// Get performance metrics for this review
  Map<String, dynamic> getPerformanceMetrics() {
    return {
      "image_load_count": _imageLoadCount,
      "average_load_time": _averageLoadTime,
      "is_image_optimized": _isImageOptimized,
      "last_load_time": _lastLoadTime?.toIso8601String(),
      "has_image": image?.isNotEmpty ?? false,
    };
  }
}
