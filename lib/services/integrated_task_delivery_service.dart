import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/delivery_personnel.dart';
import '../models/order.dart';
import '../models/task.dart';
import 'error_handling_service.dart';
import 'unified_performance_service.dart';

/// Integrated service that bridges Ifrili tasks with delivery system
///
/// This service provides a unified interface for managing both Ifrili tasks and
/// traditional delivery orders within a single delivery dashboard. It handles:
///
/// - Task assignment and completion workflows
/// - Real-time updates for both tasks and orders
/// - Unified dashboard data aggregation
/// - Location-based task discovery
/// - Earnings tracking for task completion
/// - Performance monitoring and optimization
///
/// The service acts as a bridge between the Ifrili task system and the existing
/// delivery infrastructure, ensuring seamless integration without disrupting
/// existing functionality.
///
/// Example usage:
/// ```dart
/// final service = IntegratedTaskDeliveryService.instance;
///
/// // Get available tasks for delivery
/// final tasks = await service.getAvailableTasksForDelivery();
///
/// // Accept a task
/// final success = await service.acceptTaskForDelivery(
///   taskId: 'task-id',
///   deliveryPersonId: 'delivery-person-id',
/// );
///
/// // Get unified dashboard data
/// final data = await service.getUnifiedDashboardData('delivery-person-id');
/// ```
class IntegratedTaskDeliveryService {
  IntegratedTaskDeliveryService._();
  static final IntegratedTaskDeliveryService instance =
      IntegratedTaskDeliveryService._();

  SupabaseClient get _client => Supabase.instance.client;

  // Error handling and performance monitoring
  final ErrorHandlingService _errorHandler = ErrorHandlingService();
  final UnifiedPerformanceService _performanceService =
      UnifiedPerformanceService();

  // =====================================================
  // TASK-DELIVERY INTEGRATION METHODS
  // =====================================================

  /// Get all available tasks for delivery personnel (only pending tasks)
  Future<List<Task>> getAvailableTasksForDelivery() async {
    final stopwatch = Stopwatch()..start();
    try {
      _performanceService.startOperation('getAvailableTasksForDelivery');

      final res = await _client
          .from('v_available_tasks') // Use the new view for available tasks
          .select('*, special_instructions')
          .order('created_at', ascending: true);

      final rows = (res as List).cast<Map<String, dynamic>>();
      final result = _aggregateBundlesFromRows(rows);

      stopwatch.stop();
      _performanceService.endOperation('getAvailableTasksForDelivery');

      return result;
    } catch (e) {
      stopwatch.stop();
      _performanceService.endOperation('getAvailableTasksForDelivery');

      _errorHandler.handleError(
        'Failed to fetch available tasks for delivery',
        context: 'IntegratedTaskDeliveryService.getAvailableTasksForDelivery',
      );

      throw Exception('Failed to fetch available tasks for delivery: $e');
    }
  }

  /// Get tasks currently being reviewed by delivery person (cost_review status)
  Future<List<Task>> getCostReviewTasksForDelivery(
      String deliveryPersonId) async {
    try {
      final res = await _client
          .from('v_cost_review_tasks') // Use the new view for cost review tasks
          .select('*, special_instructions')
          .eq('reviewing_delivery_person_id', deliveryPersonId)
          .order('created_at', ascending: true);

      final rows = (res as List).cast<Map<String, dynamic>>();
      return _aggregateBundlesFromRows(rows);
    } catch (e) {
      throw Exception(
          'Failed to fetch cost review tasks for delivery. Error: $e. Please check your internet connection and try again.');
    }
  }

  /// Get tasks with cost proposals (cost_proposed status)
  Future<List<Task>> getCostProposedTasksForDelivery() async {
    try {
      final res = await _client
          .from(
              'v_cost_proposed_tasks') // Use the new view for cost proposed tasks
          .select('*, special_instructions')
          .order('created_at', ascending: true);

      final rows = (res as List).cast<Map<String, dynamic>>();
      return _aggregateBundlesFromRows(rows);
    } catch (e) {
      throw Exception(
          'Failed to fetch cost proposed tasks for delivery. Error: $e. Please check your internet connection and try again.');
    }
  }

  /// Get tasks with user counter proposals (user_counter_proposed status)
  Future<List<Task>> getUserCounterProposedTasksForDelivery() async {
    try {
      final res = await _client
          .from(
              'v_user_counter_proposed_tasks') // Use the new view for user counter proposed tasks
          .select('*, special_instructions')
          .order('created_at', ascending: true);

      final rows = (res as List).cast<Map<String, dynamic>>();
      return _aggregateBundlesFromRows(rows);
    } catch (e) {
      throw Exception(
          'Failed to fetch user counter proposed tasks for delivery. Error: $e. Please check your internet connection and try again.');
    }
  }

