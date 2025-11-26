import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/delivery_personnel.dart';
import '../models/order.dart';
import 'context_aware_service.dart';
import 'queue_service.dart';

class DeliveryService extends ChangeNotifier {
  static final DeliveryService _instance = DeliveryService._internal();
  factory DeliveryService() => _instance;
  DeliveryService._internal();

  SupabaseClient get client => Supabase.instance.client;

  // Context-aware service for tracking and validation
  final ContextAwareService _contextAware = ContextAwareService();

  // Initialize the service with context tracking
  Future<void> initialize() async {
    await _contextAware.initialize();
    debugPrint('🚀 DeliveryService initialized with context tracking');
  }

  // Get available delivery personnel
  Future<List<DeliveryPersonnel>?> getAvailableDeliveryPersonnel({
    double? latitude,
    double? longitude,
    double radiusKm = 10.0,
  }) async {
    return _contextAware.executeWithContext(
      operation: 'getAvailableDeliveryPersonnel',
      service: 'DeliveryService',
      operationFunction: () async {
        try {
          final query = client
              .from('delivery_personnel')
              .select('*')
              .eq('is_available', 'true')
              .eq('is_online', true);

          final response = await query;

          List<DeliveryPersonnel> personnel =
              response.map((json) => DeliveryPersonnel.fromJson(json)).toList();

          // Filter by location if provided
          if (latitude != null && longitude != null) {
            personnel = personnel.where((person) {
              if (!person.hasLocation) return false;

              final distance = _calculateDistance(
                latitude,
                longitude,
                person.currentLatitude!,
                person.currentLongitude!,
              );

              return distance <= radiusKm;
            }).toList();
          }

          // Sort by rating (highest first)
          personnel.sort((a, b) => b.rating.compareTo(a.rating));

          return personnel;
        } catch (e) {
          debugPrint('Error fetching available delivery personnel: $e');
          return [];
        }
      },
      metadata: {
        'latitude': latitude,
        'longitude': longitude,
        'radius_km': radiusKm,
      },
    );
  }

