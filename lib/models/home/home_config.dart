import 'package:flutter/foundation.dart';

/// High-performance, immutable configuration for the home screen module
///
/// This configuration class provides fine-grained control over:
/// - Feature flags for real-time capabilities
/// - Performance optimizations for smooth scrolling and loading
/// - Caching strategies for instant UI rendering
/// - UI enhancements and accessibility features
///
/// All configurations are immutable and thread-safe. Use the predefined presets
/// or create custom configurations with copyWith() for specific use cases.
@immutable
class HomeConfig {
  // ==================== FEATURE FLAGS ====================
  /// Enable real-time notifications and live updates
  /// Default: true - Provides immediate feedback for orders, deliveries, etc.
  final bool enableRealTimeNotifications;

  /// Enable background synchronization for fresh data
  /// Default: true - Keeps data current without user intervention
  final bool enableBackgroundSync;

  /// Enable predictive preloading based on user behavior patterns
  /// Default: true - Improves perceived performance by anticipating user actions
  final bool enablePredictivePreloading;

  /// Enable aggressive image preloading for smoother scrolling
  /// Default: true - Reduces loading delays when scrolling through restaurants
  final bool enableImagePreloading;

  // ==================== PERFORMANCE SETTINGS ====================
  /// Enable scroll performance monitoring and optimization
  /// Default: true - Tracks and optimizes scroll performance for large lists
  final bool enableScrollPerformanceMonitoring;

  /// Enable scroll-based preloading of nearby items
  /// Default: true - Loads content just before it enters viewport
  final bool enableScrollBasedPreloading;

  /// Enable CDN optimization for images (compression, WebP, etc.)
  /// Default: true - Reduces bandwidth usage and improves load times
  final bool enableImageCDNOptimization;

  // ==================== CACHE SETTINGS ====================
  /// Enable global caching for all data types
  /// Default: true - Dramatically improves app responsiveness
  final bool enableGlobalCache;

  /// Enable specific image caching optimizations
  /// Default: true - Prevents repeated image downloads
  final bool enableImageCache;

  /// Enable data caching for restaurants, categories, etc.
  /// Default: true - Provides instant loading from cache
  final bool enableDataCache;

  // ==================== UI SETTINGS ====================
  /// Enable animations and transitions
  /// Default: true - Provides smooth, polished user experience
  final bool enableAnimations;

  /// Enable shimmer loading effects
  /// Default: true - Provides visual feedback during loading states
  final bool enableShimmerEffects;

  /// Enable accessibility features (screen reader support, etc.)
  /// Default: true - Ensures app is usable by all users
  final bool enableAccessibilityFeatures;

  /// Default configuration with balanced performance and features
  static const HomeConfig _default = HomeConfig();

  const HomeConfig({
    this.enableRealTimeNotifications = true,
    this.enableBackgroundSync = true,
    this.enablePredictivePreloading = true,
    this.enableImagePreloading = true,
    this.enableScrollPerformanceMonitoring = true,
    this.enableScrollBasedPreloading = true,
    this.enableImageCDNOptimization = true,
    this.enableGlobalCache = true,
    this.enableImageCache = true,
    this.enableDataCache = true,
    this.enableAnimations = true,
    this.enableShimmerEffects = true,
    this.enableAccessibilityFeatures = true,
  });

  // ==================== PREDEFINED OPTIMIZED PRESETS ====================

  /// Performance-optimized configuration for low-end devices
  /// Disables heavy features while maintaining core functionality
  static const HomeConfig performanceOptimized = HomeConfig(
    enableRealTimeNotifications: true, // Keep for immediate feedback
    enableBackgroundSync: true, // Essential for data freshness
    enablePredictivePreloading: false, // Disable for performance
    enableImagePreloading: true, // Keep for smooth scrolling
    enableScrollPerformanceMonitoring: false, // Disable for performance
    enableScrollBasedPreloading: true, // Keep for UX
    enableImageCDNOptimization: true, // Essential for bandwidth
    enableGlobalCache: true, // Critical for performance
    enableImageCache: true, // Essential for images
    enableDataCache: true, // Critical for instant loading
    enableAnimations: true, // Keep for UX
    enableShimmerEffects: false, // Disable for performance
    enableAccessibilityFeatures: true, // Always keep accessibility
  );

