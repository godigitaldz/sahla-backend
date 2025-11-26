import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Header widget for Manage Orders Screen
class ManageOrdersHeaderWidget extends StatelessWidget
    implements PreferredSizeWidget {
  const ManageOrdersHeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        'Manage Orders',
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
