import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user.dart' as app_user;
// import '../models/booking.dart'; // Removed missing import
// import '../models/review.dart'; // Removed missing import
// import '../models/payment.dart'; // Removed missing import
// import '../models/notification.dart' as app_notification; // Removed missing import
// import '../models/message.dart'; // Removed missing import

class SupabaseService {
  static SupabaseClient get _supabase => Supabase.instance.client;

  // Cache for performance
  static final Map<String, dynamic> _cache = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // ==================== USER MANAGEMENT API ====================

  /// Get current user profile with caching
  static Future<app_user.User?> getCurrentUser() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('No authenticated user found');
        return null;
      }

      // Check cache first
      final cacheKey = 'user_${user.id}';
      final cached = _cache[cacheKey];
      if (cached != null &&
          cached['timestamp'] >
              DateTime.now().subtract(_cacheExpiry).millisecondsSinceEpoch) {
        debugPrint('Returning cached user data');
        return app_user.User.fromJson(cached['data']);
      }

      debugPrint('Fetching user profile for ID: ${user.id}');

      final response =
          await _supabase.from('users').select().eq('id', user.id).single();

      // Cache the result
      _cache[cacheKey] = {
        'data': response,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      debugPrint('User profile retrieved successfully');
      return app_user.User.fromJson(response);
    } catch (e) {
      debugPrint('Error getting current user: $e');
      if (e.toString().contains('No rows returned')) {
        debugPrint('User profile not found in database');
      }
      return null;
    }
  }

  /// Update user profile
  static Future<bool> updateUserProfile({
    required String userId,
    String? name,
    String? email,
    String? phone,
    String? profileImage,
    String? bio,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name.trim();
      if (email != null) updates['email'] = email.trim();
      if (phone != null) updates['phone'] = phone.trim();
      if (profileImage != null) updates['profile_image'] = profileImage;
      if (bio != null) updates['bio'] = bio.trim();
      updates['updated_at'] = DateTime.now().toIso8601String();

      await _supabase.from('profiles').update(updates).eq('id', userId);

      // Clear cache
      _cache.remove('user_$userId');

      debugPrint('User profile updated successfully');
      return true;
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      return false;
    }
  }

  /// Upload user avatar
  static Future<String?> uploadUserAvatar(
      String userId, Uint8List imageBytes) async {
    try {
      final fileName =
          'avatar_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'avatars/$fileName';

      await _supabase.storage
          .from('user-avatars')
          .uploadBinary(path, imageBytes);

      final url = _supabase.storage.from('user-avatars').getPublicUrl(path);

      // Update user profile with new avatar URL
      await updateUserProfile(userId: userId, profileImage: url);

      debugPrint('Avatar uploaded successfully');
      return url;
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
      return null;
    }
  }

  /// Get user by ID
  static Future<app_user.User?> getUserById(String userId) async {
    try {
      final response =
          await _supabase.from('profiles').select().eq('id', userId).single();

      return app_user.User.fromJson(response);
    } catch (e) {
      debugPrint('Error getting user by ID: $e');
      return null;
    }
  }

  // ==================== CAR MANAGEMENT API ====================

  /// Get all cars with filtering and pagination
  static Future<List<dynamic>> getCars({
    String? categoryId,
    String? location,
    double? minPrice,
    double? maxPrice,
    String? useType,
    int? passengers,
    String? transmission,
    String? fuelType,
    bool? available,
    bool? featured,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      var query = _supabase.from('cars').select('''
            *,
            categories(name, description, icon),
            profiles!cars_host_id_fkey(name, profile_image)
          ''');

      // Apply filters
      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }
      if (location != null && location.isNotEmpty) {
        query = query.ilike('location', '%$location%');
      }
      if (useType != null && useType.isNotEmpty) {
        query = query.eq('use_type', useType.toLowerCase());
      }
      if (minPrice != null) {
        query = query.gte('price_per_day', minPrice);
      }
      if (maxPrice != null) {
        query = query.lte('price_per_day', maxPrice);
      }
      if (passengers != null) {
        query = query.eq('passengers', passengers);
      }
      if (transmission != null) {
        query = query.eq('transmission', transmission);
      }
      if (fuelType != null) {
        query = query.eq('fuel_type', fuelType);
      }
      if (available != null) {
        query = query.eq('available', available);
      }
      if (featured != null) {
        query = query.eq('featured', featured);
      }

      final response =
          await query.limit(limit).range(offset, offset + limit - 1);

      return response;
    } catch (e) {
      debugPrint('Error getting cars: $e');
      return [];
    }
  }

  /// Get car by ID with full details
  static Future<dynamic> getCarById(String carId) async {
    try {
      final response = await _supabase.from('cars').select('''
            *,
            categories(name, description, icon),
            profiles!cars_host_id_fkey(name, profile_image, phone),
            reviews(*)
          ''').eq('id', carId).single();

      return response;
    } catch (e) {
      debugPrint('Error getting car by ID: $e');
      return null;
    }
  }

  // ==================== BOOKING MANAGEMENT API ====================

  /// Create new booking
  static Future<String?> createBooking(dynamic booking) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('bookings')
          .insert({
            'car_id': booking.carId,
            'user_id': user.id,
            'host_id': booking.hostId,
            'start_date': booking.startDate.toIso8601String(),
            'end_date': booking.endDate.toIso8601String(),
            'total_price': booking.totalPrice,
            'status': booking.status,
            'notes': booking.notes,
          })
          .select()
          .single();

      debugPrint('Booking created successfully');
      return response['id'];
    } catch (e) {
      debugPrint('Error creating booking: $e');
      return null;
    }
  }

  /// Get user bookings
  static Future<List<dynamic>> getUserBookings({
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return [];
      }

      var query = _supabase.from('bookings').select('''
            *,
            cars(name, image, price_per_day),
            profiles!bookings_host_id_fkey(name, profile_image)
          ''').eq('user_id', user.id);

      if (status != null) {
        query = query.eq('status', status);
      }

      final response =
          await query.limit(limit).range(offset, offset + limit - 1);

      return response;
    } catch (e) {
      debugPrint('Error getting user bookings: $e');
      return [];
    }
  }

  /// Update booking status
  static Future<bool> updateBookingStatus(
      String bookingId, String status) async {
    try {
      await _supabase.from('bookings').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', bookingId);

      debugPrint('Booking status updated successfully');
      return true;
    } catch (e) {
      debugPrint('Error updating booking status: $e');
      return false;
    }
  }

  // ==================== REVIEW MANAGEMENT API ====================

  /// Create new review
  static Future<String?> createReview(Map<String, dynamic> reviewData) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final response =
          await _supabase.from('reviews').insert(reviewData).select().single();

      debugPrint('Review created successfully');
      return response['id'];
    } catch (e) {
      debugPrint('Error creating review: $e');
      return null;
    }
  }

  /// Get reviews for target
  static Future<List<dynamic>> getReviews(
      String targetId, String targetType) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select('''
            *,
            profiles!reviews_reviewer_id_fkey(name, profile_image)
          ''')
          .eq('target_id', targetId)
          .eq('target_type', targetType)
          .eq('status', 'approved')
          .order('created_at', ascending: false);

      return response;
    } catch (e) {
      debugPrint('Error getting reviews: $e');
      return [];
    }
  }

  /// Search cars with filters
  static Future<List<dynamic>> searchCars({
    String? query,
    String? category,
    String? location,
    double? minPrice,
    double? maxPrice,
    DateTime? startDate,
    DateTime? endDate,
    int? passengers,
    String? transmission,
    String? fuelType,
    double? minRating,
    String? useType,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      var q = _supabase
          .from('cars')
          .select('*, categories(*), profiles!cars_host_id_fkey(*)')
          .eq('available', true);

      if (query != null && query.isNotEmpty) {
        q = q.or('name.ilike.%$query%,description.ilike.%$query%');
      }
      if (category != null && category.isNotEmpty) {
        q = q.eq('category', category);
      }
      if (location != null && location.isNotEmpty) {
        q = q.ilike('location', '%$location%');
      }
      if (useType != null && useType.isNotEmpty) {
        q = q.eq('use_type', useType.toLowerCase());
      }
      if (minPrice != null) {
        q = q.gte('price_per_day', minPrice);
      }
      if (maxPrice != null) {
        q = q.lte('price_per_day', maxPrice);
      }
      if (passengers != null) {
        q = q.eq('passengers', passengers);
      }
      if (transmission != null && transmission.isNotEmpty) {
        q = q.eq('transmission', transmission);
      }
      if (fuelType != null && fuelType.isNotEmpty) {
        q = q.eq('fuel_type', fuelType);
      }
      if (minRating != null) {
        q = q.gte('rating', minRating);
      }

      // Date range availability can be implemented with NOT IN bookings overlap
      // Skipped for brevity here

      final response = await q
          .range(offset, offset + limit - 1)
          .order('rating', ascending: false);

      return response;
    } catch (e) {
      debugPrint('Error searching cars: $e');
      return [];
    }
  }

  /// Get popular locations
  static Future<List<String>> getPopularLocations() async {
    try {
      final response =
          await _supabase.from('cars').select('location').eq('available', true);

      final locations = response
          .map((json) => json['location'] as String)
          .where((location) => location.isNotEmpty)
          .toSet()
          .toList();

      return locations.take(10).toList();
    } catch (e) {
      debugPrint('Error getting popular locations: $e');
      return [];
    }
  }

  /// Get car categories
  static Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response =
          await _supabase.from('categories').select().order('name');

      return response;
    } catch (e) {
      debugPrint('Error getting categories: $e');
      return [];
    }
  }

  /// Upload car image
  static Future<String?> uploadCarImage(
      String carId, Uint8List imageBytes) async {
    try {
      final fileName =
          'car_${carId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'cars/$fileName';

      await _supabase.storage.from('car-images').uploadBinary(path, imageBytes);

      final url = _supabase.storage.from('car-images').getPublicUrl(path);

      return url;
    } catch (e) {
      debugPrint('Error uploading car image: $e');
      return null;
    }
  }

  /// Create notification
  static Future<bool> createNotification({
    required String userId,
    required String title,
    required String message,
    String? type,
    String? relatedId,
  }) async {
    try {
      final notificationData = {
        'user_id': userId,
        'title': title,
        'message': message,
        'type': type ?? 'general',
        'related_id': relatedId,
        'read': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('notifications').insert(notificationData);

      return true;
    } catch (e) {
      debugPrint('Error creating notification: $e');
      return false;
    }
  }

  /// Subscribe to notifications (placeholder)
  static void subscribeToNotifications(
      void Function(Map<String, dynamic>) callback) {
    // TODO(dev): Implement notification subscription
    debugPrint('Notification subscription not implemented yet');
  }

  // ==================== PAYMENT MANAGEMENT API ====================

  /// Create payment record
  static Future<String?> createPayment(Map<String, dynamic> paymentData) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('payments')
          .insert(paymentData)
          .select()
          .single();

      debugPrint('Payment created successfully');
      return response['id'];
    } catch (e) {
      debugPrint('Error creating payment: $e');
      return null;
    }
  }

  /// Get user payment history
  static Future<List<Map<String, dynamic>>> getUserPayments() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return [];
      }

      final response = await _supabase.from('payments').select('''
            *,
            bookings(cars(name, image))
          ''').eq('user_id', user.id).order('created_at', ascending: false);

      return response;
    } catch (e) {
      debugPrint('Error getting user payments: $e');
      return [];
    }
  }

  // ==================== NOTIFICATION MANAGEMENT API ====================

  /// Get user notifications
  static Future<List<dynamic>> getUserNotifications() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return [];
      }

      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);

      return response;
    } catch (e) {
      debugPrint('Error getting user notifications: $e');
      return [];
    }
  }

  /// Mark notification as read
  static Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'read': true}).eq('id', notificationId);

      debugPrint('Notification marked as read');
      return true;
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      return false;
    }
  }

  // ==================== FAVORITE MANAGEMENT API ====================

  /// Add car to favorites
  static Future<bool> addToFavorites(String carId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return false;
      }

      await _supabase.from('favorites').insert({
        'user_id': user.id,
        'car_id': carId,
      });

      debugPrint('Car added to favorites');
      return true;
    } catch (e) {
      debugPrint('Error adding to favorites: $e');
      return false;
    }
  }

  /// Remove car from favorites
  static Future<bool> removeFromFavorites(String carId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return false;
      }

      await _supabase
          .from('favorites')
          .delete()
          .eq('user_id', user.id)
          .eq('car_id', carId);

      debugPrint('Car removed from favorites');
      return true;
    } catch (e) {
      debugPrint('Error removing from favorites: $e');
      return false;
    }
  }

  /// Get user favorites
  static Future<List<dynamic>> getUserFavorites() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return [];
      }

      final response = await _supabase.from('favorites').select('''
            cars(
              *,
              categories(name, description, icon),
              profiles!cars_host_id_fkey(name, profile_image)
            )
          ''').eq('user_id', user.id);

      return response.map((favorite) => favorite['cars']).toList();
    } catch (e) {
      debugPrint('Error getting user favorites: $e');
      return [];
    }
  }

  /// Check if car is in favorites
  static Future<bool> isInFavorites(String carId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return false;
      }

      final response = await _supabase
          .from('favorites')
          .select()
          .eq('user_id', user.id)
          .eq('car_id', carId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('Error checking favorites: $e');
      return false;
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Clear cache
  static void clearCache() {
    _cache.clear();
    debugPrint('Cache cleared');
  }

  /// Get cache size
  static int getCacheSize() {
    return _cache.length;
  }

  /// Subscribe to real-time updates (placeholder)
  static void subscribeToChannel(
      String channelName, void Function(Map<String, dynamic>) callback) {
    // TODO(dev): Implement real-time subscription
    debugPrint('Real-time subscription not implemented yet');
  }

  /// Unsubscribe from real-time updates (placeholder)
  static Future<void> unsubscribeFromChannel(String channelName) async {
    // TODO(dev): Implement real-time unsubscription
    debugPrint('Real-time unsubscription not implemented yet');
  }
}
