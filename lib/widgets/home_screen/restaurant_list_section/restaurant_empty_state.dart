import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Restaurant empty state widget
///
/// Displays when no restaurants are available
/// Shows icon and message to the user
class RestaurantEmptyState extends StatelessWidget {
  const RestaurantEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.store_outlined,
              size: 40,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              "No restaurants available",
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