  /// Get tasks assigned to a specific delivery person (assigned status with delivery_man_id)
  Future<List<Task>> getAssignedTasksForDeliveryPerson(
      String deliveryPersonId) async {
    try {
      debugPrint(
          '🔍 Querying assigned tasks for delivery person: $deliveryPersonId');
      final res = await _client
          .from('v_assigned_tasks') // Use the new view for assigned tasks
          .select('*, special_instructions')
          .eq('delivery_person_id', deliveryPersonId)
          .order('assigned_at', ascending: true);

      final rows = (res as List).cast<Map<String, dynamic>>();
      debugPrint('📋 Found ${rows.length} assigned tasks in database');
      for (final row in rows) {
        debugPrint(
            '  - Task ${row['id']}: status=${row['status']}, delivery_man_id=${row['delivery_man_id']}');
      }

      final aggregatedTasks = _aggregateBundlesFromRows(rows);
      debugPrint('📦 Aggregated to ${aggregatedTasks.length} task bundles');
      return aggregatedTasks;
    } catch (e) {
      debugPrint('❌ Error fetching assigned tasks: $e');
      throw Exception(
          'Failed to fetch assigned tasks for delivery person $deliveryPersonId. Error: $e. Please check your internet connection and try again.');
    }
  }

  /// Get active tasks for delivery person (alias for getAssignedTasksForDeliveryPerson)
  Future<List<Task>> getActiveTasksForDelivery(String deliveryPersonId) async {
    return getAssignedTasksForDeliveryPerson(deliveryPersonId);
  }

