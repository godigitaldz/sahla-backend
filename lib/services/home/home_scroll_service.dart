// ignore_for_file: use_setters_to_change_properties, avoid_positional_boolean_parameters

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Next-generation high-performance scroll service for Flutter apps
///
/// Manages all scroll behaviors, controllers, and optimizations for complex
/// food delivery/marketplace apps with multiple scrollable sections.
/// Optimized for performance, memory efficiency, and smooth scrolling on all devices.
///
/// Features:
/// - Multi-controller management with auto-disposal
/// - Adaptive scroll physics for different scenarios
/// - Dynamic cache extent and item extent calculation
/// - Advanced scroll actions and state detection
/// - Performance monitoring and lazy loading
/// - Extensible architecture for future scroll behaviors
@immutable
class HomeScrollService {
  // ==================== SCROLL CONTROLLER MANAGEMENT ====================

  /// Registry of all active scroll controllers for proper lifecycle management
  final Map<String, ScrollController> _controllers = {};

  /// Scroll position preservation map for seamless navigation
  final Map<String, double> _savedPositions = {};

  /// Performance tracking for scroll operations
  final Map<String, DateTime> _lastScrollTimes = {};

  /// Debug mode flag for performance logging
  static bool _debugMode = false;

  /// Enable/disable debug logging (zero overhead in production)
  static void setDebugMode(bool enabled) {
    _debugMode = enabled;
  }

  /// Create and register a main scroll controller for the home screen
  ScrollController createMainScrollController({String? key}) {
    final controllerKey = key ?? 'main';
    return _createOrGetController(
      controllerKey,
      () => ScrollController(),
    );
  }

  /// Create and register a restaurants horizontal scroll controller
  ScrollController createRestaurantsScrollController({String? key}) {
    final controllerKey = key ?? 'restaurants';
    return _createOrGetController(
      controllerKey,
      () => ScrollController(),
    );
  }

  /// Create and register a recently viewed scroll controller
  ScrollController createRecentlyViewedScrollController({String? key}) {
    final controllerKey = key ?? 'recently_viewed';
    return _createOrGetController(
      controllerKey,
      () => ScrollController(),
    );
  }

  /// Create and register a promo codes carousel scroll controller
  ScrollController createPromoScrollController({String? key}) {
    final controllerKey = key ?? 'promo_codes';
    return _createOrGetController(
      controllerKey,
      () => ScrollController(),
    );
  }

  /// Create a custom scroll controller with specific key
  ScrollController createCustomScrollController(String key) {
    return _createOrGetController(
      key,
      () => ScrollController(),
    );
  }

  /// Get existing controller safely, create if doesn't exist
  ScrollController _createOrGetController(
      String key, ScrollController Function() factory) {
    if (_controllers.containsKey(key)) {
      return _controllers[key]!;
    }

    final controller = factory();
    _controllers[key] = controller;

    // Add performance tracking listener
    controller.addListener(() => _onScrollUpdate(key, controller));

    if (_debugMode) {
      debugPrint('🏃 HomeScrollService: Created controller for $key');
    }

    return controller;
  }

  /// Get controller by key safely
  ScrollController? getController(String key) {
    return _controllers[key];
  }

  /// Get all registered controller keys for debugging
  Set<String> get registeredControllerKeys =>
      Set.unmodifiable(_controllers.keys);

  /// Save scroll position for a controller key
  void saveScrollPosition(String key) {
    final controller = _controllers[key];
    if (controller != null && controller.hasClients) {
      _savedPositions[key] = controller.offset;
      if (_debugMode) {
        debugPrint(
            '💾 HomeScrollService: Saved position for $key: ${controller.offset}');
      }
    }
  }

