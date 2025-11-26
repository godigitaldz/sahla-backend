// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/order.dart';
import '../../models/restaurant.dart';
import '../../services/auth_service.dart';
import '../../services/order_assignment_service.dart';
import '../../services/order_service.dart';
import '../../services/restaurant_service.dart';
import 'manage_orders_screen/manage_orders_header_widget.dart';
import 'manage_orders_screen/order_filter_bar_widget.dart';
import 'manage_orders_screen/order_list_section_widget.dart';

/// Manage Orders Screen
/// Dedicated screen for managing restaurant orders with filtering and actions
class ManageOrdersScreen extends StatefulWidget {
  const ManageOrdersScreen({super.key});

  @override
  State<ManageOrdersScreen> createState() => _ManageOrdersScreenState();
}

class _ManageOrdersScreenState extends State<ManageOrdersScreen> {
  bool _isLoading = true;
  List<Order> _orders = [];
  Restaurant? _restaurant;

  // Filter tab bar state
  String _activeFilter = 'pending'; // Default to pending orders

  // Refresh functionality
  DateTime? _lastRefreshTime;
  static const Duration _pullRefreshCooldown = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Load restaurant
      final restaurantService =
          Provider.of<RestaurantService>(context, listen: false);
      _restaurant =
          await restaurantService.getRestaurantByOwnerId(currentUser.id);

      if (_restaurant == null) {
        if (mounted) {
          setState(() {
            _orders = [];
            _isLoading = false;
          });
        }
        return;
      }

      // Load orders
      final orderService = Provider.of<OrderService>(context, listen: false);
      final restaurantOrders = await orderService.getRestaurantOrders(
        restaurantId: _restaurant!.id,
      );

