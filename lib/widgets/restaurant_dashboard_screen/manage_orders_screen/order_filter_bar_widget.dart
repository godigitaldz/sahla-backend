import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Order filter bar widget for filtering orders by status
class OrderFilterBarWidget extends StatelessWidget {
  final String activeFilter;
  final Function(String) onFilterChanged;
  final int pendingCount;
  final int onProcessCount;
  final int completedCount;

  const OrderFilterBarWidget({
    required this.activeFilter,
    required this.onFilterChanged,
    required this.pendingCount,
    required this.onProcessCount,
    required this.completedCount,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 47,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23.5),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          _buildFilterTab('pending', 'Pending', pendingCount),
          _buildFilterDivider(),
          _buildFilterTab('onProcess', 'On Process', onProcessCount),
          _buildFilterDivider(),
          _buildFilterTab('completed', 'Completed', completedCount),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String filterKey, String label, int count) {
    final isActive = activeFilter == filterKey;

    return Expanded(
      child: GestureDetector(
        onTap: () => onFilterChanged(filterKey),
        child: Container(
          height: 47,
          decoration: BoxDecoration(
            color: isActive ? Colors.orange[600] : Colors.transparent,
            borderRadius: BorderRadius.circular(23.5),
          ),
          child: Center(
            child: Text(
              '$label ($count)',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : Colors.grey[700],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDivider() {
    return Container(
      width: 1,
      height: 30,
      color: Colors.grey[300],
    );
  }
}
