import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/performance_utils.dart';

class MenuItemsHeader extends StatelessWidget {
  const MenuItemsHeader({
    required this.onBack,
    required this.searchController,
    required this.onSearchChanged,
    super.key,
  });

  final VoidCallback onBack;
  final TextEditingController searchController;
  final Function(String) onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PerformanceUtils.measurePerformanceWidget("MenuItemsHeaderBuild",
        () {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(
              bottom: 8,
              left: 16,
              right: 16,
            ),
            child: Row(
              children: [
                // Back button with floating style
                PerformanceUtils.constWrapper(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.black87, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Search bar with floating 3D shadow style
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      decoration: InputDecoration(
                        hintText: l10n?.searchMenuItems ?? 'Search menu items',
                        hintStyle: GoogleFonts.inter(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey.shade500,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      style: GoogleFonts.inter(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}
