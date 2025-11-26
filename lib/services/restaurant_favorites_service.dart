import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant.dart';

class RestaurantFavoritesService extends ChangeNotifier {
  SupabaseClient get _supabase => Supabase.instance.client;
  final Map<String, bool> _favorites = {};
  RealtimeChannel? _favoritesChannel;
  Timer? _syncTimer;

  bool isRestaurantFavorite(String restaurantId) {
    return _favorites[restaurantId] ?? false;
  }

  /// Initialize service with real-time subscriptions
  Future<void> initialize() async {
    await _loadUserFavorites();
    _setupRealtimeSubscription();
  }

  /// Setup real-time subscription for live updates
  void _setupRealtimeSubscription() {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      _favoritesChannel?.unsubscribe();
      _favoritesChannel = _supabase
          .channel('restaurant_favorites_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'user_favorites',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) async {
              debugPrint(
                  '🔄 Restaurant favorites real-time update: ${payload.eventType}');
              await _loadUserFavorites();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('❌ Failed to setup restaurant favorites realtime: $e');
    }
  }

  /// Toggle restaurant favorite status with optimistic updates
  Future<bool> toggleRestaurantFavorite(Restaurant restaurant) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final currentState = _favorites[restaurant.id] ?? false;
      final newState = !currentState;

      // Optimistic update
      _favorites[restaurant.id] = newState;
      notifyListeners();

      if (newState) {
        // Add to favorites
        await _supabase.from('user_favorites').upsert({
          'user_id': userId,
          'restaurant_id': restaurant.id,
          'created_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id,restaurant_id');
      } else {
        // Remove from favorites
        await _supabase.from('user_favorites').delete().match({
          'user_id': userId,
          'restaurant_id': restaurant.id,
        });
      }

      debugPrint(
          '✅ Restaurant ${restaurant.name} ${newState ? 'added to' : 'removed from'} favorites');
      return true;
    } catch (e) {
      // Rollback optimistic update on error
      final currentState = _favorites[restaurant.id] ?? false;
      _favorites[restaurant.id] = !currentState;
      notifyListeners();

      debugPrint('❌ Error toggling restaurant favorite: $e');
      return false;
    }
  }

  Future<void> addRestaurantToFavorites(Restaurant restaurant) async {
    await toggleRestaurantFavorite(restaurant);
  }

  Future<void> removeRestaurantFromFavorites(String restaurantId) async {
    // Find restaurant by ID (this is a legacy method, prefer toggleRestaurantFavorite)
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('user_favorites').delete().match({
        'user_id': userId,
        'restaurant_id': restaurantId,
      });

      _favorites[restaurantId] = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing restaurant from favorites: $e');
    }
  }

  Future<List<String>> getUserFavoriteRestaurantIds() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('user_favorites')
          .select('restaurant_id')
          .eq('user_id', userId);

      return (response as List)
          .map((item) => item['restaurant_id'] as String)
          .toList();
    } catch (e) {
      debugPrint('Error getting user favorite restaurant IDs: $e');
      return [];
    }
  }

  Future<void> loadUserFavorites() async {
    await _loadUserFavorites();
  }

  Future<void> _loadUserFavorites() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('user_favorites')
          .select('restaurant_id')
          .eq('user_id', userId);

      _favorites.clear();
      for (final item in response) {
        final restaurantId = item['restaurant_id'] as String;
        _favorites[restaurantId] = true;
      }
      notifyListeners();
      debugPrint('✅ Loaded ${_favorites.length} favorite restaurants');
    } catch (e) {
      debugPrint('❌ Error loading user favorites: $e');
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    _favoritesChannel?.unsubscribe();
    _syncTimer?.cancel();
    super.dispose();
  }
}
