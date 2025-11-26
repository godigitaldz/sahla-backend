import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../utils/performance_utils.dart';
// import 'package:shared_preferences/shared_preferences.dart'; // Removed local persistence

class ImageLoadingService {
  // Cache for failed images to avoid repeated attempts
  static final Set<String> _failedImages = <String>{};

  // Performance tracking
  static final Map<String, int> _loadTimes = <String, int>{};
  static final Map<String, int> _loadCounts = <String, int>{};

  // Load image with enhanced caching and error handling
  static Widget loadImage({
    required String imagePath,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget? placeholder,
    Widget? errorWidget,
    bool enableFadeIn = true,
    Duration fadeInDuration = const Duration(milliseconds: 300),
    bool enableRetry = true,
    int maxRetries = 3,
    VoidCallback? onLoadComplete,
    VoidCallback? onLoadError,
  }) {
    // Check for empty image path
    if (imagePath.isEmpty) {
      onLoadError?.call();
      return errorWidget ?? _buildDefaultErrorWidget(width, height);
    }

    // Check if it's a network image or asset
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return _buildNetworkImage(
        imagePath: imagePath,
        width: width,
        height: height,
        fit: fit,
        borderRadius: borderRadius,
        placeholder: placeholder,
        errorWidget: errorWidget,
        enableFadeIn: enableFadeIn,
        fadeInDuration: fadeInDuration,
        enableRetry: enableRetry,
        maxRetries: maxRetries,
        onLoadComplete: onLoadComplete,
        onLoadError: onLoadError,
      );
    } else {
      return _buildAssetImage(
        imagePath: imagePath,
        width: width,
        height: height,
        fit: fit,
        borderRadius: borderRadius,
        placeholder: placeholder,
        errorWidget: errorWidget,
        enableFadeIn: enableFadeIn,
        fadeInDuration: fadeInDuration,
        onLoadComplete: onLoadComplete,
        onLoadError: onLoadError,
      );
    }
  }

  // Load network image with enhanced caching
  static Widget _buildNetworkImage({
    required String imagePath,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget? placeholder,
    Widget? errorWidget,
    bool enableFadeIn = true,
    Duration fadeInDuration = const Duration(milliseconds: 300),
    bool enableRetry = true,
    int maxRetries = 3,
    VoidCallback? onLoadComplete,
    VoidCallback? onLoadError,
  }) {
    // Previously we skipped retrying failed URLs. Allow retries to recover from transient errors or permission changes.

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: imagePath,
        width: width,
        height: height,
        fit: fit,
        fadeInDuration: enableFadeIn ? fadeInDuration : Duration.zero,
        errorWidget: (context, url, error) {
          _trackLoadError(imagePath);
          onLoadError?.call();
          return errorWidget ?? _buildDefaultErrorWidget(width, height);
        },
        httpHeaders: _getDefaultHeaders(),
        memCacheWidth: width.isFinite ? (width * 2).round() : null,
        memCacheHeight: height.isFinite ? (height * 2).round() : null,
        maxWidthDiskCache: width.isFinite ? (width * 2).round() : null,
        maxHeightDiskCache: height.isFinite ? (height * 2).round() : null,
        cacheKey: _generateCacheKey(imagePath),
        placeholder: (context, url) =>
            placeholder ?? _buildDefaultPlaceholder(width, height),
      ),
    );
  }

  // Load asset image with enhanced error handling
  static Widget _buildAssetImage({
    required String imagePath,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget? placeholder,
    Widget? errorWidget,
    bool enableFadeIn = true,
    Duration fadeInDuration = const Duration(milliseconds: 300),
    VoidCallback? onLoadComplete,
    VoidCallback? onLoadError,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: AnimatedSwitcher(
        duration: enableFadeIn ? fadeInDuration : Duration.zero,
        child: Image.asset(
          imagePath,
          width: width,
          height: height,
          fit: fit,
          key: ValueKey(imagePath),
          errorBuilder: (context, error, stackTrace) {
            _trackLoadError(imagePath);
            onLoadError?.call();
            return errorWidget ?? _buildDefaultErrorWidget(width, height);
          },
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) {
              _trackLoadSuccess(imagePath);
              onLoadComplete?.call();
              return child;
            }
            return AnimatedOpacity(
              opacity: frame == null ? 0.0 : 1.0,
              duration: enableFadeIn ? fadeInDuration : Duration.zero,
              child: child,
            );
          },
        ),
      ),
    );
  }

  // Enhanced default placeholder widget
  static Widget _buildDefaultPlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.grey.shade400,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Loading...',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Enhanced default error widget with retry option
  static Widget _buildDefaultErrorWidget(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image,
              size: 32,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'Image not available',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Preload images with enhanced performance tracking using PerformanceUtils
  static Future<void> preloadImages(
      List<String> imagePaths, BuildContext context) async {
    final stopwatch = Stopwatch()..start();

    // Use PerformanceUtils for efficient batch preloading
    await PerformanceUtils.preloadImages(context, imagePaths);

    stopwatch.stop();
    debugPrint(
        '📸 ImageLoadingService: Preloaded ${imagePaths.length} images in ${stopwatch.elapsedMilliseconds}ms');
  }

  // Enhanced cache management
  static Future<void> clearImageCache() async {
    try {
      // Clear memory cache
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // Clear failed images cache
      _failedImages.clear();

      // Clear performance tracking
      _loadTimes.clear();
      _loadCounts.clear();

      debugPrint('Image cache cleared successfully');
    } catch (e) {
      debugPrint('Error clearing image cache: $e');
    }
  }

  // Get cache statistics
  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      return {
        'failedImages': _failedImages.length,
        'loadTimes': _loadTimes.length,
        'loadCounts': _loadCounts.length,
        'hasData': false,
        'cacheSize': 0,
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'failedImages': _failedImages.length,
        'loadTimes': _loadTimes.length,
        'loadCounts': _loadCounts.length,
      };
    }
  }

  // Optimize image for display with enhanced features
  static Widget buildOptimizedImage({
    required String imagePath,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    bool enableBlurHash = true,
    String? blurHash,
    Widget? placeholder,
    Widget? errorWidget,
    bool enableRetry = true,
    VoidCallback? onLoadComplete,
    VoidCallback? onLoadError,
  }) {
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: CachedNetworkImage(
          imageUrl: imagePath,
          width: width,
          height: height,
          fit: fit,
          placeholder: (context, url) {
            if (enableBlurHash && blurHash != null) {
              return _buildBlurHashPlaceholder(blurHash, width, height);
            }
            return placeholder ?? _buildDefaultPlaceholder(width, height);
          },
          errorWidget: (context, url, error) {
            return errorWidget ?? _buildDefaultErrorWidget(width, height);
          },
          memCacheWidth: (width * 2).round(),
          memCacheHeight: (height * 2).round(),
          maxWidthDiskCache: (width * 2).round(),
          maxHeightDiskCache: (height * 2).round(),
          cacheKey: _generateCacheKey(imagePath),
        ),
      );
    } else {
      return _buildAssetImage(
        imagePath: imagePath,
        width: width,
        height: height,
        fit: fit,
        borderRadius: borderRadius,
        placeholder: placeholder,
        errorWidget: errorWidget,
        onLoadComplete: onLoadComplete,
        onLoadError: onLoadError,
      );
    }
  }

  // Build blur hash placeholder for better loading experience
  static Widget _buildBlurHashPlaceholder(
      String blurHash, double width, double height) {
    // Note: This would require a blur hash package
    // For now, return a simple placeholder
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          Icons.image,
          size: 32,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }

  // Load hero image with enhanced transition
  static Widget buildHeroImage({
    required String imagePath,
    required String heroTag,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget? placeholder,
    Widget? errorWidget,
    VoidCallback? onLoadComplete,
    VoidCallback? onLoadError,
  }) {
    return Hero(
      tag: heroTag,
      child: loadImage(
        imagePath: imagePath,
        width: width,
        height: height,
        fit: fit,
        borderRadius: borderRadius,
        placeholder: placeholder,
        errorWidget: errorWidget,
        enableFadeIn: true,
        fadeInDuration: const Duration(milliseconds: 500),
        onLoadComplete: onLoadComplete,
        onLoadError: onLoadError,
      ),
    );
  }

  // Load restaurant image with lazy loading
  static Widget buildRestaurantImage({
    required String imagePath,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    bool isVisible = true,
    VoidCallback? onLoadComplete,
    VoidCallback? onLoadError,
  }) {
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: loadImage(
        imagePath: imagePath,
        width: width,
        height: height,
        fit: fit,
        borderRadius: borderRadius,
        enableFadeIn: true,
        fadeInDuration: const Duration(milliseconds: 400),
        onLoadComplete: onLoadComplete,
        onLoadError: onLoadError,
      ),
    );
  }

  // Load menu item image with lazy loading
  static Widget buildMenuItemImage({
    required String imagePath,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    bool isVisible = true,
    VoidCallback? onLoadComplete,
    VoidCallback? onLoadError,
  }) {
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: loadImage(
        imagePath: imagePath,
        width: width,
        height: height,
        fit: fit,
        borderRadius: borderRadius,
        enableFadeIn: true,
        fadeInDuration: const Duration(milliseconds: 400),
        onLoadComplete: onLoadComplete,
        onLoadError: onLoadError,
      ),
    );
  }

  // Load food delivery app image with optimized settings
  static Widget buildFoodDeliveryImage({
    required String imagePath,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget? placeholder,
    Widget? errorWidget,
    bool enableFadeIn = true,
    VoidCallback? onLoadComplete,
    VoidCallback? onLoadError,
  }) {
    return buildOptimizedImage(
      imagePath: imagePath,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      placeholder: placeholder ?? _buildFoodDeliveryPlaceholder(width, height),
      errorWidget: errorWidget ?? _buildFoodDeliveryErrorWidget(width, height),
      onLoadComplete: onLoadComplete,
      onLoadError: onLoadError,
    );
  }

  // Build food delivery specific placeholder
  static Widget _buildFoodDeliveryPlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant,
              size: 32,
              color: Colors.orange.shade300,
            ),
            const SizedBox(height: 8),
            Text(
              'Loading food image...',
              style: TextStyle(
                color: Colors.orange.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build food delivery specific error widget
  static Widget _buildFoodDeliveryErrorWidget(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 32,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'Food image not available',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  static String _generateCacheKey(String imagePath) {
    return 'food_delivery_app_${imagePath.hashCode}';
  }

  static Map<String, String> _getDefaultHeaders() {
    return {
      'User-Agent': 'Food Delivery App',
      'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
    };
  }

  static void _trackLoadSuccess(String imagePath) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _loadTimes[imagePath] = now;
    _loadCounts[imagePath] = (_loadCounts[imagePath] ?? 0) + 1;
  }

  static void _trackLoadError(String imagePath) {
    _failedImages.add(imagePath);
    debugPrint('Image load failed: $imagePath');
  }

  // Get performance statistics
  static Map<String, dynamic> getPerformanceStats() {
    return {
      'totalLoads': _loadCounts.values.fold(0, (sum, count) => sum + count),
      'uniqueImages': _loadCounts.length,
      'failedImages': _failedImages.length,
      'averageLoadTime': _calculateAverageLoadTime(),
    };
  }

  static double _calculateAverageLoadTime() {
    if (_loadTimes.isEmpty) return 0.0;

    final now = DateTime.now().millisecondsSinceEpoch;
    final times = _loadTimes.values.map((time) => now - time).toList();
    return times.reduce((a, b) => a + b) / times.length;
  }
}