  /// Memory-optimized configuration for devices with limited RAM
  /// Minimizes memory usage while maintaining functionality
  static const HomeConfig memoryOptimized = HomeConfig(
    enableRealTimeNotifications: true, // Keep essential features
    enableBackgroundSync: false, // Disable to save memory
    enablePredictivePreloading: false, // Disable to save memory
    enableImagePreloading: false, // Disable to save memory
    enableScrollPerformanceMonitoring: false, // Disable to save memory
    enableScrollBasedPreloading: false, // Disable to save memory
    enableImageCDNOptimization: false, // Disable to save memory
    enableGlobalCache: false, // Disable to save memory
    enableImageCache: false, // Disable to save memory
    enableDataCache: true, // Keep essential data caching
    enableAnimations: false, // Disable to save memory
    enableShimmerEffects: false, // Disable to save memory
    enableAccessibilityFeatures: true, // Always keep accessibility
  );

  /// Feature-rich configuration for high-end devices
  /// Enables all features for the best user experience
  static const HomeConfig featureRich = HomeConfig(
    enableRealTimeNotifications: true,
    enableBackgroundSync: true,
    enablePredictivePreloading: true,
    enableImagePreloading: true,
    enableScrollPerformanceMonitoring: true,
    enableScrollBasedPreloading: true,
    enableImageCDNOptimization: true,
    enableGlobalCache: true,
    enableImageCache: true,
    enableDataCache: true,
    enableAnimations: true,
    enableShimmerEffects: true,
    enableAccessibilityFeatures: true,
  );

  // ==================== CONVENIENT HELPER METHODS ====================

  /// Check if any caching is enabled
  bool get isCacheEnabled =>
      enableGlobalCache || enableImageCache || enableDataCache;

  /// Check if any synchronization is enabled
  bool get isSyncEnabled => enableBackgroundSync || enableRealTimeNotifications;

  /// Check if any animations are enabled
  bool get isAnimationEnabled => enableAnimations || enableShimmerEffects;

  /// Check if performance optimizations are enabled
  bool get isPerformanceOptimized =>
      !enablePredictivePreloading &&
      !enableScrollPerformanceMonitoring &&
      !enableShimmerEffects;

  /// Check if memory optimizations are active
  bool get isMemoryOptimized =>
      !enableBackgroundSync &&
      !enablePredictivePreloading &&
      !enableImagePreloading &&
      !enableScrollPerformanceMonitoring &&
      !enableScrollBasedPreloading &&
      !enableImageCDNOptimization &&
      !enableGlobalCache &&
      !enableImageCache &&
      !enableAnimations &&
      !enableShimmerEffects;

  /// Get a summary of enabled features for debugging
  Map<String, bool> get featureSummary => {
        'realTimeNotifications': enableRealTimeNotifications,
        'backgroundSync': enableBackgroundSync,
        'predictivePreloading': enablePredictivePreloading,
        'imagePreloading': enableImagePreloading,
        'scrollMonitoring': enableScrollPerformanceMonitoring,
        'scrollPreloading': enableScrollBasedPreloading,
        'imageOptimization': enableImageCDNOptimization,
        'globalCache': enableGlobalCache,
        'imageCache': enableImageCache,
        'dataCache': enableDataCache,
        'animations': enableAnimations,
        'shimmerEffects': enableShimmerEffects,
        'accessibility': enableAccessibilityFeatures,
      };

  // ==================== LIGHTWEIGHT, TYPE-SAFE COPYWITH ====================

