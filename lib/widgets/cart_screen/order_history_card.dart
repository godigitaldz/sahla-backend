import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../models/task.dart';
import '../../screens/real_time_order_tracking_screen.dart';
import '../../screens/task_details_screen.dart';
import '../../services/enhanced_order_tracking_service.dart';
import '../../services/order_service.dart';
import '../../services/refresh_manager.dart';
import '../../services/task_service.dart';
import '../../utils/price_formatter.dart';

class OrderHistoryCard extends StatefulWidget {
  final Order order;
  final Future<void> Function()? onUpdated;

  const OrderHistoryCard({required this.order, super.key, this.onUpdated});

  @override
  State<OrderHistoryCard> createState() => _OrderHistoryCardState();
}

class _OrderHistoryCardState extends State<OrderHistoryCard> {
  List<Task> _activeTasks = [];

  // Real-time subscriptions
  RealtimeChannel? _orderChannel;
  StreamSubscription? _orderStatusSubscription;
  StreamSubscription? _deliveryLocationSubscription;
  StreamSubscription? _refreshSubscription;

  @override
  void initState() {
    super.initState();
    _loadActiveTasks();
    _initializeRealtimeSubscriptions();
    _setupRefreshManager();
  }

  /// Initialize real-time subscriptions for order updates
  void _initializeRealtimeSubscriptions() {
    _subscribeToOrderUpdates();
    _subscribeToTaskUpdates();
  }

  /// Subscribe to order status updates via Supabase realtime
  void _subscribeToOrderUpdates() {
    try {
      _orderChannel?.unsubscribe();
      final client = Supabase.instance.client;
      _orderChannel = client
          .channel('realtime:orders:${widget.order.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'orders',
            callback: (payload) async {
              // Check if this update is for our specific order
              final newRecord = payload.newRecord;
              final oldRecord = payload.oldRecord;

              final recordId = (newRecord['id'] ?? oldRecord['id']) as String?;

              if (recordId == widget.order.id) {
                if (!mounted) return;
                debugPrint(
                    '🔄 Order ${widget.order.id} status updated via realtime');
                await _refreshOrderData();
              }
            },
          )..subscribe();
    } catch (e) {
      debugPrint('❌ Error subscribing to order updates: $e');
    }
  }

  /// Subscribe to enhanced order tracking updates
  void _subscribeToTaskUpdates() {
    try {
      final enhancedTrackingService =
          Provider.of<EnhancedOrderTrackingService>(context, listen: false);

      _orderStatusSubscription?.cancel();
      _deliveryLocationSubscription?.cancel();

      _orderStatusSubscription =
          enhancedTrackingService.deliveryStatusStream.listen((data) {
        if (!mounted) return;
        final orderId = data['orderId'] as String?;
        if (orderId == widget.order.id) {
          debugPrint(
              '🔄 Order ${widget.order.id} status updated via enhanced tracking');
          _refreshOrderData();
        }
      });

      _deliveryLocationSubscription =
          enhancedTrackingService.deliveryLocationStream.listen((data) {
        if (!mounted) return;
        final orderId = data['orderId'] as String?;
        if (orderId == widget.order.id) {
          debugPrint('📍 Order ${widget.order.id} location updated');
          setState(() {}); // Trigger UI refresh for location updates
        }
      });
    } catch (e) {
      debugPrint('❌ Error subscribing to enhanced tracking: $e');
    }
  }

  /// Setup refresh manager for this order card
  void _setupRefreshManager() {
    final componentId = 'order_history_card_${widget.order.id}';

    // Register with refresh manager
    RefreshManager().registerComponent(
      componentId,
      refreshInterval: const Duration(minutes: 2),
    );

    // Listen to refresh events
    _refreshSubscription = RefreshManager().listenToRefresh(
      componentId,
      () async {
        if (!mounted) return;

        // Only refresh if order is still active (not delivered/cancelled)
        if (widget.order.status != OrderStatus.delivered &&
            widget.order.status != OrderStatus.cancelled) {
          debugPrint(
              '🔄 OrderHistoryCard: Refresh triggered for order ${widget.order.id}');
          await _refreshOrderData();
        } else {
          debugPrint(
              '⏸️ OrderHistoryCard: Skipping refresh for completed order ${widget.order.id}');
          // Stop refresh for completed orders
          RefreshManager().stopRefresh(componentId);
        }
      },
    );
  }

