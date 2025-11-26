import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/task.dart';
import '../services/task_service.dart';
import '../widgets/app_header.dart';
import 'create_task_screen.dart';
import 'task_details_screen.dart';

class MyTasksScreen extends StatefulWidget {
  final bool showHeader;
  const MyTasksScreen({super.key, this.showHeader = true});

  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen> {
  List<Task> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    TaskService.instance.onMyTasksChanged().listen((_) => _load());
  }

  Future<void> _load() async {
    try {
      final tasks = await TaskService.instance.getMyTasks();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = _tasks
        .where((t) =>
            t.status == TaskStatus.scheduled &&
            (t.scheduledAt?.isAfter(DateTime.now()) ?? false))
        .toList();
    final inProgress = _tasks
        .where((t) =>
            t.status == TaskStatus.assigned ||
            t.status == TaskStatus.pending ||
            t.status == TaskStatus.costReview ||
            t.status == TaskStatus.costProposed ||
            t.status == TaskStatus.costAccepted ||
            t.status == TaskStatus.userCounterProposed ||
            t.status == TaskStatus.deliveryCounterProposed ||
            t.status == TaskStatus.negotiationFinalized)
        .toList();
    final completed =
        _tasks.where((t) => t.status == TaskStatus.completed).toList();
    final expired = _tasks
        .where((t) =>
            (t.scheduledAt != null) &&
            t.scheduledAt!.isBefore(DateTime.now()) &&
            t.status != TaskStatus.completed)
        .toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFd47b00),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateTaskScreen()),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Builder(builder: (context) {
                final hasAny = upcoming.isNotEmpty ||
                    inProgress.isNotEmpty ||
                    completed.isNotEmpty ||
                    expired.isNotEmpty;
                if (!hasAny) {
                  // PERFORMANCE FIX: Convert ListView(children) to ListView.builder for consistency
                  final emptyStateChildren = [
                    if (widget.showHeader)
                      const SafeArea(
                          bottom: false, child: AppHeader(title: 'My Tasks')),
                    if (widget.showHeader) const SizedBox(height: 16),
                    Center(
                      child: Icon(Icons.assignment_outlined,
                          size: 72, color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text('No tasks yet',
                          style: GoogleFonts.poppins(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                          'Create your first Ifrili task to get started',
                          style: GoogleFonts.inter(color: Colors.grey[600])),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFd47b00),
                        foregroundColor: Colors.white,
                        elevation: 10,
                        shadowColor:
                            const Color(0xFFd47b00).withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25.5)),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const CreateTaskScreen()),
                        );
                      },
                      icon: const Icon(Icons.add_task),
                      label: Text('Create Ifrili Task',
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                    ),
                  ];

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: emptyStateChildren.length,
                    itemBuilder: (context, index) => emptyStateChildren[index],
                  );
                }
                // PERFORMANCE FIX: Convert ListView(children) to ListView.builder for virtualization
                // This prevents building all items upfront and enables lazy loading
                // For small lists (<50 items), this still provides better memory efficiency
                final allSections = [
                  if (widget.showHeader)
                    const SafeArea(
                        bottom: false, child: AppHeader(title: 'My Tasks')),
                  if (widget.showHeader) const SizedBox(height: 12),
                  _section('Upcoming', upcoming),
                  _section('In Progress', inProgress),
                  _section('Completed', completed),
                  _section('Expired', expired),
                ];

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: allSections.length,
                  itemBuilder: (context, index) => allSections[index],
                );
              }),
            ),
    );
  }

  Widget _section(String title, List<Task> tasks) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
                GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...tasks.map(_taskCard),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _taskCard(Task t) {
    final startsIn =
        (t.scheduledAt != null && t.scheduledAt!.isAfter(DateTime.now()))
            ? t.scheduledAt!.difference(DateTime.now())
            : null;
    final startsLabel = startsIn != null
        ? 'Starts in ${startsIn.inHours}h ${startsIn.inMinutes % 60}m'
        : null;
    const staticPreview = SizedBox(
      width: 60,
      height: 60,
      child: ClipOval(
        child: Image(
          image: AssetImage('assets/icon/app_icon.png'),
          width: 60,
          height: 60,
          fit: BoxFit.cover,
        ),
      ),
    );
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: staticPreview,
        title: Text('Task #${t.id.substring(0, 8).toUpperCase()}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // Delivery man info if assigned
            if (t.status == TaskStatus.assigned &&
                t.deliveryManName != null) ...[
              Text('Delivery Man: ${t.deliveryManName}',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.blue[600])),
              if (t.deliveryManPhone != null)
                Text('Phone: ${t.deliveryManPhone}',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey[600])),
              const SizedBox(height: 8),
            ],
            // Task real-time status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(t.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _getStatusColor(t.status).withValues(alpha: 0.3)),
              ),
              child: Text(
                _getStatusText(t.status),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _getStatusColor(t.status),
                ),
              ),
            ),
            if (t.scheduledAt != null) ...[
              const SizedBox(height: 8),
              Text(
                  'Scheduled: ${t.scheduledAt!.toLocal().toString().split('.')[0]}',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey[600])),
            ],
            if (startsLabel != null) ...[
              const SizedBox(height: 4),
              Text(startsLabel,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.orange[600])),
            ],
            const SizedBox(height: 8),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TaskDetailsScreen(taskId: t.id)),
          );
        },
      ),
    );
  }

  String _getStatusText(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return 'Pending';
      case TaskStatus.costReview:
        return 'Cost Review';
      case TaskStatus.costProposed:
        return 'Cost Proposed';
      case TaskStatus.costAccepted:
        return 'Cost Accepted';
      case TaskStatus.userCounterProposed:
        return 'Waiting User Response';
      case TaskStatus.deliveryCounterProposed:
        return 'Delivery Counter';
      case TaskStatus.negotiationFinalized:
        return 'Negotiation Finalized';
      case TaskStatus.assigned:
        return 'Assigned';
      case TaskStatus.completed:
        return 'Completed';
      case TaskStatus.scheduled:
        return 'Scheduled';
      case TaskStatus.expired:
        return 'Expired';
    }
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return Colors.orange;
      case TaskStatus.costReview:
        return Colors.blue;
      case TaskStatus.costProposed:
        return Colors.purple;
      case TaskStatus.costAccepted:
        return Colors.green;
      case TaskStatus.userCounterProposed:
        return Colors.amber;
      case TaskStatus.deliveryCounterProposed:
        return Colors.indigo;
      case TaskStatus.negotiationFinalized:
        return Colors.teal;
      case TaskStatus.assigned:
        return Colors.green;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.scheduled:
        return Colors.blue;
      case TaskStatus.expired:
        return Colors.red;
    }
  }
}
