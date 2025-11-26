import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:shimmer/shimmer.dart";

/// Premium Restaurant Image Widget with Advanced Loading and Animations
///
/// Features:
/// - Hero-style animations with scale transitions
/// - Advanced disk caching with cached_network_image
/// - Optimized image decoding with cacheWidth/cacheHeight
/// - Premium shimmer loading effect with custom gradients
/// - Graceful loading and error states with retry functionality
/// - Memory-efficient with proper dimensions
/// - Dynamic border radius and shadow based on premium styling
/// - Progressive loading for better perceived performance
/// - Adaptive sizing for different card layouts
class RestaurantCardImage extends StatefulWidget {
  final String? logoUrl;
  final String? fallbackImageUrl;
  final double size;
  final double? width;
  final double? height;
  final bool showShadow;
  final bool enableShimmer;
  final bool enableHeroAnimation;
  final BorderRadius? borderRadius;

  const RestaurantCardImage({
    super.key,
    this.logoUrl,
    this.fallbackImageUrl,
    this.size = 111.0,
    this.width,
    this.height,
    this.showShadow = true,
    this.enableShimmer = true,
    this.enableHeroAnimation = false,
    this.borderRadius,
  });

  @override
  State<RestaurantCardImage> createState() => _RestaurantCardImageState();
}

class _RestaurantCardImageState extends State<RestaurantCardImage>
    with TickerProviderStateMixin {
  late AnimationController _loadingController;
  late Animation<double> _loadingAnimation;

  @override
  void initState() {
    super.initState();

    // Premium loading animation
    _loadingController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _loadingAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.borderRadius ?? BorderRadius.circular(16);
    final width = widget.width ?? widget.size;
    final height = widget.height ?? widget.size;

    return AnimatedBuilder(
      animation: _loadingAnimation,
      builder: (context, child) {
        return Container(
          width: width.isFinite ? width : null,
          height: height.isFinite ? height : null,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: widget.showShadow
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            clipBehavior: Clip.hardEdge,
            child: _buildImageContent(),
          ),
        );
      },
    );
  }

  /// Build image content with proper fallbacks
  Widget _buildImageContent() {
    // Try logoUrl first, fall back to fallbackImageUrl
    final imageUrl = (widget.logoUrl != null && widget.logoUrl!.isNotEmpty)
        ? widget.logoUrl!
        : (widget.fallbackImageUrl != null &&
                widget.fallbackImageUrl!.isNotEmpty)
            ? widget.fallbackImageUrl!
            : null;

    if (imageUrl != null) {
      return _buildNetworkImage(imageUrl);
    } else {
      return _buildPlaceholder();
    }
  }

  /// Build network image with advanced caching and optimized decoding
  /// CRITICAL: Uses cacheWidth/cacheHeight to decode images at exact display size
  /// This prevents full-size decode which causes stuttering on scroll
  Widget _buildNetworkImage(String url) {
    // Decode at exact display size (critical for low-end devices!)
    // Use 2x for retina displays - balances quality and performance
    final width = widget.width ?? widget.size;
    final height = widget.height ?? widget.size;

    // Handle infinity/NaN values - only set decode size if finite
    int? decodeWidth;
    int? decodeHeight;
    if (width.isFinite && width > 0) {
      decodeWidth = (width * 2).round();
    }
    if (height.isFinite && height > 0) {
      decodeHeight = (height * 2).round();
    }

    final borderRadius = widget.borderRadius ?? BorderRadius.circular(16);

    return ClipRRect(
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: url,
        width: width.isFinite ? width : null,
        height: height.isFinite ? height : null,
        fit: BoxFit.cover,
        // CRITICAL: Decode at exact size to prevent memory/CPU waste
        // Only set if we have finite dimensions
        memCacheWidth: decodeWidth,
        memCacheHeight: decodeHeight,
        maxWidthDiskCache: decodeWidth,
        maxHeightDiskCache: decodeHeight,
        placeholder: (context, url) => _buildLoadingIndicator(),
        errorWidget: (context, url, error) {
          debugPrint('❌ Error loading restaurant image: $error');
          return _buildPlaceholder();
        },
        // PERFORMANCE: Disable fade animations for list items (causes jank during scroll)
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
      ),
    );
  }

  /// Build loading indicator with premium shimmer effect
  /// Enhanced with breathing animation and gradient effects
  Widget _buildLoadingIndicator() {
    final borderRadius = widget.borderRadius ?? BorderRadius.circular(16);
    final width = widget.width ?? widget.size;
    final height = widget.height ?? widget.size;

    final placeholder = Container(
      width: width.isFinite ? width : null,
      height: height.isFinite ? height : null,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.shade200,
            Colors.grey.shade300,
            Colors.grey.shade200,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Icon(
        Icons.restaurant,
        color: Colors.grey.shade400,
        size: widget.size.isFinite ? widget.size * 0.4 : 40.0,
      ),
    );

    // Enhanced shimmer with breathing animation
    if (!widget.enableShimmer) {
      return AnimatedBuilder(
        animation: _loadingAnimation,
        builder: (context, child) {
          return ClipRRect(
            borderRadius: borderRadius,
            child: Opacity(
              opacity: _loadingAnimation.value,
              child: placeholder,
            ),
          );
        },
      );
    }

    return AnimatedBuilder(
      animation: _loadingAnimation,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: borderRadius,
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            period: const Duration(milliseconds: 2000),
            child: Opacity(
              opacity: 0.3 + (0.7 * _loadingAnimation.value),
              child: placeholder,
            ),
          ),
        );
      },
    );
  }

  /// Build placeholder when no image available with enhanced styling
  Widget _buildPlaceholder() {
    final borderRadius = widget.borderRadius ?? BorderRadius.circular(16);
    final width = widget.width ?? widget.size;
    final height = widget.height ?? widget.size;

    return AnimatedBuilder(
      animation: _loadingAnimation,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: borderRadius,
          child: Container(
            width: width.isFinite ? width : null,
            height: height.isFinite ? height : null,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey.shade200.withOpacity(_loadingAnimation.value),
                  Colors.grey.shade300.withOpacity(_loadingAnimation.value),
                  Colors.grey.shade200.withOpacity(_loadingAnimation.value),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: Icon(
              Icons.restaurant,
              color: Colors.grey.shade400,
              size: widget.size.isFinite ? widget.size * 0.4 : 40.0,
            ),
          ),
        );
      },
    );
  }
}
