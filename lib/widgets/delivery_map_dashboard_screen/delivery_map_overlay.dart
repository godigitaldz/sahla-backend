import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DeliveryMapOverlay extends StatelessWidget {
  final bool isOnline;
  final bool isAvailable;
  final VoidCallback onToggleOnline;
  final int activeOrdersCount;
  final int availableOrdersCount;
  final VoidCallback? onBackPressed;

  const DeliveryMapOverlay({
    required this.isOnline,
    required this.isAvailable,
    required this.onToggleOnline,
    required this.activeOrdersCount,
    required this.availableOrdersCount,
    super.key,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Top Status Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 40,
                  offset: const Offset(0, 10),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              children: [
                // Back Button
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: onBackPressed ??
                        () {
                          // Default behavior - do nothing to prevent navigation away
                        },
                    icon: Icon(
                      Icons.arrow_back,
                      size: 20,
                      color: Colors.grey[800],
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),

                const SizedBox(width: 16),

                // Status Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivery Dashboard',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isAvailable ? Colors.green : Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isAvailable ? 'Available' : 'Unavailable',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isAvailable
                                  ? Colors.green[700]
                                  : Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Availability Toggle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isAvailable ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color:
                          isAvailable ? Colors.green[200]! : Colors.red[200]!,
                      width: 2,
                    ),
                  ),
                  child: IconButton(
                    onPressed: onToggleOnline,
                    icon: Icon(
                      isAvailable ? Icons.check_circle : Icons.cancel,
                      size: 20,
                      color: isAvailable ? Colors.green[700] : Colors.red[700],
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: isAvailable ? 'Set Unavailable' : 'Set Available',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Stats Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.local_shipping,
                  label: 'Active',
                  count: activeOrdersCount,
                  color: const Color(0xFFd47b00),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.notifications,
                  label: 'Available',
                  count: availableOrdersCount,
                  color: Colors.green[600]!,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
