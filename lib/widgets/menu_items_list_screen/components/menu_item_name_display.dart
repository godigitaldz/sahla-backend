import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Isolated menu item name widget
/// Const widget that never rebuilds
class MenuItemNameDisplay extends StatelessWidget {
  const MenuItemNameDisplay({
    required this.name,
    required this.fontSize,
    required this.isRTL,
    super.key,
  });

  final String name;
  final double fontSize;
  final bool isRTL;

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      style: GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
    );
  }
}
