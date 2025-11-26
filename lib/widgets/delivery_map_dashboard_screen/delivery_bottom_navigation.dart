import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app_animations.dart';

class DeliveryBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final int activeOrdersCount;
  final int availableOrdersCount;

  const DeliveryBottomNavigation({
    required this.selectedIndex,
    required this.onItemTapped,
    required this.activeOrdersCount,
    required this.availableOrdersCount,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding =
        Platform.isIOS ? MediaQuery.of(context).padding.bottom : 0.0;
    const baseHeight = 68.0;
    const baseMargin = 19.0;
    final totalHeight = baseHeight + bottomPadding;
    final totalMargin = baseMargin + bottomPadding;

    return Container(
      height: totalHeight,
      margin: EdgeInsets.fromLTRB(baseMargin, 0, baseMargin, totalMargin),
      decoration: BoxDecoration(
        color: const Color(0xFFd47b00),
        boxShadow: [
          // Main shadow for 3D floating effect
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 25,
            offset: const Offset(0, 10),
            spreadRadius: 0,
          ),
          // Secondary shadow for depth
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 50,
            offset: const Offset(0, 20),
            spreadRadius: 0,
          ),
          // Highlight shadow for 3D effect
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.15),
            blurRadius: 2,
            offset: const Offset(0, -2),
            spreadRadius: 0,
          ),
          // Additional depth shadow for full rounded effect
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 80,
            offset: const Offset(0, 30),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16,
            6,
            16,
            6 +
                MediaQuery.of(context)
                    .padding
                    .bottom), // Adjusted padding to prevent overflow
        child: AnimatedSwitcher(
          duration: AppAnimationDefaults.tabSwitchDuration,
          switchInCurve: AppAnimationDefaults.tabSwitchCurve,
          switchOutCurve: AppAnimationDefaults.tabSwitchCurve,
          child: Row(
            key: ValueKey<int>(selectedIndex),
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.map_outlined,
                activeIcon: Icons.map,
                label: 'Map',
                index: 0,
                isSelected: selectedIndex == 0,
              ),
              _buildNavItem(
                icon: Icons.local_shipping_outlined,
                activeIcon: Icons.local_shipping,
                label: 'Orders',
                index: 1,
                isSelected: selectedIndex == 1,
                badgeCount: activeOrdersCount + availableOrdersCount,
              ),
              _buildNavItem(
                icon: Icons.attach_money_outlined,
                activeIcon: Icons.attach_money,
                label: 'Earnings',
                index: 2,
                isSelected: selectedIndex == 2,
              ),
              _buildNavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                index: 3,
                isSelected: selectedIndex == 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required bool isSelected,
    int? badgeCount,
  }) {
    return GestureDetector(
      onTap: () => onItemTapped(index),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 13, vertical: 6), // Adjusted to prevent overflow
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14), // Reduced from 16 to 14
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 22, // Slightly larger for bold appearance
                  color: Colors.white, // Always white for bold appearance
                ),
                if (badgeCount != null && badgeCount > 0)
                  Positioned(
                    right: -7, // Reduced from -8 to -7
                    top: -7, // Reduced from -8 to -7
                    child: Container(
                      padding: const EdgeInsets.all(3), // Reduced from 4 to 3
                      decoration: BoxDecoration(
                        color: const Color(0xFFd47b00),
                        borderRadius:
                            BorderRadius.circular(8), // Reduced from 10 to 8
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 17, // Reduced from 20 to 17
                        minHeight: 17, // Reduced from 20 to 17
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : badgeCount.toString(),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10, // Slightly larger for bold appearance
                          fontWeight:
                              FontWeight.bold, // Already bold, keeping it
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3), // Reduced from 4 to 3
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11, // Slightly larger for bold appearance
                fontWeight:
                    FontWeight.bold, // Always bold for white bold appearance
                color: Colors.white, // Always white for bold appearance
              ),
            ),
          ],
        ),
      ),
    );
  }
}