  /// Refresh all order-related data
  Future<void> _refreshOrderData() async {
    await _loadActiveTasks();
    if (widget.onUpdated != null) {
      await widget.onUpdated!();
    }
  }

  Future<void> _loadActiveTasks() async {
    try {
      final taskService = TaskService.instance;

      // Get both assigned and pending tasks
      final assignedTasks = await taskService.getMyTasks(status: 'assigned');
      final pendingTasks = await taskService.getMyTasks(status: 'pending');

      // Combine and sort by creation date
      final allTasks = [...assignedTasks, ...pendingTasks];
      allTasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() => _activeTasks = allTasks);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _activeTasks = []);
      }
    }
  }

  @override
  void dispose() {
    _orderChannel?.unsubscribe();
    _orderStatusSubscription?.cancel();
    _deliveryLocationSubscription?.cancel();
    _refreshSubscription?.cancel();
    RefreshManager().stopRefresh('order_history_card_${widget.order.id}');
    super.dispose();
  }

  /// Check if order can be tracked
  bool _canTrackOrder() {
    return widget.order.status != OrderStatus.delivered &&
        widget.order.status != OrderStatus.cancelled;
  }

  /// Navigate to order tracking screen
  void _trackOrder(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RealTimeOrderTrackingScreen(order: widget.order),
      ),
    );
  }

  /// Check if reception can be confirmed
  bool _canConfirmReception() {
    return widget.order.status != OrderStatus.delivered &&
        widget.order.status != OrderStatus.cancelled;
  }

  /// Confirm order reception with dynamic status handling
  Future<void> _confirmReception(BuildContext context) async {
    try {
      final orderService = Provider.of<OrderService>(context, listen: false);
      final success = await orderService.updateOrderStatus(
        orderId: widget.order.id,
        status: OrderStatus.delivered,
        notes: 'Customer confirmed reception',
      );

      if (success) {
        if (context.mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.receptionConfirmed)),
          );
        }
        if (widget.onUpdated != null) {
          await widget.onUpdated!();
        }
      } else {
        if (context.mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.failedToConfirmReception)),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.failedToConfirm}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Header with order info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFd47b00),
                  const Color(0xFFd47b00).withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: isRTL
                ? Row(
                    children: [
                      // For RTL: Status badge first (right side)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _formatStatusLocalized(
                              widget.order.status.toString().split('.').last,
                              l10n),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Order info in the middle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${l10n.orderNumber}${widget.order.orderNumber}',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.right,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(widget.order.createdAt, l10n),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      // For LTR: Original layout (order info, status badge)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${l10n.orderNumber}${widget.order.orderNumber}',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.left,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(widget.order.createdAt, l10n),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _formatStatusLocalized(
                              widget.order.status.toString().split('.').last,
                              l10n),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Restaurant info
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[200],
                      ),
                      child: Icon(Icons.restaurant, color: Colors.grey[400]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: isRTL
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.order.restaurant?.name ?? l10n.restaurant,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            textAlign: isRTL ? TextAlign.right : TextAlign.left,
                          ),
                          Text(
                            '${widget.order.orderItems?.length ?? 0} ${(widget.order.orderItems?.length ?? 0) == 1 ? l10n.item : l10n.items}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            textAlign: isRTL ? TextAlign.right : TextAlign.left,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Expandable items summary
                _HistoryExpandableOrderSummary(
                    order: widget.order, l10n: l10n, isRTL: isRTL),
                const SizedBox(height: 16),

                // Order total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.total,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      textAlign: isRTL ? TextAlign.right : TextAlign.left,
                    ),
                    Text(
                      PriceFormatter.formatWithSettings(
                          context, widget.order.totalAmount.toString()),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFd47b00),
                      ),
                      textAlign: isRTL ? TextAlign.left : TextAlign.right,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Action buttons - dynamic based on current order status
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _canTrackOrder()
                            ? () => _trackOrder(context)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFd47b00),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            l10n.trackOrder,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _canConfirmReception()
                            ? () => _confirmReception(context)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFd47b00),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _getConfirmButtonText(l10n),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Active Tasks Section
                if (_activeTasks.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildActiveTasksSection(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatStatusLocalized(String status, AppLocalizations l10n) {
    switch (status.toLowerCase()) {
      case 'pending':
        return l10n.placed;
      case 'confirmed':
        return l10n.placed;
      case 'preparing':
        return l10n.preparing;
      case 'ready':
        return l10n.preparing;
      case 'out_for_delivery':
        return l10n.pickedUp;
      case 'delivered':
        return l10n.delivered;
      case 'cancelled':
        return l10n.delivered;
      default:
        return status;
    }
  }

  String _getConfirmButtonText(AppLocalizations l10n) {
    return l10n.confirmReception;
  }

  String _formatDate(DateTime date, AppLocalizations l10n) {
    return '${l10n.dateAt} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} ${date.day}/${date.month}/${date.year}';
  }

  Widget _buildActiveTasksSection() {
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFd47b00),
                  const Color(0xFFd47b00).withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.assignment, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.tasksAndOrders,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: isRTL ? TextAlign.right : TextAlign.left,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_activeTasks.length} ${l10n.active}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: isRTL ? TextAlign.right : TextAlign.left,
                  ),
                ),
              ],
            ),
          ),

          // Tasks List
          Column(
            children: _activeTasks.map((task) => _buildTaskItem(task)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(Task task) {
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaskDetailsScreen(taskId: task.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task description and status
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.description,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: isRTL ? TextAlign.right : TextAlign.left,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFd47b00).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatTaskStatus(task.status),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFd47b00),
                    ),
                    textAlign: isRTL ? TextAlign.right : TextAlign.left,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Location info
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[200],
                  ),
                  child: Icon(Icons.location_on,
                      color: Colors.grey[400], size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.locationName,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: isRTL ? TextAlign.right : TextAlign.left,
                      ),
                      if (task.locationPurpose != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          task.locationPurpose!,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Scheduled time
            if (task.scheduledAt != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Scheduled: ${_formatTaskDate(task.scheduledAt!)}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTaskStatus(TaskStatus status) {
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
        return 'User Counter';
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

  String _formatTaskDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _HistoryExpandableOrderSummary extends StatefulWidget {
  final Order order;
  final AppLocalizations l10n;
  final bool isRTL;

  const _HistoryExpandableOrderSummary({
    required this.order,
    required this.l10n,
    required this.isRTL,
  });

  @override
  State<_HistoryExpandableOrderSummary> createState() =>
      _HistoryExpandableOrderSummaryState();
}

class _HistoryExpandableOrderSummaryState
    extends State<_HistoryExpandableOrderSummary> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final isRTL = widget.isRTL;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => isExpanded = !isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long,
                      color: Color(0xFFfc9d2d), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.orderSummary,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2E2E2E),
                      ),
                      textAlign: isRTL ? TextAlign.right : TextAlign.left,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.order.orderItems?.length ?? 0} ${(widget.order.orderItems?.length ?? 0) == 1 ? l10n.item : l10n.items}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey[600], size: 20),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, thickness: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.order.orderItems != null &&
                      widget.order.orderItems!.isNotEmpty) ...[
                    ...widget.order.orderItems!
                        .map((item) => _HistoryOrderItemCard(item: item)),
                  ] else ...[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          l10n.noItemsInOrder,
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: Colors.grey[500]),
                          textAlign: isRTL ? TextAlign.right : TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    PriceFormatter.formatWithSettings(
                        context, widget.order.totalAmount.toString()),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFfc9d2d),
                    ),
                  ),
                  Text(
                    '${widget.order.createdAt.day}/${widget.order.createdAt.month}/${widget.order.createdAt.year}',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryOrderItemCard extends StatelessWidget {
  final OrderItem item;
  const _HistoryOrderItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with name and total price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.menuItem?.name ?? 'Unknown Item',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: isRTL ? TextAlign.right : TextAlign.left,
                ),
              ),
              Text(
                PriceFormatter.formatWithSettings(
                    context, item.totalPrice.toString()),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFfc9d2d),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Quantity and unit price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${l10n.quantity} ${item.quantity}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: isRTL ? TextAlign.right : TextAlign.left,
              ),
              Text(
                '${l10n.unitPrice} ${PriceFormatter.formatWithSettings(context, item.unitPrice.toString())}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: isRTL ? TextAlign.left : TextAlign.right,
              ),
            ],
          ),

          // Special instructions
          if (item.specialInstructions?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.specialInstructions,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                    textAlign: isRTL ? TextAlign.right : TextAlign.left,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.specialInstructions!,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.blue[600],
                    ),
                    textAlign: isRTL ? TextAlign.right : TextAlign.left,
                  ),
                ],
              ),
            ),
          ],

          // Customizations
          if (_hasItemCustomizations(item)) ...[
            const SizedBox(height: 8),
            _buildItemCustomizations(item),
          ],
        ],
      ),
    );
  }

  bool _hasItemCustomizations(OrderItem item) {
    return item.customizations != null && item.customizations!.isNotEmpty;
  }

  Widget _buildItemCustomizations(OrderItem item) {
    final customizations = item.customizations!;
    final List<Widget> customizationWidgets = [];

    // Variant
    final variant = customizations['variant'];
    if (variant != null) {
      if (variant is String && variant.isNotEmpty) {
        customizationWidgets.add(_buildCustomizationRow('Variant', variant));
      } else if (variant is Map<String, dynamic> && variant['name'] != null) {
        customizationWidgets
            .add(_buildCustomizationRow('Variant', variant['name']));
      }
    }

    // Size
    final size = customizations['size'];
    if (size != null && size is String && size.isNotEmpty) {
      customizationWidgets.add(_buildCustomizationRow('Size', size));
    }

    // Supplements
    final supplements = customizations['supplements'];
    if (supplements != null) {
      if (supplements is List && supplements.isNotEmpty) {
        final supplementNames = supplements
            .map((s) =>
                s is Map<String, dynamic> ? (s['name'] ?? '') : s.toString())
            .where((name) => name.isNotEmpty)
            .join(', ');
        if (supplementNames.isNotEmpty) {
          customizationWidgets
              .add(_buildCustomizationRow('Supplements', supplementNames));
        }
      }
    }

    // Drinks
    final drinks = customizations['drinks'];
    if (drinks != null) {
      if (drinks is List && drinks.isNotEmpty) {
        final drinkNames = drinks
            .map((d) =>
                d is Map<String, dynamic> ? (d['name'] ?? '') : d.toString())
            .where((name) => name.isNotEmpty)
            .join(', ');
        if (drinkNames.isNotEmpty) {
          customizationWidgets
              .add(_buildCustomizationRow('Drinks', drinkNames));
        }
      }
    }

    // Ingredient preferences
    final preferences = customizations['ingredient_preferences'];
    if (preferences != null && preferences is Map && preferences.isNotEmpty) {
      final preferenceTexts = preferences.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join(', ');
      customizationWidgets
          .add(_buildCustomizationRow('Ingredients', preferenceTexts));
    }

    if (customizationWidgets.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: customizationWidgets,
    );
  }

  Widget _buildCustomizationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
