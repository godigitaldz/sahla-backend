import 'package:flutter/material.dart';

import '../../models/menu_item.dart';
import '../../widgets/menu_items_list_screen/menu_items_shimmer_loading.dart';

/// Scrollable menu items list content widget
/// Handles loading, empty, and list states with scroll compensation
class MenuItemsListContent extends StatelessWidget {
  const MenuItemsListContent({
    required this.scrollOffset,
    required this.isFirstFrame,
    required this.maxScrollOffset,
    required this.scrollController,
    required this.fixedSectionsSpacing,
    required this.isLoading,
    required this.hasCompletedInitialLoad,
    required this.displayedMenuItems,
    required this.isLoadingMore,
    required this.onBuildMenuItemCard,
    required this.onCalculateItemExtent,
    required this.emptyStateWidget,
    super.key,
  });

  final ValueNotifier<double> scrollOffset;
  final bool isFirstFrame;
  final double maxScrollOffset;
  final ScrollController scrollController;
  final double fixedSectionsSpacing;
  final bool isLoading;
  final bool hasCompletedInitialLoad;
  final List<MenuItem> displayedMenuItems;
  final bool isLoadingMore;
  final Widget Function(MenuItem menuItem) onBuildMenuItemCard;
  final double Function(BuildContext context) onCalculateItemExtent;
  final Widget emptyStateWidget;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: scrollOffset,
      builder: (context, scrollOffsetValue, child) {
        return Transform.translate(
          // Phase 1: Compensate for container translation (content stays put)
          // Phase 2: Stop compensating (content scrolls naturally)
          // Skip transform on first frame to prevent layout conflicts
          offset: isFirstFrame
              ? Offset.zero
              : Offset(0, scrollOffsetValue.clamp(0.0, maxScrollOffset)),
          child: child,
        );
      },
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (isLoading && !hasCompletedInitialLoad) {
      return _buildLoadingState(context);
    }

    if (displayedMenuItems.isEmpty) {
      return _buildEmptyState(context);
    }

    return _buildListState(context);
  }

  Widget _buildLoadingState(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      physics: const ClampingScrollPhysics(),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: fixedSectionsSpacing),
          const MenuItemsShimmerLoading(),
          SizedBox(
            height: MediaQuery.of(context).padding.bottom +
                24.0, // Small buffer for visual spacing
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      physics: const ClampingScrollPhysics(),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: fixedSectionsSpacing),
          emptyStateWidget,
          SizedBox(
            height: MediaQuery.of(context).padding.bottom +
                24.0, // Small buffer for visual spacing
          ),
        ],
      ),
    );
  }

  Widget _buildListState(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding =
        screenHeight * 0.65; // 20% of screen height for full card display

    return ListView.builder(
      controller: scrollController,
      physics: const ClampingScrollPhysics(),
      clipBehavior: Clip.hardEdge,
      // CRITICAL: Fixed extent = huge performance win
      itemExtent: onCalculateItemExtent(context),
      // PERFORMANCE: Reduced cache extent (1.5 screens instead of 2.5)
      cacheExtent: screenHeight * 1.5,
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: fixedSectionsSpacing,
        bottom: MediaQuery.of(context).padding.bottom +
            bottomPadding, // 20% screen height + safe area padding
      ),
      itemCount: displayedMenuItems.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == displayedMenuItems.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        final menuItem = displayedMenuItems[index];
        return RepaintBoundary(
          key: ValueKey(
              "menu_item_${index}_${menuItem.id}_${menuItem.restaurantId}"),
          child: onBuildMenuItemCard(menuItem),
        );
      },
    );
  }
}
