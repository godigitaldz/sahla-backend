import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OrdersFilterTabBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabSelected;
  final int availableCount;
  final int activeCount;
  final int completedCount;

  const OrdersFilterTabBar({
    required this.selectedIndex,
    required this.onTabSelected,
    required this.availableCount,
    required this.activeCount,
    required this.completedCount,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 47,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 40,
            offset: const Offset(0, 16),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTabItem(
            context: context,
            index: 0,
            label: 'Available',
            count: availableCount,
            isSelected: selectedIndex == 0,
          ),
          _buildTabItem(
            context: context,
            index: 1,
            label: 'Active',
            count: activeCount,
            isSelected: selectedIndex == 1,
          ),
          _buildTabItem(
            context: context,
            index: 2,
            label: 'Completed',
            count: completedCount,
            isSelected: selectedIndex == 2,
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required BuildContext context,
    required int index,
    required String label,
    required int count,
    required bool isSelected,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTabSelected(index),
        child: Container(
          height: 47,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFd47b00) : Colors.transparent,
            borderRadius: BorderRadius.circular(23.5),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.2)
                          : const Color(0xFFd47b00).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      count > 99 ? '99+' : count.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color:
                            isSelected ? Colors.white : const Color(0xFFd47b00),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