  /// Lightweight copyWith that only modifies specified fields and returns same instance if no changes
  HomeConfig copyWith({
    bool? enableRealTimeNotifications,
    bool? enableBackgroundSync,
    bool? enablePredictivePreloading,
    bool? enableImagePreloading,
    bool? enableScrollPerformanceMonitoring,
    bool? enableScrollBasedPreloading,
    bool? enableImageCDNOptimization,
    bool? enableGlobalCache,
    bool? enableImageCache,
    bool? enableDataCache,
    bool? enableAnimations,
    bool? enableShimmerEffects,
    bool? enableAccessibilityFeatures,
  }) {
    // Early return if no changes would be made (optimization)
    if (enableRealTimeNotifications == null &&
        enableBackgroundSync == null &&
        enablePredictivePreloading == null &&
        enableImagePreloading == null &&
        enableScrollPerformanceMonitoring == null &&
        enableScrollBasedPreloading == null &&
        enableImageCDNOptimization == null &&
        enableGlobalCache == null &&
        enableImageCache == null &&
        enableDataCache == null &&
        enableAnimations == null &&
        enableShimmerEffects == null &&
        enableAccessibilityFeatures == null) {
      return this;
    }

    return HomeConfig(
      enableRealTimeNotifications:
          enableRealTimeNotifications ?? this.enableRealTimeNotifications,
      enableBackgroundSync: enableBackgroundSync ?? this.enableBackgroundSync,
      enablePredictivePreloading:
          enablePredictivePreloading ?? this.enablePredictivePreloading,
      enableImagePreloading:
          enableImagePreloading ?? this.enableImagePreloading,
      enableScrollPerformanceMonitoring: enableScrollPerformanceMonitoring ??
          this.enableScrollPerformanceMonitoring,
      enableScrollBasedPreloading:
          enableScrollBasedPreloading ?? this.enableScrollBasedPreloading,
      enableImageCDNOptimization:
          enableImageCDNOptimization ?? this.enableImageCDNOptimization,
      enableGlobalCache: enableGlobalCache ?? this.enableGlobalCache,
      enableImageCache: enableImageCache ?? this.enableImageCache,
      enableDataCache: enableDataCache ?? this.enableDataCache,
      enableAnimations: enableAnimations ?? this.enableAnimations,
      enableShimmerEffects: enableShimmerEffects ?? this.enableShimmerEffects,
      enableAccessibilityFeatures:
          enableAccessibilityFeatures ?? this.enableAccessibilityFeatures,
    );
  }

  // ==================== UTILITY METHODS ====================

  /// Create a configuration based on device performance tier
  factory HomeConfig.forDevicePerformance(
      {required bool isLowEnd, required bool isMidRange}) {
    if (isLowEnd) return HomeConfig.performanceOptimized;
    if (isMidRange) return _default;
    return HomeConfig.featureRich;
  }

  /// Create a configuration based on network conditions
  factory HomeConfig.forNetworkCondition({required bool isSlowConnection}) {
    return isSlowConnection
        ? HomeConfig.memoryOptimized.copyWith(enableImageCDNOptimization: false)
        : _default;
  }

  /// Create a configuration based on user preferences
  factory HomeConfig.forUserPreferences({
    bool reducedAnimations = false,
    bool reducedMotion = false,
  }) {
    return _default.copyWith(
      enableAnimations: !reducedAnimations && !reducedMotion,
      enableShimmerEffects: !reducedMotion,
      enableAccessibilityFeatures: true, // Always enable accessibility
    );
  }

  // ==================== EQUALITY AND HASH CODE ====================

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! HomeConfig) return false;

    return other.enableRealTimeNotifications == enableRealTimeNotifications &&
        other.enableBackgroundSync == enableBackgroundSync &&
        other.enablePredictivePreloading == enablePredictivePreloading &&
        other.enableImagePreloading == enableImagePreloading &&
        other.enableScrollPerformanceMonitoring ==
            enableScrollPerformanceMonitoring &&
        other.enableScrollBasedPreloading == enableScrollBasedPreloading &&
        other.enableImageCDNOptimization == enableImageCDNOptimization &&
        other.enableGlobalCache == enableGlobalCache &&
        other.enableImageCache == enableImageCache &&
        other.enableDataCache == enableDataCache &&
        other.enableAnimations == enableAnimations &&
        other.enableShimmerEffects == enableShimmerEffects &&
        other.enableAccessibilityFeatures == enableAccessibilityFeatures;
  }

  @override
  int get hashCode => Object.hash(
        enableRealTimeNotifications,
        enableBackgroundSync,
        enablePredictivePreloading,
        enableImagePreloading,
        enableScrollPerformanceMonitoring,
        enableScrollBasedPreloading,
        enableImageCDNOptimization,
        enableGlobalCache,
        enableImageCache,
        enableDataCache,
        enableAnimations,
        enableShimmerEffects,
        enableAccessibilityFeatures,
      );

  @override
  String toString() {
    return 'HomeConfig('
        'realTime: $enableRealTimeNotifications, '
        'sync: $enableBackgroundSync, '
        'preload: $enablePredictivePreloading, '
        'cache: $isCacheEnabled, '
        'animations: $isAnimationEnabled, '
        'performanceOptimized: $isPerformanceOptimized, '
        'memoryOptimized: $isMemoryOptimized)';
  }
}
