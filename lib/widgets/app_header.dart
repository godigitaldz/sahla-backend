import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? leadingAction; // e.g., refresh button
  final Widget? trailingAction; // optional trailing control (e.g., Save)
  final bool includeSafeArea; // whether to include SafeArea wrapper
  final EdgeInsets? padding; // custom padding around the header
  final Color? backgroundColor; // background color for the safe area

  const AppHeader({
    required this.title,
    super.key,
    this.onBack,
    this.leadingAction,
    this.trailingAction,
    this.includeSafeArea = true,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final headerWidget = Container(
      height: 57,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(25),
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
          // Back button
          Container(
            width: 44,
            height: 44,
            margin: const EdgeInsets.only(left: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: IconButton(
              onPressed: onBack ?? () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.arrow_back,
                size: 20,
                color: Colors.black,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),

          const SizedBox(width: 16),

          if (leadingAction != null) ...[
            leadingAction!,
            const SizedBox(width: 16),
          ],

          // Title pill
          Expanded(
            child: Container(
              height: 44,
              margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFd47b00),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFd47b00).withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: const Color(0xFFd47b00).withValues(alpha: 0.08),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),

          if (trailingAction != null) ...[
            const SizedBox(width: 16),
            trailingAction!,
          ],
        ],
      ),
    );

    // Wrap with SafeArea if requested
    if (includeSafeArea) {
      if (Platform.isIOS) {
        return Container(
          color: backgroundColor ?? Colors.grey[50],
          child: SafeArea(
            top: true,
            bottom: true,
            left: true,
            right: true,
            child: Padding(
              padding: padding ?? _getResponsivePadding(context),
              child: headerWidget,
            ),
          ),
        );
      }

      return Container(
        color: backgroundColor ?? Colors.grey[50],
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: padding ?? const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: headerWidget,
          ),
        ),
      );
    }

    return headerWidget;
  }

  /// Get responsive padding based on screen width
  static EdgeInsets _getResponsivePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (Platform.isIOS) {
      if (screenWidth <= 375) {
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
      } else if (screenWidth <= 414) {
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
      } else {
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 20);
      }
    }
    return const EdgeInsets.fromLTRB(20, 0, 20, 0);
  }
}