  // Assign delivery person to order
  Future<bool> assignDeliveryPerson({
    required String orderId,
    required String deliveryPersonId,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'assignDeliveryPerson',
          service: 'DeliveryService',
          operationFunction: () async {
            try {
              // Update order with delivery person
              await client.from('orders').update({
                'delivery_person_id': deliveryPersonId,
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('id', orderId);

              // Update delivery person status to busy
              await client.from('delivery_personnel').update({
                'is_available': false,
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('id', deliveryPersonId);

              // Get order details for notifications
              final orderRes = await client
                  .from('orders')
                  .select('order_number, customer_id')
                  .eq('id', orderId)
                  .single();
              final queue = QueueService();

              // Notify customer asynchronously
              try {
                final result = await queue.enqueue(
                  taskIdentifier: 'send_notification',
                  payload: {
                    'user_id': orderRes['customer_id'],
                    'title': 'Delivery Assigned',
                    'message':
                        'A delivery partner has been assigned to your order #${orderRes['order_number']}.',
                  },
                );
                if (!result.success) {
                  debugPrint(
                      'Failed to enqueue delivery assignment notification: ${result.error}');
                }
              } catch (_) {}

              // Notify delivery person asynchronously
              try {
                final deliveryPersonRes = await client
                    .from('delivery_personnel')
                    .select('user_id')
                    .eq('id', deliveryPersonId)
                    .single();

                if (deliveryPersonRes['user_id'] != null) {
                  final result = await queue.enqueue(
                    taskIdentifier: 'send_notification',
                    payload: {
                      'user_id': deliveryPersonRes['user_id'],
                      'title': 'New Order Assigned',
                      'message':
                          'You have been assigned a new order #${orderRes['order_number']}. Please check your dashboard.',
                    },
                  );
                  if (!result.success) {
                    debugPrint(
                        'Failed to enqueue delivery person notification: ${result.error}');
                  }
                }
              } catch (e) {
                debugPrint('Error notifying delivery person: $e');
              }

              notifyListeners();
              return true;
            } catch (e) {
              debugPrint('Error assigning delivery person: $e');
              return false;
            }
          },
          metadata: {
            'order_id': orderId,
            'delivery_person_id': deliveryPersonId,
          },
        ) ??
        false;
  }

  // Update delivery person location
  Future<bool> updateDeliveryPersonLocation({
    required String deliveryPersonId,
    required double latitude,
    required double longitude,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'updateDeliveryPersonLocation',
          service: 'DeliveryService',
          operationFunction: () async {
            try {
              await client.from('delivery_personnel').update({
                'current_latitude': latitude,
                'current_longitude': longitude,
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('id', deliveryPersonId);

              notifyListeners();
              return true;
            } catch (e) {
              debugPrint('Error updating delivery person location: $e');
              return false;
            }
          },
          metadata: {
            'delivery_person_id': deliveryPersonId,
            'latitude': latitude,
            'longitude': longitude,
          },
        ) ??
        false;
  }

  // Update delivery person status
  Future<bool> updateDeliveryPersonStatus({
    required String deliveryPersonId,
    required bool isAvailable,
    required bool isOnline,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'updateDeliveryPersonStatus',
          service: 'DeliveryService',
          operationFunction: () async {
            try {
              await client.from('delivery_personnel').update({
                'is_available': isAvailable,
                'is_online': isOnline,
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('id', deliveryPersonId);

              notifyListeners();
              return true;
            } catch (e) {
              debugPrint('Error updating delivery person status: $e');
              return false;
            }
          },
          metadata: {
            'delivery_person_id': deliveryPersonId,
            'is_available': isAvailable,
            'is_online': isOnline,
          },
        ) ??
        false;
  }

  // Get delivery person by ID
  Future<DeliveryPersonnel?> getDeliveryPersonById(
      String deliveryPersonId) async {
    return _contextAware.executeWithContext(
      operation: 'getDeliveryPersonById',
      service: 'DeliveryService',
      operationFunction: () async {
        try {
          final response = await client
              .from('delivery_personnel')
              .select('*')
              .eq('id', deliveryPersonId)
              .single();

          return DeliveryPersonnel.fromJson(response);
        } catch (e) {
          debugPrint('Error getting delivery person by ID: $e');
          return null;
        }
      },
      metadata: {
        'delivery_person_id': deliveryPersonId,
      },
    );
  }

  // Get delivery person by user ID
  Future<DeliveryPersonnel?> getDeliveryPersonByUserId(String userId) async {
    return _contextAware.executeWithContext(
      operation: 'getDeliveryPersonByUserId',
      service: 'DeliveryService',
      operationFunction: () async {
        try {
          final response = await client
              .from('delivery_personnel')
              .select('*')
              .eq('user_id', userId)
              .single();

          return DeliveryPersonnel.fromJson(response);
        } catch (e) {
          debugPrint('Error getting delivery person by user ID: $e');
          return null;
        }
      },
      metadata: {
        'user_id': userId,
      },
    );
  }

  // Create delivery person profile
  Future<DeliveryPersonnel?> createDeliveryPerson({
    required String userId,
    required String vehicleType,
    String? licenseNumber,
    String? vehiclePlate,
  }) async {
    return _contextAware.executeWithContext(
      operation: 'createDeliveryPerson',
      service: 'DeliveryService',
      operationFunction: () async {
        try {
          final deliveryPersonData = {
            'user_id': userId,
            'vehicle_type': vehicleType,
            'license_number': licenseNumber,
            'vehicle_plate': vehiclePlate,
            'is_available': true,
            'is_online': false,
            'rating': 0.0,
            'total_deliveries': 0,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };

          final response = await client
              .from('delivery_personnel')
              .insert(deliveryPersonData)
              .select('''
                *,
                users(*)
              ''').single();

          notifyListeners();
          return DeliveryPersonnel.fromJson(response);
        } catch (e) {
          debugPrint('Error creating delivery person: $e');
          return null;
        }
      },
      metadata: {
        'user_id': userId,
        'vehicle_type': vehicleType,
        'license_number': licenseNumber,
        'vehicle_plate': vehiclePlate,
      },
    );
  }

  // Update delivery person rating
  Future<bool> updateDeliveryPersonRating({
    required String deliveryPersonId,
    required double newRating,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'updateDeliveryPersonRating',
          service: 'DeliveryService',
          operationFunction: () async {
            try {
              // Get current delivery person data
              final currentPerson =
                  await getDeliveryPersonById(deliveryPersonId);
              if (currentPerson == null) return false;

              // Calculate new average rating
              final totalDeliveries = currentPerson.totalDeliveries + 1;
              final currentTotalRating =
                  currentPerson.rating * currentPerson.totalDeliveries;
              final newAverageRating =
                  (currentTotalRating + newRating) / totalDeliveries;

              await client.from('delivery_personnel').update({
                'rating': newAverageRating,
                'total_deliveries': totalDeliveries,
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('id', deliveryPersonId);

              notifyListeners();
              return true;
            } catch (e) {
              debugPrint('Error updating delivery person rating: $e');
              return false;
            }
          },
          metadata: {
            'delivery_person_id': deliveryPersonId,
            'new_rating': newRating,
          },
        ) ??
        false;
  }

  // Get delivery person orders
  Future<List<Order>?> getDeliveryPersonOrders({
    required String deliveryPersonId,
    OrderStatus? status,
    int limit = 20,
    int offset = 0,
  }) async {
    return _contextAware.executeWithContext(
      operation: 'getDeliveryPersonOrders',
      service: 'DeliveryService',
      operationFunction: () async {
        try {
          var query = client.from('orders').select('''
                *,
                restaurants(*),
                user_profiles(*),
                delivery_personnel(
                  *,
                  user:user_id(
                    id,
                    email,
                    phone,
                    full_name,
                    name,
                    profile_image
                  )
                ),
                order_items(
                  *,
                  menu_items(*)
                )
              ''').eq('delivery_person_id', deliveryPersonId);

          if (status != null) {
            query = query.eq('status', status.name);
          }

          final response = await query
              .order('created_at', ascending: false)
              .range(offset, offset + limit - 1);

          return response.map((json) => Order.fromJson(json)).toList();
        } catch (e) {
          debugPrint('Error fetching delivery person orders: $e');
          return [];
        }
      },
      metadata: {
        'delivery_person_id': deliveryPersonId,
        'status': status?.name,
        'limit': limit,
        'offset': offset,
      },
    );
  }

  // Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);

    final double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }

  // Get context summary for debugging
  Map<String, dynamic> getContextSummary() {
    return _contextAware.getContextSummary();
  }
}
