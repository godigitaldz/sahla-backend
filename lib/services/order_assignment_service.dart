import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/delivery_personnel.dart';
import 'context_aware_service.dart';
import 'delivery_service.dart';
import 'logging_service.dart';
import 'queue_service.dart';

class OrderAssignmentService extends ChangeNotifier {
  static final OrderAssignmentService _instance =
      OrderAssignmentService._internal();
  factory OrderAssignmentService() => _instance;
  OrderAssignmentService._internal();

  SupabaseClient get client => Supabase.instance.client;

  // Context-aware service for tracking and validation
  final ContextAwareService _contextAware = ContextAwareService();
  final DeliveryService _deliveryService = DeliveryService();
  final LoggingService _logger = LoggingService();

  // Performance tracking
  final Map<String, DateTime> _operationStartTimes = {};
  final Map<String, int> _operationCounts = {};

  // Initialize the service with context tracking
  Future<void> initialize() async {
    try {
      _logger.startPerformanceTimer('order_assignment_service_init');
      await _contextAware.initialize();
      _logger.endPerformanceTimer('order_assignment_service_init',
          details: 'OrderAssignmentService initialized successfully');
      debugPrint('🚀 OrderAssignmentService initialized with context tracking');
      _logger.info('OrderAssignmentService initialized',
          tag: 'ORDER_ASSIGNMENT');
    } catch (e) {
      _logger.error('Failed to initialize OrderAssignmentService',
          tag: 'ORDER_ASSIGNMENT', error: e);
      rethrow;
    }
  }

  // Broadcast order to all active delivery personnel (first-accept-wins)
  Future<bool> broadcastOrderToDeliveryPersonnel({
    required String orderId,
    double? restaurantLatitude,
    double? restaurantLongitude,
    double radiusKm = 10.0,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'broadcastOrderToDeliveryPersonnel',
          service: 'OrderAssignmentService',
          operationFunction: () async {
            try {
              // Get all active delivery personnel within radius (or all if location is null)
              final activePersonnel =
                  await _deliveryService.getAvailableDeliveryPersonnel(
                latitude: restaurantLatitude,
                longitude: restaurantLongitude,
                radiusKm:
                    restaurantLatitude != null && restaurantLongitude != null
                        ? radiusKm
                        : double.infinity,
              );

              if (activePersonnel == null || activePersonnel.isEmpty) {
                debugPrint(
                    'No active delivery personnel found to broadcast order $orderId');
                return false;
              }

              debugPrint(
                  'Broadcasting order $orderId to ${activePersonnel.length} active delivery personnel');

              // Send notifications to all active delivery personnel
              final queue = await _getQueueService();
              final orderRes = await Supabase.instance.client
                  .from('orders')
                  .select('order_number')
                  .eq('id', orderId)
                  .single();

              for (final deliveryPerson in activePersonnel) {
                try {
                  final deliveryPersonRes = await Supabase.instance.client
                      .from('delivery_personnel')
                      .select('user_id')
                      .eq('id', deliveryPerson.id)
                      .single();

                  if (deliveryPersonRes['user_id'] != null) {
                    final result = await queue.enqueue(
                      taskIdentifier: 'send_notification',
                      payload: {
                        'user_id': deliveryPersonRes['user_id'],
                        'title': 'New Order Available',
                        'message':
                            'Order #${orderRes['order_number']} is available for pickup.',
                        'order_id': orderId,
                        'type': 'order_available',
                      },
                    );
                    if (!result.success) {
                      debugPrint(
                          'Failed to enqueue order available notification: ${result.error}');
                    }
                  }
                } catch (e) {
                  debugPrint(
                      'Error notifying delivery person ${deliveryPerson.id}: $e');
                }
              }

              // Update order status to indicate it's being broadcast
              final broadcastAt = DateTime.now();

              await Supabase.instance.client.from('orders').update({
                'status': 'broadcasting',
                'broadcast_at': broadcastAt.toIso8601String(),
                'updated_at': broadcastAt.toIso8601String(),
              }).eq('id', orderId);

              notifyListeners();
              return true;
            } catch (e) {
              debugPrint('Error broadcasting order: $e');
              return false;
            }
          },
          metadata: {
            'order_id': orderId,
            'restaurant_latitude': restaurantLatitude,
            'restaurant_longitude': restaurantLongitude,
            'radius_km': radiusKm,
          },
        ) ??
        false;
  }