      if (mounted) {
        setState(() {
          _orders = restaurantOrders ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load orders: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handlePullRefresh() async {
    final now = DateTime.now();
    if (_lastRefreshTime != null &&
        now.difference(_lastRefreshTime!) < _pullRefreshCooldown) {
      return;
    }

    await _loadOrders();
    _lastRefreshTime = DateTime.now();
  }

  // Filter count methods
  int _getPendingOrdersCount() {
    return _orders.where((order) => order.status == OrderStatus.pending).length;
  }

  int _getOnProcessOrdersCount() {
    return _orders
        .where((order) =>
            order.status == OrderStatus.preparing ||
            order.status == OrderStatus.ready ||
            order.status == OrderStatus.pickedUp)
        .length;
  }

  int _getCompletedOrdersCount() {
    return _orders
        .where((order) => order.status == OrderStatus.delivered)
        .length;
  }

  List<Order> _getFilteredOrders() {
    switch (_activeFilter) {
      case 'pending':
        return _orders
            .where((order) => order.status == OrderStatus.pending)
            .toList();
      case 'onProcess':
        return _orders
            .where((order) =>
                order.status == OrderStatus.preparing ||
                order.status == OrderStatus.ready ||
                order.status == OrderStatus.pickedUp)
            .toList();
      case 'completed':
        return _orders
            .where((order) => order.status == OrderStatus.delivered)
            .toList();
      default:
        return _orders;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: const ManageOrdersHeaderWidget(),
      body: RefreshIndicator(
        onRefresh: _handlePullRefresh,
        child: SingleChildScrollView(
          child: Column(
            children: [
              OrderFilterBarWidget(
                activeFilter: _activeFilter,
                onFilterChanged: (filter) {
                  setState(() {
                    _activeFilter = filter;
                  });
                },
                pendingCount: _getPendingOrdersCount(),
                onProcessCount: _getOnProcessOrdersCount(),
                completedCount: _getCompletedOrdersCount(),
              ),
              OrderListSectionWidget(
                isLoading: _isLoading,
                filteredOrders: _getFilteredOrders(),
                activeFilter: _activeFilter,
                actionButtonBuilder: (order) => _buildOrderActionButton(order),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderActionButton(Order order) {
    switch (order.status) {
      case OrderStatus.pending:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _confirmAndStartPrepOrder(order),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Accept & Start',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _showRejectOrderDialog(order),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Reject',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        );

      case OrderStatus.confirmed:
        return ElevatedButton(
          onPressed: () => _startPreparingOrder(order),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Start Prep',
            style:
                GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        );

      case OrderStatus.preparing:
        if (order.deliveryPersonId == null) {
          return ElevatedButton(
            onPressed: () => _broadcastOrderToDelivery(order),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Broadcast to Delivery',
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          );
        } else {
          return ElevatedButton(
            onPressed: () => _markOrderReady(order),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Mark Ready',
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }

      case OrderStatus.ready:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFd47b00).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFd47b00).withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            'Waiting for pickup',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFd47b00),
            ),
            textAlign: TextAlign.center,
          ),
        );

      case OrderStatus.pickedUp:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            'Out for delivery',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.blue[700],
            ),
            textAlign: TextAlign.center,
          ),
        );

      case OrderStatus.delivered:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFd47b00).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFd47b00).withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            'Delivered',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFd47b00),
            ),
            textAlign: TextAlign.center,
          ),
        );

      case OrderStatus.cancelled:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red[200]!),
          ),
          child: Text(
            'Cancelled',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.red[700],
            ),
            textAlign: TextAlign.center,
          ),
        );
    }
  }

  Future<void> _confirmAndStartPrepOrder(Order order) async {
    try {
      final orderService = Provider.of<OrderService>(context, listen: false);
      final currentOrder = await orderService.getOrderById(order.id);

      if (currentOrder == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Order #${order.orderNumber} is no longer available - it may have been cancelled.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.orange[600],
            ),
          );
          await _loadOrders();
        }
        return;
      }

      final success = await orderService.updateOrderStatus(
        orderId: order.id,
        status: OrderStatus.preparing,
        notes: 'Order confirmed and preparation started by restaurant',
      );

      if (success) {
        if (!mounted) return;
        await _assignDeliveryPerson(order);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order #${order.orderNumber} accepted and preparation started!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.orange[600],
          ),
        );
        await _loadOrders();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to accept order. Please try again.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error accepting order: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _assignDeliveryPerson(Order order) async {
    try {
      final orderAssignmentService = OrderAssignmentService();

      double restaurantLatitude = 0.0;
      double restaurantLongitude = 0.0;

      try {
        final restaurantService =
            Provider.of<RestaurantService>(context, listen: false);
        final currentUser =
            Provider.of<AuthService>(context, listen: false).currentUser;

        if (currentUser != null) {
          final restaurant =
              await restaurantService.getRestaurantByOwnerId(currentUser.id);
          if (restaurant != null &&
              restaurant.latitude != null &&
              restaurant.longitude != null) {
            restaurantLatitude = restaurant.latitude!;
            restaurantLongitude = restaurant.longitude!;
          } else {
            if (!mounted) return;
            final orderService =
                Provider.of<OrderService>(context, listen: false);
            final orderDetails = await orderService.getOrderById(order.id);
            if (orderDetails != null && orderDetails.restaurant != null) {
              final orderRestaurant = orderDetails.restaurant!;
              if (orderRestaurant.latitude != null &&
                  orderRestaurant.longitude != null) {
                restaurantLatitude = orderRestaurant.latitude!;
                restaurantLongitude = orderRestaurant.longitude!;
              }
            }
          }
        }

        if (restaurantLatitude == 0.0 && restaurantLongitude == 0.0) {
          if (order.deliveryAddress['latitude'] != null &&
              order.deliveryAddress['longitude'] != null) {
            restaurantLatitude = order.deliveryAddress['latitude'];
            restaurantLongitude = order.deliveryAddress['longitude'];
          }
        }
      } catch (e) {
        debugPrint('Could not get restaurant location: $e');
      }

      final broadcastSuccess =
          await orderAssignmentService.broadcastOrderToDeliveryPersonnel(
        orderId: order.id,
        restaurantLatitude:
            restaurantLatitude == 0.0 ? null : restaurantLatitude,
        restaurantLongitude:
            restaurantLongitude == 0.0 ? null : restaurantLongitude,
        radiusKm: restaurantLatitude == 0.0 && restaurantLongitude == 0.0
            ? double.infinity
            : 10.0,
      );

      if (broadcastSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order #${order.orderNumber} broadcast to delivery personnel!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: const Color(0xFFd47b00),
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order accepted but broadcasting failed. No delivery personnel available.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.amber[700],
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error in delivery assignment for order ${order.id}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order accepted but delivery assignment failed. Please try manual assignment.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  Future<void> _startPreparingOrder(Order order) async {
    try {
      final orderService = Provider.of<OrderService>(context, listen: false);
      final success = await orderService.updateOrderStatus(
        orderId: order.id,
        status: OrderStatus.preparing,
        notes: 'Order preparation started',
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Started preparing order #${order.orderNumber}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.blue,
          ),
        );
        await _loadOrders();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update order status. Please try again.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error updating order: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _broadcastOrderToDelivery(Order order) async {
    try {
      final orderAssignmentService = OrderAssignmentService();

      double restaurantLatitude = 0.0;
      double restaurantLongitude = 0.0;

      try {
        final restaurantService =
            Provider.of<RestaurantService>(context, listen: false);
        final currentUser =
            Provider.of<AuthService>(context, listen: false).currentUser;

        if (currentUser != null) {
          final restaurant =
              await restaurantService.getRestaurantByOwnerId(currentUser.id);
          if (restaurant != null &&
              restaurant.latitude != null &&
              restaurant.longitude != null) {
            restaurantLatitude = restaurant.latitude!;
            restaurantLongitude = restaurant.longitude!;
          } else {
            if (!mounted) return;
            final orderService =
                Provider.of<OrderService>(context, listen: false);
            final orderDetails = await orderService.getOrderById(order.id);
            if (orderDetails != null && orderDetails.restaurant != null) {
              final orderRestaurant = orderDetails.restaurant!;
              if (orderRestaurant.latitude != null &&
                  orderRestaurant.longitude != null) {
                restaurantLatitude = orderRestaurant.latitude!;
                restaurantLongitude = orderRestaurant.longitude!;
              }
            }
          }
        }

        if (restaurantLatitude == 0.0 && restaurantLongitude == 0.0) {
          if (order.deliveryAddress['latitude'] != null &&
              order.deliveryAddress['longitude'] != null) {
            restaurantLatitude = order.deliveryAddress['latitude'];
            restaurantLongitude = order.deliveryAddress['longitude'];
          }
        }
      } catch (e) {
        debugPrint('Could not get restaurant location: $e');
      }

      final broadcastSuccess =
          await orderAssignmentService.broadcastOrderToDeliveryPersonnel(
        orderId: order.id,
        restaurantLatitude:
            restaurantLatitude == 0.0 ? null : restaurantLatitude,
        restaurantLongitude:
            restaurantLongitude == 0.0 ? null : restaurantLongitude,
        radiusKm: restaurantLatitude == 0.0 && restaurantLongitude == 0.0
            ? double.infinity
            : 10.0,
      );

      if (broadcastSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order #${order.orderNumber} broadcast to delivery personnel!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.blue[600],
          ),
        );
        await _loadOrders();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to broadcast order. No delivery personnel available.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error broadcasting order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error broadcasting order: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markOrderReady(Order order) async {
    try {
      final orderService = Provider.of<OrderService>(context, listen: false);
      final success = await orderService.updateOrderStatus(
        orderId: order.id,
        status: OrderStatus.ready,
        notes: 'Order marked as ready for pickup',
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order #${order.orderNumber} is ready for pickup!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.purple,
          ),
        );
        await _loadOrders();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update order. Please try again.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error updating order: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRejectOrderDialog(Order order) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Reject Order',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please provide a reason for rejecting this order:',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter rejection reason...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.red[400]!),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Please provide a rejection reason',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop();
                _rejectOrder(order, reason);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(
                'Reject Order',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _rejectOrder(Order order, String reason) async {
    try {
      final orderService = Provider.of<OrderService>(context, listen: false);
      final success = await orderService.cancelOrder(
        orderId: order.id,
        cancellationDate: DateTime.now(),
        reason: reason,
      );

      if (success != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order #${order.orderNumber} rejected successfully',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
        await _loadOrders();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to reject order. Please try again.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error rejecting order: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
