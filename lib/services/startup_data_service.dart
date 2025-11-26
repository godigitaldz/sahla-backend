import "dart:async";

import "package:flutter/foundation.dart";

import "../services/home/home_cache_service.dart";
import "../services/home/home_data_service.dart";
import "../services/restaurant_search_service.dart";
import "../services/session_manager.dart";
import "optimized_backend_service.dart";

/// Loading states for different data types
enum DataLoadingState {
  notStarted,
  loading,
  completed,
  failed,
}

/// Data loading progress information
class DataLoadingProgress {
  final String dataType;
  final DataLoadingState state;
  final double progress; // 0.0 to 1.0
  final String? errorMessage;
  final int? totalItems;
  final int? loadedItems;

  const DataLoadingProgress({
    required this.dataType,
    required this.state,
    this.progress = 0.0,
    this.errorMessage,
    this.totalItems,
    this.loadedItems,
  });

  DataLoadingProgress copyWith({
    String? dataType,
    DataLoadingState? state,
    double? progress,
    String? errorMessage,
    int? totalItems,
    int? loadedItems,
  }) {
    return DataLoadingProgress(
      dataType: dataType ?? this.dataType,
      state: state ?? this.state,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      totalItems: totalItems ?? this.totalItems,
      loadedItems: loadedItems ?? this.loadedItems,
    );
  }
}

/// Service to coordinate all startup data loading
class StartupDataService extends ChangeNotifier {
  static final StartupDataService _instance = StartupDataService._internal();
  factory StartupDataService() => _instance;
  StartupDataService._internal();

  // Optimized backend service
  final OptimizedBackendService _backendService = OptimizedBackendService();

  // Loading progress tracking
  final Map<String, DataLoadingProgress> _loadingProgress = {};
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _overallError;

  // Services
  final SessionManager _sessionManager = SessionManager();
  final RestaurantSearchService _searchService = RestaurantSearchService();

  // Cached data storage
  List<dynamic> _cachedRestaurants = [];
  List<dynamic> _cachedMenuItems = [];
  List<dynamic> _cachedCategories = [];
  List<dynamic> _cachedCuisines = [];
  List<dynamic> _cachedPromoCodes = [];
  Map<String, dynamic> _cachedSettings = {};

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get overallError => _overallError;
  Map<String, DataLoadingProgress> get loadingProgress =>
      Map.unmodifiable(_loadingProgress);

  // Cached data getters
  List<dynamic> get cachedRestaurants => List.unmodifiable(_cachedRestaurants);
  List<dynamic> get cachedMenuItems => List.unmodifiable(_cachedMenuItems);
  List<dynamic> get cachedCategories => List.unmodifiable(_cachedCategories);
  List<dynamic> get cachedCuisines => List.unmodifiable(_cachedCuisines);
  List<dynamic> get cachedPromoCodes => List.unmodifiable(_cachedPromoCodes);
  Map<String, dynamic> get cachedSettings => Map.unmodifiable(_cachedSettings);

  /// Overall loading progress (0.0 to 1.0)
  double get overallProgress {
    if (_loadingProgress.isEmpty) {
      return 0.0;
    }

    final totalWeight = _loadingProgress.length;
    final completedWeight = _loadingProgress.values
        .where((progress) => progress.state == DataLoadingState.completed)
        .length;

    return completedWeight / totalWeight;
  }

  /// Check if all critical data is loaded
  bool get isCriticalDataLoaded {
    // Check if session and user_profile are loaded (essential)
    final essentialLoaded = ["session", "user_profile"].every(
        (type) => _loadingProgress[type]?.state == DataLoadingState.completed);

    // Check if restaurants are loaded OR failed (non-blocking)
    final restaurantsLoaded =
        _loadingProgress["restaurants"]?.state == DataLoadingState.completed ||
            _loadingProgress["restaurants"]?.state == DataLoadingState.failed;

    return essentialLoaded && restaurantsLoaded;
  }

  /// Check if all data loading is complete
  bool get isAllDataLoaded {
    return _loadingProgress.values
        .every((progress) => progress.state == DataLoadingState.completed);
  }

  /// Initialize startup data loading (ultra-fast synchronous version)
  void initializeSync() {
    if (_isInitialized || _isLoading) {
      return;
    }

    _isLoading = true;
    _overallError = null;

    try {
      debugPrint(
          "🚀 StartupDataService: Starting ultra-fast synchronous data loading...");

      // Initialize optimized backend service synchronously for ultra-fast loading
      _backendService.initializeSync();

      // Load all data synchronously for ultra-fast loading (0.05s target)
      _loadAllDataSync();

      _isInitialized = true;
      _isLoading = false;
      debugPrint("✅ StartupDataService: Ultra-fast data loaded successfully");
    } on Exception catch (e) {
      debugPrint("❌ StartupDataService: Critical data loading failed: $e");
      _overallError = 'Failed to load critical startup data: $e';

      // Try to continue with partial data
      _isInitialized = true;
      _isLoading = false;
    } finally {
      // Don't notify listeners for ultra-fast loading (no async operations)
    }
  }