  /// Restore scroll position for a controller key
  void restoreScrollPosition(String key) {
    final controller = _controllers[key];
    final savedPosition = _savedPositions[key];

    if (controller != null && savedPosition != null) {
      // Schedule restoration for next frame to ensure layout is complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.hasClients) {
          controller.jumpTo(savedPosition);
          if (_debugMode) {
            debugPrint(
                '🔄 HomeScrollService: Restored position for $key: $savedPosition');
          }
        }
      });
    }
  }

  /// Dispose all registered controllers and clean up resources
  void disposeAllControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _savedPositions.clear();
    _lastScrollTimes.clear();

    if (_debugMode) {
      debugPrint('🗑️ HomeScrollService: Disposed all controllers');
    }
  }

  /// Dispose specific controller by key
  void disposeController(String key) {
    final controller = _controllers.remove(key);
    controller?.dispose();
    _savedPositions.remove(key);
    _lastScrollTimes.remove(key);

    if (_debugMode) {
      debugPrint('🗑️ HomeScrollService: Disposed controller $key');
    }
  }

  /// Scroll update callback for performance tracking
  void _onScrollUpdate(String key, ScrollController controller) {
    _lastScrollTimes[key] = DateTime.now();

    if (_debugMode) {
      debugPrint(
          '📜 HomeScrollService: Scroll update for $key at ${controller.offset}');
    }
  }

  // ==================== SCROLL PHYSICS ====================

  /// Create optimized scroll physics for vertical scrolling
  static ScrollPhysics getVerticalScrollPhysics({
    bool suppressGlow = true,
    double bounceFactor = 0.8,
    double damping = 0.9,
  }) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    ).applyTo(const ClampingScrollPhysics()).applyTo(_CustomScrollPhysics(
          suppressGlow: suppressGlow,
          bounceFactor: bounceFactor,
          damping: damping,
        ));
  }

  /// Create optimized scroll physics for horizontal scrolling
  static ScrollPhysics getHorizontalScrollPhysics({
    bool suppressGlow = true,
    double bounceFactor = 0.8,
    double damping = 0.9,
  }) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    ).applyTo(_CustomScrollPhysics(
      suppressGlow: suppressGlow,
      bounceFactor: bounceFactor,
      damping: damping,
    ));
  }

  /// Create scroll physics for nested scrollables
  static ScrollPhysics getNestedScrollPhysics() {
    return const NeverScrollableScrollPhysics();
  }

  /// Create scroll physics for sticky headers
  static ScrollPhysics getStickyHeaderPhysics() {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }

  // ==================== CACHE EXTENT & ITEM EXTENT ====================

  /// Calculate optimal cache extent based on screen size and device capabilities
  static double calculateCacheExtent(
    BuildContext context, {
    double multiplier = 2.0,
    bool isHorizontal = false,
  }) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) {
      return 500.0 * multiplier; // reasonable fallback
    }
    final screenSize =
        isHorizontal ? mediaQuery.size.width : mediaQuery.size.height;
    final pixelRatio = mediaQuery.devicePixelRatio;

    // Adaptive cache extent based on device capabilities
    final baseExtent = screenSize * multiplier;
    final adaptiveExtent = baseExtent / pixelRatio.clamp(1.0, 3.0);

    return adaptiveExtent;
  }

  /// Calculate optimal item extent for horizontal restaurant cards
  static double calculateHorizontalItemExtent(
    BuildContext context, {
    double widthRatio = 0.85, // 85% of screen width
    double aspectRatio = 0.75, // 3:4 aspect ratio for cards
  }) {
    final mq = MediaQuery.maybeOf(context);
    final screenWidth = mq?.size.width ?? 360.0;
    final itemWidth = screenWidth * widthRatio;

    // Ensure minimum and maximum item widths
    return itemWidth.clamp(200.0, 400.0);
  }

  /// Calculate optimal item extent for vertical lists
  static double calculateVerticalItemExtent(
    BuildContext context, {
    double heightRatio = 0.15, // 15% of screen height
    double minHeight = 80.0,
    double maxHeight = 200.0,
  }) {
    final mq = MediaQuery.maybeOf(context);
    final screenHeight = mq?.size.height ?? 640.0;
    final itemHeight = screenHeight * heightRatio;

    return itemHeight.clamp(minHeight, maxHeight);
  }

  // ==================== SCROLL ACTIONS ====================

  /// Animate to top position with smooth curve
  Future<void> animateToTop(String controllerKey,
      {Duration? duration, Curve? curve}) async {
    await _executeScrollAction(controllerKey, (controller) async {
      if (controller.hasClients) {
        await controller.animateTo(
          0.0,
          duration: duration ?? const Duration(milliseconds: 300),
          curve: curve ?? Curves.easeOut,
        );
      }
    });
    return;
  }

  /// Animate to bottom position with smooth curve
  Future<void> animateToBottom(String controllerKey,
      {Duration? duration, Curve? curve}) async {
    await _executeScrollAction(controllerKey, (controller) async {
      if (controller.hasClients) {
        final maxExtent = controller.position.maxScrollExtent;
        await controller.animateTo(
          maxExtent,
          duration: duration ?? const Duration(milliseconds: 300),
          curve: curve ?? Curves.easeOut,
        );
      }
    });
    return;
  }

  /// Animate to specific position with smooth curve
  Future<void> animateToPosition(String controllerKey, double position,
      {Duration? duration, Curve? curve}) async {
    await _executeScrollAction(controllerKey, (controller) async {
      if (controller.hasClients) {
        await controller.animateTo(
          position,
          duration: duration ?? const Duration(milliseconds: 300),
          curve: curve ?? Curves.easeOut,
        );
      }
    });
  }

  /// Jump immediately to position (no animation)
  void jumpToPosition(String controllerKey, double position) {
    _executeScrollActionSync(controllerKey, (controller) {
      if (controller.hasClients) {
        controller.jumpTo(position);
      }
    });
  }

  /// Jump immediately to top
  void jumpToTop(String controllerKey) {
    jumpToPosition(controllerKey, 0.0);
  }

  /// Jump immediately to bottom
  void jumpToBottom(String controllerKey) {
    _executeScrollActionSync(controllerKey, (controller) {
      if (controller.hasClients) {
        controller.jumpTo(controller.position.maxScrollExtent);
      }
    });
  }

  /// Scroll to specific item in a list (requires item index and extent)
  Future<void> scrollToItem(
    String controllerKey,
    int itemIndex,
    double itemExtent, {
    Duration? duration,
    Curve? curve,
    bool alignToTop = true,
  }) async {
    final position = itemIndex * itemExtent;
    await animateToPosition(controllerKey, position,
        duration: duration, curve: curve);
  }

  /// Execute scroll action safely with error handling
  Future<void> _executeScrollAction(
    String controllerKey,
    Future<void> Function(ScrollController) action,
  ) async {
    try {
      final controller = _controllers[controllerKey];
      if (controller != null) {
        await action(controller);
      } else if (_debugMode) {
        debugPrint(
            '⚠️ HomeScrollService: No controller found for key $controllerKey');
      }
    } catch (e) {
      if (_debugMode) {
        debugPrint(
            '❌ HomeScrollService: Scroll action failed for $controllerKey: $e');
      }
    }
  }

  /// Execute scroll action safely with error handling (sync version)
  void _executeScrollActionSync(
    String controllerKey,
    void Function(ScrollController) action,
  ) {
    try {
      final controller = _controllers[controllerKey];
      if (controller != null) {
        action(controller);
      } else if (_debugMode) {
        debugPrint(
            '⚠️ HomeScrollService: No controller found for key $controllerKey');
      }
    } catch (e) {
      if (_debugMode) {
        debugPrint(
            '❌ HomeScrollService: Scroll action failed for $controllerKey: $e');
      }
    }
  }

  // ==================== SCROLL STATE & UTILITIES ====================

  /// Check if scroll controller is at top (within tolerance)
  bool isAtTop(String controllerKey, {double tolerance = 10.0}) {
    final controller = _controllers[controllerKey];
    return controller?.hasClients == true &&
        (controller!.offset - tolerance) <= 0;
  }

  /// Check if scroll controller is at bottom (within tolerance)
  bool isAtBottom(String controllerKey, {double tolerance = 10.0}) {
    final controller = _controllers[controllerKey];
    if (controller?.hasClients != true) return false;

    final maxExtent = controller!.position.maxScrollExtent;
    return (controller.offset + tolerance) >= maxExtent;
  }

  /// Check if scroll controller is near top (within threshold)
  bool isNearTop(String controllerKey, {double threshold = 100.0}) {
    final controller = _controllers[controllerKey];
    return controller?.hasClients == true && controller!.offset <= threshold;
  }

  /// Check if scroll controller is near bottom (within threshold)
  bool isNearBottom(String controllerKey, {double threshold = 100.0}) {
    final controller = _controllers[controllerKey];
    if (controller?.hasClients != true) return false;

    final maxExtent = controller!.position.maxScrollExtent;
    return (controller.offset + threshold) >= maxExtent;
  }

  /// Check if controller can scroll in a specific direction
  bool canScrollInDirection(String controllerKey, AxisDirection direction) {
    final controller = _controllers[controllerKey];
    if (controller?.hasClients != true) return false;

    switch (direction) {
      case AxisDirection.up:
        return controller!.offset > 0;
      case AxisDirection.down:
        return controller!.offset < controller.position.maxScrollExtent;
      case AxisDirection.left:
        return controller!.offset > 0;
      case AxisDirection.right:
        return controller!.offset < controller.position.maxScrollExtent;
    }
  }

  /// Get current scroll position safely
  double? getCurrentPosition(String controllerKey) {
    final controller = _controllers[controllerKey];
    return controller?.hasClients == true ? controller!.offset : null;
  }

  /// Get maximum scroll extent safely
  double? getMaxScrollExtent(String controllerKey) {
    final controller = _controllers[controllerKey];
    return controller?.hasClients == true
        ? controller!.position.maxScrollExtent
        : null;
  }

  /// Get viewport dimension safely
  double? getViewportDimension(String controllerKey) {
    final controller = _controllers[controllerKey];
    return controller?.hasClients == true
        ? controller!.position.viewportDimension
        : null;
  }

  /// Get scroll velocity (for performance monitoring)
  double? getScrollVelocity(String controllerKey) {
    final controller = _controllers[controllerKey];
    if (controller?.hasClients != true) return null;

    // Calculate velocity based on recent position changes
    final lastScrollTime = _lastScrollTimes[controllerKey];
    if (lastScrollTime == null) return 0.0;

    final timeDiff = DateTime.now().difference(lastScrollTime).inMilliseconds;
    if (timeDiff == 0) return 0.0;

    final positionDiff = controller!.offset -
        (_savedPositions[controllerKey] ?? controller.offset);
    return (positionDiff.abs() / timeDiff) * 1000; // pixels per second
  }

  // ==================== PERFORMANCE OPTIMIZATIONS ====================

  /// Create optimized ListView.builder with performance settings
  Widget createOptimizedVerticalList({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    String? controllerKey,
    double? cacheExtent,
    double? itemExtent,
    ScrollPhysics? physics,
    EdgeInsetsGeometry? padding,
    bool addRepaintBoundaries = true,
    bool addAutomaticKeepAlives = true,
    bool addSemanticIndexes = true,
    VoidCallback? onScrollNotification,
  }) {
    return ListView.builder(
      controller: controllerKey != null ? getController(controllerKey) : null,
      physics: physics ?? getVerticalScrollPhysics(),
      cacheExtent: cacheExtent,
      itemExtent: itemExtent,
      padding: padding,
      itemCount: itemCount,
      addRepaintBoundaries: addRepaintBoundaries,
      addAutomaticKeepAlives: addAutomaticKeepAlives,
      addSemanticIndexes: addSemanticIndexes,
      itemBuilder: (context, index) {
        if (onScrollNotification != null) {
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              onScrollNotification();
              return false;
            },
            child: itemBuilder(context, index),
          );
        }
        return itemBuilder(context, index);
      },
    );
  }

  /// Create optimized horizontal ListView.builder
  Widget createOptimizedHorizontalList({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    String? controllerKey,
    double? cacheExtent,
    double? itemExtent,
    ScrollPhysics? physics,
    EdgeInsetsGeometry? padding,
    bool addRepaintBoundaries = true,
    bool addAutomaticKeepAlives = true,
    bool addSemanticIndexes = true,
    VoidCallback? onScrollNotification,
  }) {
    return ListView.builder(
      controller: controllerKey != null ? getController(controllerKey) : null,
      physics: physics ?? getHorizontalScrollPhysics(),
      cacheExtent: cacheExtent,
      itemExtent: itemExtent,
      padding: padding,
      scrollDirection: Axis.horizontal,
      itemCount: itemCount,
      addRepaintBoundaries: addRepaintBoundaries,
      addAutomaticKeepAlives: addAutomaticKeepAlives,
      addSemanticIndexes: addSemanticIndexes,
      itemBuilder: (context, index) {
        if (onScrollNotification != null) {
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              onScrollNotification();
              return false;
            },
            child: itemBuilder(context, index),
          );
        }
        return itemBuilder(context, index);
      },
    );
  }

  /// Create RefreshIndicator wrapper with optimized refresh behavior
  Widget createRefreshableList({
    required Widget child,
    required Future<void> Function() onRefresh,
    String? controllerKey,
    RefreshIndicatorTriggerMode triggerMode =
        RefreshIndicatorTriggerMode.onEdge,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      triggerMode: triggerMode,
      child: child,
      // Optimize refresh indicator performance
      notificationPredicate: (ScrollNotification notification) {
        return notification.depth == 0; // Only handle top-level scrolls
      },
    );
  }

  /// Create infinite scroll detector for automatic loading
  Widget createInfiniteScrollDetector({
    required Widget child,
    required VoidCallback onLoadMore,
    String? controllerKey,
    double loadMoreThreshold = 100.0,
  }) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification) {
          final controller =
              controllerKey != null ? _controllers[controllerKey] : null;
          if (controller?.hasClients == true) {
            final isNearBottom = controller!.offset >=
                (controller.position.maxScrollExtent - loadMoreThreshold);

            if (isNearBottom) {
              onLoadMore();
            }
          }
        }
        return false;
      },
      child: child,
    );
  }

  // ==================== REUSABLE WIDGETS ====================

  /// Create optimized restaurant card list widget
  Widget createRestaurantCardList({
    required List<Widget> restaurants,
    String? controllerKey,
    EdgeInsetsGeometry? padding,
    bool enableInfiniteScroll = false,
    VoidCallback? onLoadMore,
  }) {
    return createRefreshableList(
      onRefresh: () async {
        // Implement refresh logic if needed
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: enableInfiniteScroll && onLoadMore != null
          ? createInfiniteScrollDetector(
              child: createOptimizedHorizontalList(
                itemCount: restaurants.length,
                itemBuilder: (context, index) => restaurants[index],
                controllerKey: controllerKey,
                // Use defaults; avoid direct MediaQuery dependency here
                physics: getHorizontalScrollPhysics(),
                padding: padding,
              ),
              onLoadMore: onLoadMore,
              controllerKey: controllerKey,
            )
          : createOptimizedHorizontalList(
              itemCount: restaurants.length,
              itemBuilder: (context, index) => restaurants[index],
              controllerKey: controllerKey,
              // Use defaults; avoid direct MediaQuery dependency here
              physics: getHorizontalScrollPhysics(),
              padding: padding,
            ),
    );
  }

  /// Create optimized vertical list widget
  Widget createVerticalList({
    required List<Widget> items,
    String? controllerKey,
    EdgeInsetsGeometry? padding,
    bool enablePullToRefresh = false,
    Future<void> Function()? onRefresh,
    bool enableInfiniteScroll = false,
    VoidCallback? onLoadMore,
    double loadMoreThreshold = 100.0,
  }) {
    Widget child = createOptimizedVerticalList(
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
      controllerKey: controllerKey,
      // Use defaults; avoid direct MediaQuery dependency here
      physics: getVerticalScrollPhysics(),
      padding: padding,
    );

    if (enablePullToRefresh && onRefresh != null) {
      child = createRefreshableList(
        onRefresh: onRefresh,
        child: child,
      );
    }

    if (enableInfiniteScroll && onLoadMore != null) {
      child = createInfiniteScrollDetector(
        child: child,
        onLoadMore: onLoadMore,
        controllerKey: controllerKey,
        loadMoreThreshold: loadMoreThreshold,
      );
    }

    return child;
  }

  // ==================== EXTENSIBILITY HOOKS ====================

  /// Hook for future sticky header implementation
  Widget createStickyHeaderList({
    required Widget header,
    required Widget list,
    String? controllerKey,
  }) {
    // Placeholder for future sticky header implementation
    return list;
  }

  /// Hook for future parallax effects
  Widget createParallaxList({
    required Widget list,
    required Widget parallaxChild,
    String? controllerKey,
    double parallaxFactor = 0.5,
  }) {
    // Placeholder for future parallax implementation
    return list;
  }

  /// Hook for future scroll-based animations
  Widget createAnimatedList({
    required Widget list,
    required Animation<double> animation,
    String? controllerKey,
  }) {
    // Placeholder for future scroll animation implementation
    return list;
  }

  // ==================== PERFORMANCE MONITORING ====================

  /// Get scroll performance metrics for debugging
  Map<String, dynamic> getScrollMetrics(String controllerKey) {
    final controller = _controllers[controllerKey];
    final lastScrollTime = _lastScrollTimes[controllerKey];

    return {
      'hasClients': controller?.hasClients ?? false,
      'position': controller?.offset ?? 0.0,
      'maxExtent': controller?.position.maxScrollExtent ?? 0.0,
      'viewportDimension': controller?.position.viewportDimension ?? 0.0,
      'lastScrollTime': lastScrollTime?.toIso8601String(),
      'velocity': getScrollVelocity(controllerKey) ?? 0.0,
      'isAtTop': isAtTop(controllerKey),
      'isAtBottom': isAtBottom(controllerKey),
      'isNearTop': isNearTop(controllerKey),
      'isNearBottom': isNearBottom(controllerKey),
    };
  }

  /// Get overall performance summary
  Map<String, dynamic> getPerformanceSummary() {
    return {
      'totalControllers': _controllers.length,
      'savedPositions': _savedPositions.length,
      'lastActivities': _lastScrollTimes
          .map((key, value) => MapEntry(key, value.toIso8601String())),
      'debugMode': _debugMode,
    };
  }

  /// Export scroll state for persistence
  Map<String, dynamic> exportScrollState() {
    return {
      'savedPositions': _savedPositions,
      'lastScrollTimes': _lastScrollTimes
          .map((key, value) => MapEntry(key, value.toIso8601String())),
      'controllerKeys': _controllers.keys.toList(),
    };
  }

  /// Import scroll state from persistence
  void importScrollState(Map<String, dynamic> state) {
    final savedPositions = state['savedPositions'] as Map<String, dynamic>?;
    final lastScrollTimes = state['lastScrollTimes'] as Map<String, dynamic>?;

    if (savedPositions != null) {
      _savedPositions.addAll(
          savedPositions.map((key, value) => MapEntry(key, value as double)));
    }

    if (lastScrollTimes != null) {
      _lastScrollTimes.addAll(lastScrollTimes
          .map((key, value) => MapEntry(key, DateTime.parse(value as String))));
    }

    if (_debugMode) {
      debugPrint('📥 HomeScrollService: Imported scroll state');
    }
  }

  /// Reset all scroll states
  void resetScrollStates() {
    _savedPositions.clear();
    _lastScrollTimes.clear();

    if (_debugMode) {
      debugPrint('🔄 HomeScrollService: Reset all scroll states');
    }
  }

  @override
  String toString() {
    return 'HomeScrollService(controllers: ${_controllers.length}, positions: ${_savedPositions.length})';
  }
}