  // Accept order by delivery personnel (first-accept-wins)
  Future<bool> acceptOrderByDeliveryPerson({
    required String orderId,
    required String deliveryPersonId,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'acceptOrderByDeliveryPerson',
          service: 'OrderAssignmentService',
          operationFunction: () async {
            try {
              debugPrint(
                  '🔍 Checking order $orderId availability for delivery person $deliveryPersonId');

              // Check if order is still available for acceptance
              final orderResponse = await Supabase.instance.client
                  .from('orders')
                  .select('status, delivery_person_id')
                  .eq('id', orderId)
                  .single();

              // Handle case where order has been deleted from database
              // Note: Supabase single() throws an exception if not found, so this check is unnecessary
              debugPrint('✅ Order $orderId found in database');

              final orderStatus = orderResponse['status'];
              final assignedDeliveryPersonId =
                  orderResponse['delivery_person_id'];

              debugPrint(
                  '📊 Order $orderId current status: $orderStatus, assigned to: $assignedDeliveryPersonId');

              // Check if order is still preparing and not assigned to someone else
              if (orderStatus != 'preparing') {
                debugPrint(
                    '❌ Order $orderId is not in preparing status (current: $orderStatus)');
                return false;
              }

              if (assignedDeliveryPersonId != null) {
                debugPrint(
                    '❌ Order $orderId is already assigned to delivery person: $assignedDeliveryPersonId');
                return false;
              }

              // Check if delivery person is still available
              debugPrint(
                  '👤 Checking delivery person $deliveryPersonId availability...');
              final deliveryPerson = await _deliveryService
                  .getDeliveryPersonByUserId(deliveryPersonId);
              if (deliveryPerson == null) {
                debugPrint(
                    '❌ Delivery person $deliveryPersonId not found in database');
                return false;
              }
              debugPrint(
                  '👤 Delivery person found: online=${deliveryPerson.isOnline}, available=${deliveryPerson.isAvailable}');

              if (!deliveryPerson.isAvailable) {
                debugPrint(
                    '❌ Delivery person $deliveryPersonId is not available');
                return false;
              }

              if (!deliveryPerson.isOnline) {
                debugPrint('❌ Delivery person $deliveryPersonId is not online');
                return false;
              }

              // Atomic acceptance via RPC to prevent race conditions
              debugPrint(
                  '🔄 Calling RPC function accept_order_by_delivery_person...');
              final rpcResult = await Supabase.instance.client.rpc(
                'accept_order_by_delivery_person',
                params: {
                  'p_order_id': orderId,
                  'p_delivery_person_id': deliveryPersonId,
                },
              );
              debugPrint('📋 RPC result: $rpcResult');

              final accepted = rpcResult == true;
              if (accepted) {
                debugPrint(
                    '✅ Order $orderId accepted by delivery person $deliveryPersonId');
                // The RPC function already handles the assignment and status update
                // No need for additional updates that could cause foreign key violations
                notifyListeners();
                return true;
              } else {
                debugPrint(
                    '❌ Failed to accept order $orderId via RPC (already taken or not preparing)');
                return false;
              }
            } catch (e) {
              debugPrint('Error accepting order: $e');
              // If error indicates order doesn't exist, clean up
              if (e.toString().contains('not found') ||
                  e.toString().contains('does not exist')) {
                await _cleanupDeletedOrder(orderId, deliveryPersonId);
              }
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

  // Delivery-side status updates scoped to the assigned delivery person
  Future<bool> markOrderPickedUpByDelivery({
    required String orderId,
    required String deliveryPersonId,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'markOrderPickedUpByDelivery',
          service: 'OrderAssignmentService',
          operationFunction: () async {
            try {
              // Prefer server-side RPC with SECURITY DEFINER to bypass RLS, while checking assignment
              try {
                final rpc = await Supabase.instance.client.rpc(
                  'mark_order_picked_up',
                  params: {
                    'p_order_id': orderId,
                  },
                );
                if (rpc == true) {
                  notifyListeners();
                  return true;
                }
              } catch (_) {}

              final now = DateTime.now().toIso8601String();
              debugPrint('🔍 Updating order in database:');
              debugPrint('  - Order ID: $orderId');
              debugPrint('  - Delivery Person ID: $deliveryPersonId');
              debugPrint('  - Update time: $now');

              final response = await Supabase.instance.client
                  .from('orders')
                  .update({
                    'status': 'picked_up',
                    'actual_pickup_time': now,
                    'updated_at': now,
                  })
                  .eq('id', orderId)
                  .eq('delivery_person_id', deliveryPersonId)
                  .select('id');

              debugPrint(
                  '📊 Database response: ${response.length} rows updated');

              if (response.isEmpty) {
                debugPrint(
                    '❌ markOrderPickedUpByDelivery: No rows updated (order not found or not assigned to this delivery person)');
                // Debug current order owner/status
                try {
                  final debugRow = await Supabase.instance.client
                      .from('orders')
                      .select('id, status, delivery_person_id')
                      .eq('id', orderId)
                      .maybeSingle();
                  debugPrint(
                      'ℹ️ Current order row: ${debugRow?.toString() ?? 'null'}');
                  debugPrint('ℹ️ Acting delivery_person_id: $deliveryPersonId');
                } catch (de) {
                  debugPrint('ℹ️ Debug fetch failed: $de');
                }
                return false;
              }

              notifyListeners();
              return true;
            } catch (e) {
              debugPrint('❌ markOrderPickedUpByDelivery error: $e');
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

  Future<bool> markOrderDeliveredByDelivery({
    required String orderId,
    required String deliveryPersonId,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'markOrderDeliveredByDelivery',
          service: 'OrderAssignmentService',
          operationFunction: () async {
            try {
              // Prefer server-side RPC with SECURITY DEFINER to bypass RLS, while checking assignment
              try {
                final rpc = await Supabase.instance.client.rpc(
                  'mark_order_delivered',
                  params: {
                    'p_order_id': orderId,
                  },
                );
                if (rpc == true) {
                  notifyListeners();
                  return true;
                }
              } catch (_) {}

              final now = DateTime.now().toIso8601String();
              final response = await Supabase.instance.client
                  .from('orders')
                  .update({
                    'status': 'delivered',
                    'actual_delivery_time': now,
                    'delivered_at': now,
                    'updated_at': now,
                  })
                  .eq('id', orderId)
                  .eq('delivery_person_id', deliveryPersonId)
                  .select('id');

              if (response.isEmpty) {
                debugPrint(
                    '❌ markOrderDeliveredByDelivery: No rows updated (order not found or not assigned to this delivery person)');
                // Debug current order owner/status
                try {
                  final debugRow = await Supabase.instance.client
                      .from('orders')
                      .select('id, status, delivery_person_id')
                      .eq('id', orderId)
                      .maybeSingle();
                  debugPrint(
                      'ℹ️ Current order row: ${debugRow?.toString() ?? 'null'}');
                  debugPrint('ℹ️ Acting delivery_person_id: $deliveryPersonId');
                } catch (de) {
                  debugPrint('ℹ️ Debug fetch failed: $de');
                }
                return false;
              }

              notifyListeners();
              return true;
            } catch (e) {
              debugPrint('❌ markOrderDeliveredByDelivery error: $e');
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

  // Cleanup method for when orders are deleted from database
  Future<void> _cleanupDeletedOrder(
      String orderId, String deliveryPersonId) async {
    try {
      debugPrint(
          '🧹 Cleaning up deleted order $orderId for delivery person $deliveryPersonId');

      // Remove any delivery assignments for this order
      await Supabase.instance.client
          .from('delivery_assignments')
          .delete()
          .eq('order_id', orderId);

      // Remove any notifications related to this order
      await Supabase.instance.client
          .from('notifications')
          .delete()
          .eq('order_id', orderId);

      // Remove any tracking data for this order
      await Supabase.instance.client
          .from('delivery_tracking')
          .delete()
          .eq('order_id', orderId);

      // Remove any queue items for this order
      await Supabase.instance.client
          .from('queue_items')
          .delete()
          .eq('order_id', orderId);

      debugPrint('✅ Cleanup completed for deleted order $orderId');
    } catch (cleanupError) {
      debugPrint(
          '❌ Error during cleanup of deleted order $orderId: $cleanupError');
    }
  }

  // Helper method to get queue service
  Future<dynamic> _getQueueService() async {
    // Import the queue service dynamically to avoid circular imports
    return QueueService();
  }

  // Automatically assign order to best available delivery person
  Future<String?> autoAssignOrder({
    required String orderId,
    double? restaurantLatitude,
    double? restaurantLongitude,
    double radiusKm = 10.0,
  }) async {
    return _contextAware.executeWithContext(
      operation: 'autoAssignOrder',
      service: 'OrderAssignmentService',
      operationFunction: () async {
        try {
          // Get available delivery personnel within radius (or all if location is null)
          final availablePersonnel =
              await _deliveryService.getAvailableDeliveryPersonnel(
            latitude: restaurantLatitude,
            longitude: restaurantLongitude,
            radiusKm: restaurantLatitude != null && restaurantLongitude != null
                ? radiusKm
                : double.infinity,
          );

          if (availablePersonnel == null || availablePersonnel.isEmpty) {
            debugPrint(
                'No available delivery personnel found${restaurantLatitude != null && restaurantLongitude != null ? ' within radius' : ''}');
            return null;
          }

          // Find the best delivery person based on multiple factors
          final bestDeliveryPerson = _findBestDeliveryPerson(
            availablePersonnel,
            restaurantLatitude,
            restaurantLongitude,
          );

          if (bestDeliveryPerson == null) {
            debugPrint('No suitable delivery person found');
            return null;
          }

          // Assign the order
          final success = await _deliveryService.assignDeliveryPerson(
            orderId: orderId,
            deliveryPersonId: bestDeliveryPerson.id,
          );

          if (success) {
            debugPrint(
                'Order $orderId assigned to delivery person ${bestDeliveryPerson.id}');
            notifyListeners();
            return bestDeliveryPerson.id;
          } else {
            debugPrint('Failed to assign order $orderId');
            return null;
          }
        } catch (e) {
          debugPrint('Error in auto assignment: $e');
          return null;
        }
      },
      metadata: {
        'order_id': orderId,
        'restaurant_latitude': restaurantLatitude,
        'restaurant_longitude': restaurantLongitude,
        'radius_km': radiusKm,
      },
    );
  }

  // Manually assign order to specific delivery person
  Future<bool> manualAssignOrder({
    required String orderId,
    required String deliveryPersonId,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'manualAssignOrder',
          service: 'OrderAssignmentService',
          operationFunction: () async {
            try {
              // Check if delivery person is available
              final deliveryPerson = await _deliveryService
                  .getDeliveryPersonById(deliveryPersonId);
              if (deliveryPerson == null ||
                  !deliveryPerson.isAvailable ||
                  !deliveryPerson.isOnline) {
                debugPrint(
                    'Delivery person $deliveryPersonId is not available');
                return false;
              }

              // Assign the order
              final success = await _deliveryService.assignDeliveryPerson(
                orderId: orderId,
                deliveryPersonId: deliveryPersonId,
              );

              if (success) {
                debugPrint(
                    'Order $orderId manually assigned to delivery person $deliveryPersonId');
                notifyListeners();
                return true;
              } else {
                debugPrint('Failed to manually assign order $orderId');
                return false;
              }
            } catch (e) {
              debugPrint('Error in manual assignment: $e');
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

  // Reassign order to different delivery person
  Future<bool> reassignOrder({
    required String orderId,
    required String newDeliveryPersonId,
    String? reason,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'reassignOrder',
          service: 'OrderAssignmentService',
          operationFunction: () async {
            try {
              // Get current order
              final orderResponse = await client
                  .from('orders')
                  .select('delivery_person_id, status')
                  .eq('id', orderId)
                  .single();

              final currentDeliveryPersonId =
                  orderResponse['delivery_person_id'] as String?;
              final orderStatus = orderResponse['status'] as String;

              // Check if order can be reassigned
              if (orderStatus == 'delivered' || orderStatus == 'cancelled') {
                debugPrint(
                    'Cannot reassign order $orderId with status $orderStatus');
                return false;
              }

              // Check if new delivery person is available
              final newDeliveryPerson = await _deliveryService
                  .getDeliveryPersonById(newDeliveryPersonId);
              if (newDeliveryPerson == null ||
                  !newDeliveryPerson.isAvailable ||
                  !newDeliveryPerson.isOnline) {
                debugPrint(
                    'New delivery person $newDeliveryPersonId is not available');
                return false;
              }

              // Make current delivery person available if exists
              if (currentDeliveryPersonId != null) {
                await _deliveryService.updateDeliveryPersonStatus(
                  deliveryPersonId: currentDeliveryPersonId,
                  isAvailable: true,
                  isOnline: true,
                );
              }

              // Assign to new delivery person
              final success = await _deliveryService.assignDeliveryPerson(
                orderId: orderId,
                deliveryPersonId: newDeliveryPersonId,
              );

              if (success) {
                debugPrint(
                    'Order $orderId reassigned from $currentDeliveryPersonId to $newDeliveryPersonId');
                notifyListeners();
                return true;
              } else {
                debugPrint('Failed to reassign order $orderId');
                return false;
              }
            } catch (e) {
              debugPrint('Error in reassignment: $e');
              return false;
            }
          },
          metadata: {
            'order_id': orderId,
            'new_delivery_person_id': newDeliveryPersonId,
            'reason': reason,
          },
        ) ??
        false;
  }

  // Unassign order (make delivery person available)
  Future<bool> unassignOrder({
    required String orderId,
    String? reason,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'unassignOrder',
          service: 'OrderAssignmentService',
          operationFunction: () async {
            try {
              // Get current order
              final orderResponse = await client
                  .from('orders')
                  .select('delivery_person_id, status')
                  .eq('id', orderId)
                  .single();

              final deliveryPersonId =
                  orderResponse['delivery_person_id'] as String?;
              final orderStatus = orderResponse['status'] as String;

              // Check if order can be unassigned
              if (orderStatus == 'delivered' || orderStatus == 'cancelled') {
                debugPrint(
                    'Cannot unassign order $orderId with status $orderStatus');
                return false;
              }

              // Remove delivery person from order
              await client.from('orders').update({
                'delivery_person_id': null,
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('id', orderId);

              // Make delivery person available if exists
              if (deliveryPersonId != null) {
                await _deliveryService.updateDeliveryPersonStatus(
                  deliveryPersonId: deliveryPersonId,
                  isAvailable: true,
                  isOnline: true,
                );
              }

              debugPrint('Order $orderId unassigned');
              notifyListeners();
              return true;
            } catch (e) {
              debugPrint('Error in unassignment: $e');
              return false;
            }
          },
          metadata: {
            'order_id': orderId,
            'reason': reason,
          },
        ) ??
        false;
  }

  // Get assignment suggestions for an order
  Future<List<DeliveryPersonnel>?> getAssignmentSuggestions({
    required String orderId,
    double? restaurantLatitude,
    double? restaurantLongitude,
    double radiusKm = 10.0,
    int limit = 5,
  }) async {
    return _contextAware.executeWithContext(
      operation: 'getAssignmentSuggestions',
      service: 'OrderAssignmentService',
      operationFunction: () async {
        try {
          // Get available delivery personnel within radius
          final availablePersonnel =
              await _deliveryService.getAvailableDeliveryPersonnel(
            latitude: restaurantLatitude,
            longitude: restaurantLongitude,
            radiusKm: radiusKm,
          );

          if (availablePersonnel == null || availablePersonnel.isEmpty) {
            return [];
          }

          // Sort by suitability score
          final suggestions = _rankDeliveryPersonnel(
            availablePersonnel,
            restaurantLatitude,
            restaurantLongitude,
          );

          return suggestions.take(limit).toList();
        } catch (e) {
          debugPrint('Error getting assignment suggestions: $e');
          return [];
        }
      },
      metadata: {
        'order_id': orderId,
        'restaurant_latitude': restaurantLatitude,
        'restaurant_longitude': restaurantLongitude,
        'radius_km': radiusKm,
        'limit': limit,
      },
    );
  }

  // Find the best delivery person based on multiple factors
  DeliveryPersonnel? _findBestDeliveryPerson(
    List<DeliveryPersonnel> personnel,
    double? restaurantLatitude,
    double? restaurantLongitude,
  ) {
    if (personnel.isEmpty) return null;

    // Rank personnel by suitability
    final rankedPersonnel = _rankDeliveryPersonnel(
      personnel,
      restaurantLatitude,
      restaurantLongitude,
    );

    return rankedPersonnel.isNotEmpty ? rankedPersonnel.first : null;
  }

  // Rank delivery personnel by suitability score
  List<DeliveryPersonnel> _rankDeliveryPersonnel(
    List<DeliveryPersonnel> personnel,
    double? restaurantLatitude,
    double? restaurantLongitude,
  ) {
    // Calculate suitability score for each delivery person
    final scoredPersonnel = personnel.map((person) {
      double score = 0.0;

      // Rating factor (40% weight)
      score += person.rating * 0.4;

      // Distance factor (30% weight) - closer is better
      // Only apply distance factor if restaurant location is available
      if (person.hasLocation &&
          restaurantLatitude != null &&
          restaurantLongitude != null) {
        final distance = _calculateDistance(
          restaurantLatitude,
          restaurantLongitude,
          person.currentLatitude!,
          person.currentLongitude!,
        );
        // Normalize distance (closer = higher score)
        final distanceScore = (10.0 - distance.clamp(0.0, 10.0)) / 10.0;
        score += distanceScore * 0.3;
      } else if (restaurantLatitude == null && restaurantLongitude == null) {
        // If no location filtering, give full distance score to all personnel
        score += 0.3;
      }

      // Experience factor (20% weight)
      final experienceScore = (person.totalDeliveries / 100.0).clamp(0.0, 1.0);
      score += experienceScore * 0.2;

      // Availability factor (10% weight)
      if (person.isAvailable && person.isOnline) {
        score += 0.1;
      }

      return MapEntry(person, score);
    }).toList();

    // Sort by score (highest first)
    scoredPersonnel.sort((a, b) => b.value.compareTo(a.value));

    return scoredPersonnel.map((entry) => entry.key).toList();
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

  // Get assignment statistics
  Future<Map<String, dynamic>?> getAssignmentStats() async {
    return _contextAware.executeWithContext(
      operation: 'getAssignmentStats',
      service: 'OrderAssignmentService',
      operationFunction: () async {
        try {
          // Get total orders
          final totalOrdersResponse = await client
              .from('orders')
              .select('id')
              .neq('status', 'cancelled');

          // Get assigned orders
          final assignedOrdersResponse = await client
              .from('orders')
              .select('id')
              .not('delivery_person_id', 'is', null)
              .neq('status', 'cancelled');

          // Get available delivery personnel
          final availablePersonnelResponse = await client
              .from('delivery_personnel')
              .select('id')
              .eq('is_available', 'true')
              .eq('is_online', true);

          final totalOrders = totalOrdersResponse.length;
          final assignedOrders = assignedOrdersResponse.length;
          final availablePersonnel = availablePersonnelResponse.length;
          final unassignedOrders = totalOrders - assignedOrders;

          return {
            'total_orders': totalOrders,
            'assigned_orders': assignedOrders,
            'unassigned_orders': unassignedOrders,
            'available_personnel': availablePersonnel,
            'assignment_rate':
                totalOrders > 0 ? assignedOrders / totalOrders : 0.0,
          };
        } catch (e) {
          debugPrint('Error fetching assignment stats: $e');
          return null;
        }
      },
      metadata: {},
    );
  }

  // Get context summary for debugging
  Map<String, dynamic> getContextSummary() {
    return _contextAware.getContextSummary();
  }

  /// Get performance analytics for the service
  Map<String, dynamic> getPerformanceAnalytics() {
    final totalOperations =
        _operationCounts.values.fold(0, (sum, count) => sum + count);
    final averageOperationTime = _operationStartTimes.isNotEmpty
        ? _operationStartTimes.values
                .map((startTime) =>
                    DateTime.now().difference(startTime).inMilliseconds)
                .reduce((a, b) => a + b) /
            _operationStartTimes.length
        : 0.0;

    return {
      'service_name': 'OrderAssignmentService',
      'total_operations': totalOperations,
      'average_operation_time_ms': averageOperationTime,
      'operation_counts': Map.from(_operationCounts),
    };
  }

  /// Clear performance cache
  void clearPerformanceCache() {
    _operationStartTimes.clear();
    _operationCounts.clear();
    _logger.info('OrderAssignmentService performance cache cleared',
        tag: 'ORDER_ASSIGNMENT');
  }
}
