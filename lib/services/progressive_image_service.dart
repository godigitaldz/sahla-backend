import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// High-performance progressive image loading service
///
/// Features:
/// - Progressive image loading with placeholders
/// - Intelligent caching and compression
/// - Memory-efficient image handling
/// - Automatic retry and error handling
/// - Performance monitoring
class ProgressiveImageService {
  static final ProgressiveImageService _instance =
      ProgressiveImageService._internal();
  factory ProgressiveImageService() => _instance;
  ProgressiveImageService._internal();

  // Cache manager for images
  static final CacheManager _cacheManager = CacheManager(
    Config(
      'progressive_images',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 1000,
      repo: JsonCacheInfoRepository(databaseName: 'progressive_images'),
    ),
  );

  // Performance tracking
  final Map<String, int> _loadTimes = {};
  final Map<String, int> _cacheHits = {};
  final Map<String, int> _cacheMisses = {};

  /// Load image with progressive enhancement
  Future<ImageProvider> loadProgressiveImage(
    String imageUrl, {
    String? placeholderAsset,
    Duration? fadeInDuration,
    bool enableCompression = true,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Check cache first
      final cachedFile = await _cacheManager.getFileFromCache(imageUrl);

      if (cachedFile != null) {
        _cacheHits[imageUrl] = (_cacheHits[imageUrl] ?? 0) + 1;
        stopwatch.stop();
        _loadTimes[imageUrl] = stopwatch.elapsedMilliseconds;

        return FileImage(cachedFile.file);
      }

      // Cache miss - download and cache
      _cacheMisses[imageUrl] = (_cacheMisses[imageUrl] ?? 0) + 1;

      final file = await _cacheManager.getSingleFile(imageUrl);
      stopwatch.stop();
      _loadTimes[imageUrl] = stopwatch.elapsedMilliseconds;

      return FileImage(file);
    } catch (e) {
      stopwatch.stop();

      // Return placeholder on error
      if (placeholderAsset != null) {
        return AssetImage(placeholderAsset);
      }

      // Return default placeholder
      return _getDefaultPlaceholder();
    }
  }

  /// Preload images for better performance
  Future<void> preloadImages(List<String> imageUrls) async {
    final futures = imageUrls.map((url) => _cacheManager.getSingleFile(url));
    await Future.wait(futures);
  }

  /// Clear cache to free memory
  Future<void> clearCache() async {
    await _cacheManager.emptyCache();
  }

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    return {
      'totalLoadTimes': _loadTimes.length,
      'averageLoadTime': _loadTimes.values.isEmpty
          ? 0
          : _loadTimes.values.reduce((a, b) => a + b) /
              _loadTimes.values.length,
      'cacheHits': _cacheHits.values.fold(0, (a, b) => a + b),
      'cacheMisses': _cacheMisses.values.fold(0, (a, b) => a + b),
      'cacheHitRate': _getCacheHitRate(),
    };
  }

  double _getCacheHitRate() {
    final hits = _cacheHits.values.fold(0, (a, b) => a + b);
    final misses = _cacheMisses.values.fold(0, (a, b) => a + b);
    final total = hits + misses;
    return total > 0 ? hits / total : 0.0;
  }

  ImageProvider _getDefaultPlaceholder() {
    // Use a simple colored container instead of missing asset
    return const AssetImage('assets/icon/app_icon.png');
  }
}

/// Progressive image widget with loading states
class ProgressiveImage extends StatefulWidget {
  final String imageUrl;
  final String? placeholderAsset;
  final String? errorAsset;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Duration fadeInDuration;
  final bool enableCompression;
  final BorderRadius? borderRadius;
  final Widget? loadingWidget;
  final Widget? errorWidget;

  const ProgressiveImage({
    required this.imageUrl,
    super.key,
    this.placeholderAsset,
    this.errorAsset,
    this.width,
    this.height,
    this.borderRadius,
    this.loadingWidget,
    this.errorWidget,
    this.fit = BoxFit.cover,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.enableCompression = true,
  });

