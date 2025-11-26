import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Header widget with back arrow and search bar for manage menu screen
/// Copied from menu_items_list_screen.dart exact implementation
class ManageMenuHeaderWidget extends StatelessWidget {
  const ManageMenuHeaderWidget({
    required this.onBack,
    required this.searchController,
    required this.onSearchChanged,
    required this.statusBarHeight,
    super.key,
  });

  final VoidCallback onBack;
  final TextEditingController searchController;
  final Function(String) onSearchChanged;
  final double statusBarHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Header positioned immediately below status bar
    return Positioned(
      top: statusBarHeight,
      left: 14,
      right: 14,
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: onBack,
            child: const Icon(Icons.arrow_back, size: 24),
          ),
          const SizedBox(width: 12),
          // Search bar
          Expanded(
            child: SizedBox(
              height: 43.2,
              child: TextField(
                controller: searchController,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: l10n?.searchMenuItems ?? 'Search menu items...',
                  hintStyle: const TextStyle(fontSize: 14),
                  prefixIcon:
                      const Icon(Icons.search, color: Colors.grey, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  filled: true,
                  fillColor: const Color(0xFFf8eded),
                  isDense: true,
                ),
                onChanged: onSearchChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
