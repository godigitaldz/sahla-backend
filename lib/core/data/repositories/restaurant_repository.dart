import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/restaurant.dart';
import '../repository_base.dart';

/// Repository for restaurants with 3-tier caching
class RestaurantRepository extends RepositoryBase<String, Restaurant> {
  final SupabaseClient _supabase;

  RestaurantRepository({
    Duration? memoryTtl,
    Duration? diskTtl,
    int? maxMemorySize,
    SupabaseClient? supabaseClient,
  })  : _supabase = supabaseClient ?? Supabase.instance.client,
        super(
          memoryTtl: memoryTtl ?? const Duration(minutes: 10),
          diskTtl: diskTtl ?? const Duration(hours: 24),
          maxMemorySize: maxMemorySize ?? 200,
        );

  @override
  Future<Restaurant> fetchFromNetwork(String key) async {
    try {
      final response = await _supabase
          .from('restaurants')
          .select('*')
          .eq('id', key)
          .single();

      return fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error fetching restaurant $key from network: $e');
      rethrow;
    }
  }

  @override
  Map<String, dynamic> toJson(Restaurant value) {
    // Use Restaurant's toJson if available, otherwise create manually
    try {
      return value.toJson();
    } catch (e) {
      // Fallback to manual conversion
      return {
        'id': value.id,
        'owner_id': value.ownerId,
        'name': value.name,
        'description': value.description,
        'phone': value.phone,
        'address_line1': value.addressLine1,
        'city': value.city,
        'state': value.state,
        'rating': value.rating,
        'review_count': value.reviewCount,
        'delivery_fee': value.deliveryFee,
        'minimum_order': value.minimumOrder,
        'estimated_delivery_time': value.estimatedDeliveryTime,
        'is_open': value.isOpen,
        'is_featured': value.isFeatured,
        'is_verified': value.isVerified,
        'created_at': value.createdAt.toIso8601String(),
        'updated_at': value.updatedAt.toIso8601String(),
        if (value.image != null) 'image': value.image,
        if (value.email != null) 'email': value.email,
        if (value.addressLine2 != null) 'address_line2': value.addressLine2,
        if (value.postalCode != null) 'postal_code': value.postalCode,
        if (value.latitude != null) 'latitude': value.latitude,
        if (value.longitude != null) 'longitude': value.longitude,
        if (value.wilaya != null) 'wilaya': value.wilaya,
        if (value.logoUrl != null) 'logo_url': value.logoUrl,
      };
    }
  }

  @override
  Restaurant fromJson(Map<String, dynamic> json) {
    return Restaurant.fromJson(json);
  }

  /// Get restaurant by owner ID
  Future<CacheResult<Restaurant>> getByOwnerId(String ownerId) async {
    return get('owner:$ownerId', forceRefresh: false);
  }

  /// Get multiple restaurants with pagination
  Future<List<Restaurant>> getRestaurants({
    int offset = 0,
    int limit = 20,
    String? category,
    String? cuisine,
    bool? isOpen,
    bool? isFeatured,
  }) async {
    try {
      var query = _supabase.from('restaurants').select('*');

      if (category != null) {
        query = query.eq('category', category);
      }
      if (cuisine != null) {
        query = query.eq('cuisine_type', cuisine);
      }
      if (isOpen != null) {
        query = query.eq('is_open', isOpen);
      }
      if (isFeatured != null) {
        query = query.eq('is_featured', isFeatured);
      }

      final response = await query
          .order('rating', ascending: false)
          .range(offset, offset + limit - 1);

      final restaurants = (response as List)
          .map((json) => Restaurant.fromJson(json as Map<String, dynamic>))
          .toList();

      // Cache each restaurant individually
      for (final restaurant in restaurants) {
        unawaited(cacheItem(restaurant.id, restaurant));
      }

      return restaurants;
    } catch (e) {
      debugPrint('Error fetching restaurants: $e');
      return [];
    }
  }
}