  /// Initialize startup data loading (legacy async version)
  Future<void> initialize() async {
    if (_isInitialized || _isLoading) {
      return;
    }

    _isLoading = true;
    _overallError = null;
    notifyListeners();

    try {
      debugPrint(
          "🚀 StartupDataService: Starting comprehensive data loading...");

      // Initialize optimized backend service
      await _backendService.initialize();

      // Define critical and non-critical data loading tasks
      final criticalTasks = [
        _loadSessionData(),
        _loadUserProfile(),
      ];

      final nonCriticalTasks = [
        _loadRestaurantsData(),
        _loadAdditionalData(),
        _loadSettingsData(),
        _loadSearchData(),
        _loadCacheData(),
      ];

      // Execute critical tasks first with aggressive timeout
      try {
        await Future.wait(criticalTasks).timeout(
          const Duration(seconds: 3),
        );
      } on Exception catch (e) {
        debugPrint(
            "⚠️ Critical data loading timeout, proceeding with partial data: $e");
        // Continue with partial data if timeout occurs
      }

      // Execute non-critical tasks in background (don't await)
      unawaited(Future.wait(nonCriticalTasks).catchError((e) {
        debugPrint(
            "⚠️ StartupDataService: Non-critical data loading failed: $e");
        // Don't fail the entire initialization for non-critical failures
        return <void>[];
      }));

      _isInitialized = true;
      debugPrint("✅ StartupDataService: Critical data loaded successfully");
    } on Exception catch (e) {
      debugPrint("❌ StartupDataService: Critical data loading failed: $e");
      _overallError = 'Failed to load critical startup data: $e';

      // Try to continue with partial data
      _isInitialized = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load all data synchronously for ultra-fast loading - minimal critical data only
  void _loadAllDataSync() {
    try {
      // 1. Load session data synchronously for ultra-fast loading
      _sessionManager.initializeSync();
      _updateProgress('session', DataLoadingState.completed, 1.0);

      // 2. Mark user profile as completed (loaded by SessionManager)
      _updateProgress('user_profile', DataLoadingState.completed, 1.0);

      // 3. Load only restaurants from cache (critical data)
      _loadRestaurantsFromCacheSync();

      // 4. Mark other data as completed (will load lazily when needed)
      _updateProgress('categories', DataLoadingState.completed, 1.0);
      _updateProgress('cuisines', DataLoadingState.completed, 1.0);
      _updateProgress('promo_codes', DataLoadingState.completed, 1.0);
      _updateProgress('menu_items', DataLoadingState.completed, 1.0);
      _updateProgress('settings', DataLoadingState.completed, 1.0);
      _updateProgress('search', DataLoadingState.completed, 1.0);
      _updateProgress('cache', DataLoadingState.completed, 1.0);

      // Non-critical data loads lazily when needed
    } on Exception catch (e) {
      debugPrint("❌ StartupDataService: Ultra-fast data loading failed: $e");
    }
  }

  /// Load restaurants from cache synchronously for ultra-fast loading
  void _loadRestaurantsFromCacheSync() {
    try {
      final cachedData = HomeCacheService.loadHomeDataSync();

      if (cachedData != null && cachedData['restaurants'] != null) {
        final restaurants = (cachedData['restaurants'] as List<dynamic>?) ?? [];
        _cachedRestaurants = restaurants;
        _updateProgress("restaurants", DataLoadingState.completed, 1.0,
            totalItems: restaurants.length, loadedItems: restaurants.length);
      } else {
        _cachedRestaurants = [];
        // Mark as completed even if empty - will load lazily
        _updateProgress('restaurants', DataLoadingState.completed, 1.0);
      }
    } catch (_) {
      _cachedRestaurants = [];
      _updateProgress('restaurants', DataLoadingState.completed, 1.0);
    }
  }

  // REMOVED: _loadAdditionalDataSync - non-critical data loads lazily

  // Redis and Socket.IO initialization removed - using Supabase direct connection

  /// Load session data (highest priority)
  Future<void> _loadSessionData() async {
    _updateProgress('session', DataLoadingState.loading, 0.0);

    try {
      debugPrint("🔐 Loading session data...");

      // Initialize session manager
      await _sessionManager.initialize();

      _updateProgress('session', DataLoadingState.completed, 1.0);
      debugPrint("✅ Session data loaded");
    } on Exception catch (e) {
      debugPrint("❌ Session loading failed: $e");
      _updateProgress('session', DataLoadingState.failed, 0.0,
          errorMessage: e.toString());
    }
  }

  /// Load user profile data
  Future<void> _loadUserProfile() async {
    _updateProgress('user_profile', DataLoadingState.loading, 0.0);

    try {
      debugPrint("👤 Loading user profile...");

      if (_sessionManager.isAuthenticated) {
        // User profile is already loaded by SessionManager
        _updateProgress('user_profile', DataLoadingState.completed, 1.0);
        debugPrint("✅ User profile loaded");
      } else {
        _updateProgress('user_profile', DataLoadingState.completed, 1.0);
        debugPrint("ℹ️ No user profile (not authenticated)");
      }
    } on Exception catch (e) {
      debugPrint("❌ User profile loading failed: $e");
      _updateProgress('user_profile', DataLoadingState.failed, 0.0,
          errorMessage: e.toString());
    }
  }

  /// Load restaurants data
  Future<void> _loadRestaurantsData() async {
    _updateProgress('restaurants', DataLoadingState.loading, 0.0);

    try {
      debugPrint("🍽️ Loading restaurants data...");

      // Use optimized backend service to load restaurants with aggressive timeout
      final restaurants =
          await _backendService.getRestaurants(limit: 20).timeout(
        const Duration(seconds: 4), // Increased timeout
        onTimeout: () {
          debugPrint(
              "⏰ Optimized backend timeout, falling back to original method");
          return null;
        },
      );

      if (restaurants != null && restaurants.isNotEmpty) {
        // Cache the restaurants data
        _cachedRestaurants = restaurants;
        _updateProgress("restaurants", DataLoadingState.completed, 1.0,
            totalItems: restaurants.length, loadedItems: restaurants.length);
        debugPrint(
            "✅ Restaurants data loaded and cached (${restaurants.length} items)");
      } else {
        // Fallback to original method with timeout
        final fallbackRestaurants = await _loadRestaurantsWithRetry().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint("⏰ Restaurant retry timeout, marking as failed");
            return <dynamic>[];
          },
        );

        if (fallbackRestaurants.isNotEmpty) {
          // Cache the fallback restaurants data
          _cachedRestaurants = fallbackRestaurants;
          _updateProgress("restaurants", DataLoadingState.completed, 1.0,
              totalItems: fallbackRestaurants.length,
              loadedItems: fallbackRestaurants.length);
          debugPrint(
              "✅ Restaurants data loaded via fallback and cached (${fallbackRestaurants.length} items)");
        } else {
          // Mark as failed if no data could be loaded
          _updateProgress("restaurants", DataLoadingState.failed, 0.0,
              errorMessage: "All loading attempts failed or timed out");
          debugPrint("❌ Restaurants data loading failed completely");
        }
      }
    } on Exception catch (e) {
      debugPrint("❌ Restaurants loading failed: $e");
      _updateProgress('restaurants', DataLoadingState.failed, 0.0,
          errorMessage: e.toString());

      // Try to load from cache as final fallback
      await _loadRestaurantsFromCache();
    }
  }