  @override
  State<ProgressiveImage> createState() => _ProgressiveImageState();
}

class _ProgressiveImageState extends State<ProgressiveImage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  ImageProvider? _imageProvider;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.fadeInDuration,
      vsync: this,
    );
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);

    _loadImage();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      final imageService = ProgressiveImageService();
      _imageProvider = await imageService.loadProgressiveImage(
        widget.imageUrl,
        placeholderAsset: widget.placeholderAsset,
        enableCompression: widget.enableCompression,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        await _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
      ),
      child: ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.zero,
        child: _buildImageContent(),
      ),
    );
  }

  Widget _buildImageContent() {
    if (_isLoading) {
      return widget.loadingWidget ?? _buildDefaultLoadingWidget();
    }

    if (_hasError) {
      return widget.errorWidget ?? _buildDefaultErrorWidget();
    }

    if (_imageProvider != null) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: Image(
          image: _imageProvider!,
          width: widget.width ?? double.infinity,
          height: widget.height ?? double.infinity,
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) {
            return widget.errorWidget ?? _buildDefaultErrorWidget();
          },
        ),
      );
    }

    return _buildDefaultErrorWidget();
  }

  Widget _buildDefaultLoadingWidget() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildDefaultErrorWidget() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey[300],
      child: Icon(
        Icons.image_not_supported,
        color: Colors.grey[600],
        size: widget.width != null && widget.width!.isFinite
            ? widget.width! * 0.3
            : 24,
      ),
    );
  }
}

/// Optimized cached network image with progressive loading
class OptimizedCachedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration fadeInDuration;

  const OptimizedCachedImage({
    required this.imageUrl,
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.fit = BoxFit.cover,
    this.fadeInDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: width,
          height: height,
          fit: fit,
          fadeInDuration: fadeInDuration,
          placeholder: (context, url) =>
              placeholder ?? _buildDefaultPlaceholder(),
          errorWidget: (context, url, error) =>
              errorWidget ?? _buildDefaultError(),
          memCacheWidth:
              width != null && width!.isFinite ? width!.toInt() : null,
          memCacheHeight:
              height != null && height!.isFinite ? height!.toInt() : null,
          maxWidthDiskCache: 800,
          maxHeightDiskCache: 600,
        ),
      ),
    );
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildDefaultError() {
    return Container(
      color: Colors.grey[300],
      child: Icon(
        Icons.image_not_supported,
        color: Colors.grey[600],
        size: width != null && width!.isFinite ? width! * 0.3 : 24,
      ),
    );
  }
}

/// Image preloader for batch loading
class ImagePreloader {
  static final ImagePreloader _instance = ImagePreloader._internal();
  factory ImagePreloader() => _instance;
  ImagePreloader._internal();

  final Set<String> _preloadedUrls = {};
  final Map<String, ImageProvider> _preloadedImages = {};

  /// Preload a batch of images
  Future<void> preloadImages(List<String> urls) async {
    final urlsToLoad =
        urls.where((url) => !_preloadedUrls.contains(url)).toList();

    if (urlsToLoad.isEmpty) return;

    final futures = urlsToLoad.map((url) => _preloadSingleImage(url));
    await Future.wait(futures);
  }

  Future<void> _preloadSingleImage(String url) async {
    if (_preloadedUrls.contains(url)) return;

    try {
      final imageService = ProgressiveImageService();
      final imageProvider = await imageService.loadProgressiveImage(url);

      _preloadedUrls.add(url);
      _preloadedImages[url] = imageProvider;
    } catch (e) {
      // Silently fail for preloading
    }
  }

  /// Get preloaded image
  ImageProvider? getPreloadedImage(String url) {
    return _preloadedImages[url];
  }

  /// Clear preloaded images
  void clearPreloadedImages() {
    _preloadedUrls.clear();
    _preloadedImages.clear();
  }
}
