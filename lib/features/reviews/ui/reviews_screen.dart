import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../widgets/pill_dropdown.dart';
import '../logic/reviews_viewmodel.dart';
import 'widgets/review_skeleton.dart';
import 'widgets/review_tile.dart';

/// Production-grade reviews screen with slivers, pagination, and optimizations.
class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({
    required this.restaurantId,
    required this.restaurantName,
    this.initialSelectedMenuItem,
    super.key,
  });

  final String restaurantId;
  final String restaurantName;
  final String? initialSelectedMenuItem;

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  late ScrollController _scrollController;
  late ReviewsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _viewModel = ReviewsViewModel(restaurantId: widget.restaurantId);
    _viewModel.loadReviews();

    // Set initial menu item filter if provided
    if (widget.initialSelectedMenuItem != null) {
      // Delay setting the filter until after reviews are loaded
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _viewModel.setSelectedMenuItem(widget.initialSelectedMenuItem);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      _viewModel.checkScrollPosition(
        _scrollController.position.pixels,
        _scrollController.position.maxScrollExtent,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: Consumer<ReviewsViewModel>(
          builder: (context, viewModel, _) {
            return RefreshIndicator(
              onRefresh: viewModel.refresh,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // App bar with title and sort dropdown
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: Colors.white,
                    elevation: 0,
                    iconTheme: const IconThemeData(color: Colors.black87),
                    title: Row(
                      children: [
                        Text(
                          widget.restaurantName,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        _buildSortDropdown(viewModel),
                      ],
                    ),
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(1),
                      child: Container(
                        color: Colors.grey[200],
                        height: 1,
                      ),
                    ),
                  ),

                  // Menu item filter chips
                  if (viewModel.uniqueMenuItems.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildMenuItemFilters(viewModel),
                    ),

                  // Content
                  if (viewModel.isLoading && viewModel.reviews.isEmpty)
                    const ReviewSkeletonList()
                  else if (viewModel.error != null && viewModel.reviews.isEmpty)
                    _buildErrorState(viewModel)
                  else if (viewModel.filteredReviews.isEmpty)
                    _buildEmptyState()
                  else
                    _buildReviewsList(viewModel),

                  // Loading more indicator
                  if (viewModel.isLoadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildReviewsList(ReviewsViewModel viewModel) {
    final list = viewModel.filteredReviews;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return ReviewTile(review: list[index]);
        },
        childCount: list.length,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        addSemanticIndexes: false,
      ),
    );
  }

  Widget _buildSortDropdown(ReviewsViewModel viewModel) {
    final l10n = AppLocalizations.of(context);
    return Transform.scale(
      scale: 0.85,
      child: SizedBox(
        width: 141, // Compensate for scale (120 / 0.85)
        child: PillDropdown<String>(
          value: viewModel.sortBy,
          onChanged: (value) {
            if (value != null) {
              viewModel.changeSortOrder(value);
            }
          },
          items: [
            DropdownMenuItem(
                value: 'newest', child: Text(l10n?.newest ?? 'Newest')),
            DropdownMenuItem(
                value: 'oldest', child: Text(l10n?.oldest ?? 'Oldest')),
            DropdownMenuItem(
                value: 'rating_high',
                child: Text(l10n?.highestRated ?? 'Highest Rated')),
            DropdownMenuItem(
                value: 'rating_low',
                child: Text(l10n?.lowestRated ?? 'Lowest Rated')),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ReviewsViewModel viewModel) {
    final l10n = AppLocalizations.of(context);
    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[400],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n?.oops ?? 'Oops!',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                viewModel.error ??
                    (l10n?.failedToLoadReviews ?? 'Failed to load reviews'),
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: viewModel.retry,
                icon: const Icon(Icons.refresh),
                label: Text(l10n?.retry ?? 'Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFfc9d2d),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.rate_review_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n?.noReviewsYet ?? 'No reviews yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${l10n?.beTheFirstToReview ?? 'Be the first to review'} ${widget.restaurantName}',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItemFilters(ReviewsViewModel viewModel) {
    final l10n = AppLocalizations.of(context);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Align(
        alignment: Alignment.center,
        child: SizedBox(
          height: 32,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 1 + viewModel.uniqueMenuItems.length,
            itemBuilder: (context, index) {
              if (index == 0) {
                // "All Reviews" chip
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(l10n?.allReviews ?? 'All Reviews'),
                    selected: viewModel.selectedMenuItem == null,
                    onSelected: (selected) {
                      if (selected) {
                        viewModel.setSelectedMenuItem(null);
                      }
                    },
                    backgroundColor: Colors.grey[100],
                    selectedColor: const Color(0xFFfc9d2d),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: viewModel.selectedMenuItem == null
                          ? Colors.white
                          : Colors.grey[700],
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                      side: BorderSide.none,
                    ),
                    showCheckmark: false,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                );
              }
              // Menu item chips
              final menuItem = viewModel.uniqueMenuItems[index - 1];
              final isSelected = viewModel.selectedMenuItem == menuItem;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(menuItem),
                  selected: isSelected,
                  onSelected: (selected) {
                    viewModel.setSelectedMenuItem(selected ? menuItem : null);
                  },
                  backgroundColor: Colors.grey[100],
                  selectedColor: const Color(0xFFfc9d2d),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                    side: BorderSide.none,
                  ),
                  showCheckmark: false,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
