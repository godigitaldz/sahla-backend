import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for loading images via Node.js API with Supabase fallback
/// Provides optimized batch loading and caching for better performance
class ImageApiService {
  static final ImageApiService _instance = ImageApiService._internal();
  factory ImageApiService() => _instance;
  ImageApiService._internal();

  // Backend API base URL - set this to enable Node.js API
  // If empty, will fallback to Supabase direct calls
  static String? _backendBaseUrl;

  /// Set backend base URL (e.g., 'http://localhost:3001' or 'https://api.example.com')
  static void setBackendUrl(String? url) {
    _backendBaseUrl = url;
    debugPrint('🔄 ImageApiService: Backend URL set to: ${url ?? "null (using Supabase fallback)"}');
  }

  /// Get backend base URL
  static String? get backendUrl => _backendBaseUrl;

  /// Check if backend API is enabled
  static bool get isBackendEnabled => _backendBaseUrl != null && _backendBaseUrl!.isNotEmpty;

  // HTTP client with timeout
  final http.Client _httpClient = http.Client();
  static const Duration _timeout = Duration(seconds: 10);

  /// Batch load images by menu item IDs
  /// Returns a map of item ID to image URL
  Future<Map<String, String>> loadImagesBatch(List<String> itemIds) async {
    if (itemIds.isEmpty) {
      return {};
    }

    debugPrint('🔄 ImageApiService: loadImagesBatch called with ${itemIds.length} item IDs');
    debugPrint('   Backend enabled: $isBackendEnabled');
    debugPrint('   Backend URL: $_backendBaseUrl');

    // Try Node.js API first if enabled
    if (isBackendEnabled) {
      try {
        debugPrint('🚀 ImageApiService: Attempting API call...');
        return await _loadImagesBatchFromApi(itemIds);
      } catch (e) {
        debugPrint('⚠️ ImageApiService: API call failed, falling back to Supabase: $e');
        // Fallback to Supabase
      }
    } else {
      debugPrint('⚠️ ImageApiService: Backend not enabled, using Supabase fallback');
    }

    // Fallback to Supabase direct call
    return await _loadImagesBatchFromSupabase(itemIds);
  }

  /// Load images from Node.js API
  Future<Map<String, String>> _loadImagesBatchFromApi(List<String> itemIds) async {
    final url = Uri.parse('$_backendBaseUrl/api/images/batch');
    debugPrint('🔄 ImageApiService: Calling API: POST $url with ${itemIds.length} item IDs');

    try {
      final response = await _httpClient
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({'itemIds': itemIds}),
          )
          .timeout(_timeout);

      debugPrint('📡 ImageApiService: API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final imageMap = Map<String, String>.from(data['data']);
          debugPrint('✅ ImageApiService: Loaded ${imageMap.length} images from API');
          return imageMap;
        } else {
          debugPrint('⚠️ ImageApiService: API returned success=false or null data');
        }
      } else {
        debugPrint('❌ ImageApiService: API returned status ${response.statusCode}: ${response.body}');
      }

