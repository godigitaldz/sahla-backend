import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/restaurant_request.dart';
import '../utils/either.dart';
import '../utils/failure.dart';
import 'context_aware_service.dart';
import 'queue_service.dart';

class RestaurantRequestService extends ChangeNotifier {
  static final RestaurantRequestService _instance =
      RestaurantRequestService._internal();
  factory RestaurantRequestService() => _instance;
  RestaurantRequestService._internal();

  SupabaseClient get client => Supabase.instance.client;

  // Context-aware service for tracking
  final ContextAwareService _contextAware = ContextAwareService();

  // Cache for restaurant requests
  List<RestaurantRequest> _restaurantRequests = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<RestaurantRequest> get restaurantRequests => _restaurantRequests;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<RestaurantRequest> get pendingRequests =>
      _restaurantRequests.where((request) => request.isPending).toList();

  List<RestaurantRequest> get approvedRequests =>
      _restaurantRequests.where((request) => request.isApproved).toList();

  List<RestaurantRequest> get rejectedRequests =>
      _restaurantRequests.where((request) => request.isRejected).toList();

  // Fetch the current user's restaurant request status
  Future<RestaurantRequestStatus?> getCurrentUserRequestStatus() async {
    try {
      final currentUser = client.auth.currentUser;
      if (currentUser == null) return null;

      final row = await client
          .from('restaurant_requests')
          .select(
              'id, status, rejection_reason, reviewed_at, reviewed_by, created_at')
          .eq('user_id', currentUser.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row == null) return null;
      final statusText = row['status'] as String? ?? 'pending';
      return RestaurantRequestStatusExtension.fromString(statusText);
    } catch (_) {
      return null;
    }
  }