/// Custom scroll physics for enhanced performance and behavior
class _CustomScrollPhysics extends ScrollPhysics {
  final bool suppressGlow;
  final double bounceFactor;
  final double damping;

  const _CustomScrollPhysics({
    required this.suppressGlow,
    required this.bounceFactor,
    required this.damping,
    super.parent,
  });

  @override
  _CustomScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _CustomScrollPhysics(
      suppressGlow: suppressGlow,
      bounceFactor: bounceFactor,
      damping: damping,
      parent: buildParent(ancestor),
    );
  }

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
        mass: 1.0,
        stiffness: 100.0,
        ratio: damping,
      );

  @override
  double get dragStartDistanceMotionThreshold => 3.0;

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    // Suppress overscroll glow if requested
    if (suppressGlow) {
      return null;
    }

    final tolerance = toleranceFor(position);
    if (position.outOfRange) {
      final end = position.outOfRange
          ? position.pixels.clamp(
              position.minScrollExtent,
              position.maxScrollExtent,
            )
          : position.pixels;

      return SpringSimulation(
        spring,
        position.pixels,
        end,
        velocity * bounceFactor,
      );
    }

    if (velocity.abs() < tolerance.velocity) return null;

    final end =
        position.pixels + velocity * 0.5; // Reduced velocity for smoother stop
    return SpringSimulation(
      spring,
      position.pixels,
      end,
      velocity,
    );
  }
}