  /// Get completed tasks for delivery person
  Future<List<Task>> getCompletedTasksForDelivery(
      String deliveryPersonId) async {
    try {
      final res = await _client
          .from('tasks')
          .select('*')
          .eq('delivery_man_id', deliveryPersonId)
          .eq('status', 'completed')
          .order('updated_at', ascending: false);

      return (res as List)
          .map((e) => Task.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception(
          'Failed to fetch completed tasks for delivery person $deliveryPersonId. Error: $e. Please check your internet connection and try again.');
    }
  }

  /// Accept task for delivery (alias for assignTaskToDeliveryPerson)
  Future<bool> acceptTaskForDelivery({
    required String taskId,
    required String deliveryPersonId,
  }) async {
    return assignTaskToDeliveryPerson(
      taskId: taskId,
      deliveryPersonId: deliveryPersonId,
    );
  }

  /// Complete task for delivery (alias for completeTask)
  Future<bool> completeTaskForDelivery({
    required String taskId,
    required String deliveryPersonId,
  }) async {
    return completeTask(
      taskId: taskId,
      deliveryPersonId: deliveryPersonId,
    );
  }

  /// Assign a task to a delivery person
  Future<bool> assignTaskToDeliveryPerson({
    required String taskId,
    required String deliveryPersonId,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      _performanceService.startOperation('assignTaskToDeliveryPerson');

      // If this is a bundle synthetic id, assign all tasks in the bundle
      if (taskId.startsWith('group-')) {
        final groupId = taskId.replaceFirst('group-', '');
        final nowIso = DateTime.now().toIso8601String();
        await _client
            .from('tasks')
            .update({
              'delivery_man_id': deliveryPersonId,
              'status': 'assigned',
              'assignment_type': 'manual',
              'assigned_by': deliveryPersonId,
              'updated_at': nowIso,
            })
            .ilike('special_instructions', '%group:$groupId%')
            .eq('status', 'pending');

        await _client.from('delivery_personnel').update({
          'is_available': false,
          'updated_at': nowIso,
        }).eq('user_id', deliveryPersonId);

        stopwatch.stop();
        _performanceService.endOperation('assignTaskToDeliveryPerson');
        return true;
      }
      // Check if delivery person is available
      final deliveryPerson = await _getDeliveryPersonById(deliveryPersonId);
      debugPrint('🔍 Delivery person lookup result: ${deliveryPerson?.id}');
      if (deliveryPerson == null ||
          !deliveryPerson.isAvailable ||
          !deliveryPerson.isOnline) {
        throw Exception('Delivery person is not available');
      }

      // Update task with assignment
      await _client
          .from('tasks')
          .update({
            'delivery_man_id': deliveryPersonId,
            'status': 'assigned',
            'assignment_type': 'manual',
            'assigned_by': deliveryPersonId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', taskId)
          .eq('status', 'pending'); // Only assign if still pending

      // Mark delivery person as busy
      await _client.from('delivery_personnel').update({
        'is_available': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', deliveryPersonId);

      stopwatch.stop();
      _performanceService.endOperation('assignTaskToDeliveryPerson');
      return true;
    } catch (e) {
      stopwatch.stop();
      _performanceService.endOperation('assignTaskToDeliveryPerson');

      _errorHandler.handleError(
        'Failed to assign task $taskId to delivery person $deliveryPersonId',
        context: 'IntegratedTaskDeliveryService.assignTaskToDeliveryPerson',
      );

      throw Exception(
          'Failed to assign task $taskId to delivery person $deliveryPersonId: $e');
    }
  }

  /// Complete a task and update delivery person status
  Future<bool> completeTask({
    required String taskId,
    required String deliveryPersonId,
  }) async {
    try {
      if (taskId.startsWith('group-')) {
        final groupId = taskId.replaceFirst('group-', '');
        final nowIso = DateTime.now().toIso8601String();
        await _client
            .from('tasks')
            .update({
              'status': 'completed',
              'updated_at': nowIso,
            })
            .ilike('special_instructions', '%group:$groupId%')
            .eq('delivery_man_id', deliveryPersonId)
            .inFilter('status', ['assigned', 'scheduled']);

        await _client.from('delivery_personnel').update({
          'is_available': true,
          'updated_at': nowIso,
        }).eq('user_id', deliveryPersonId);

        // Record earnings for each task in the bundle
        final bundleRows = await _client
            .from('tasks')
            .select('id')
            .ilike('special_instructions', '%group:$groupId%')
            .eq('delivery_man_id', deliveryPersonId);
        for (final row in (bundleRows as List)) {
          await _recordTaskEarnings(
              taskId: row['id'] as String, deliveryPersonId: deliveryPersonId);
        }
        return true;
      }
      // Update task status
      await _client
          .from('tasks')
          .update({
            'status': 'completed',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', taskId)
          .eq('delivery_man_id', deliveryPersonId);

      // Mark delivery person as available again
      await _client.from('delivery_personnel').update({
        'is_available': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', deliveryPersonId);

      // Record earnings for task completion
      await _recordTaskEarnings(
          taskId: taskId, deliveryPersonId: deliveryPersonId);

      return true;
    } catch (e) {
      throw Exception(
          'Failed to complete task $taskId for delivery person $deliveryPersonId. Error: $e. Please ensure the task is assigned to you and try again.');
    }
  }

  /// Get unified dashboard data (tasks + orders) for delivery person
  Future<Map<String, dynamic>> getUnifiedDashboardData(
      String deliveryPersonId) async {
    try {
      // Get assigned tasks
      final assignedTasks =
          await getAssignedTasksForDeliveryPerson(deliveryPersonId);

      // Get available tasks
      final availableTasks = await getAvailableTasksForDelivery();

      // Get active orders (from existing delivery system)
      final activeOrders =
          await _getActiveOrdersForDeliveryPerson(deliveryPersonId);

      // Get available orders (from existing delivery system)
      final availableOrders = await _getAvailableOrders();

      return {
        'assignedTasks': assignedTasks,
        'availableTasks': availableTasks,
        'activeOrders': activeOrders,
        'availableOrders': availableOrders,
        'totalAssigned': assignedTasks.length + activeOrders.length,
        'totalAvailable': availableTasks.length + availableOrders.length,
      };
    } catch (e) {
      throw Exception(
          'Failed to fetch unified dashboard data for delivery person $deliveryPersonId. Error: $e. Please check your internet connection and try again.');
    }
  }

  /// Get tasks near delivery person's location
  Future<List<Task>> getTasksNearLocation({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
  }) async {
    try {
      // Use PostGIS or simple distance calculation
      final res = await _client.rpc('get_tasks_near_location', params: {
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_radius_km': radiusKm,
      });

      return (res as List)
          .map((e) => Task.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Fallback to simple query if RPC function doesn't exist
      final res = await _client
          .from('tasks')
          .select('*')
          .eq('status', 'pending')
          .order('created_at', ascending: true);

      return (res as List)
          .map((e) => Task.fromMap(e as Map<String, dynamic>))
          .toList();
    }
  }

  // =====================================================
  // PERFORMANCE MONITORING METHODS
  // =====================================================

  /// Get performance statistics for task operations
  Map<String, dynamic> getPerformanceStats() {
    return _performanceService.getOperationStats();
  }

  /// Get error statistics for task operations
  Map<String, dynamic> getErrorStats() {
    return _errorHandler.getErrorStats();
  }

  /// Clear performance and error statistics
  void clearStats() {
    _performanceService.clearStats();
    _errorHandler.clearStats();
  }

  /// Get service health status
  Map<String, dynamic> getServiceHealth() {
    final performanceStats = getPerformanceStats();
    final errorStats = getErrorStats();

    return {
      'service': 'IntegratedTaskDeliveryService',
      'status': 'healthy',
      'performance': performanceStats,
      'errors': errorStats,
      'lastChecked': DateTime.now().toIso8601String(),
    };
  }

  // =====================================================
  // PRIVATE HELPER METHODS
  // =====================================================

  List<Task> _aggregateBundlesFromRows(List<Map<String, dynamic>> rows) {
    final Map<String, List<Task>> bundles = {};
    final List<Task> singles = [];
    for (final row in rows) {
      final t = Task.fromMap(row);
      final gid = _extractGroupIdFromRow(row);
      if (gid == null) {
        singles.add(t);
      } else {
        bundles.putIfAbsent(gid, () => []).add(t);
      }
    }

    final List<Task> result = [];
    bundles.forEach((gid, list) {
      if (list.isEmpty) return;
      final first = list.first;
      result.add(Task(
        id: 'group-$gid',
        description:
            'Ifrili bundle (${list.length}) - Multi-stop request. Tap to view details.',
        locationName:
            list.length == 1 ? first.locationName : 'Multiple locations',
        locationPurpose:
            list.length == 1 ? first.locationPurpose : 'Multiple locations',
        latitude: first.latitude,
        longitude: first.longitude,
        status: first.status,
        scheduledAt: first.scheduledAt,
        userId: first.userId,
        deliveryManId: first.deliveryManId,
        imageUrl: first.imageUrl,
        imagePath: first.imagePath,
        createdAt: first.createdAt,
        updatedAt: first.updatedAt,
        assignedAt: first.assignedAt,
        completedAt: first.completedAt,
        assignmentType: first.assignmentType,
        assignedBy: first.assignedBy,
        assignmentNotes: first.assignmentNotes,
      ));
    });

    result.addAll(singles);
    return result;
  }

  String? _extractGroupIdFromRow(Map<String, dynamic> row) {
    final si = (row['special_instructions'] ?? '').toString();
    if (si.isEmpty) return null;
    final idx = si.indexOf('group:');
    if (idx == -1) return null;
    final start = idx + 6;
    // take until whitespace or end
    int end = si.indexOf(' ', start);
    if (end == -1) end = si.length;
    final gid = si.substring(start, end).trim();
    return gid.isEmpty ? null : gid;
  }

  Future<DeliveryPersonnel?> _getDeliveryPersonById(
      String deliveryPersonId) async {
    try {
      final res = await _client
          .from('delivery_personnel')
          .select('*')
          .eq('user_id', deliveryPersonId) // Use user_id, not id
          .single();

      return DeliveryPersonnel.fromJson(res);
    } catch (e) {
      return null;
    }
  }

  Future<List<Order>> _getActiveOrdersForDeliveryPerson(
      String deliveryPersonId) async {
    try {
      final res = await _client
          .from('v_active_orders')
          .select('*')
          .eq('delivery_person_id', deliveryPersonId);

      return (res as List).map((e) => Order.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Order>> _getAvailableOrders() async {
    try {
      final res = await _client.from('v_available_orders').select('*');

      return (res as List).map((e) => Order.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _recordTaskEarnings({
    required String taskId,
    required String deliveryPersonId,
  }) async {
    try {
      // Get task details for earnings calculation
      final taskRes =
          await _client.from('tasks').select('price').eq('id', taskId).single();

      final taskPrice = (taskRes['price'] as num).toDouble();

      // Calculate earnings (e.g., 70% of task price)
      final earnings = taskPrice * 0.7;

      // Record earnings
      await _client.from('delivery_earnings').insert({
        'delivery_person_id': deliveryPersonId,
        'base_fee': earnings,
        'total_earnings': earnings,
        'type': 'base_fee',
        'description': 'Ifrili task completion earnings',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Log error but don't fail the task completion
      debugPrint('Failed to record task earnings: $e');
    }
  }

  // =====================================================
  // COST NEGOTIATION METHODS
  // =====================================================

  /// Start cost review for a task (delivery man picks up task)
  Future<bool> startCostReview({
    required String taskId,
    required String deliveryPersonId,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      _performanceService.startOperation('startCostReview');

      debugPrint('IntegratedTaskDeliveryService: Starting cost review');
      debugPrint('Task ID: $taskId');
      debugPrint('Delivery Person ID: $deliveryPersonId');

      // Validate inputs
      if (taskId.isEmpty) {
        throw Exception('Task ID cannot be empty');
      }
      if (deliveryPersonId.isEmpty) {
        throw Exception('Delivery Person ID cannot be empty');
      }

      // First, let's check the current task status
      final taskRes = await _client
          .from('tasks')
          .select('status, delivery_man_id')
          .eq('id', taskId)
          .single();

      debugPrint('Current task status: ${taskRes['status']}');
      debugPrint('Current delivery_man_id: ${taskRes['delivery_man_id']}');

      // Check if delivery person exists and their availability
      final deliveryRes = await _client
          .from('delivery_personnel')
          .select('user_id, is_available')
          .eq('user_id', deliveryPersonId)
          .single();

      debugPrint('Delivery person exists: true');
      debugPrint(
          'Delivery person is_available: ${deliveryRes['is_available']}');

      // Check for existing cost proposals
      final proposalsRes = await _client
          .from('task_cost_proposals')
          .select('id, status, proposed_at')
          .eq('task_id', taskId)
          .eq('delivery_person_id', deliveryPersonId)
          .eq('status', 'pending');

      debugPrint('Existing proposals count: ${proposalsRes.length}');

      // Use the new database function that handles everything atomically
      final result = await _client.rpc('start_cost_review', params: {
        'p_task_id': taskId,
        'p_delivery_person_id': deliveryPersonId,
      });

      debugPrint('RPC result: $result');

      if (result == null || result == false) {
        throw Exception(
            'Task is no longer available or already taken by another delivery person. Check task status, delivery person availability, or existing proposals.');
      }

      debugPrint('Cost review started successfully');
      stopwatch.stop();
      _performanceService.endOperation('startCostReview');
      return true;
    } catch (e) {
      stopwatch.stop();
      _performanceService.endOperation('startCostReview');

      debugPrint('Error in startCostReview: $e');

      _errorHandler.handleError(
        'Failed to start cost review for task $taskId',
        context: 'IntegratedTaskDeliveryService.startCostReview',
      );

      throw Exception('Failed to start cost review for task $taskId: $e');
    }
  }

  /// Propose cost for a task (delivery man sets cost)
  Future<bool> proposeCost({
    required String taskId,
    required String deliveryPersonId,
    required double cost,
    String? notes,
  }) async {
    try {
      debugPrint('IntegratedTaskDeliveryService: Proposing cost');
      debugPrint('Task ID: $taskId');
      debugPrint('Delivery Person ID: $deliveryPersonId');
      debugPrint('Cost: $cost');
      debugPrint('Notes: $notes');

      // Validate inputs
      if (taskId.isEmpty) {
        throw Exception('Task ID cannot be empty');
      }
      if (deliveryPersonId.isEmpty) {
        throw Exception('Delivery Person ID cannot be empty');
      }
      if (cost <= 0) {
        throw Exception('Cost must be greater than 0');
      }

      final result = await _client.rpc('propose_task_cost', params: {
        'p_task_id': taskId,
        'p_delivery_person_id': deliveryPersonId,
        'p_proposed_cost': cost,
        'p_cost_notes': notes,
      });

      debugPrint('RPC result: $result');

      if (result == null || result == false) {
        throw Exception(
            'Failed to propose cost. Task may not be in cost review status or you may not be the assigned delivery person.');
      }

      debugPrint('Cost proposed successfully');
      return true;
    } catch (e) {
      debugPrint('Error in proposeCost: $e');
      throw Exception('Failed to propose cost for task $taskId. Error: $e');
    }
  }

  /// Update existing cost proposal (delivery man modifies their offer)
  Future<bool> updateCostProposal({
    required String taskId,
    required String deliveryPersonId,
    required double cost,
    String? notes,
  }) async {
    try {
      debugPrint('IntegratedTaskDeliveryService: Updating cost proposal');
      debugPrint('Task ID: $taskId');
      debugPrint('Delivery Person ID: $deliveryPersonId');
      debugPrint('New Cost: $cost');
      debugPrint('Notes: $notes');

      // Validate inputs
      if (taskId.isEmpty) {
        throw Exception('Task ID cannot be empty');
      }
      if (deliveryPersonId.isEmpty) {
        throw Exception('Delivery Person ID cannot be empty');
      }
      if (cost <= 0) {
        throw Exception('Cost must be greater than 0');
      }

      // Use the new database function for updating cost proposals
      final result = await _client.rpc('update_cost_proposal', params: {
        'p_task_id': taskId,
        'p_delivery_person_id': deliveryPersonId,
        'p_proposed_cost': cost,
        'p_cost_notes': notes,
      });

      debugPrint('RPC result: $result');

      if (result == null || result == false) {
        throw Exception(
            'Failed to update cost proposal. Task may not be in correct status or you may not have an existing proposal.');
      }

      debugPrint('Cost proposal updated successfully');
      return true;
    } catch (e) {
      debugPrint('Error in updateCostProposal: $e');
      throw Exception(
          'Failed to update cost proposal for task $taskId. Error: $e');
    }
  }

  /// Accept proposed cost (user accepts cost)
  Future<bool> acceptProposedCost({
    required String taskId,
    required String userId,
  }) async {
    try {
      // Get the first pending proposal for this task
      final proposalRes = await _client
          .from('task_cost_proposals')
          .select('id')
          .eq('task_id', taskId)
          .eq('status', 'pending')
          .order('proposed_at', ascending: true)
          .limit(1)
          .single();

      final proposalId = proposalRes['id'] as String?;

      if (proposalId == null) {
        throw Exception('No pending cost proposal found for task $taskId');
      }

      // Use the new database function to accept the proposal
      final result = await _client.rpc('accept_cost_proposal', params: {
        'p_task_id': taskId,
        'p_proposal_id': proposalId,
        'p_user_id': userId,
      });

      if (result == null || result == false) {
        throw Exception(
            'Failed to accept cost proposal. Proposal may not exist or task may not be in correct status.');
      }

      return true;
    } catch (e) {
      throw Exception('Failed to accept cost for task $taskId. Error: $e');
    }
  }

  /// Accept user counter offer (delivery man accepts user's counter proposal)
  Future<bool> acceptUserCounterOffer({
    required String taskId,
    required String deliveryPersonId,
  }) async {
    try {
      debugPrint('IntegratedTaskDeliveryService: Accepting user counter offer');
      debugPrint('Task ID: $taskId');
      debugPrint('Delivery Person ID: $deliveryPersonId');

      // Validate inputs
      if (taskId.isEmpty) {
        throw Exception('Task ID cannot be empty');
      }
      if (deliveryPersonId.isEmpty) {
        throw Exception('Delivery Person ID cannot be empty');
      }

      // First, verify the task is in user_counter_proposed status
      final taskRes = await _client
          .from('tasks')
          .select('status')
          .eq('id', taskId)
          .single();

      if (taskRes['status'] != 'user_counter_proposed') {
        throw Exception('Task is not in user_counter_proposed status');
      }

      // Get the user counter offer from task_cost_proposals
      final proposalRes = await _client
          .from('task_cost_proposals')
          .select('proposed_cost, cost_notes')
          .eq('task_id', taskId)
          .eq('status', 'user_counter')
          .single();

      if (proposalRes.isEmpty) {
        throw Exception('No user counter offer found for this task');
      }

      // Update the task to accept the user's counter offer
      final updateRes = await _client
          .from('tasks')
          .update({
            'status': 'assigned',
            'delivery_man_id': deliveryPersonId,
            'accepted_cost': proposalRes['proposed_cost'],
            'cost_accepted_at': DateTime.now().toIso8601String(),
            'assignment_type': 'manual', // Fixed: use valid constraint value
            'assigned_by': deliveryPersonId,
            'assigned_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', taskId)
          .eq('status', 'user_counter_proposed')
          .select('id');

      if (updateRes.isEmpty) {
        throw Exception(
            'Failed to update task. Task may not exist or status may have changed.');
      }

      // Mark the user counter proposal as accepted
      await _client
          .from('task_cost_proposals')
          .update({
            'status': 'accepted',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('task_id', taskId)
          .eq('status', 'user_counter');

      debugPrint('User counter offer accepted successfully');
      return true;
    } catch (e) {
      debugPrint('Error in acceptUserCounterOffer: $e');
      throw Exception(
          'Failed to accept user counter offer for task $taskId. Error: $e');
    }
  }

  /// Accept a specific cost proposal (user accepts specific proposal)
  Future<bool> acceptSpecificCostProposal({
    required String taskId,
    required String proposalId,
    required String userId,
  }) async {
    try {
      final result = await _client.rpc('accept_cost_proposal', params: {
        'p_task_id': taskId,
        'p_proposal_id': proposalId,
        'p_user_id': userId,
      });

      if (result == null || result == false) {
        throw Exception(
            'Failed to accept cost proposal. Proposal may not exist or task may not be in correct status.');
      }

      return true;
    } catch (e) {
      throw Exception(
          'Failed to accept cost proposal for task $taskId. Error: $e');
    }
  }

  /// Get all cost proposals for a task
  Future<List<Map<String, dynamic>>> getTaskCostProposals(String taskId) async {
    try {
      final response = await _client
          .from('task_cost_proposals')
          .select('''
            id,
            proposed_cost,
            cost_notes,
            proposed_at,
            status,
            delivery_person_id,
            delivery_personnel:delivery_person_id (
              user_id,
              vehicle_type,
              rating,
              total_deliveries
            )
          ''')
          .eq('task_id', taskId)
          .eq('status', 'pending')
          .order('proposed_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception(
          'Failed to get cost proposals for task $taskId. Error: $e');
    }
  }

  /// Reject proposed cost (user rejects cost)
  Future<bool> rejectProposedCost({
    required String taskId,
    required String userId,
  }) async {
    try {
      final result = await _client.rpc('reject_all_cost_proposals', params: {
        'p_task_id': taskId,
        'p_user_id': userId,
      });

      if (result == null || result == false) {
        throw Exception(
            'Failed to reject cost proposals. Task may not be in correct status.');
      }

      return true;
    } catch (e) {
      throw Exception('Failed to reject cost for task $taskId. Error: $e');
    }
  }

  /// Cancel cost review (delivery man cancels)
  Future<bool> cancelCostReview({
    required String taskId,
    required String deliveryPersonId,
  }) async {
    try {
      final result = await _client.rpc('cancel_cost_review', params: {
        'p_task_id': taskId,
        'p_delivery_person_id': deliveryPersonId,
      });

      if (result == null || result == false) {
        throw Exception(
            'Failed to cancel cost review. Task may not be in correct status.');
      }

      return true;
    } catch (e) {
      throw Exception(
          'Failed to cancel cost review for task $taskId. Error: $e');
    }
  }

  /// User proposes counter-offer to delivery man
  Future<bool> userProposeCounterOffer({
    required String taskId,
    required String userId,
    required double counterCost,
    String? notes,
  }) async {
    try {
      debugPrint('IntegratedTaskDeliveryService: User proposing counter-offer');
      debugPrint('Task ID: $taskId');
      debugPrint('User ID: $userId');
      debugPrint('Counter cost: $counterCost');

      // Validate inputs
      if (taskId.isEmpty) {
        throw Exception('Task ID cannot be empty');
      }
      if (userId.isEmpty) {
        throw Exception('User ID cannot be empty');
      }
      if (counterCost <= 0) {
        throw Exception('Counter cost must be greater than 0');
      }

      // Use the database function to handle user counter-offer
      final result = await _client.rpc('user_propose_counter_offer', params: {
        'p_task_id': taskId,
        'p_user_id': userId,
        'p_counter_cost': counterCost,
        'p_notes': notes,
      });

      debugPrint('RPC result: $result');

      if (result == null || result == false) {
        throw Exception('Failed to propose counter-offer');
      }

      debugPrint('Counter-offer proposed successfully');
      return true;
    } catch (e) {
      debugPrint('Error in userProposeCounterOffer: $e');
      throw Exception(
          'Failed to propose counter-offer for task $taskId. Error: $e');
    }
  }

  /// Delivery man responds to user counter-offer
  Future<bool> deliveryManRespondToCounterOffer({
    required String taskId,
    required String deliveryPersonId,
    required String responseType, // 'accept', 'reject', 'counter'
    double? newCost,
    String? notes,
  }) async {
    try {
      debugPrint(
          'IntegratedTaskDeliveryService: Delivery man responding to counter-offer');
      debugPrint('Task ID: $taskId');
      debugPrint('Delivery Person ID: $deliveryPersonId');
      debugPrint('Response type: $responseType');
      debugPrint('New cost: $newCost');

      // Validate inputs
      if (taskId.isEmpty) {
        throw Exception('Task ID cannot be empty');
      }
      if (deliveryPersonId.isEmpty) {
        throw Exception('Delivery Person ID cannot be empty');
      }
      if (!['accept', 'reject', 'counter'].contains(responseType)) {
        throw Exception(
            'Invalid response type. Must be accept, reject, or counter');
      }
      if (responseType == 'counter' && (newCost == null || newCost <= 0)) {
        throw Exception(
            'New cost must be provided and greater than 0 for counter response');
      }

      // Use the database function to handle delivery man response
      final result =
          await _client.rpc('delivery_man_respond_to_counter_offer', params: {
        'p_task_id': taskId,
        'p_delivery_person_id': deliveryPersonId,
        'p_response_type': responseType,
        'p_new_cost': newCost,
        'p_notes': notes,
      });

      debugPrint('RPC result: $result');

      if (result == null || result == false) {
        throw Exception('Failed to respond to counter-offer');
      }

      debugPrint('Response to counter-offer sent successfully');
      return true;
    } catch (e) {
      debugPrint('Error in deliveryManRespondToCounterOffer: $e');
      throw Exception(
          'Failed to respond to counter-offer for task $taskId. Error: $e');
    }
  }

  /// Finalize cost negotiation when both parties agree
  Future<bool> finalizeCostNegotiation({
    required String taskId,
    required double finalCost,
    required String agreedBy, // 'user' or 'delivery_man'
  }) async {
    try {
      debugPrint('IntegratedTaskDeliveryService: Finalizing cost negotiation');
      debugPrint('Task ID: $taskId');
      debugPrint('Final cost: $finalCost');
      debugPrint('Agreed by: $agreedBy');

      // Validate inputs
      if (taskId.isEmpty) {
        throw Exception('Task ID cannot be empty');
      }
      if (finalCost <= 0) {
        throw Exception('Final cost must be greater than 0');
      }
      if (!['user', 'delivery_man'].contains(agreedBy)) {
        throw Exception(
            'Invalid agreed by value. Must be user or delivery_man');
      }

      // Use the database function to finalize negotiation
      final result = await _client.rpc('finalize_cost_negotiation', params: {
        'p_task_id': taskId,
        'p_final_cost': finalCost,
        'p_agreed_by': agreedBy,
      });

      debugPrint('RPC result: $result');

      if (result == null || result == false) {
        throw Exception('Failed to finalize cost negotiation');
      }

      debugPrint('Cost negotiation finalized successfully');
      return true;
    } catch (e) {
      debugPrint('Error in finalizeCostNegotiation: $e');
      throw Exception(
          'Failed to finalize cost negotiation for task $taskId. Error: $e');
    }
  }

  /// Cancel cost negotiation and return task to pending
  Future<bool> cancelCostNegotiation({
    required String taskId,
    required String cancelledBy, // 'user' or 'delivery_man'
    required String cancelledById,
  }) async {
    try {
      debugPrint('IntegratedTaskDeliveryService: Cancelling cost negotiation');
      debugPrint('Task ID: $taskId');
      debugPrint('Cancelled by: $cancelledBy');
      debugPrint('Cancelled by ID: $cancelledById');

      // Validate inputs
      if (taskId.isEmpty) {
        throw Exception('Task ID cannot be empty');
      }
      if (cancelledById.isEmpty) {
        throw Exception('Cancelled by ID cannot be empty');
      }

      // Use the database function to cancel negotiation
      final result = await _client.rpc('cancel_cost_negotiation', params: {
        'p_task_id': taskId,
        'p_cancelled_by': cancelledBy,
        'p_cancelled_by_id': cancelledById,
      });

      debugPrint('RPC result: $result');

      if (result == null || result == false) {
        throw Exception('Failed to cancel cost negotiation');
      }

      debugPrint('Cost negotiation cancelled successfully');
      return true;
    } catch (e) {
      debugPrint('Error in cancelCostNegotiation: $e');
      throw Exception(
          'Failed to cancel cost negotiation for task $taskId. Error: $e');
    }
  }

  // =====================================================
  // REAL-TIME STREAMS
  // =====================================================

  /// Stream for available tasks updates (includes all negotiable statuses)
  Stream<List<Task>> onAvailableTasksChanged() {
    return _client.from('tasks').stream(primaryKey: ['id']).map((rows) => rows
        .where((e) => [
              'pending',
              'cost_review',
              'cost_proposed',
              'user_counter_proposed',
              'delivery_counter_proposed'
            ].contains(e['status']))
        .map((e) => Task.fromMap(e))
        .toList());
  }

  /// Stream for assigned tasks updates (includes all active statuses)
  Stream<List<Task>> onAssignedTasksChanged(String deliveryPersonId) {
    return _client.from('tasks').stream(primaryKey: ['id']).map((rows) => rows
        .where((e) =>
            e['delivery_man_id'] == deliveryPersonId &&
            [
              'assigned',
              'cost_review',
              'cost_proposed',
              'user_counter_proposed',
              'delivery_counter_proposed'
            ].contains(e['status']))
        .map((e) => Task.fromMap(e))
        .toList());
  }

  /// Add a note to a specific location in a task
  Future<bool> addLocationNote({
    required String taskId,
    required int locationIndex,
    required String note,
  }) async {
    try {
      debugPrint('IntegratedTaskDeliveryService: Adding location note');
      debugPrint('Task ID: $taskId');
      debugPrint('Location Index: $locationIndex');
      debugPrint('Note: $note');

      // Validate inputs
      if (taskId.isEmpty) {
        throw Exception('Task ID cannot be empty');
      }
      if (note.isEmpty) {
        throw Exception('Note cannot be empty');
      }

      // Update the task with location note
      final result = await _client
          .from('tasks')
          .update({
            'location_notes': {
              'location_$locationIndex': note,
              'updated_at': DateTime.now().toIso8601String(),
            },
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', taskId)
          .select('id');

      if (result.isEmpty) {
        throw Exception('Failed to add location note');
      }

      debugPrint('Location note added successfully');
      return true;
    } catch (e) {
      debugPrint('Error in addLocationNote: $e');
      throw Exception(
          'Failed to add location note for task $taskId. Error: $e');
    }
  }

  /// Mark a specific location as completed in a task
  Future<bool> markLocationAsCompleted({
    required String taskId,
    required int locationIndex,
  }) async {
    try {
      debugPrint(
          'IntegratedTaskDeliveryService: Marking location as completed');
      debugPrint('Task ID: $taskId');
      debugPrint('Location Index: $locationIndex');

      // Validate inputs
      if (taskId.isEmpty) {
        throw Exception('Task ID cannot be empty');
      }

      // Get current location completions
      final taskRes = await _client
          .from('tasks')
          .select('location_completions')
          .eq('id', taskId)
          .single();

      List<int> completions = [];
      if (taskRes['location_completions'] != null) {
        completions = List<int>.from(taskRes['location_completions']);
      }

      // Add the location index if not already completed
      if (!completions.contains(locationIndex)) {
        completions.add(locationIndex);
      }

      // Update the task with completed locations
      final result = await _client
          .from('tasks')
          .update({
            'location_completions': completions,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', taskId)
          .select('id');

      if (result.isEmpty) {
        throw Exception('Failed to mark location as completed');
      }

      debugPrint('Location marked as completed successfully');
      return true;
    } catch (e) {
      debugPrint('Error in markLocationAsCompleted: $e');
      throw Exception(
          'Failed to mark location as completed for task $taskId. Error: $e');
    }
  }

  /// Get a task by ID
  Future<Task?> getTaskById(String taskId) async {
    try {
      final res = await _client
          .from('v_user_tasks_with_delivery_info')
          .select('*')
          .eq('id', taskId)
          .single();

      return Task.fromMap(res);
    } catch (e) {
      debugPrint('Error getting task by ID: $e');
      return null;
    }
  }
}
