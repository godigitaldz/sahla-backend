import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../services/integrated_task_delivery_service.dart';

/// Comprehensive task management widget system for IntegratedTaskDeliveryService
///
/// This widget provides a complete interface for managing Ifrili tasks including:
/// - Task listing and filtering
/// - Cost negotiation
/// - Task assignment and completion
/// - Performance monitoring
/// - Error handling
class TaskManagementWidget extends StatefulWidget {
  final String? deliveryPersonId;
  final TaskManagementMode mode;
  final Function(Task)? onTaskSelected;
  final Function(Task)? onTaskCompleted;
  final Function(String)? onError;

  const TaskManagementWidget({
    super.key,
    this.deliveryPersonId,
    this.mode = TaskManagementMode.available,
    this.onTaskSelected,
    this.onTaskCompleted,
    this.onError,
  });

  @override
  State<TaskManagementWidget> createState() => _TaskManagementWidgetState();
}

class _TaskManagementWidgetState extends State<TaskManagementWidget> {
  final IntegratedTaskDeliveryService _service =
      IntegratedTaskDeliveryService.instance;
  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<Task> tasks = [];

      switch (widget.mode) {
        case TaskManagementMode.available:
          tasks = await _service.getAvailableTasksForDelivery();
          break;
        case TaskManagementMode.assigned:
          if (widget.deliveryPersonId != null) {
            tasks = await _service
                .getAssignedTasksForDeliveryPerson(widget.deliveryPersonId!);
          }
          break;
        case TaskManagementMode.completed:
          if (widget.deliveryPersonId != null) {
            tasks = await _service
                .getCompletedTasksForDelivery(widget.deliveryPersonId!);
          }
          break;
        case TaskManagementMode.costReview:
          if (widget.deliveryPersonId != null) {
            tasks = await _service
                .getCostReviewTasksForDelivery(widget.deliveryPersonId!);
          }
          break;
        case TaskManagementMode.costProposed:
          tasks = await _service.getCostProposedTasksForDelivery();
          break;
        case TaskManagementMode.userCounterProposed:
          tasks = await _service.getUserCounterProposedTasksForDelivery();
          break;
      }

      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      widget.onError?.call(_error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          _buildErrorWidget()
        else
          _buildTasksList(),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _getModeTitle(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadTasks,
            ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showServiceHealth,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Error loading tasks',
                  style: TextStyle(
                    color: Colors.red.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Colors.red.shade700),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loadTasks,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksList() {
    if (_tasks.isEmpty) {
      return _buildEmptyState();
    }

    // PERFORMANCE FIX: Removed shrinkWrap ListView, using Column instead
    // This eliminates O(N) layout calculations on every frame
    // For small lists (<50 items), Column is much more efficient than shrinkWrap ListView
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        _tasks.length,
        (index) {
          final task = _tasks[index];
          return TaskCard(
            task: task,
            mode: widget.mode,
            deliveryPersonId: widget.deliveryPersonId,
            onTaskSelected: widget.onTaskSelected,
            onTaskCompleted: widget.onTaskCompleted,
            onError: widget.onError,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No ${_getModeTitle().toLowerCase()}',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getEmptyStateMessage(),
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getModeTitle() {
    switch (widget.mode) {
      case TaskManagementMode.available:
        return 'Available Tasks';
      case TaskManagementMode.assigned:
        return 'My Tasks';
      case TaskManagementMode.completed:
        return 'Completed Tasks';
      case TaskManagementMode.costReview:
        return 'Cost Review Tasks';
      case TaskManagementMode.costProposed:
        return 'Cost Proposed Tasks';
      case TaskManagementMode.userCounterProposed:
        return 'User Counter Proposed Tasks';
    }
  }

  String _getEmptyStateMessage() {
    switch (widget.mode) {
      case TaskManagementMode.available:
        return 'No tasks are currently available for delivery. Check back later!';
      case TaskManagementMode.assigned:
        return 'You don\'t have any assigned tasks at the moment.';
      case TaskManagementMode.completed:
        return 'You haven\'t completed any tasks yet.';
      case TaskManagementMode.costReview:
        return 'No tasks are currently under cost review.';
      case TaskManagementMode.costProposed:
        return 'No tasks have cost proposals pending.';
      case TaskManagementMode.userCounterProposed:
        return 'No tasks have user counter proposals.';
    }
  }

  void _showServiceHealth() {
    final health = _service.getServiceHealth();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Service Health'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Service: ${health['service']}'),
              Text('Status: ${health['status']}'),
              Text('Last Checked: ${health['lastChecked']}'),
              const SizedBox(height: 16),
              const Text('Performance Stats:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...health['performance']
                  .entries
                  .map((e) => Text('${e.key}: ${e.value}')),
              const SizedBox(height: 16),
              const Text('Error Stats:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...health['errors']
                  .entries
                  .map((e) => Text('${e.key}: ${e.value}')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Individual task card widget
class TaskCard extends StatelessWidget {
  final Task task;
  final TaskManagementMode mode;
  final String? deliveryPersonId;
  final Function(Task)? onTaskSelected;
  final Function(Task)? onTaskCompleted;
  final Function(String)? onError;

  const TaskCard({
    required this.task,
    required this.mode,
    super.key,
    this.deliveryPersonId,
    this.onTaskSelected,
    this.onTaskCompleted,
    this.onError,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(),
          child: Icon(
            _getStatusIcon(),
            color: Colors.white,
          ),
        ),
        title: Text(
          task.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location: ${task.locationName}'),
            Text('Status: ${task.status}'),
            if (task.acceptedCost != null)
              Text('Price: ${task.acceptedCost!.toStringAsFixed(2)} DZD'),
          ],
        ),
        trailing: _buildActionButton(),
        onTap: () => onTaskSelected?.call(task),
      ),
    );
  }

  Widget? _buildActionButton() {
    switch (mode) {
      case TaskManagementMode.available:
        return ElevatedButton(
          onPressed: () => _acceptTask(),
          child: const Text('Accept'),
        );
      case TaskManagementMode.assigned:
        return ElevatedButton(
          onPressed: () => _completeTask(),
          child: const Text('Complete'),
        );
      case TaskManagementMode.costReview:
        return ElevatedButton(
          onPressed: () => _proposeCost(),
          child: const Text('Propose Cost'),
        );
      case TaskManagementMode.costProposed:
        return ElevatedButton(
          onPressed: () => _acceptCost(),
          child: const Text('Accept Cost'),
        );
      case TaskManagementMode.userCounterProposed:
        return ElevatedButton(
          onPressed: () => _acceptCounterOffer(),
          child: const Text('Accept'),
        );
      case TaskManagementMode.completed:
        return null;
    }
  }

  Color _getStatusColor() {
    switch (task.status) {
      case TaskStatus.pending:
        return Colors.orange;
      case TaskStatus.assigned:
        return Colors.blue;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.costReview:
        return Colors.purple;
      case TaskStatus.costProposed:
        return Colors.teal;
      case TaskStatus.userCounterProposed:
        return Colors.amber;
      case TaskStatus.costAccepted:
        return Colors.green;
      case TaskStatus.deliveryCounterProposed:
        return Colors.cyan;
      case TaskStatus.negotiationFinalized:
        return Colors.indigo;
      case TaskStatus.scheduled:
        return Colors.blue;
      case TaskStatus.expired:
        return Colors.red;
    }
  }

  IconData _getStatusIcon() {
    switch (task.status) {
      case TaskStatus.pending:
        return Icons.schedule;
      case TaskStatus.assigned:
        return Icons.assignment;
      case TaskStatus.completed:
        return Icons.check_circle;
      case TaskStatus.costReview:
        return Icons.monetization_on;
      case TaskStatus.costProposed:
        return Icons.price_check;
      case TaskStatus.userCounterProposed:
        return Icons.handshake;
      case TaskStatus.costAccepted:
        return Icons.check_circle_outline;
      case TaskStatus.deliveryCounterProposed:
        return Icons.swap_horiz;
      case TaskStatus.negotiationFinalized:
        return Icons.gavel;
      case TaskStatus.scheduled:
        return Icons.schedule;
      case TaskStatus.expired:
        return Icons.access_time;
    }
  }

  Future<void> _acceptTask() async {
    if (deliveryPersonId == null) return;

    try {
      await IntegratedTaskDeliveryService.instance.acceptTaskForDelivery(
        taskId: task.id,
        deliveryPersonId: deliveryPersonId!,
      );
      onTaskCompleted?.call(task);
    } catch (e) {
      onError?.call(e.toString());
    }
  }

  Future<void> _completeTask() async {
    if (deliveryPersonId == null) return;

    try {
      await IntegratedTaskDeliveryService.instance.completeTaskForDelivery(
        taskId: task.id,
        deliveryPersonId: deliveryPersonId!,
      );
      onTaskCompleted?.call(task);
    } catch (e) {
      onError?.call(e.toString());
    }
  }

  Future<void> _proposeCost() async {
    // This would typically open a dialog for cost input
    // For now, just show a placeholder
    onError?.call('Cost proposal dialog not implemented');
  }

  Future<void> _acceptCost() async {
    // This would typically show cost details and allow acceptance
    onError?.call('Cost acceptance dialog not implemented');
  }

  Future<void> _acceptCounterOffer() async {
    if (deliveryPersonId == null) return;

    try {
      await IntegratedTaskDeliveryService.instance.acceptUserCounterOffer(
        taskId: task.id,
        deliveryPersonId: deliveryPersonId!,
      );
      onTaskCompleted?.call(task);
    } catch (e) {
      onError?.call(e.toString());
    }
  }
}

/// Task management mode enum
enum TaskManagementMode {
  available,
  assigned,
  completed,
  costReview,
  costProposed,
  userCounterProposed,
}

/// Task management wrapper widget for easy integration
class TaskManagementWrapper extends StatelessWidget {
  final String? deliveryPersonId;
  final Widget child;

  const TaskManagementWrapper({
    required this.child,
    super.key,
    this.deliveryPersonId,
  });

  @override
  Widget build(BuildContext context) {
    return Provider<IntegratedTaskDeliveryService>(
      create: (_) => IntegratedTaskDeliveryService.instance,
      child: child,
    );
  }
}
