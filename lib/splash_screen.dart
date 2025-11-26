import "dart:async";
import "dart:ui";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "home_screen.dart";
import "screens/permissions_screen.dart";
import "screens/phone_auth_screen.dart";
import "services/home/home_cache_service.dart";
import "services/performance_monitoring_service.dart";
import "services/permission_flow_service.dart";
import "services/realtime_service.dart";
import "services/session_manager.dart";
import "services/startup_data_service.dart";
import "services/transition_service.dart";

/// Configuration constants for splash screen behavior
class SplashScreenConfig {
  static const Duration fastSessionTimeout = Duration(milliseconds: 2000);
  static const Duration criticalDataTimeout = Duration(milliseconds: 15000);
  static const Duration realtimeInitTimeout = Duration(seconds: 2);
  static const Duration cacheWarmTimeout = Duration(seconds: 3);

  // GIF duration - must match the actual splash.gif duration
  // Update this value to match your splash.gif file duration
  static const Duration splashGifDuration = Duration(seconds: 3);

  static const double tabletBreakpoint = 600.0;
  static const double highRefreshRateThreshold = 60.0;

  // Animation durations (ms)
  static const int fadeAnimationDuration = 800;
  static const int blurAnimationDuration = 600;
  static const int loaderAnimationDuration = 400;
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _blurController;
  late AnimationController _loaderController;

  // Animation definitions
  late Animation<double> _fadeAnimation;
  late Animation<double> _blurAnimation;
  late Animation<double> _loaderAnimation;

  // State management
  bool _didNavigate = false;
  bool _showLoader = false;
  bool _isHighEndDevice = false;
  bool _gifCompleted = false;
  bool _sessionReady = false;
  bool _dataReady = false;
  Timer? _sessionTimeoutTimer;
  Timer? _loaderTimer;
  Timer? _gifTimer;

  // Data loading state
  late StartupDataService _startupDataService;
  Map<String, DataLoadingProgress> _loadingProgress = {};
  double _overallProgress = 0.0;

  late RealtimeService _realtimeService;
  late PerformanceMonitoringService _performanceService;

  // Performance detection - using configuration constants

  @override
  void initState() {
    super.initState();

    // Initialize startup data service
    _startupDataService = StartupDataService();

    _realtimeService = RealtimeService();
    _performanceService = PerformanceMonitoringService();

    // Detect device performance for adaptive animations
    _detectDevicePerformance();

    // Initialize animations with performance-adaptive durations
    _initializeAnimations();

    // Start GIF timer to wait for GIF completion
    _startGifTimer();

    // Start comprehensive data loading and navigation logic
    _initializeDataLoadingAndNavigation();

    // Record performance metrics
    _recordPerformanceMetrics();
  }

  void _detectDevicePerformance() {
    // Simple heuristic: check if device supports high refresh rate
    final display = WidgetsBinding.instance.platformDispatcher.displays.first;
    _isHighEndDevice =
        display.refreshRate > SplashScreenConfig.highRefreshRateThreshold;
  }

