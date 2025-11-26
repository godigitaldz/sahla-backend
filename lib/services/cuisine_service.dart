import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cuisine_type.dart';

class CuisineService {
  static final CuisineService _instance = CuisineService._internal();
  factory CuisineService() => _instance;
  CuisineService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  // Ultra-fast synchronous cache
  static List<CuisineType>? _cachedCuisines;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(hours: 2);

  // Preloaded data from startup service
  static List<CuisineType>? _preloadedCuisines;

  /// ULTRA-FAST: Get cuisines synchronously from cache (0ms response)
  static List<CuisineType>? getActiveCuisineTypesSync() {
    // 1. Check preloaded data first (fastest)
    if (_preloadedCuisines != null) return _preloadedCuisines!;

    // 2. Check memory cache (very fast)
    if (_cachedCuisines != null && _cacheTimestamp != null) {
      final age = DateTime.now().difference(_cacheTimestamp!);
      if (age < _cacheDuration) return _cachedCuisines!;
    }

    return null;
  }

  /// Set preloaded cuisines for ultra-fast access
  static void setPreloadedCuisines(List<CuisineType> cuisines) {
    _preloadedCuisines = cuisines;
    _cachedCuisines = cuisines;
    _cacheTimestamp = DateTime.now();
  }

  /// Get all active cuisine types - OPTIMIZED with aggressive caching
  Future<List<CuisineType>> getActiveCuisineTypes() async {
    try {
      // Check synchronous cache first (0ms response)
      final cached = getActiveCuisineTypesSync();
      if (cached != null) return cached;

      // Fetch from Supabase if not cached
      return await _getCuisinesFromSupabase();
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading cuisines: $e');
      return _getCuisinesFromSupabase();
    }
  }

  /// Fallback method for direct Supabase calls - OPTIMIZED
  Future<List<CuisineType>> _getCuisinesFromSupabase() async {
    try {
      // Simplified query - fetch active cuisines only, sort in memory
      final response =
          await _supabase.from('cuisine_types').select().eq('is_active', true);

      final cuisineTypes =
          (response as List).map((json) => CuisineType.fromJson(json)).toList();

      // Sort in memory (faster than database sort)
      cuisineTypes.sort((a, b) {
        // Sort by display_order first, then by name
        final orderCompare = a.displayOrder.compareTo(b.displayOrder);
        return orderCompare != 0 ? orderCompare : a.name.compareTo(b.name);
      });

      // Cache for future ultra-fast access
      _cachedCuisines = cuisineTypes;
      _cacheTimestamp = DateTime.now();

      if (kDebugMode) {
        debugPrint('✅ Loaded ${cuisineTypes.length} cuisines');
      }
      return cuisineTypes;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to fetch cuisines: $e');
      }
      throw Exception('Failed to fetch cuisine types: $e');
    }
  }

  /// Get all cuisine types (including inactive)
  Future<List<CuisineType>> getAllCuisineTypes() async {
    try {
      final response = await _supabase
          .from('cuisine_types')
          .select()
          .order('display_order')
          .order('name');

      return (response as List)
          .map((json) => CuisineType.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch all cuisine types: $e');
    }
  }

  /// Get cuisine type by ID
  Future<CuisineType?> getCuisineTypeById(String id) async {
    try {
      final response =
          await _supabase.from('cuisine_types').select().eq('id', id).single();

      return CuisineType.fromJson(response);
    } catch (e) {
      if (e.toString().contains('PGRST116')) {
        return null; // Not found
      }
      throw Exception('Failed to fetch cuisine type: $e');
    }
  }

  /// Get cuisine type by name
  Future<CuisineType?> getCuisineTypeByName(String name) async {
    try {
      final response = await _supabase
          .from('cuisine_types')
          .select()
          .eq('name', name)
          .single();

      return CuisineType.fromJson(response);
    } catch (e) {
      if (e.toString().contains('PGRST116')) {
        return null; // Not found
      }
      throw Exception('Failed to fetch cuisine type by name: $e');
    }
  }

  /// Create a new cuisine type
  Future<CuisineType> createCuisineType(CuisineType cuisineType) async {
    try {
      final response = await _supabase
          .from('cuisine_types')
          .insert(cuisineType.toJson())
          .select()
          .single();

      return CuisineType.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create cuisine type: $e');
    }
  }

  /// Update a cuisine type
  Future<CuisineType> updateCuisineType(CuisineType cuisineType) async {
    try {
      final response = await _supabase
          .from('cuisine_types')
          .update(cuisineType.toJson())
          .eq('id', cuisineType.id)
          .select()
          .single();

      return CuisineType.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update cuisine type: $e');
    }
  }

  /// Delete a cuisine type (soft delete by setting is_active to false)
  Future<void> deleteCuisineType(String id) async {
    try {
      await _supabase
          .from('cuisine_types')
          .update({'is_active': false}).eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete cuisine type: $e');
    }
  }

  /// Hard delete a cuisine type
  Future<void> hardDeleteCuisineType(String id) async {
    try {
      await _supabase.from('cuisine_types').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to hard delete cuisine type: $e');
    }
  }

  /// Search cuisine types by name
  Future<List<CuisineType>> searchCuisineTypes(String query) async {
    try {
      final response = await _supabase
          .from('cuisine_types')
          .select()
          .ilike('name', '%$query%')
          .eq('is_active', true)
          .order('display_order')
          .order('name');

      return (response as List)
          .map((json) => CuisineType.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to search cuisine types: $e');
    }
  }
}