/// Example usage widget demonstrating scroll service capabilities
class ScrollServiceExample extends StatelessWidget {
  ScrollServiceExample({super.key});

  final HomeScrollService scrollService = HomeScrollService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scroll Service Example')),
      body: Column(
        children: [
          // Example: Pull-to-refresh vertical list
          Expanded(
            child: scrollService.createVerticalList(
              items: List.generate(
                  50, (index) => ListTile(title: Text('Item $index'))),
              controllerKey: 'main',
              enablePullToRefresh: true,
              onRefresh: () async => Future.delayed(const Duration(seconds: 1)),
              enableInfiniteScroll: true,
              onLoadMore: () => debugPrint('Load more items'),
            ),
          ),

          // Example: Horizontal restaurant carousel
          SizedBox(
            height: 200,
            child: scrollService.createRestaurantCardList(
              restaurants: List.generate(
                10,
                (index) => Container(
                  width: 200,
                  margin: const EdgeInsets.all(8),
                  color: Colors.orange.shade100,
                  child: Center(child: Text('Restaurant $index')),
                ),
              ),
              controllerKey: 'restaurants',
              enableInfiniteScroll: true,
              onLoadMore: () => debugPrint('Load more restaurants'),
            ),
          ),
        ],
      ),
    );
  }
}
