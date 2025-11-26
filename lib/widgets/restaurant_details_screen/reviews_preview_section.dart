import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../models/menu_item_review.dart';
import '../../models/restaurant.dart';
import '../../screens/restaurant_reviews_screen.dart';
import '../../services/restaurant_review_service.dart';
import '../../services/transition_service.dart';

class ReviewsPreviewSection extends StatefulWidget {
  const ReviewsPreviewSection({
    required this.restaurant,
    super.key,
  });

  final Restaurant restaurant;

  @override
  State<ReviewsPreviewSection> createState() => _ReviewsPreviewSectionState();
}

class _ReviewsPreviewSectionState extends State<ReviewsPreviewSection> {
  final RestaurantReviewService _reviewService = RestaurantReviewService();
  bool _isLoadingGallery = true;
  List<ReviewImage> _reviewImages = [];
  int _totalReviewsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoadingGallery = true;
    });

    try {
      debugPrint(
          '🔍 Reviews Preview: Loading all reviews for restaurant ${widget.restaurant.id}');

      // Fetch restaurant reviews
      final restaurantReviews = await _reviewService.getRestaurantReviews(
        restaurantId: widget.restaurant.id,
        offset: 0,
        limit: 20,
        sortBy: 'rating_high',
      );

      debugPrint(
          '✅ Reviews Preview: Loaded ${restaurantReviews.length} restaurant reviews');

      // Fetch menu items for this restaurant
      final supabase = Supabase.instance.client;
      final menuItemsResponse = await supabase
          .from('menu_items')
          .select('id')
          .eq('restaurant_id', widget.restaurant.id)
          .eq('is_available', true);

      final menuItemIds = (menuItemsResponse as List)
          .map((item) => item['id'] as String)
          .toList();

      debugPrint('✅ Reviews Preview: Found ${menuItemIds.length} menu items');

      // Fetch menu item reviews for all menu items
      List<MenuItemReview> allMenuItemReviews = [];
      if (menuItemIds.isNotEmpty) {
        // Fetch reviews for all menu items in batches
        final menuItemReviewsResponse = await supabase
            .from('menu_item_reviews')
            .select('''
              id,
              menu_item_id,
              user_id,
              rating,
              comment,
              image,
              photos,
              created_at,
              updated_at,
              user_profiles:user_id (
                name,
                profile_image
              )
            ''')
            .inFilter('menu_item_id', menuItemIds)
            .order('rating', ascending: false)
            .order('created_at', ascending: false)
            .limit(20);

        allMenuItemReviews = (menuItemReviewsResponse as List)
            .map((json) => MenuItemReview.fromJson(json))
            .toList();

        debugPrint(
            '✅ Reviews Preview: Loaded ${allMenuItemReviews.length} menu item reviews');
      }

      // Extract images from both types of reviews
      final images = <ReviewImage>[];

      // From restaurant reviews
      for (final review in restaurantReviews) {
        if (review.image != null && review.image!.isNotEmpty) {
          images.add(ReviewImage(
            imageUrl: review.image!,
            rating: review.rating.toDouble(),
          ));
        }
        if (review.photos != null && review.photos!.isNotEmpty) {
          for (final photo in review.photos!) {
            if (photo.isNotEmpty) {
              images.add(ReviewImage(
                imageUrl: photo,
                rating: review.rating.toDouble(),
              ));
            }
          }
        }
      }

      // From menu item reviews
      for (final review in allMenuItemReviews) {
        if (review.image != null && review.image!.isNotEmpty) {
          images.add(ReviewImage(
            imageUrl: review.image!,
            rating: review.rating.toDouble(),
          ));
        }
        if (review.photos != null && review.photos!.isNotEmpty) {
          for (final photo in review.photos!) {
            if (photo.isNotEmpty) {
              images.add(ReviewImage(
                imageUrl: photo,
                rating: review.rating.toDouble(),
              ));
            }
          }
        }
      }

      debugPrint(
          '✅ Reviews Preview: Extracted ${images.length} total images from all reviews');

      // Calculate total reviews count (restaurant + menu item reviews)
      final totalReviews = restaurantReviews.length + allMenuItemReviews.length;
      debugPrint(
          '✅ Reviews Preview: Total reviews count: $totalReviews (${restaurantReviews.length} restaurant + ${allMenuItemReviews.length} menu item)');

      if (mounted) {
        setState(() {
          _reviewImages = images;
          _totalReviewsCount = totalReviews;
          _isLoadingGallery = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Reviews Preview: Error loading reviews: $e');
      if (mounted) {
        setState(() {
          _isLoadingGallery = false;
        });
      }
    }
  }

  void _navigateToFullReviews() {
    TransitionService.navigateWithTransition(
      context,
      RestaurantReviewsScreen(
        restaurant: widget.restaurant,
      ),
      transitionType: TransitionType.slideFromRight,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _navigateToFullReviews,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unified Reviews Header (RTL aware)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)?.reviews ?? 'Reviews',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  GestureDetector(
                    onTap: _navigateToFullReviews,
                    child: Text(
                      '${AppLocalizations.of(context)?.viewAll ?? 'See All'} ($_totalReviewsCount)',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.grey[700],
                      ),
                      textDirection: Directionality.of(context),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Rating Summary
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    widget.restaurant.rating.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(5, (index) {
                          final rating = widget.restaurant.rating;
                          final starValue = index + 1;

                          if (rating >= starValue) {
                            return const Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.amber,
                            );
                          } else if (rating >= starValue - 0.5) {
                            return const Icon(
                              Icons.star_half,
                              size: 16,
                              color: Colors.amber,
                            );
                          } else {
                            return Icon(
                              Icons.star_border,
                              size: 16,
                              color: Colors.grey[400],
                            );
                          }
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.restaurant.reviewCount} ${AppLocalizations.of(context)?.reviews ?? 'ratings'}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                height: 1,
                thickness: 1,
                color: Colors.grey[200],
              ),
            ),

            const SizedBox(height: 16),

            // Gallery Images
            if (_isLoadingGallery)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildGallerySkeleton(),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate width to fit exactly 3.0 images per screen width
                    final imageWidth = (constraints.maxWidth / 3.0) - 8;
                    return SizedBox(
                      height: 114, // Reduced by 5% from 120
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _reviewImages.length,
                        itemBuilder: (context, index) {
                          final image = _reviewImages[index];
                          return Container(
                            width: imageWidth,
                            margin: const EdgeInsetsDirectional.only(end: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: image.imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey[200],
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.error),
                                    ),
                                  ),
                                  // Rating overlay (RTL aware)
                                  PositionedDirectional(
                                    bottom: 8,
                                    start: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.black.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            size: 14,
                                            color: Colors.amber,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            image.rating.toString(),
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildGallerySkeleton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate width to fit exactly 3.0 images per screen width
        final imageWidth = (constraints.maxWidth / 3.0) - 8;
        return SizedBox(
          height: 114, // Reduced by 5% from 120
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            itemBuilder: (context, index) {
              return Container(
                width: imageWidth,
                margin: const EdgeInsetsDirectional.only(end: 8),
                child: Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// Helper class for review images in gallery
class ReviewImage {
  final String imageUrl;
  final double rating;

  ReviewImage({
    required this.imageUrl,
    required this.rating,
  });
}
