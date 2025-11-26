import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../models/restaurant.dart';
import '../services/menu_item_image_service.dart';
import '../services/menu_item_review_service.dart';
import '../services/order_review_service.dart';
import '../services/restaurant_review_service.dart';
import '../utils/bottom_padding.dart';

/// Enum to define the type of review being submitted
enum ReviewType {
  menuItem,
  restaurant,
  order,
}

/// A reusable widget for submitting reviews for menu items, restaurants, or orders
class ReviewSubmissionWidget extends StatefulWidget {
  const ReviewSubmissionWidget({
    required this.reviewType,
    this.menuItem,
    this.restaurant,
    this.order,
    this.onReviewSubmitted,
    this.onReviewCompleted,
    super.key,
  });

  final ReviewType reviewType;
  final MenuItem? menuItem;
  final Restaurant? restaurant;
  final Order? order;
  final VoidCallback? onReviewSubmitted;
  final VoidCallback? onReviewCompleted;

  @override
  State<ReviewSubmissionWidget> createState() => _ReviewSubmissionWidgetState();
}

class _ReviewSubmissionWidgetState extends State<ReviewSubmissionWidget> {
  // Services
  final RestaurantReviewService _restaurantReviewService =
      RestaurantReviewService();
  final MenuItemReviewService _menuItemReviewService = MenuItemReviewService();
  final OrderReviewService _orderReviewService = OrderReviewService();

  // Form state
  int _rating = 5;
  final TextEditingController _commentController = TextEditingController();
  final List<File> _selectedImages = [];
  bool _isSubmitting = false;

  // Updated rating (refreshed after review submission)
  double? _updatedRating;

  // Restaurant logo for menu item reviews
  String? _restaurantLogoUrl;
  bool _isLoadingRestaurantLogo = false;

  // Restaurant review state (for in-card review)
  int? _restaurantRating;
  bool _isSubmittingRestaurantReview = false;
  bool _hasSubmittedRestaurantReview = false;

  // UI colors
  static const Color _backgroundColor = Color(0xFFFAFAFA);

  // Responsive sizing helper
  Map<String, dynamic> _getResponsiveSizes(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isLargeScreen = screenWidth > 600;

    return {
      'isSmallScreen': isSmallScreen,
      'isLargeScreen': isLargeScreen,
      'screenWidth': screenWidth,
      'imageSize': isSmallScreen ? 60.0 : 70.0,
      'borderRadius': isSmallScreen ? 10.0 : 12.0,
      'padding': isSmallScreen ? 14.0 : 16.0,
      'titleFontSize': isSmallScreen ? 14.0 : 16.0,
      'subtitleFontSize': isSmallScreen ? 11.0 : 13.0,
      'headingFontSize': isSmallScreen ? 16.0 : 18.0,
      'starSize': isSmallScreen ? 28.0 : 32.0,
    };
  }

