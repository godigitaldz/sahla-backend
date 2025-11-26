import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";

/// Performance optimization utilities for high-performance UI
class PerformanceUtils {
  /// Optimized image cache configuration
  static void configureImageCache() {
    // Increase image cache size for better performance
    PaintingBinding.instance.imageCache.maximumSize = 1000;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 200 << 20; // 200 MB
  }

  /// Debounce function to prevent excessive calls
  /// Performance: Returns a wrapper that properly manages timer cleanup
  static Function debounce(Function func, Duration delay) {
    Timer? timer;

    // Performance: Return a function that includes cleanup capability
    void debouncedFunction([Object? arg]) {
      timer?.cancel();
      timer = Timer(delay, () {
        try {
          // Check if the function expects parameters by examining its signature
          if (arg != null) {
            // Try to call the function with the argument
            func(arg);
          } else {
            // Call without arguments for VoidCallback
            func();
          }
        } on Exception catch (e) {
          debugPrint("⚡ Error calling debounced function: $e");
          // Try the alternative approach
          try {
            if (arg != null) {
              func();
            } else {
              func(arg);
            }
          } on Exception catch (e2) {
            debugPrint("⚡ Error in fallback debounced function call: $e2");
          }
        }
      });
    }

    return debouncedFunction;
  }

  /// Performance: Debounce with manual cleanup capability
  static ({Function call, void Function() dispose}) debounceWithCleanup(
    Function func,
    Duration delay,
  ) {
    Timer? timer;

    void callFunction([Object? arg]) {
      timer?.cancel();
      timer = Timer(delay, () {
        try {
          if (arg != null) {
            func(arg);
          } else {
            func();
          }
        } on Exception catch (e) {
          debugPrint("⚡ Error calling debounced function: $e");
        }
      });
    }

    void disposeFunction() {
      timer?.cancel();
      timer = null;
    }

    return (call: callFunction, dispose: disposeFunction);
  }

  /// Throttle function to limit call frequency
  static Function throttle(Function func, Duration delay) {
    bool isThrottled = false;

    return (
        [List<dynamic>? positionalArguments,
        Map<Symbol, dynamic>? namedArguments]) {
      if (!isThrottled) {
        Function.apply(func, positionalArguments, namedArguments);
        isThrottled = true;
        Timer(delay, () {
          isThrottled = false;
        });
      }
    };
  }

  /// Preload images for better performance
  static Future<void> preloadImages(
      BuildContext context, List<String> imageUrls) async {
    debugPrint(
        "🖼️ PerformanceUtils.preloadImages() called with ${imageUrls.length} images");
    final futures = imageUrls.map((url) {
      return precacheImage(NetworkImage(url), context);
    }).toList();

    await Future.wait(futures);
    debugPrint("✅ PerformanceUtils.preloadImages() completed successfully");
  }

  /// Optimize list view performance with automatic keep alive
  static Widget optimizedListView({
    required List<Widget> children,
    ScrollController? controller,
    ScrollPhysics? physics,
    EdgeInsets? padding,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
    Axis scrollDirection = Axis.horizontal,
  }) {
    return ListView.builder(
      controller: controller,
      physics: physics ?? const BouncingScrollPhysics(),
      padding: padding,
      scrollDirection: scrollDirection,
      itemCount: children.length,
      addAutomaticKeepAlives: addAutomaticKeepAlives,
      addRepaintBoundaries: addRepaintBoundaries,
      addSemanticIndexes: addSemanticIndexes,
      itemBuilder: (context, index) => children[index],
    );
  }

  /// Create optimized network image with caching
  static Widget optimizedNetworkImage({
    required String url,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
    FilterQuality filterQuality = FilterQuality.low,
  }) {
    // Safe width and height calculations to prevent NaN/Infinity errors
    final safeWidth = (width != null && width.isFinite) ? width : null;
    final safeHeight = (height != null && height.isFinite) ? height : null;

    return Image.network(
      url,
      width: safeWidth,
      height: safeHeight,
      fit: fit,
      filterQuality: filterQuality,
      cacheWidth: safeWidth?.round(),
      cacheHeight: safeHeight?.round(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return placeholder ??
            SizedBox(
              width: safeWidth,
              height: safeHeight,
              child: const Center(child: CircularProgressIndicator()),
            );
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ??
            SizedBox(
              width: safeWidth,
              height: safeHeight,
              child: const Icon(Icons.error),
            );
      },
    );
  }

