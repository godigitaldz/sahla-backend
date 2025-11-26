import 'package:equatable/equatable.dart';

/// Domain model for a review (restaurant or menu item).
class Review extends Equatable {
  const Review({
    required this.id,
    required this.userId,
    required this.rating,
    required this.createdAt,
    this.userName,
    this.userAvatar,
    this.comment,
    this.imageUrl,
    this.thumbnailUrl,
    this.photos,
    this.isVerified = false,
    this.restaurantId,
    this.menuItemId,
    this.menuItemName,
  });

  final String id;
  final String userId;
  final String? userName;
  final String? userAvatar;
  final int rating;
  final String? comment;
  final String? imageUrl;
  final String? thumbnailUrl;
  final List<String>? photos;
  final DateTime createdAt;
  final bool isVerified;
  final String? restaurantId;
  final String? menuItemId;
  final String? menuItemName;

  factory Review.fromJson(Map<String, dynamic> json) {
    // Handle nested user profile data
    final userProfile = json['user_profiles'] as Map<String, dynamic>?;

    // Parse photos - handle both single image and photos array (menu items only)
    final photos = <String>[];
    if (json['photos'] != null && json['photos'] is List) {
      photos.addAll(
        (json['photos'] as List)
            .map((e) => e.toString())
            .where((s) => s.isNotEmpty),
      );
    }
    if (json['image'] != null && json['image'].toString().isNotEmpty) {
      if (!photos.contains(json['image'].toString())) {
        photos.insert(0, json['image'].toString());
      }
    }

    // Handle both customer_id (restaurant reviews) and user_id (menu item reviews)
    final userId =
        json['customer_id']?.toString() ?? json['user_id']?.toString() ?? '';

    // Handle nested menu item data (Supabase returns single object for foreign keys)
    final menuItem = json['menu_items'];
    String? menuItemName;

    if (menuItem != null) {
      if (menuItem is Map<String, dynamic>) {
        menuItemName = menuItem['name']?.toString();
      } else if (menuItem is List && menuItem.isNotEmpty) {
        menuItemName =
            (menuItem.first as Map<String, dynamic>)['name']?.toString();
      }
    }

    return Review(
      id: json['id'].toString(),
      userId: userId,
      userName: userProfile?['name']?.toString(),
      userAvatar: userProfile?['profile_image_url']?.toString(),
      rating: json['rating'] as int,
      comment: json['comment']?.toString(),
      imageUrl: photos.isNotEmpty ? photos.first : null,
      thumbnailUrl: json['thumbnail_url']?.toString(),
      photos: photos.isNotEmpty ? photos : null,
      createdAt: DateTime.parse(json['created_at'].toString()),
      isVerified: false, // restaurant_reviews doesn't have this field
      restaurantId: json['restaurant_id']?.toString(),
      menuItemId: json['menu_item_id']?.toString(),
      menuItemName: menuItemName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'rating': rating,
      'comment': comment,
      'image': imageUrl,
      'thumbnail_url': thumbnailUrl,
      'photos': photos,
      'created_at': createdAt.toIso8601String(),
      'is_verified_purchase': isVerified,
      'restaurant_id': restaurantId,
      'menu_item_id': menuItemId,
      'user_profiles': {
        'name': userName,
        'profile_image': userAvatar,
      },
      'menu_items': menuItemName != null ? {'name': menuItemName} : null,
    };
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        userName,
        userAvatar,
        rating,
        comment,
        imageUrl,
        thumbnailUrl,
        photos,
        createdAt,
        isVerified,
        restaurantId,
        menuItemId,
        menuItemName,
      ];
}
