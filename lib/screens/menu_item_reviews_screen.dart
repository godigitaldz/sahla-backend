import "dart:async";

import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "../models/menu_item.dart";
import "../models/menu_item_review.dart";
import "../services/menu_item_review_service.dart";
import "../utils/performance_utils.dart";

class MenuItemReviewsScreen extends StatefulWidget {
  const MenuItemReviewsScreen({
    required this.menuItem,
    super.key,
  });

  final MenuItem menuItem;

  @override
  State<MenuItemReviewsScreen> createState() => _MenuItemReviewsScreenState();
}

class _MenuItemReviewsScreenState extends State<MenuItemReviewsScreen> {
  final MenuItemReviewService _reviewService = MenuItemReviewService();
  bool _isLoading = true;
  List<MenuItemReview> _reviews = [];
  String? _errorMessage;
  bool _hasError = false;

  // Pagination
  int _currentOffset = 0;
  static const int _pageSize = 10;
  bool _isLoadingMore = false;
  bool _hasMorePages = true;

  // Filtering and sorting
  String _sortBy = "newest"; // "newest", "oldest", "rating_high", "rating_low"
  int? _filterRating; // null for all, 1-5 for specific rating

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews({bool loadMore = false}) async {
    if (loadMore && (!_hasMorePages || _isLoadingMore)) {
      return;
    }

    setState(() {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
        _errorMessage = null;
        _hasError = false;
      }
    });

    try {
      final reviews = await _reviewService.getMenuItemReviews(
        menuItemId: widget.menuItem.id,
        offset: loadMore ? _currentOffset : 0,
        limit: _pageSize,
        sortBy: _sortBy,
        minRating: _filterRating,
        maxRating: _filterRating,
      );

      setState(() {
        if (loadMore) {
          _reviews.addAll(reviews);
          _currentOffset += reviews.length;
          _isLoadingMore = false;
        } else {
          _reviews = reviews;
          _currentOffset = reviews.length;
          _isLoading = false;
        }

        _hasMorePages = reviews.length == _pageSize;
      });
    } on Exception catch (e) {
      debugPrint("❌ Error loading menu item reviews: $e");
      setState(() {
        _errorMessage = "Failed to load reviews. Please try again.";
        _hasError = true;
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _onSortChanged(String? value) {
    if (value != null && value != _sortBy) {
      setState(() {
        _sortBy = value;
      });
      _loadReviews(); // Reload with new sorting
    }
  }

  void _onFilterRatingChanged(int? rating) {
    setState(() {
      _filterRating = rating;
    });
    _loadReviews(); // Reload with new filter
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Reviews for ${widget.menuItem.name}",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          // Sort dropdown
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: DropdownButton<String>(
              value: _sortBy,
              onChanged: _onSortChanged,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
              ),
              underline: Container(
                height: 2,
                color: Colors.orange[600],
              ),
              items: const [
                DropdownMenuItem(
                  value: "newest",
                  child: Text("Newest"),
                ),
                DropdownMenuItem(
                  value: "oldest",
                  child: Text("Oldest"),
                ),
                DropdownMenuItem(
                  value: "rating_high",
                  child: Text("Highest Rated"),
                ),
                DropdownMenuItem(
                  value: "rating_low",
                  child: Text("Lowest Rated"),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _hasError
              ? _buildErrorState()
              : Column(
                  children: [
                    // Filter chips
                    Container(
                      height: 50,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildFilterChip(null, "All"),
                          _buildFilterChip(5, "5★"),
                          _buildFilterChip(4, "4★"),
                          _buildFilterChip(3, "3★"),
                          _buildFilterChip(2, "2★"),
                          _buildFilterChip(1, "1★"),
                        ],
                      ),
                    ),

                    // Reviews list
                    Expanded(
                      child: _reviews.isEmpty
                          ? _buildEmptyState()
                          : PerformanceUtils.optimizedListView(
                              children: [
                                ..._reviews.map(_buildReviewCard),
                                if (_isLoadingMore)
                                  const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                        child: CircularProgressIndicator()),
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildFilterChip(int? rating, String label) {
    final isSelected = _filterRating == rating;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        selected: isSelected,
        onSelected: (bool selected) {
          _onFilterRatingChanged(selected ? rating : null);
        },
        selectedColor: Colors.orange[600],
        checkmarkColor: Colors.white,
        backgroundColor: Colors.grey[100],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.rate_review_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            "No reviews yet",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Be the first to review ${widget.menuItem.name}",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(MenuItemReview review) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info and rating
            Row(
              children: [
                // User avatar
                CircleAvatar(
                  radius: 20,
                  backgroundImage: review.user?.profileImage != null
                      ? NetworkImage(review.user!.profileImage!)
                      : null,
                  backgroundColor: Colors.grey[300],
                  child: review.user?.profileImage == null
                      ? Text(
                          review.user?.name?.isNotEmpty == true
                              ? review.user!.name![0].toUpperCase()
                              : "U",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        )
                      : null,
                ),

                const SizedBox(width: 12),

                // User name and verified badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            review.user?.name ?? "Anonymous",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          if (review.isVerifiedPurchase) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.verified,
                              size: 16,
                              color: Colors.green[600],
                            ),
                          ],
                        ],
                      ),
                      Text(
                        review.timeAgo,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // Rating stars
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < review.rating ? Icons.star : Icons.star_border,
                      size: 16,
                      color: Colors.amber[600],
                    );
                  }),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Review comment
            if (review.hasComment)
              Text(
                review.comment!,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),

            // Review images (if any)
            if (review.hasPhotos && review.photos!.isNotEmpty)
              Container(
                height: 80,
                margin: const EdgeInsets.only(top: 12),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: review.photos!.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 80,
                      height: 80,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(review.photos![index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Main review image (if any)
            if (review.hasImage && review.image!.isNotEmpty)
              Container(
                width: double.infinity,
                height: 200,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: NetworkImage(review.image!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Color(0xFF593CFB),
          ),
          SizedBox(height: 16),
          Text(
            'Loading reviews...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off,
              size: 48,
              color: Colors.orange[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Connection Error',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ??
                  'Unable to load reviews. Please check your connection and try again.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loadReviews,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF593CFB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'Try Again',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