  @override
  void initState() {
    super.initState();
    // Load restaurant logo for menu item reviews
    if (widget.reviewType == ReviewType.menuItem && widget.menuItem != null) {
      _loadRestaurantLogo();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// Load restaurant logo from database
  Future<void> _loadRestaurantLogo() async {
    if (widget.menuItem == null) return;

    setState(() {
      _isLoadingRestaurantLogo = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('restaurants')
          .select('logo_url, image')
          .eq('id', widget.menuItem!.restaurantId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          // Prefer logo_url, fallback to image
          _restaurantLogoUrl =
              response['logo_url'] as String? ?? response['image'] as String?;
          _isLoadingRestaurantLogo = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoadingRestaurantLogo = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading restaurant logo: $e');
      if (mounted) {
        setState(() {
          _isLoadingRestaurantLogo = false;
        });
      }
    }
  }

  /// Submit restaurant review (in-card experience)
  Future<void> _submitRestaurantReview(int rating) async {
    if (widget.menuItem == null) return;

    setState(() {
      _restaurantRating = rating;
      _isSubmittingRestaurantReview = true;
    });

    try {
      final success = await _restaurantReviewService.submitRestaurantReview(
        restaurantId: widget.menuItem!.restaurantId,
        rating: rating,
        comment: null, // In-card review doesn't include comments
        photos: [], // In-card review doesn't include photos
      );

      if (success) {
        if (mounted) {
          setState(() {
            _hasSubmittedRestaurantReview = true;
            _isSubmittingRestaurantReview = false;
          });

          // Show success snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!
                    .restaurantReviewSubmittedSuccessfully,
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green[600],
              duration: const Duration(seconds: 2),
            ),
          );

          // Notify parent if callback is provided
          widget.onReviewCompleted?.call();
        }
      } else {
        if (mounted) {
          setState(() {
            _restaurantRating = null;
            _isSubmittingRestaurantReview = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.failedToSubmitRestaurantReview,
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red[600],
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error submitting restaurant review: $e');
      if (mounted) {
        setState(() {
          _restaurantRating = null;
          _isSubmittingRestaurantReview = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.errorOccurredTryAgain,
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Refresh rating from database
  Future<void> _refreshRatingData() async {
    try {
      switch (widget.reviewType) {
        case ReviewType.menuItem:
          await _refreshMenuItemRating();
          break;
        case ReviewType.restaurant:
          await _refreshRestaurantRating();
          break;
        case ReviewType.order:
          // Orders don't have ratings to refresh
          break;
      }
    } catch (e) {
      debugPrint('❌ Error refreshing rating data: $e');
    }
  }

  /// Refresh menu item rating from database
  Future<void> _refreshMenuItemRating() async {
    if (widget.menuItem == null) return;

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('menu_items')
          .select('rating')
          .eq('id', widget.menuItem!.id)
          .single();

      if (mounted) {
        setState(() {
          _updatedRating = (response['rating'] as num?)?.toDouble();
        });
      }
    } catch (e) {
      debugPrint('❌ Error refreshing menu item rating: $e');
    }
  }

  /// Refresh restaurant rating from database
  Future<void> _refreshRestaurantRating() async {
    if (widget.restaurant == null) return;

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('restaurants')
          .select('rating')
          .eq('id', widget.restaurant!.id)
          .single();

      if (mounted) {
        setState(() {
          _updatedRating = (response['rating'] as num?)?.toDouble();
        });
      }
    } catch (e) {
      debugPrint('❌ Error refreshing restaurant rating: $e');
    }
  }

  /// Get the title based on review type
  String _reviewTitle(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (widget.reviewType) {
      case ReviewType.menuItem:
        return widget.menuItem?.name ?? l10n.reviewMenuItem;
      case ReviewType.restaurant:
        return widget.restaurant?.name ?? l10n.reviewRestaurant;
      case ReviewType.order:
        return '${l10n.reviewOrder}${widget.order?.orderNumber ?? ''}';
    }
  }

  /// Get the subtitle based on review type
  String _reviewSubtitle(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (widget.reviewType) {
      case ReviewType.menuItem:
        return l10n.reviewMenuItemSubtitle;
      case ReviewType.restaurant:
        return l10n.reviewRestaurantSubtitle;
      case ReviewType.order:
        return l10n.reviewOrderSubtitle;
    }
  }

  /// Pick images from gallery
  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(
      maxHeight: 1800,
      maxWidth: 1800,
      imageQuality: 85,
    );

    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images.map((xFile) => File(xFile.path)));
      });
    }
  }

  /// Remove an image from selection
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  /// Submit the review based on review type
  Future<void> _submitReview() async {
    final l10n = AppLocalizations.of(context)!;

    if (_rating < 1 || _rating > 5) {
      _showSnackBar(l10n.pleaseSelectValidRating, Colors.red);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      bool success = false;

      switch (widget.reviewType) {
        case ReviewType.menuItem:
          if (widget.menuItem == null) {
            _showSnackBar(l10n.menuItemNotFound, Colors.red);
            return;
          }
          success = await _submitMenuItemReview();
          break;

        case ReviewType.restaurant:
          if (widget.restaurant == null) {
            _showSnackBar(l10n.restaurantNotFound, Colors.red);
            return;
          }
          success = await _submitRestaurantReviewFull();
          break;

        case ReviewType.order:
          if (widget.order == null) {
            _showSnackBar(l10n.orderNotFound, Colors.red);
            return;
          }
          success = await _submitOrderReview();
          break;
      }

      if (success) {
        // Refresh rating data to show updated rating before closing
        await _refreshRatingData();

        _showSnackBar(l10n.reviewSubmittedSuccessfully, Colors.green);
        widget.onReviewSubmitted?.call();
        widget.onReviewCompleted?.call(); // Notify parent to refresh data

        // Give time for user to see the updated rating before closing
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        _showSnackBar(l10n.failedToSubmitReview, Colors.red);
      }
    } catch (e) {
      debugPrint('❌ Error submitting review: $e');
      _showSnackBar(l10n.failedToSubmitReview, Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  /// Submit menu item review
  Future<bool> _submitMenuItemReview() async {
    debugPrint('🔍 _submitMenuItemReview called');
    debugPrint('🔍 Selected images count: ${_selectedImages.length}');
    debugPrint(
        '🔍 Image paths: ${_selectedImages.map((file) => file.path).toList()}');

    final result = await _menuItemReviewService.submitMenuItemReview(
      menuItemId: widget.menuItem!.id,
      rating: _rating,
      comment: _commentController.text.trim().isNotEmpty
          ? _commentController.text.trim()
          : null,
      photos: _selectedImages.map((file) => file.path).toList(),
    );

    debugPrint('🔍 Submit result: $result');
    return result;
  }

  /// Submit restaurant review (full form)
  Future<bool> _submitRestaurantReviewFull() async {
    return _restaurantReviewService.submitRestaurantReview(
      restaurantId: widget.restaurant!.id,
      rating: _rating,
      comment: _commentController.text.trim().isNotEmpty
          ? _commentController.text.trim()
          : null,
      photos: _selectedImages.map((file) => file.path).toList(),
    );
  }

  /// Submit order review
  Future<bool> _submitOrderReview() async {
    return _orderReviewService.submitOrderReview(
      orderId: widget.order!.id,
      rating: _rating,
      comment: _commentController.text.trim().isNotEmpty
          ? _commentController.text.trim()
          : null,
      photos: _selectedImages.map((file) => file.path).toList(),
    );
  }

  /// Show snackbar message
  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  /// Get rating text description
  String _getRatingText(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (_rating) {
      case 1:
        return l10n.ratingPoor;
      case 2:
        return l10n.ratingFair;
      case 3:
        return l10n.ratingGood;
      case 4:
        return l10n.ratingVeryGood;
      case 5:
        return l10n.ratingExcellent;
      default:
        return l10n.selectRating;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive sizing
    final bool isSmallScreen = screenWidth < 360;
    final bool isLargeScreen = screenWidth > 600;
    final maxWidth = isLargeScreen ? 600.0 : screenWidth;

    // Responsive spacing
    final horizontalPadding =
        isSmallScreen ? 16.0 : (isLargeScreen ? 32.0 : 20.0);
    final verticalSpacing =
        isSmallScreen ? 20.0 : (isLargeScreen ? 36.0 : 28.0);

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.reviewTitle(_reviewTitle(context)),
          style: GoogleFonts.poppins(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              isSmallScreen ? 16 : 20,
              horizontalPadding,
              isSmallScreen ? 16 : 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header info
                _buildHeaderInfo(context),

                SizedBox(height: verticalSpacing * 0.85),

                // Rating section
                _buildRatingSection(context),

                SizedBox(height: verticalSpacing),

                // Comment section
                _buildCommentSection(context),

                SizedBox(height: verticalSpacing),

                // Restaurant review card (for menu items only)
                if (widget.reviewType == ReviewType.menuItem &&
                    widget.menuItem != null)
                  _buildRestaurantReviewCard(context),

                if (widget.reviewType == ReviewType.menuItem &&
                    widget.menuItem != null)
                  SizedBox(height: verticalSpacing),

                // Photo upload section
                _buildPhotoSection(context),

                // Bottom spacing for submit button
                SizedBox(height: isSmallScreen ? 90 : 100),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomSubmitBar(),
    );
  }

  /// Build header info widget
  Widget _buildHeaderInfo(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isSmallScreen ? 14 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Image or Icon
          _buildHeaderImage(context),
          SizedBox(width: isSmallScreen ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _reviewTitle(context),
                        style: GoogleFonts.poppins(
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildRatingStars(),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _reviewSubtitle(context),
                  style: GoogleFonts.poppins(
                    fontSize: isSmallScreen ? 11 : 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build 5-star rating display
  Widget _buildRatingStars() {
    double currentRating = 0.0;

    // Use updated rating if available (after review submission)
    if (_updatedRating != null) {
      currentRating = _updatedRating!;
    } else {
      switch (widget.reviewType) {
        case ReviewType.menuItem:
          currentRating = widget.menuItem?.rating ?? 0.0;
          break;
        case ReviewType.restaurant:
          currentRating = widget.restaurant?.rating ?? 0.0;
          break;
        case ReviewType.order:
          // Orders don't have ratings
          return const SizedBox.shrink();
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (index) {
          final starValue = index + 1;
          final isFilled = currentRating >= starValue;
          final isHalfFilled =
              currentRating >= starValue - 0.5 && currentRating < starValue;

          if (isHalfFilled) {
            return const Icon(
              Icons.star_half,
              size: 14,
              color: Color(0xFFfc9d2d),
            );
          } else if (isFilled) {
            return const Icon(
              Icons.star,
              size: 14,
              color: Color(0xFFfc9d2d),
            );
          } else {
            return Icon(
              Icons.star_border,
              size: 14,
              color: Colors.grey[300],
            );
          }
        }),
        const SizedBox(width: 4),
        Text(
          currentRating.toStringAsFixed(1),
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFfc9d2d),
          ),
        ),
      ],
    );
  }

  /// Build header image based on review type
  Widget _buildHeaderImage(BuildContext context) {
    final sizes = _getResponsiveSizes(context);
    // For menu items, show the item image
    if (widget.reviewType == ReviewType.menuItem && widget.menuItem != null) {
      final imageUrl = widget.menuItem!.images.isNotEmpty
          ? MenuItemImageService().ensureImageUrl(widget.menuItem!.images.first)
          : (widget.menuItem!.image.isNotEmpty
              ? MenuItemImageService().ensureImageUrl(widget.menuItem!.image)
              : null);

      if (imageUrl != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(sizes['borderRadius']),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            width: sizes['imageSize'],
            height: sizes['imageSize'],
            fit: BoxFit.cover,
            placeholder: (ctx, url) => Container(
              width: sizes['imageSize'],
              height: sizes['imageSize'],
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (ctx, url, error) =>
                _buildDefaultIconContainer(context),
          ),
        );
      }
    }

    // For restaurants, show the restaurant logo or image
    if (widget.reviewType == ReviewType.restaurant &&
        widget.restaurant != null) {
      // Prefer logoUrl, fallback to image
      final imageUrl = widget.restaurant!.logoUrl?.isNotEmpty == true
          ? widget.restaurant!.logoUrl
          : widget.restaurant!.image;

      if (imageUrl != null && imageUrl.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(sizes['borderRadius']),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            width: sizes['imageSize'],
            height: sizes['imageSize'],
            fit: BoxFit.cover,
            placeholder: (ctx, url) => Container(
              width: sizes['imageSize'],
              height: sizes['imageSize'],
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (ctx, url, error) =>
                _buildDefaultIconContainer(context),
          ),
        );
      }
    }

    // Default: show icon
    return _buildDefaultIconContainer(context);
  }

  /// Build default icon container
  Widget _buildDefaultIconContainer(BuildContext context) {
    final sizes = _getResponsiveSizes(context);
    return Container(
      width: sizes['imageSize'],
      height: sizes['imageSize'],
      decoration: BoxDecoration(
        color: Colors.orange[600]!.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(sizes['borderRadius']),
      ),
      child: Icon(
        _getIconForReviewType(),
        color: Colors.orange[600],
        size: sizes['imageSize'] * 0.45,
      ),
    );
  }

  /// Get icon based on review type
  IconData _getIconForReviewType() {
    switch (widget.reviewType) {
      case ReviewType.menuItem:
        return Icons.restaurant_menu;
      case ReviewType.restaurant:
        return Icons.store;
      case ReviewType.order:
        return Icons.receipt_long;
    }
  }

  /// Build rating section
  Widget _buildRatingSection(BuildContext context) {
    final sizes = _getResponsiveSizes(context);
    final fontSize = sizes['headingFontSize'];
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.howWouldYouRateIt,
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 20),

        // Star rating selector
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starRating = index + 1;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _rating = starRating;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    starRating <= _rating ? Icons.star : Icons.star_border,
                    size: 33,
                    color: Colors.amber[600],
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 12),

        // Rating text
        Center(
          child: Text(
            _getRatingText(context),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.orange[600],
            ),
          ),
        ),
      ],
    );
  }

  /// Build comment section
  Widget _buildCommentSection(BuildContext context) {
    final sizes = _getResponsiveSizes(context);
    final screenWidth = sizes['screenWidth'];
    final l10n = AppLocalizations.of(context)!;

    // Adaptive text based on screen size
    final titleText = screenWidth < 400
        ? l10n.shareYourExperience
        : l10n.shareYourExperienceOptional;
    final fontSize = screenWidth < 350 ? 16.0 : 18.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titleText,
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _commentController,
          maxLines: 1,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: l10n.tellOthersAboutExperience,
            hintStyle: GoogleFonts.poppins(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.orange[600]!, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  /// Build restaurant review card (for menu items)
  Widget _buildRestaurantReviewCard(BuildContext context) {
    if (widget.menuItem == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final restaurantName =
        widget.menuItem!.restaurantName ?? l10n.reviewRestaurant;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with logo/icon and title
            Row(
              children: [
                // Restaurant logo or icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _restaurantLogoUrl != null
                        ? Colors.white
                        : Colors.orange[600],
                    borderRadius: BorderRadius.circular(12),
                    border: _restaurantLogoUrl != null
                        ? Border.all(color: Colors.grey[200]!, width: 1)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: _restaurantLogoUrl != null
                            ? Colors.black.withValues(alpha: 0.08)
                            : Colors.orange.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _isLoadingRestaurantLogo
                      ? Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.orange[600]!,
                              ),
                            ),
                          ),
                        )
                      : _restaurantLogoUrl != null &&
                              _restaurantLogoUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: _restaurantLogoUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.orange[600]!,
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Icon(
                                    Icons.restaurant,
                                    color: Colors.orange[600],
                                    size: 24,
                                  ),
                                ),
                              ),
                            )
                          : const Padding(
                              padding: EdgeInsets.all(12),
                              child: Icon(
                                Icons.restaurant,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.alsoEnjoying(restaurantName),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.shareRestaurantExperience,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Divider
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey[200]!.withValues(alpha: 0.2),
                    Colors.grey[300]!,
                    Colors.grey[200]!.withValues(alpha: 0.2),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Rating prompt with interactive stars (one row)
            if (!_hasSubmittedRestaurantReview)
              Row(
                children: [
                  // Interactive star icons
                  ...List.generate(5, (index) {
                    final starRating = index + 1;
                    return GestureDetector(
                      onTap: _isSubmittingRestaurantReview
                          ? null
                          : () => _submitRestaurantReview(starRating),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          _restaurantRating != null &&
                                  starRating <= _restaurantRating!
                              ? Icons.star
                              : Icons.star_border,
                          size: 20,
                          color: _restaurantRating != null &&
                                  starRating <= _restaurantRating!
                              ? Colors.orange[600]
                              : Colors.orange[400],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.rateOverallService,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  if (_isSubmittingRestaurantReview)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.orange[600]!,
                        ),
                      ),
                    ),
                ],
              ),

            // Success message after submission
            if (_hasSubmittedRestaurantReview)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green[200]!,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.thankYouForRating(restaurantName),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build photo section
  Widget _buildPhotoSection(BuildContext context) {
    final sizes = _getResponsiveSizes(context);
    final screenWidth = sizes['screenWidth'];
    final l10n = AppLocalizations.of(context)!;

    // Adaptive text based on screen size
    final titleText =
        screenWidth < 400 ? l10n.addPhotos : l10n.addPhotosOptional;
    final fontSize = screenWidth < 350 ? 16.0 : 18.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titleText,
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),

        // Selected images preview
        if (_selectedImages.isNotEmpty) ...[
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 100,
                  height: 100,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: FileImage(_selectedImages[index]),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Add photos button
        ElevatedButton.icon(
          onPressed: _pickImages,
          icon: const Icon(Icons.add_photo_alternate),
          label: Text(
            _selectedImages.isEmpty ? l10n.addPhotosButton : l10n.addMorePhotos,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[600],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      ],
    );
  }

  /// Build bottom submit bar with gradient and rounded top edges
  Widget _buildBottomSubmitBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.95),
            Colors.white,
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: 16 + BottomPaddingHelper.getBottomPadding(context),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitReview,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(27),
              ),
              elevation: _isSubmitting ? 0 : 2,
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    AppLocalizations.of(context)!.submitReview,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
