import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/delivery_man_request.dart';
import '../utils/either.dart';
import '../utils/failure.dart';
import 'context_aware_service.dart';
import 'queue_service.dart';

class DeliveryManRequestService extends ChangeNotifier {
  static final DeliveryManRequestService _instance =
      DeliveryManRequestService._internal();
  factory DeliveryManRequestService() => _instance;
  DeliveryManRequestService._internal();

  SupabaseClient get client => Supabase.instance.client;

  // Context-aware service for tracking
  final ContextAwareService _contextAware = ContextAwareService();

  // Cache for delivery man requests
  List<DeliveryManRequest> _deliveryManRequests = [];
  List<DeliveryManRequest> _filteredRequests = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String _selectedSort = 'newest';

  // Pagination
  int _currentPage = 1;
  final int _itemsPerPage = 20;
  bool _hasMorePages = true;

  // Performance optimizations
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 5);
  final Map<String, dynamic> _queryCache = {};

  // Getters
  List<DeliveryManRequest> get deliveryManRequests => _deliveryManRequests;
  List<DeliveryManRequest> get filteredRequests =>
      _filteredRequests.isNotEmpty ? _filteredRequests : _deliveryManRequests;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get selectedSort => _selectedSort;
  int get currentPage => _currentPage;
  bool get hasMorePages => _hasMorePages;

  List<DeliveryManRequest> get pendingRequests =>
      _getFilteredRequestsByStatus(DeliveryManRequestStatus.pending);

  List<DeliveryManRequest> get approvedRequests =>
      _getFilteredRequestsByStatus(DeliveryManRequestStatus.approved);

  List<DeliveryManRequest> get rejectedRequests =>
      _getFilteredRequestsByStatus(DeliveryManRequestStatus.rejected);

  // Fetch the current user's delivery man request status
  Future<DeliveryManRequestStatus?> getCurrentUserRequestStatus() async {
    try {
      final currentUser = client.auth.currentUser;
      if (currentUser == null) return null;

      final row = await client
          .from('delivery_man_requests')
          .select(
              'id, status, rejection_reason, reviewed_at, reviewed_by, created_at')
          .eq('user_id', currentUser.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row == null) return null;
      final statusText = row['status'] as String? ?? 'pending';
      return DeliveryManRequestStatusExtension.fromString(statusText);
    } catch (_) {
      return null;
    }
  }

  // Submit delivery man request
  Future<Either<Failure, void>> submitDeliveryManRequest({
    required String fullName,
    required String phone,
    required String address,
    required String vehicleType,
    required String plateNumber,
    required String availability,
    required bool hasValidLicense,
    required bool hasVehicle,
    required bool isAvailableWeekends,
    required bool isAvailableEvenings,
    String? experience,
    String? vehicleModel,
    String? vehicleYear,
    String? vehicleColor,
  }) async {
    try {
      final currentUser = client.auth.currentUser;
      if (currentUser == null) {
        return Either.left(const Failure('Please sign in'));
      }

      // Check if user already has a pending request
      final existingRequest = await getCurrentUserRequestStatus();
      if (existingRequest == DeliveryManRequestStatus.pending) {
        return Either.left(
            const Failure('You already have a pending delivery man request'));
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

      // Insert delivery man request
      await client.from('delivery_man_requests').insert({
        'user_id': currentUser.id,
        'user_name': userName,
        'user_email': userEmail,
        'full_name': fullName,
        'phone': phone,
        'address': address,
        'vehicle_type': vehicleType,
        'plate_number': plateNumber,
        'vehicle_model': vehicleModel,
        'vehicle_year': vehicleYear,
        'vehicle_color': vehicleColor,
        'availability': availability,
        'experience': experience,
        'has_valid_license': hasValidLicense,
        'has_vehicle': hasVehicle,
        'is_available_weekends': isAvailableWeekends,
        'is_available_evenings': isAvailableEvenings,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Track the event
      try {
        _contextAware.trackEvent(
          eventName: 'delivery_man_request_submitted',
          service: 'DeliveryManRequestService',
          operation: 'submit_delivery_man_request',
          metadata: {
            'user_id': currentUser.id,
            'full_name': fullName,
            'vehicle_type': vehicleType,
            'availability': availability,
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
              'title': 'New Delivery Man Request',
              'message': '$userName wants to become a delivery man'
            },
          );
          if (!result.success) {
            debugPrint(
                'Failed to enqueue delivery man request notification: ${result.error}');
          }
        }
      } catch (_) {}

      return Either.right(null);
    } catch (e) {
      return Either.left(Failure(e.toString()));
    }
  }

  // Load delivery man requests (for admin) with caching and optimizations
  Future<void> loadDeliveryManRequests({bool forceRefresh = false}) async {
    final cacheKey =
        'requests_page_${_currentPage}_sort_${_selectedSort}_search_$_searchQuery';

    // Check cache validity
    if (!forceRefresh &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration &&
        _queryCache.containsKey(cacheKey) &&
        !_isLoading) {
      // Use cached data
      _deliveryManRequests = _queryCache[cacheKey];
      _applyFiltersAndSort();
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      if (forceRefresh) {
        resetPagination();
      }
      notifyListeners();

      // Build query with optimizations
      final query = client.from('delivery_man_requests').select('*');

      // Apply sorting based on selection
      final sortedQuery = switch (_selectedSort) {
        'oldest' => query.order('created_at', ascending: true),
        'name' => query.order('full_name', ascending: true),
        'newest' || _ => query.order('created_at', ascending: false),
      };

      // Apply pagination
      final paginatedQuery = sortedQuery.range(0, _itemsPerPage - 1);

      final response = await paginatedQuery;

      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) {
        _deliveryManRequests = [];
        _hasMorePages = false;
      } else {
        // Parse and validate data
        _deliveryManRequests = data
            .map((row) {
              try {
                return DeliveryManRequest.fromMap(row as Map<String, dynamic>);
              } catch (e) {
                // Log parsing error but continue with valid records
                debugPrint('Error parsing delivery man request: $e');
                return null;
              }
            })
            .whereType<DeliveryManRequest>()
            .toList();

        // Check if there are more pages
        _hasMorePages = _deliveryManRequests.length == _itemsPerPage;
      }

      // Update cache only if we have valid data
      if (_deliveryManRequests.isNotEmpty) {
        _lastFetchTime = DateTime.now();
        _queryCache[cacheKey] = List.from(_deliveryManRequests);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = _getDetailedErrorMessage(e.toString());
      _isLoading = false;
      notifyListeners();
    }
  }

  String _getDetailedErrorMessage(String error) {
    if (error.contains('permission') || error.contains('unauthorized')) {
      return 'Database access denied. Please check your permissions.';
    } else if (error.contains('network') || error.contains('connection')) {
      return 'Database connection failed. Please check your internet connection.';
    } else if (error.contains('timeout')) {
      return 'Database query timed out. Please try again.';
    } else if (error.contains('table') && error.contains('not exist')) {
      return 'Database table not found. Please run database migrations.';
    }
    return 'Database error: $error';
  }

  // Approve delivery man request
  Future<bool> approveDeliveryManRequest(
    String requestId,
    String adminId,
    String adminName,
  ) async {
    try {
      // Update request status
      await client.from('delivery_man_requests').update({
        'status': 'approved',
        'reviewed_by': adminName,
        'reviewed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      // Get the request details
      final request = _deliveryManRequests.firstWhere((r) => r.id == requestId);

      // Update user role to delivery_man
      await client.from('user_profiles').update({
        'role': 'delivery_man',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', request.userId);

      // Ensure a corresponding delivery_personnel record exists
      try {
        final existing = await client
            .from('delivery_personnel')
            .select('id')
            .eq('user_id', request.userId)
            .maybeSingle();

        if (existing == null) {
          // Create new delivery person profile from request details
          await client.from('delivery_personnel').insert({
            'user_id': request.userId,
            'license_number': request.plateNumber,
            'vehicle_plate': request.plateNumber,
            'vehicle_type': request.vehicleType,
            'vehicle_brand': request.vehicleModel?.split(' ').first,
            'vehicle_model': request.vehicleModel,
            'vehicle_color': request.vehicleColor,
            'vehicle_year': request.vehicleYear != null
                ? int.tryParse(request.vehicleYear!)
                : null,
            'delivery_name': request.fullName,
            'work_phone': request.phone,
            'is_available': true,
            'is_online': false,
            'rating': 0.0,
            'total_deliveries': 0,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        } else {
          // Update existing record with the latest license and vehicle data
          await client.from('delivery_personnel').update({
            'license_number': request.plateNumber,
            'vehicle_plate': request.plateNumber,
            'vehicle_type': request.vehicleType,
            'vehicle_brand': request.vehicleModel?.split(' ').first,
            'vehicle_model': request.vehicleModel,
            'vehicle_color': request.vehicleColor,
            'vehicle_year': request.vehicleYear != null
                ? int.tryParse(request.vehicleYear!)
                : null,
            'delivery_name': request.fullName,
            'work_phone': request.phone,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', existing['id']);
        }
      } catch (_) {
        // If creating the delivery personnel entry fails, surface failure
        return false;
      }

      // Track the event
      try {
        _contextAware.trackEvent(
          eventName: 'delivery_man_request_approved',
          service: 'DeliveryManRequestService',
          operation: 'approve_delivery_man_request',
          metadata: {
            'request_id': requestId,
            'user_id': request.userId,
            'full_name': request.fullName,
            'admin_id': adminId,
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
            'title': 'Delivery Man Request Approved!',
            'message':
                'Congratulations! Your delivery man application has been approved.'
          },
        );
        if (!result.success) {
          debugPrint(
              'Failed to enqueue approval notification: ${result.error}');
        }
      } catch (_) {}

      // Reload requests
      await loadDeliveryManRequests();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Reject delivery man request
  Future<bool> rejectDeliveryManRequest(
    String requestId,
    String adminId,
    String adminName,
    String reason,
  ) async {
    try {
      // Update request status
      await client.from('delivery_man_requests').update({
        'status': 'rejected',
        'rejection_reason': reason,
        'reviewed_by': adminName,
        'reviewed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      // Get the request details
      final request = _deliveryManRequests.firstWhere((r) => r.id == requestId);

      // Track the event
      try {
        _contextAware.trackEvent(
          eventName: 'delivery_man_request_rejected',
          service: 'DeliveryManRequestService',
          operation: 'reject_delivery_man_request',
          metadata: {
            'request_id': requestId,
            'user_id': request.userId,
            'full_name': request.fullName,
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
            'title': 'Delivery Man Request Update',
            'message':
                'Your delivery man application has been reviewed. Please check the details.'
          },
        );
        if (!result.success) {
          debugPrint(
              'Failed to enqueue delivery man request update notification: ${result.error}');
        }
      } catch (_) {}

      // Clear any previous errors and notify listeners
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Helper method to get filtered requests by status
  List<DeliveryManRequest> _getFilteredRequestsByStatus(
      DeliveryManRequestStatus status) {
    final requests =
        _filteredRequests.isNotEmpty ? _filteredRequests : _deliveryManRequests;
    return requests.where((request) => request.status == status).toList();
  }

  // Search and filter methods
  void filterRequests(String query) {
    _searchQuery = query.toLowerCase();
    _applyFiltersAndSort();
  }

  void sortRequests(String sortOption) {
    _selectedSort = sortOption;
    _applyFiltersAndSort();
  }

  void _applyFiltersAndSort() {
    List<DeliveryManRequest> filtered = _deliveryManRequests;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((request) {
        return request.fullName.toLowerCase().contains(_searchQuery) ||
            request.userName.toLowerCase().contains(_searchQuery) ||
            request.userEmail.toLowerCase().contains(_searchQuery) ||
            request.vehicleType.toLowerCase().contains(_searchQuery) ||
            request.phone.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    // Apply sorting
    switch (_selectedSort) {
      case 'newest':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'oldest':
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'name':
        filtered.sort((a, b) => a.fullName.compareTo(b.fullName));
        break;
    }

    _filteredRequests = filtered;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedSort = 'newest';
    _filteredRequests = [];
    _currentPage = 1;
    _hasMorePages = true;
    _queryCache.clear(); // Clear cache when filters change
    notifyListeners();
  }

  // Pagination methods
  Future<void> loadMoreRequests() async {
    if (!_hasMorePages || _isLoading) return;

    try {
      _isLoading = true;
      notifyListeners();

      final response = await client
          .from('delivery_man_requests')
          .select('*')
          .order('created_at', ascending: false)
          .range(_currentPage * _itemsPerPage,
              (_currentPage + 1) * _itemsPerPage - 1);

      final newRequests = (response as List)
          .map((row) => DeliveryManRequest.fromMap(row as Map<String, dynamic>))
          .toList();

      if (newRequests.length < _itemsPerPage) {
        _hasMorePages = false;
      }

      _deliveryManRequests.addAll(newRequests);
      _currentPage++;

      _applyFiltersAndSort();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void resetPagination() {
    _currentPage = 1;
    _hasMorePages = true;
    _deliveryManRequests = [];
    _filteredRequests = [];
    _queryCache.clear(); // Clear cache when resetting pagination
    notifyListeners();
  }

  void clearCache() {
    _queryCache.clear();
    _lastFetchTime = null;
    notifyListeners();
  }

  // Force refresh data after approval/rejection
  Future<void> forceRefresh() async {
    try {
      // Clear cache and force reload
      _queryCache.clear();
      _lastFetchTime = null;
      _error = null;

      // Load fresh data
      await loadDeliveryManRequests(forceRefresh: true);

      // Ensure listeners are notified
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Check database setup
  Future<void> checkDatabaseSetup() async {
    try {
      // Check if delivery_man_requests table exists and has the right structure
      await client.from('delivery_man_requests').select('id').limit(1);
    } catch (e) {
      // Table might not exist, this is expected in development
      if (kDebugMode) {
        debugPrint('Delivery man requests table not found: $e');
      }
    }
  }
}