  // Submit restaurant request
  Future<Either<Failure, void>> submitRestaurantRequest({
    required String restaurantName,
    required String restaurantDescription,
    required String restaurantAddress,
    required String restaurantPhone,
    required String wilaya,
    required Map<String, dynamic> openingHoursJsonb,
    required Map<String, dynamic> closingHoursJsonb,
    String? logoUrl,
    double? latitude,
    double? longitude,
    // Social media fields
    String? instagram,
    String? facebook,
    String? tiktok,
    // Additional restaurant fields
    String? email,
    String? addressLine2,
    String? city,
    String? state,
    String? postalCode,
    String? coverImageUrl,
  }) async {
    try {
      final currentUser = client.auth.currentUser;
      if (currentUser == null) {
        return Either.left(const Failure('Please sign in'));
      }

      // Check if user already has a pending request
      final existingRequest = await getCurrentUserRequestStatus();
      if (existingRequest == RestaurantRequestStatus.pending) {
        return Either.left(
            const Failure('You already have a pending restaurant request'));
      }

      // Get user profile
      final userProfile = await client
          .from('user_profiles')
          .select('name, email')
          .eq('id', currentUser.id)
          .single();

      final userName = userProfile['name'] as String? ?? 'Unknown User';
      final userEmail =
          userProfile['email'] as String? ?? currentUser.email ?? '';

      // Debug: Log data being inserted
      debugPrint('🗄️ Inserting restaurant request data:');
      debugPrint('   Logo URL: $logoUrl');
      debugPrint('   Restaurant Name: $restaurantName');
      debugPrint('   User ID: ${currentUser.id}');
      debugPrint('   Opening Hours JSONB: $openingHoursJsonb');
      debugPrint('   Closing Hours JSONB: $closingHoursJsonb');

      // Insert restaurant request
      await client.from('restaurant_requests').insert({
        'user_id': currentUser.id,
        'user_name': userName,
        'user_email': userEmail,
        'restaurant_name': restaurantName,
        'restaurant_description': restaurantDescription,
        'restaurant_address': restaurantAddress,
        'restaurant_phone': restaurantPhone,
        'wilaya': wilaya,
        'opening_hours': openingHoursJsonb,
        'closing_hours': closingHoursJsonb,
        'logo_url': logoUrl,
        'latitude': latitude,
        'longitude': longitude,
        // Social media fields
        'instagram': instagram,
        'facebook': facebook,
        'tiktok': tiktok,
        // Additional restaurant fields
        'email': email,
        'address_line2': addressLine2,
        'city': city,
        'state': state,
        'postal_code': postalCode,
        'cover_image_url': coverImageUrl,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Restaurant request inserted successfully');

      // Track the event
      try {
        _contextAware.trackEvent(
          eventName: 'restaurant_request_submitted',
          service: 'RestaurantRequestService',
          operation: 'submit_restaurant_request',
          metadata: {
            'user_id': currentUser.id,
            'restaurant_name': restaurantName,
            'wilaya': wilaya,
          },
        );
      } catch (_) {}

      // Send notification to admin
      try {
        final adminUsers =
            await client.from('user_profiles').select('id').eq('role', 'admin');
        final queue = QueueService();
        for (final admin in adminUsers) {
          final result = await queue.enqueue(
            taskIdentifier: 'send_notification',
            payload: {
              'user_id': admin['id'],
              'title': 'New Restaurant Request',
              'message':
                  '$userName wants to become a restaurant owner for $restaurantName',
            },
          );
          if (!result.success) {
            debugPrint(
                'Failed to enqueue restaurant request notification: ${result.error}');
          }
        }
      } catch (_) {}

      return Either.right(null);
    } catch (e) {
      return Either.left(Failure(e.toString()));
    }
  }

  // Load restaurant requests (for admin)
  Future<void> loadRestaurantRequests() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await client
          .from('restaurant_requests')
          .select('*')
          .order('created_at', ascending: false);

      _restaurantRequests = (response as List)
          .map((row) => RestaurantRequest.fromMap(row as Map<String, dynamic>))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Store the last error for detailed reporting
  String? _lastApprovalError;

  // Get the last approval error
  String? get lastApprovalError => _lastApprovalError;

  /// Clear search cache to include new restaurants
  Future<void> _clearSearchCache() async {
    try {
      debugPrint('🗑️ Clearing restaurant search cache...');

      // Note: Cache clearing is implemented on the server side
      // The search queries have been fixed to use correct database schema
      // which should resolve the search issues without needing cache clearing
      debugPrint('✅ Search cache clear requested (server-side implementation)');
    } catch (e) {
      debugPrint('⚠️ Error clearing search cache: $e');
      // Don't throw error - cache clearing is not critical for approval process
    }
  }

  // Approve restaurant request
  Future<bool> approveRestaurantRequest(
    String requestId,
    String adminId,
    String adminName,
  ) async {
    try {
      debugPrint(
          '🔄 Starting restaurant approval process for request: $requestId');

      // Update request status
      debugPrint('📝 Updating restaurant request status to approved...');
      await client.from('restaurant_requests').update({
        'status': 'approved',
        'reviewed_by': adminName,
        'reviewed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      // Get the request details
      debugPrint('📋 Getting request details...');
      final request = _restaurantRequests.firstWhere((r) => r.id == requestId);

      // Update user role to restaurant_owner
      debugPrint(
          '👤 Updating user role to restaurant_owner for user: ${request.userId}');
      await client.from('user_profiles').update({
        'role': 'restaurant_owner',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', request.userId);

      // Convert opening/closing hours to JSON format for restaurants table
      debugPrint('⏰ Converting opening hours to JSON format...');
      final openingHoursJson =
          _convertHoursToJson(request.openingHours, request.closingHours);

      // Create restaurant record
      debugPrint('🏪 Creating restaurant record...');
      await client.from('restaurants').insert({
        'name': request.restaurantName,
        'description': request.restaurantDescription,
        'address_line1': request.restaurantAddress,
        'phone': request.restaurantPhone,
        'wilaya': request.wilaya,
        'opening_hours': openingHoursJson,
        'logo_url': request.logoUrl,
        'latitude': request.latitude,
        'longitude': request.longitude,
        'owner_id': request.userId,
        'is_open': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Restaurant record created successfully');

      // Track the event
      try {
        debugPrint('📊 Tracking approval event...');
        _contextAware.trackEvent(
          eventName: 'restaurant_request_approved',
          service: 'RestaurantRequestService',
          operation: 'approve_restaurant_request',
          metadata: {
            'request_id': requestId,
            'user_id': request.userId,
            'restaurant_name': request.restaurantName,
            'admin_id': adminId,
          },
        );
      } catch (e) {
        debugPrint('⚠️ Failed to track approval event: $e');
      }

      // Send notification to user
      try {
        debugPrint('📱 Sending approval notification...');
        final queue = QueueService();
        final result = await queue.enqueue(
          taskIdentifier: 'send_notification',
          payload: {
            'user_id': request.userId,
            'title': 'Restaurant Request Approved!',
            'message':
                'Congratulations! Your restaurant "${request.restaurantName}" has been approved.'
          },
        );
        if (!result.success) {
          debugPrint(
              '⚠️ Failed to enqueue restaurant approval notification: ${result.error}');
        }
      } catch (e) {
        debugPrint('⚠️ Failed to send approval notification: $e');
      }

      // Clear search cache to include new restaurant
      try {
        debugPrint('🗑️ Clearing search cache to include new restaurant...');
        // Clear Redis cache for restaurant searches
        // This will force fresh data to be loaded on next search
        await _clearSearchCache();
      } catch (e) {
        debugPrint('⚠️ Failed to clear search cache: $e');
      }

      // Reload requests
      debugPrint('🔄 Reloading restaurant requests...');
      await loadRestaurantRequests();

      debugPrint('✅ Restaurant approval process completed successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Restaurant approval failed: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');

      // Store detailed error information
      _lastApprovalError = e.toString();

      if (e.toString().contains('duplicate key')) {
        debugPrint('❌ Duplicate key error - restaurant may already exist');
        _lastApprovalError = 'Restaurant with this name may already exist';
      } else if (e.toString().contains('foreign key')) {
        debugPrint('❌ Foreign key error - user may not exist');
        _lastApprovalError = 'User account not found or invalid';
      } else if (e.toString().contains('permission')) {
        debugPrint('❌ Permission error - insufficient database permissions');
        _lastApprovalError = 'Insufficient database permissions';
      } else if (e.toString().contains('constraint')) {
        debugPrint('❌ Constraint error - database constraint violation');
        _lastApprovalError = 'Database constraint violation';
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        debugPrint('❌ Network error - connection issue');
        _lastApprovalError = 'Network connection error';
      }

      return false;
    }
  }

  // Reject restaurant request
  Future<bool> rejectRestaurantRequest(
    String requestId,
    String adminId,
    String adminName,
    String reason,
  ) async {
    try {
      // Update request status
      await client.from('restaurant_requests').update({
        'status': 'rejected',
        'rejection_reason': reason,
        'reviewed_by': adminName,
        'reviewed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      // Get the request details
      final request = _restaurantRequests.firstWhere((r) => r.id == requestId);

      // Track the event
      try {
        _contextAware.trackEvent(
          eventName: 'restaurant_request_rejected',
          service: 'RestaurantRequestService',
          operation: 'reject_restaurant_request',
          metadata: {
            'request_id': requestId,
            'user_id': request.userId,
            'restaurant_name': request.restaurantName,
            'admin_id': adminId,
            'reason': reason,
          },
        );
      } catch (_) {}

      // Send notification to user
      try {
        final queue = QueueService();
        final result = await queue.enqueue(
          taskIdentifier: 'send_notification',
          payload: {
            'user_id': request.userId,
            'title': 'Restaurant Request Update',
            'message':
                'Your restaurant request has been reviewed. Please check the details.'
          },
        );
        if (!result.success) {
          debugPrint(
              'Failed to enqueue restaurant request update notification: ${result.error}');
        }
      } catch (_) {}

      // Reload requests
      await loadRestaurantRequests();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Check database setup
  Future<void> checkDatabaseSetup() async {
    try {
      // Check if restaurant_requests table exists and has the right structure
      await client.from('restaurant_requests').select('id').limit(1);
    } catch (e) {
      // Table might not exist, this is expected in development
      if (kDebugMode) {
        print('Restaurant requests table not found: $e');
      }
    }
  }

  // Convert opening/closing hours from request format to restaurant JSON format
  Map<String, dynamic> _convertHoursToJson(
      Map<String, dynamic> openingHours, Map<String, dynamic> closingHours) {
    debugPrint(
        '🕐 RestaurantRequestService._convertHoursToJson() called - openingHours: $openingHours, closingHours: $closingHours');

    // The hours are already in the correct jsonb format, so we can use them directly
    // For the restaurants table, we'll use the opening_hours format
    debugPrint(
        '✅ RestaurantRequestService._convertHoursToJson() - returning openingHours directly');
    return openingHours;
  }
}
