import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';
import 'integrated_task_delivery_service.dart';

class TaskService {
  TaskService._();
  static final TaskService instance = TaskService._();

  SupabaseClient get _client => Supabase.instance.client;

  static const String _table = 'tasks';

  Future<Task> createTask(Task task) async {
    final res =
        await _client.from(_table).insert(task.toInsertMap()).select().single();
    return Task.fromMap(res);
  }

  Future<List<Task>> createTasks(List<Task> tasks) async {
    final rows = tasks.map((t) => t.toInsertMap()).toList();
    final res = await _client.from(_table).insert(rows).select();
    return (res as List)
        .map((e) => Task.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Task>> getMyTasks({String? status}) async {
    var query = _client.from('v_user_tasks_with_delivery_info').select();
    if (status != null) {
      query = query.eq('status', status);
    }
    final res = await query.order('scheduled_at', ascending: true);
    return (res as List)
        .map((e) => Task.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Task>> getAssignedTasks() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final res = await _client
        .from(_table)
        .select()
        .eq('delivery_man_id', userId)
        .order('scheduled_at', ascending: true);
    return (res as List)
        .map((e) => Task.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<Task> updateTask(String id, Map<String, dynamic> data) async {
    final res =
        await _client.from(_table).update(data).eq('id', id).select().single();
    return Task.fromMap(res);
  }

  Future<void> deleteTask(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }

  Stream<Task> onTaskChanged(String id) {
    return _client
        .from('v_user_tasks_with_delivery_info')
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .map((rows) => rows.isNotEmpty
            ? Task.fromMap(rows.first)
            : throw StateError('Task not found'));
  }

  Stream<List<Task>> onMyTasksChanged() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const Stream<List<Task>>.empty();
    }
    return _client
        .from('v_user_tasks_with_delivery_info')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('scheduled_at', ascending: true)
        .map((rows) => rows.map((e) => Task.fromMap(e)).toList());
  }

  // =====================================================
  // COST NEGOTIATION METHODS
  // =====================================================

  /// Accept proposed cost for a task
  Future<Task> acceptProposedCost(String taskId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    try {
      // Use the integrated service for proper multi-cost proposal handling
      await IntegratedTaskDeliveryService.instance.acceptProposedCost(
        taskId: taskId,
        userId: userId,
      );

      // Get the updated task
      final res = await _client
          .from(_table)
          .select()
          .eq('id', taskId)
          .eq('user_id', userId)
          .single();

      return Task.fromMap(res);
    } catch (e) {
      throw Exception('Failed to accept cost proposal: $e');
    }
  }

  /// Accept a specific cost proposal
  Future<Task> acceptSpecificCostProposal(
      String taskId, String proposalId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final result = await _client.rpc('accept_cost_proposal', params: {
      'task_id': taskId,
      'proposal_id': proposalId,
      'user_id': userId,
    });

    if (result == null || result == false) {
      throw Exception('Failed to accept cost proposal');
    }

    // Get the updated task
    final res = await _client
        .from(_table)
        .select()
        .eq('id', taskId)
        .eq('user_id', userId)
        .single();

    return Task.fromMap(res);
  }

  /// Get all cost proposals for a task
  Future<List<Map<String, dynamic>>> getTaskCostProposals(String taskId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

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
  }

  /// Reject proposed cost for a task
  Future<Task> rejectProposedCost(String taskId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final result = await _client.rpc('reject_all_cost_proposals', params: {
      'task_id': taskId,
      'user_id': userId,
    });

    if (result == null || result == false) {
      throw Exception('Failed to reject cost proposals');
    }

    // Get the updated task
    final res = await _client
        .from(_table)
        .select()
        .eq('id', taskId)
        .eq('user_id', userId)
        .single();

    return Task.fromMap(res);
  }
}