  /// Record performance metrics for monitoring
  void _recordPerformanceMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = ModalRoute.of(context);
      if (route != null && mounted) {
        final screenSize = MediaQuery.of(context).size;
        final isTablet = screenSize.width > SplashScreenConfig.tabletBreakpoint;

        _performanceService.recordMetric(
          'splash_screen_build_time',
          Duration.zero, // You might want to track actual build time
          metadata: {
            'is_high_end_device': _isHighEndDevice,
            'screen_size': '${screenSize.width}x${screenSize.height}',
            'is_tablet': isTablet,
            'refresh_rate': WidgetsBinding
                .instance.platformDispatcher.displays.first.refreshRate,
          },
        );
      }
    });
  }

  /// Start timer to wait for GIF to complete
  void _startGifTimer() {
    _gifTimer = Timer(SplashScreenConfig.splashGifDuration, () {
      if (mounted) {
        setState(() {
          _gifCompleted = true;
        });
        _checkIfReadyToNavigate();
      }
    });
  }

  void _initializeAnimations() {
    // Fade animation - consistent across devices
    _fadeController = AnimationController(
      duration: const Duration(
          milliseconds: SplashScreenConfig.fadeAnimationDuration),
      vsync: this,
    );

    // Blur animation - subtle effect for high-end devices
    _blurController = AnimationController(
      duration: const Duration(
          milliseconds: SplashScreenConfig.blurAnimationDuration),
      vsync: this,
    );

    // Loader animation
    _loaderController = AnimationController(
      duration: const Duration(
          milliseconds: SplashScreenConfig.loaderAnimationDuration),
      vsync: this,
    );

    // Define animation curves
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOutCubic,
    );

    _blurAnimation = Tween<double>(
      begin: 2,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _blurController,
      curve: Curves.easeOutQuart,
    ));

    _loaderAnimation = CurvedAnimation(
      parent: _loaderController,
      curve: Curves.easeInOut,
    );

    // Start animations
    _fadeController.forward();
    if (_isHighEndDevice) {
      _blurController.forward();
    }
  }

  Future<void> _initializeDataLoadingAndNavigation() async {
    try {
      // Pre-initialize cache for synchronous access
      await _preInitializeCache();

      // Start ultra-fast synchronous initialization (non-blocking)
      _startupDataService.initializeSync();

      // Get SessionManager from Provider
      if (!mounted) return;
      final sessionManager =
          Provider.of<SessionManager>(context, listen: false);

      // Initialize realtime in background (non-blocking)
      unawaited(_initializeRealtimeServices());

      // Listen for data loading progress updates
      _startupDataService.addListener(_onDataLoadingProgress);

      // Simplified timeout - only show loader if data takes too long
      _sessionTimeoutTimer = Timer(SplashScreenConfig.fastSessionTimeout, () {
        if (mounted && _startupDataService.isLoading) {
          _handleLoaderDisplay();
        }
      });

      // Safety timeout - proceed even if data not fully loaded
      Timer(SplashScreenConfig.criticalDataTimeout, () {
        if (mounted && !_didNavigate && !_startupDataService.isCriticalDataLoaded) {
          setState(() {
            _dataReady = true;
          });
          _checkIfReadyToNavigate();
        }
      });

      // Listen for session state changes
      sessionManager.addListener(_onSessionStateChanged);
    } catch (e) {
      if (mounted) {
        _performFallbackNavigation();
      }
    }
  }

  /// Pre-initialize cache for synchronous access
  Future<void> _preInitializeCache() async {
    try {
      await HomeCacheService.preInitialize();
    } catch (e) {
      // Continue without cached data
    }
  }

  /// Initialize Realtime services (Supabase) - background, non-blocking
  Future<void> _initializeRealtimeServices() async {
    try {
      await _realtimeService
          .initialize()
          .timeout(SplashScreenConfig.realtimeInitTimeout, onTimeout: () {
        // Timeout is expected, continue in background
      });
    } catch (e) {
      // Continue without realtime - it will initialize later if needed
    }
  }

  /// Warm Redis cache for faster subsequent requests
  // Redis cache warming and critical data preloading removed - using Supabase directly

  void _onDataLoadingProgress() {
    if (!mounted) return;

    setState(() {
      _loadingProgress = _startupDataService.loadingProgress;
      _overallProgress = _startupDataService.overallProgress;
    });

    // Mark data as ready when critical data is loaded
    if (_startupDataService.isCriticalDataLoaded) {
      setState(() {
        _dataReady = true;
      });
      _checkIfReadyToNavigate();
    }
  }

  void _onSessionStateChanged() {
    final sessionManager = Provider.of<SessionManager>(context, listen: false);

    // Mark session as ready when it's not loading
    if (!sessionManager.isLoading) {
      setState(() {
        _sessionReady = true;
      });
      _checkIfReadyToNavigate();
    }
  }

  /// Check if all conditions are met to navigate (GIF completed + data ready + session ready)
  void _checkIfReadyToNavigate() {
    if (_didNavigate || !mounted) return;

    // Wait for GIF to complete AND (data ready OR session ready)
    if (_gifCompleted && (_dataReady || _sessionReady)) {
      final sessionManager =
          Provider.of<SessionManager>(context, listen: false);
      _performNavigation(sessionManager);
    }
  }

  /// Handle loader display with safety checks
  void _handleLoaderDisplay() {
    if (!mounted || _showLoader) return;

    setState(() => _showLoader = true);
    _loaderController.forward().then((_) {
      // Optional: Add subtle pulse animation to loader
      if (mounted && _showLoader) {
        _loaderController.repeat(reverse: true);
      }
    });
  }

  void _performNavigation(SessionManager sessionManager) {
    if (!mounted || _didNavigate) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ensure navigation happens after current frame
      _safeNavigate(sessionManager);
    });
  }

  void _safeNavigate(SessionManager sessionManager) {
    if (!mounted || _didNavigate) return;

    // Cancel any pending timers
    _sessionTimeoutTimer?.cancel();
    _loaderTimer?.cancel();

    _didNavigate = true;
    sessionManager.removeListener(_onSessionStateChanged);
    _startupDataService.removeListener(_onDataLoadingProgress);

    // Check authentication first, then permissions
    _checkAuthenticationAndNavigate(sessionManager);
  }

  /// Check authentication first, then permissions
  Future<void> _checkAuthenticationAndNavigate(
      SessionManager sessionManager) async {
    try {
      // First check if user is authenticated
      if (!sessionManager.isAuthenticated) {
        if (mounted) {
          unawaited(TransitionService.replaceWithTransition(
            context,
            const PhoneAuthScreen(),
            transitionType: TransitionType.fade,
          ));
        }
        return;
      }

      // User is authenticated, now check permissions
      await _checkPermissionsAndNavigate(sessionManager);
    } catch (e) {
      debugPrint("❌ SplashScreen: Error checking authentication: $e");
      // On error, show phone auth screen
      if (mounted) {
        unawaited(TransitionService.replaceWithTransition(
          context,
          const PhoneAuthScreen(),
          transitionType: TransitionType.fade,
        ));
      }
    }
  }

  /// Check permissions and navigate accordingly (for authenticated users)
  Future<void> _checkPermissionsAndNavigate(
      SessionManager sessionManager) async {
    try {
      // Check if permissions screen should be shown
      final shouldShowPermissions =
          await PermissionFlowService.shouldShowPermissionsScreen();

      if (shouldShowPermissions) {
        if (mounted) {
          unawaited(TransitionService.replaceWithTransition(
            context,
            const PermissionsScreen(),
            transitionType: TransitionType.fade,
          ));
        }
        return;
      }

      // All permissions granted, proceed to home screen
      if (mounted) {
        unawaited(TransitionService.replaceWithTransition(
          context,
          const HomeScreen(),
          transitionType: TransitionType.fade,
        ));
      }
    } catch (e) {
      // On error, proceed to home screen
      if (mounted) {
        unawaited(TransitionService.replaceWithTransition(
          context,
          const HomeScreen(),
          transitionType: TransitionType.fade,
        ));
      }
    }
  }

  void _performFallbackNavigation() {
    if (!mounted || _didNavigate) {
      return;
    }

    _didNavigate = true;

    // Fallback to PhoneAuthScreen on any error
    TransitionService.replaceWithTransition(
      context,
      const PhoneAuthScreen(),
      transitionType: TransitionType.fade,
    );
  }

  @override
  void dispose() {
    // Cancel all timers first
    _sessionTimeoutTimer?.cancel();
    _loaderTimer?.cancel();
    _gifTimer?.cancel();

    // Remove listeners to prevent memory leaks
    _startupDataService.removeListener(_onDataLoadingProgress);

      // Get SessionManager safely and remove listener
    try {
      final sessionManager = context.read<SessionManager>();
      sessionManager.removeListener(_onSessionStateChanged);
    } catch (e) {
      // Context might be disposed, ignore error
    }

    // Dispose animation controllers
    _fadeController.dispose();
    _blurController.dispose();
    _loaderController.dispose();

    // Clean up realtime service
    _realtimeService.dispose();

    // Dispose performance service if applicable
    try {
      _performanceService.dispose();
    } catch (e) {
      debugPrint("⚠️ SplashScreen: Could not dispose performance service: $e");
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > SplashScreenConfig.tabletBreakpoint;

    return Scaffold(
      backgroundColor: Colors.orange,
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Semantics(
        label: 'Splash Screen',
        child: Stack(
          children: [
            // Main splash content
            _buildSplashContent(screenSize, isTablet),

            // Loading overlay (shows only if data loading takes time)
            if (_showLoader)
              FadeTransition(
                opacity: _loaderAnimation,
                child: Semantics(
                  label:
                      'Loading progress ${(_overallProgress * 100).toInt()}%',
                  child: Container(
                    color: Colors.orange.withValues(alpha: 0.1),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Overall progress indicator
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                value: _overallProgress,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.orange[600]!),
                                backgroundColor: Colors.orange[100],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Loading your experience...",
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "${(_overallProgress * 100).toInt()}% complete",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Individual progress items
                            if (_loadingProgress.isNotEmpty)
                              SizedBox(
                                width: 200,
                                child: Column(
                                  children:
                                      _loadingProgress.entries.map((entry) {
                                    final progress = entry.value;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          Icon(
                                            progress.state ==
                                                    DataLoadingState.completed
                                                ? Icons.check_circle
                                                : progress.state ==
                                                        DataLoadingState.failed
                                                    ? Icons.error
                                                    : Icons.hourglass_empty,
                                            size: 12,
                                            color: progress.state ==
                                                    DataLoadingState.completed
                                                ? Colors.green
                                                : progress.state ==
                                                        DataLoadingState.failed
                                                    ? Colors.red
                                                    : Colors.orange,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _getProgressLabel(
                                                  progress.dataType),
                                              style: TextStyle(
                                                color: Colors.grey[700],
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplashContent(Size screenSize, bool isTablet) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Stack(
        children: [
          // Background image with responsive sizing
          Positioned.fill(
            child: _buildBackgroundImage(screenSize, isTablet),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundImage(Size screenSize, bool isTablet) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.orange,
        image: DecorationImage(
          image: AssetImage("assets/splash.gif"),
          fit: BoxFit.cover,
        ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: _isHighEndDevice ? _blurAnimation.value : 0.0,
          sigmaY: _isHighEndDevice ? _blurAnimation.value : 0.0,
        ),
        child: Container(
          color: Colors.transparent,
        ),
      ),
    );
  }

  String _getProgressLabel(String dataType) {
    switch (dataType) {
      case 'session':
        return 'Session';
      case 'user_profile':
        return 'User Profile';
      case 'restaurants':
        return 'Restaurants';
      case 'settings':
        return 'Settings';
      case 'search':
        return 'Search Data';
      case 'cache':
        return 'Cache';
      case 'realtime_session':
        return 'Realtime Session';
      case 'realtime':
        return 'Real-time Service';
      case 'cache_warming':
        return 'Cache Warming';
      case 'critical_data_preload':
        return 'Data Preload';
      default:
        return dataType;
    }
  }
}