  /// Memory-efficient shimmer widget
  static Widget buildShimmer({
    required double width,
    required double height,
    BorderRadius? borderRadius,
    Color? baseColor,
    Color? highlightColor,
  }) {
    // Safe width and height calculations to prevent NaN/Infinity errors
    final safeWidth = width.isFinite ? width : 100.0;
    final safeHeight = height.isFinite ? height : 100.0;

    return Container(
      width: safeWidth,
      height: safeHeight,
      decoration: BoxDecoration(
        color: baseColor ?? Colors.grey[300],
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
    );
  }

  /// Optimize scroll performance
  static ScrollPhysics get optimizedScrollPhysics =>
      const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );

  /// Reduce widget rebuilds with const constructors
  static Widget constWrapper({
    required Widget child,
    Key? key,
  }) {
    return _ConstWrapper(key: key, child: child);
  }

  /// Haptic feedback helper
  static void lightHaptic() {
    HapticFeedback.lightImpact();
  }

  static void mediumHaptic() {
    HapticFeedback.mediumImpact();
  }

  static void heavyHaptic() {
    HapticFeedback.heavyImpact();
  }

  /// Performance monitoring
  static void measurePerformance(String label, VoidCallback callback) {
    final stopwatch = Stopwatch()..start();
    callback();
    stopwatch.stop();
    debugPrint("Performance [$label]: ${stopwatch.elapsedMilliseconds}ms");
  }

  /// Performance monitoring that returns the widget
  static Widget measurePerformanceWidget(
      String label, Widget Function() builder) {
    final stopwatch = Stopwatch()..start();
    final widget = builder();
    stopwatch.stop();
    debugPrint("Performance [$label]: ${stopwatch.elapsedMilliseconds}ms");
    return widget;
  }

  /// Lazy loading helper
  static Widget lazyBuilder({
    required Widget Function() builder,
    bool condition = true,
  }) {
    return condition ? builder() : const SizedBox.shrink();
  }
}

/// Const wrapper to prevent unnecessary rebuilds
class _ConstWrapper extends StatelessWidget {
  const _ConstWrapper({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Performance-optimized cached network image widget
class OptimizedCachedImage extends StatefulWidget {
  const OptimizedCachedImage({
    required this.imageUrl,
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  @override
  State<OptimizedCachedImage> createState() => _OptimizedCachedImageState();
}

class _OptimizedCachedImageState extends State<OptimizedCachedImage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: PerformanceUtils.optimizedNetworkImage(
        url: widget.imageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        placeholder: widget.placeholder,
        errorWidget: widget.errorWidget,
      ),
    );
  }
}

/// Performance-optimized list tile
class OptimizedListTile extends StatelessWidget {
  const OptimizedListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.contentPadding,
    this.dense = false,
  });

  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsets? contentPadding;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: contentPadding ?? const EdgeInsets.all(16),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title != null) title!,
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        subtitle!,
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 16),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mixin for automatic disposal of resources
mixin AutoDisposeMixin<T extends StatefulWidget> on State<T> {
  final List<VoidCallback> _disposers = [];

  void addDisposer(VoidCallback disposer) {
    _disposers.add(disposer);
  }

  @override
  void dispose() {
    for (final disposer in _disposers) {
      disposer();
    }
    _disposers.clear();
    super.dispose();
  }
}

/// Extension for performance utilities
extension PerformanceExtension on Widget {
  Widget get repaintBoundary => RepaintBoundary(child: this);

  Widget get constWrapper => PerformanceUtils.constWrapper(child: this);

  Widget conditional({required bool condition}) =>
      condition ? this : const SizedBox.shrink();
}