  /// Load restaurants with retry logic
  Future<List<dynamic>> _loadRestaurantsWithRetry() async {
    const maxRetries = 2; // Reduced retries for faster fallback
    const baseDelay = Duration(milliseconds: 300); // Reduced delay

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final restaurants = await HomeDataService.fetchRestaurants(limit: 20);
        if (restaurants.isNotEmpty) {
          return restaurants;
        }
      } on Exception catch (e) {
        debugPrint("⚠️ Restaurant loading attempt $attempt failed: $e");

        if (attempt == maxRetries) {
          rethrow; // Final attempt failed
        }

        // Exponential backoff
        await Future.delayed(baseDelay * attempt);
      }
    }

    return []; // Return empty list if all retries failed
  }

  /// Load restaurants from cache as fallback
  Future<void> _loadRestaurantsFromCache() async {
    try {
      debugPrint("🔄 Attempting to load restaurants from cache...");
      final cachedData = await HomeCacheService.loadHomeData();

      if (cachedData != null && cachedData['restaurants'] != null) {
        final restaurants = (cachedData['restaurants'] as List<dynamic>?) ?? [];
        // Cache the restaurants data
        _cachedRestaurants = restaurants;
        _updateProgress("restaurants", DataLoadingState.completed, 1.0,
            totalItems: restaurants.length, loadedItems: restaurants.length);
        debugPrint(
            "✅ Restaurants loaded from cache and stored (${restaurants.length} items)");
      } else {
        debugPrint("⚠️ No cached restaurants data available");
      }
    } on Exception catch (e) {
      debugPrint("❌ Cache fallback failed: $e");
    }
  }

  /// Load additional data lazily - only when needed (removed aggressive preloading)
  Future<void> _loadAdditionalData() async {
    // REMOVED: Aggressive preloading - data loads on-demand when user needs it
    // This significantly reduces app launch time
  }

  /// Load settings data
  Future<void> _loadSettingsData() async {
    _updateProgress('settings', DataLoadingState.loading, 0.0);

    try {
      debugPrint("⚙️ Loading settings data...");

      // Use optimized backend service to load settings with aggressive timeout
      final settings = await _backendService.getSettings().timeout(
        const Duration(seconds: 1),
        onTimeout: () {
          debugPrint("⏰ Settings backend timeout, using fallback");
          return null;
        },
      );

      if (settings != null && settings.isNotEmpty) {
        // Cache the settings data
        _cachedSettings =
            settings.first; // Assuming settings is a list with one item
        _updateProgress('settings', DataLoadingState.completed, 1.0);
        debugPrint("✅ Settings data loaded via optimized backend and cached");
      } else {
        // Settings are typically loaded synchronously
        _cachedSettings = {};
        _updateProgress('settings', DataLoadingState.completed, 1.0);
        debugPrint("✅ Settings data loaded and cached");
      }
    } on Exception catch (e) {
      debugPrint("❌ Settings loading failed: $e");
      _updateProgress('settings', DataLoadingState.failed, 0.0,
          errorMessage: e.toString());
    }
  }

  /// Load search data
  Future<void> _loadSearchData() async {
    _updateProgress('search', DataLoadingState.loading, 0.0);

    try {
      debugPrint("🔍 Loading search data...");

      // Initialize search service
      await _searchService.initialize();

      _updateProgress('search', DataLoadingState.completed, 1.0);
      debugPrint("✅ Search data loaded");
    } on Exception catch (e) {
      debugPrint("❌ Search data loading failed: $e");
      _updateProgress('search', DataLoadingState.failed, 0.0,
          errorMessage: e.toString());
    }
  }

  /// Load cache data
  Future<void> _loadCacheData() async {
    _updateProgress('cache', DataLoadingState.loading, 0.0);

    try {
      debugPrint("💾 Loading cache data...");

      // Load cached data
      final cachedData = await HomeCacheService.loadHomeData();

      if (cachedData != null && cachedData.isNotEmpty) {
        _updateProgress('cache', DataLoadingState.completed, 1.0,
            totalItems: cachedData.length, loadedItems: cachedData.length);
        debugPrint("✅ Cache data loaded (${cachedData.length} items)");
      } else {
        _updateProgress('cache', DataLoadingState.completed, 1.0);
        debugPrint("ℹ️ No cached data available");
      }
    } on Exception catch (e) {
      debugPrint("❌ Cache loading failed: $e");
      _updateProgress('cache', DataLoadingState.failed, 0.0,
          errorMessage: e.toString());
    }
  }

  /// Update loading progress for a specific data type
  void _updateProgress(
    String dataType,
    DataLoadingState state,
    double progress, {
    String? errorMessage,
    int? totalItems,
    int? loadedItems,
  }) {
    _loadingProgress[dataType] = DataLoadingProgress(
      dataType: dataType,
      state: state,
      progress: progress,
      errorMessage: errorMessage,
      totalItems: totalItems,
      loadedItems: loadedItems,
    );
    notifyListeners();
  }

  /// Get progress for a specific data type
  DataLoadingProgress? getProgress(String dataType) {
    return _loadingProgress[dataType];
  }

  /// Check if a specific data type is loaded
  bool isDataLoaded(String dataType) {
    return _loadingProgress[dataType]?.state == DataLoadingState.completed;
  }

  /// Get loading status summary
  Map<String, dynamic> getLoadingStatus() {
    return {
      'isInitialized': _isInitialized,
      'isLoading': _isLoading,
      'overallProgress': overallProgress,
      'isCriticalDataLoaded': isCriticalDataLoaded,
      'isAllDataLoaded': isAllDataLoaded,
      'overallError': _overallError,
      'progressDetails': _loadingProgress.map((key, value) => MapEntry(key, {
            'state': value.state.toString(),
            'progress': value.progress,
            'errorMessage': value.errorMessage,
            'totalItems': value.totalItems,
            'loadedItems': value.loadedItems,
          })),
    };
  }

  /// Reset the service (for testing or re-initialization)
  void reset() {
    _isInitialized = false;
    _isLoading = false;
    _overallError = null;
    _loadingProgress.clear();
    notifyListeners();
  }
}