      throw Exception('API request failed with status ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ ImageApiService: API call error: $e');
      rethrow;
    }
  }

  /// Load images from Supabase (fallback)
  Future<Map<String, String>> _loadImagesBatchFromSupabase(List<String> itemIds) async {
    try {
      debugPrint('🔄 ImageApiService: Loading ${itemIds.length} images from Supabase');
      final startTime = DateTime.now();

      final supabase = Supabase.instance.client;

      // PERFORMANCE: Single batch query instead of N+1 queries
      // Only select id and image fields to minimize data transfer
      final response = await supabase
          .from('menu_items')
          .select('id, image')
          .inFilter('id', itemIds);

      // Build map from response
      final imageMap = <String, String>{};
      for (final item in (response as List)) {
        try {
          final id = item['id'] as String?;
          final image = item['image'] as String?;

          if (id != null && image != null && image.isNotEmpty) {
            imageMap[id] = image;
          }
        } catch (e) {
          debugPrint('⚠️ ImageApiService: Error parsing image for item: $e');
        }
      }

      final responseTime = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint(
          '✅ ImageApiService: Batch loaded ${imageMap.length}/${itemIds.length} images from Supabase in ${responseTime}ms');

      return imageMap;
    } catch (e) {
      debugPrint('❌ ImageApiService: Error batch loading images from Supabase: $e');
      return {};
    }
  }

  /// Load single image by menu item ID
  Future<String?> loadImageById(String itemId) async {
    if (itemId.isEmpty) {
      return null;
    }

    // Try Node.js API first if enabled
    if (isBackendEnabled) {
      try {
        return await _loadImageByIdFromApi(itemId);
      } catch (e) {
        debugPrint('⚠️ ImageApiService: API call failed, falling back to Supabase: $e');
        // Fallback to Supabase
      }
    }

    // Fallback to Supabase direct call
    return await _loadImageByIdFromSupabase(itemId);
  }

  /// Load single image from Node.js API
  Future<String?> _loadImageByIdFromApi(String itemId) async {
    final url = Uri.parse('$_backendBaseUrl/api/images/$itemId');

    final response = await _httpClient
        .get(
          url,
          headers: {
            'Accept': 'application/json',
          },
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true && data['data'] != null) {
        final imageUrl = data['data']['image'] as String?;
        debugPrint('✅ ImageApiService: Loaded image for $itemId from API');
        return imageUrl;
      }
    } else if (response.statusCode == 404) {
      return null; // Image not found
    }

    throw Exception('API request failed with status ${response.statusCode}');
  }

  /// Load single image from Supabase (fallback)
  Future<String?> _loadImageByIdFromSupabase(String itemId) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('menu_items')
          .select('image')
          .eq('id', itemId)
          .single();

      return response['image'] as String?;
    } catch (e) {
      debugPrint('❌ ImageApiService: Error loading image for $itemId from Supabase: $e');
      return null;
    }
  }

  /// Load drink images for a restaurant
  /// Returns a map of item ID to image URL for drinks only
  Future<Map<String, String>> loadDrinkImagesByRestaurant(String restaurantId) async {
    if (restaurantId.isEmpty) {
      return {};
    }

    // Try Node.js API first if enabled
    if (isBackendEnabled) {
      try {
        return await _loadDrinkImagesFromApi(restaurantId);
      } catch (e) {
        debugPrint('⚠️ ImageApiService: API call failed, falling back to Supabase: $e');
        // Fallback to Supabase
      }
    }

    // Fallback to Supabase direct call
    return await _loadDrinkImagesFromSupabase(restaurantId);
  }

  /// Load drink images from Node.js API
  Future<Map<String, String>> _loadDrinkImagesFromApi(String restaurantId) async {
    final url = Uri.parse('$_backendBaseUrl/api/images/drinks/$restaurantId');

    final response = await _httpClient
        .get(
          url,
          headers: {
            'Accept': 'application/json',
          },
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true && data['data'] != null) {
        final imageMap = Map<String, String>.from(data['data']);
        debugPrint('✅ ImageApiService: Loaded ${imageMap.length} drink images from API');
        return imageMap;
      }
    }

    throw Exception('API request failed with status ${response.statusCode}');
  }

  /// Load drink images from Supabase (fallback)
  Future<Map<String, String>> _loadDrinkImagesFromSupabase(String restaurantId) async {
    try {
      debugPrint('🔄 ImageApiService: Loading drink images for restaurant $restaurantId from Supabase');

      final supabase = Supabase.instance.client;

      // Query drinks with optimized select fields
      final response = await supabase
          .from('menu_items')
          .select('id, image, category')
          .eq('restaurant_id', restaurantId)
          .eq('is_available', true)
          .or('category.ilike.%drink%,category.ilike.%beverage%,category.ilike.%boisson%');

      // Build map from response (only items with valid images)
      final imageMap = <String, String>{};
      for (final item in (response as List)) {
        if (item['id'] != null && item['image'] != null) {
          imageMap[item['id']] = item['image'];
        }
      }

      debugPrint('✅ ImageApiService: Loaded ${imageMap.length} drink images from Supabase');
      return imageMap;
    } catch (e) {
      debugPrint('❌ ImageApiService: Error loading drink images from Supabase: $e');
      return {};
    }
  }

  /// Dispose resources
  void dispose() {
    _httpClient.close();
  }
}
