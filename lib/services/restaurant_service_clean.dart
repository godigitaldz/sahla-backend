import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import 'package:supabase_flutter/supabase_flutter.dart';

import "../models/restaurant.dart";
import "api_client.dart";
import "context_aware_service.dart";

class RestaurantService extends ChangeNotifier {
  // Context-aware service for tracking and validation
  final ContextAwareService _contextAware = ContextAwareService();

  // Initialize the service with context tracking
  Future<void> initialize() async {
    await _contextAware.initialize();
    debugPrint("🚀 RestaurantService initialized with context tracking");
  }

  // Get all restaurants with optional filters - REDIS OPTIMIZED
  Future<List<Restaurant>> getRestaurants({
    String? category,
    String? cuisine,
    bool? isOpen,
    bool? isFeatured,
    String? location,
    double? minRating,
    int offset = 0,
    int limit = 20,
  }) async {
    try {
      // Use Node.js backend for optimized restaurant data with business logic
      final response = await ApiClient.get(
          '/api/business/restaurants/optimized',
          queryParameters: {
            'category': category ?? '',
            'cuisine': cuisine ?? '',
            'location': location ?? '',
            'limit': limit.toString(),
            'offset': offset.toString(),
          });

      if (!response['success']) {
        debugPrint(
            "❌ RestaurantService: Error fetching restaurants: ${response['error']}");
        return [];
      }

      final restaurantsData = response['data'] as List;
      final restaurants =
          restaurantsData.map((json) => Restaurant.fromJson(json)).toList();

      debugPrint(
          "🚀 RestaurantService: Fetched ${restaurants.length} restaurants via Node.js backend");
      return restaurants;
    } catch (e) {
      debugPrint("❌ RestaurantService: Error fetching restaurants via API: $e");
      return [];
    }
  }

  // Get restaurant by ID
  Future<Restaurant?> getRestaurantById(String id) async {
    try {
      // Use Node.js backend for optimized restaurant data with business logic
      final response = await ApiClient.get(
        '/api/business/restaurants/optimized',
        queryParameters: {
          'restaurantId': id,
          'includeMetrics': 'true',
        },
      );

      if (!response['success'] || response['data'].isEmpty) {
        debugPrint(
            "Error fetching restaurant from Node.js backend: ${response['error']}");
        return null;
      }

      final restaurantData = response['data'];
      return Restaurant.fromJson(restaurantData);
    } on Exception catch (e) {
      debugPrint("Error fetching restaurant by ID via API: $e");
      return null;
    }
  }

  // Get restaurant by owner ID
  Future<Restaurant?> getRestaurantByOwnerId(String ownerId) async {
    try {
      debugPrint('🔍 Fetching restaurant for owner ID: $ownerId');

      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('restaurants')
          .select()
          .eq('owner_id', ownerId)
          .maybeSingle();

      if (response == null) {
        debugPrint('❌ No restaurant found for owner: $ownerId');
        return null;
      }

      debugPrint('✅ Found restaurant: ${response['name']} (${response['id']})');
      return Restaurant.fromJson(response);
    } catch (e) {
      debugPrint("❌ Error fetching restaurant by owner ID: $e");
      return null;
    }
  }
}
