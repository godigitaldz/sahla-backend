import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../models/order.dart';
import 'manage_order_card_widget.dart';

/// Order list section widget that displays filtered orders
class OrderListSectionWidget extends StatelessWidget {
  final bool isLoading;
  final List<Order> filteredOrders;
  final String activeFilter;
  final Widget Function(Order)? actionButtonBuilder;

  const OrderListSectionWidget({
    required this.isLoading,
    required this.filteredOrders,
    required this.activeFilter,
    super.key,
    this.actionButtonBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRecentActivity(context),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    if (isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOrderSkeleton(),
          const SizedBox(height: 12),
          _buildOrderSkeleton(),
          const SizedBox(height: 12),
          _buildOrderSkeleton(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (filteredOrders.isNotEmpty) ...[
          ...filteredOrders.map(
            (order) => ManageOrderCardWidget(
              order: order,
              actionButton: actionButtonBuilder != null
                  ? actionButtonBuilder!(order)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No ${_getFilterLabel()} orders',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _getFilterLabel() {
    switch (activeFilter) {
      case 'pending':
        return 'pending';
      case 'onProcess':
        return 'on process';
      case 'completed':
        return 'completed';
      default:
        return '';
    }
  }

  Widget _buildOrderSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      period: const Duration(milliseconds: 1200),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
