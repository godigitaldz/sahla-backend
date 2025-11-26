// ignore_for_file: prefer_foreach

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'optimized_backend_service.dart';

/// Intelligent Data Prefetching and Caching Service
///
/// Features:
/// - Machine learning-based prefetching
/// - User behavior analysis
/// - Predictive caching
/// - Performance optimization
/// - Render-optimized strategies
class IntelligentPrefetchService {
  static final IntelligentPrefetchService _instance =
      IntelligentPrefetchService._internal();
  factory IntelligentPrefetchService() => _instance;
  IntelligentPrefetchService._internal();

  // Backend service
  final OptimizedBackendService _backendService = OptimizedBackendService();

  // User behavior tracking
  final Map<String, UserBehavior> _userBehaviors = {};
  final Map<String, int> _accessCounts = {};
  final Map<String, DateTime> _lastAccessTimes = {};
  final Map<String, List<String>> _accessPatterns = {};

  // Prefetching strategies
  final Map<String, PrefetchStrategy> _prefetchStrategies = {};
  final Map<String, CacheEntry> _prefetchedData = {};

  // Performance metrics
  final Map<String, PerformanceMetrics> _performanceMetrics = {};

  // Shared preferences
  SharedPreferences? _prefs;

  // Configuration
  static const Duration _behaviorTrackingWindow = Duration(hours: 24);

  /// Initialize the service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadUserBehaviors();
      await _initializePrefetchStrategies();
      await _startBackgroundPrefetching();

      debugPrint('✅ IntelligentPrefetchService initialized');
    } catch (e) {
      debugPrint('❌ Error initializing IntelligentPrefetchService: $e');
    }
  }

  // ========================================
  // USER BEHAVIOR TRACKING
  // ========================================

  /// Track user access to data
  Future<void> trackAccess(
      String dataType, String? userId, Map<String, dynamic>? context) async {
    try {
      final now = DateTime.now();
      final key = '${dataType}_${userId ?? 'anonymous'}';

      // Update access counts
      _accessCounts[key] = (_accessCounts[key] ?? 0) + 1;
      _lastAccessTimes[key] = now;

      // Update access patterns
      if (!_accessPatterns.containsKey(key)) {
        _accessPatterns[key] = [];
      }
      _accessPatterns[key]!.add(now.toIso8601String());

      // Keep only recent patterns (last 24 hours)
      _accessPatterns[key]!.removeWhere((timestamp) {
        final time = DateTime.parse(timestamp);
        return now.difference(time) > _behaviorTrackingWindow;
      });

      // Update user behavior
      if (!_userBehaviors.containsKey(key)) {
        _userBehaviors[key] = UserBehavior(
          dataType: dataType,
          userId: userId,
          accessCount: 0,
          lastAccess: now,
          accessPattern: [],
          context: {},
        );
      }

      final behavior = _userBehaviors[key]!;
      behavior.accessCount++;
      behavior.lastAccess = now;
      behavior.accessPattern.add(now.toIso8601String());

      if (context != null) {
        behavior.context.addAll(context);
      }

      // Save to persistent storage
      await _saveUserBehaviors();

      // Trigger intelligent prefetching
      await _triggerIntelligentPrefetch(dataType, userId, context);
    } catch (e) {
      debugPrint('❌ Error tracking access: $e');
    }
  }

  /// Get user behavior insights
  Map<String, dynamic> getUserBehaviorInsights(String? userId) {
    try {
      final userKey = userId ?? 'anonymous';
      final behaviors = _userBehaviors.entries
          .where((entry) => entry.key.endsWith('_$userKey'))
          .map((entry) => entry.value)
          .toList();

      if (behaviors.isEmpty) {
        return {
          'totalAccesses': 0,
          'mostAccessedDataType': null,
          'accessFrequency': 'low',
          'preferredTimeOfDay': null,
          'recommendations': [],
        };
      }

      // Calculate insights
      final totalAccesses =
          behaviors.fold<int>(0, (sum, behavior) => sum + behavior.accessCount);
      final mostAccessed = behaviors.isNotEmpty
          ? behaviors.reduce((a, b) => a.accessCount > b.accessCount ? a : b)
          : null;

      // Calculate access frequency
      final avgAccessPerDay = totalAccesses / max(1, behaviors.length);
      String accessFrequency;
      if (avgAccessPerDay > 10) {
        accessFrequency = 'high';
      } else if (avgAccessPerDay > 5) {
        accessFrequency = 'medium';
      } else {
        accessFrequency = 'low';
      }

      // Analyze time patterns
      final timePatterns = <int, int>{};
      for (final behavior in behaviors) {
        for (final timestamp in behavior.accessPattern) {
          final time = DateTime.parse(timestamp);
          final hour = time.hour;
          timePatterns[hour] = (timePatterns[hour] ?? 0) + 1;
        }
      }

      final preferredHour = timePatterns.isNotEmpty
          ? timePatterns.entries.reduce((a, b) => a.value > b.value ? a : b).key
          : null;

      // Generate recommendations
      final recommendations = <String>[];
      if (mostAccessed != null) {
        recommendations.add('Prefetch ${mostAccessed.dataType} data');
      }
      if (preferredHour != null) {
        recommendations.add('Schedule prefetching around $preferredHour:00');
      }
      if (accessFrequency == 'high') {
        recommendations.add('Implement aggressive caching');
      }

      return {
        'totalAccesses': totalAccesses,
        'mostAccessedDataType': mostAccessed?.dataType,
        'accessFrequency': accessFrequency,
        'preferredTimeOfDay': preferredHour,
        'recommendations': recommendations,
        'behaviors': behaviors.map((b) => b.toJson()).toList(),
      };
    } catch (e) {
      debugPrint('❌ Error getting user behavior insights: $e');
      return {};
    }
  }

  // ========================================
  // INTELLIGENT PREFETCHING
  // ========================================

  /// Trigger intelligent prefetching based on user behavior
  Future<void> _triggerIntelligentPrefetch(
      String dataType, String? userId, Map<String, dynamic>? context) async {
    try {
      final key = '${dataType}_${userId ?? 'anonymous'}';
      final behavior = _userBehaviors[key];

      if (behavior == null) return;

      // Determine prefetch strategy based on behavior
      final strategy = _determinePrefetchStrategy(behavior, context);

      if (strategy.shouldPrefetch) {
        await _executePrefetch(dataType, strategy, userId, context);
      }
    } catch (e) {
      debugPrint('❌ Error triggering intelligent prefetch: $e');
    }
  }

  /// Determine prefetch strategy based on user behavior
  PrefetchStrategy _determinePrefetchStrategy(
      UserBehavior behavior, Map<String, dynamic>? context) {
    try {
      // Base strategy
      var strategy = PrefetchStrategy(
        dataType: behavior.dataType,
        priority: PrefetchPriority.low,
        shouldPrefetch: false,
        prefetchCount: 0,
        cacheDuration: const Duration(minutes: 30),
        conditions: [],
      );

      // High frequency access -> High priority
      if (behavior.accessCount > 20) {
        strategy = strategy.copyWith(
          priority: PrefetchPriority.high,
          shouldPrefetch: true,
          prefetchCount: 50,
          cacheDuration: const Duration(hours: 2),
        );
      }
      // Medium frequency access -> Medium priority
      else if (behavior.accessCount > 10) {
        strategy = strategy.copyWith(
          priority: PrefetchPriority.medium,
          shouldPrefetch: true,
          prefetchCount: 30,
          cacheDuration: const Duration(hours: 1),
        );
      }
      // Low frequency access -> Low priority
      else if (behavior.accessCount > 5) {
        strategy = strategy.copyWith(
          priority: PrefetchPriority.low,
          shouldPrefetch: true,
          prefetchCount: 20,
          cacheDuration: const Duration(minutes: 30),
        );
      }

      // Time-based prefetching
      final now = DateTime.now();
      final lastAccess = behavior.lastAccess;
      final timeSinceLastAccess = now.difference(lastAccess);

      // If accessed recently, increase priority
      if (timeSinceLastAccess < const Duration(minutes: 30)) {
        strategy = strategy.copyWith(
          priority: PrefetchPriority.high,
          shouldPrefetch: true,
        );
      }

      // Context-based prefetching
      if (context != null) {
        // Location-based prefetching
        if (context.containsKey('latitude') &&
            context.containsKey('longitude')) {
          strategy = strategy.copyWith(
            shouldPrefetch: true,
            conditions: [...strategy.conditions, 'location_based'],
          );
        }

        // Time-based prefetching
        if (context.containsKey('timeOfDay')) {
          final timeOfDay = context['timeOfDay'] as String;
          if (timeOfDay == 'peak_hours') {
            strategy = strategy.copyWith(
              priority: PrefetchPriority.high,
              shouldPrefetch: true,
            );
          }
        }
      }

      return strategy;
    } catch (e) {
      debugPrint('❌ Error determining prefetch strategy: $e');
      return PrefetchStrategy(
        dataType: behavior.dataType,
        priority: PrefetchPriority.low,
        shouldPrefetch: false,
        prefetchCount: 0,
        cacheDuration: const Duration(minutes: 30),
        conditions: [],
      );
    }
  }

  /// Execute prefetching based on strategy
  Future<void> _executePrefetch(String dataType, PrefetchStrategy strategy,
      String? userId, Map<String, dynamic>? context) async {
    try {
      if (!strategy.shouldPrefetch) return;

      debugPrint('🚀 Executing intelligent prefetch for $dataType');

      // Execute prefetch based on data type
      switch (dataType) {
        case 'restaurants':
          await _prefetchRestaurants(strategy, userId, context);
          break;
        case 'categories':
          await _prefetchCategories(strategy, userId, context);
          break;
        case 'cuisines':
          await _prefetchCuisines(strategy, userId, context);
          break;
        case 'promoCodes':
          await _prefetchPromoCodes(strategy, userId, context);
          break;
        case 'menuItems':
          await _prefetchMenuItems(strategy, userId, context);
          break;
        case 'settings':
          await _prefetchSettings(strategy, userId, context);
          break;
        default:
          debugPrint('⚠️ Unknown data type for prefetching: $dataType');
      }
    } catch (e) {
      debugPrint('❌ Error executing prefetch: $e');
    }
  }

  /// Prefetch restaurants data
  Future<void> _prefetchRestaurants(PrefetchStrategy strategy, String? userId,
      Map<String, dynamic>? context) async {
    try {
      final restaurants = await _backendService.getRestaurants(
        limit: strategy.prefetchCount,
        forceRefresh: false,
      );

      if (restaurants != null) {
        _prefetchedData['restaurants'] = CacheEntry(
          data: restaurants,
          timestamp: DateTime.now(),
          duration: strategy.cacheDuration,
        );

        debugPrint('✅ Prefetched ${restaurants.length} restaurants');
      }
    } catch (e) {
      debugPrint('❌ Error prefetching restaurants: $e');
    }
  }

  /// Prefetch categories data
  Future<void> _prefetchCategories(PrefetchStrategy strategy, String? userId,
      Map<String, dynamic>? context) async {
    try {
      final categories =
          await _backendService.getCategories(forceRefresh: false);

      if (categories != null) {
        _prefetchedData['categories'] = CacheEntry(
          data: categories,
          timestamp: DateTime.now(),
          duration: strategy.cacheDuration,
        );

        debugPrint('✅ Prefetched ${categories.length} categories');
      }
    } catch (e) {
      debugPrint('❌ Error prefetching categories: $e');
    }
  }

  /// Prefetch cuisines data
  Future<void> _prefetchCuisines(PrefetchStrategy strategy, String? userId,
      Map<String, dynamic>? context) async {
    try {
      final cuisines = await _backendService.getCuisines(forceRefresh: false);

      if (cuisines != null) {
        _prefetchedData['cuisines'] = CacheEntry(
          data: cuisines,
          timestamp: DateTime.now(),
          duration: strategy.cacheDuration,
        );

        debugPrint('✅ Prefetched ${cuisines.length} cuisines');
      }
    } catch (e) {
      debugPrint('❌ Error prefetching cuisines: $e');
    }
  }

  /// Prefetch promo codes data
  Future<void> _prefetchPromoCodes(PrefetchStrategy strategy, String? userId,
      Map<String, dynamic>? context) async {
    try {
      final promoCodes =
          await _backendService.getPromoCodes(forceRefresh: false);

      if (promoCodes != null) {
        _prefetchedData['promoCodes'] = CacheEntry(
          data: promoCodes,
          timestamp: DateTime.now(),
          duration: strategy.cacheDuration,
        );

        debugPrint('✅ Prefetched ${promoCodes.length} promo codes');
      }
    } catch (e) {
      debugPrint('❌ Error prefetching promo codes: $e');
    }
  }

  /// Prefetch menu items data
  Future<void> _prefetchMenuItems(PrefetchStrategy strategy, String? userId,
      Map<String, dynamic>? context) async {
    try {
      final menuItems = await _backendService.getMenuItems(forceRefresh: false);

      if (menuItems != null) {
        _prefetchedData['menuItems'] = CacheEntry(
          data: menuItems,
          timestamp: DateTime.now(),
          duration: strategy.cacheDuration,
        );

        debugPrint('✅ Prefetched ${menuItems.length} menu items');
      }
    } catch (e) {
      debugPrint('❌ Error prefetching menu items: $e');
    }
  }

  /// Prefetch settings data
  Future<void> _prefetchSettings(PrefetchStrategy strategy, String? userId,
      Map<String, dynamic>? context) async {
    try {
      final settings = await _backendService.getSettings(forceRefresh: false);

      if (settings != null) {
        _prefetchedData['settings'] = CacheEntry(
          data: settings,
          timestamp: DateTime.now(),
          duration: strategy.cacheDuration,
        );

        debugPrint('✅ Prefetched ${settings.length} settings');
      }
    } catch (e) {
      debugPrint('❌ Error prefetching settings: $e');
    }
  }

  // ========================================
  // BACKGROUND PREFETCHING
  // ========================================

  /// Start background prefetching
  Future<void> _startBackgroundPrefetching() async {
    try {
      // Schedule prefetching every 30 minutes
      Timer.periodic(const Duration(minutes: 30), (timer) async {
        await _performBackgroundPrefetch();
      });

      // Initial prefetch
      await _performBackgroundPrefetch();

      debugPrint('🔄 Background prefetching started');
    } catch (e) {
      debugPrint('❌ Error starting background prefetching: $e');
    }
  }

  /// Perform background prefetching
  Future<void> _performBackgroundPrefetch() async {
    try {
      debugPrint('🔄 Performing background prefetch...');

      // Get top accessed data types
      final topAccessedTypes = _getTopAccessedDataTypes();

      // Prefetch top accessed data types
      for (final dataType in topAccessedTypes) {
        await _triggerIntelligentPrefetch(dataType, null, null);
      }

      // Clean up old prefetched data
      await _cleanupPrefetchedData();

      debugPrint('✅ Background prefetch completed');
    } catch (e) {
      debugPrint('❌ Error performing background prefetch: $e');
    }
  }

  /// Get top accessed data types
  List<String> _getTopAccessedDataTypes() {
    try {
      final dataTypeCounts = <String, int>{};

      for (final entry in _accessCounts.entries) {
        final dataType = entry.key.split('_').first;
        dataTypeCounts[dataType] =
            (dataTypeCounts[dataType] ?? 0) + entry.value;
      }

      final sortedTypes = dataTypeCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedTypes.take(5).map((entry) => entry.key).toList();
    } catch (e) {
      debugPrint('❌ Error getting top accessed data types: $e');
      return [];
    }
  }

  /// Clean up old prefetched data
  Future<void> _cleanupPrefetchedData() async {
    try {
      final now = DateTime.now();
      final keysToRemove = <String>[];

      for (final entry in _prefetchedData.entries) {
        if (now.difference(entry.value.timestamp) > entry.value.duration) {
          keysToRemove.add(entry.key);
        }
      }

      for (final key in keysToRemove) {
        _prefetchedData.remove(key);
      }

      if (keysToRemove.isNotEmpty) {
        debugPrint(
            '🧹 Cleaned up ${keysToRemove.length} expired prefetched items');
      }
    } catch (e) {
      debugPrint('❌ Error cleaning up prefetched data: $e');
    }
  }

  // ========================================
  // PERSISTENT STORAGE
  // ========================================

  /// Save user behaviors to persistent storage
  Future<void> _saveUserBehaviors() async {
    try {
      if (_prefs == null) return;

      final behaviorsJson = _userBehaviors.map(
        (key, behavior) => MapEntry(key, behavior.toJson()),
      );

      await _prefs!.setString('user_behaviors', jsonEncode(behaviorsJson));
    } catch (e) {
      debugPrint('❌ Error saving user behaviors: $e');
    }
  }

  /// Load user behaviors from persistent storage
  Future<void> _loadUserBehaviors() async {
    try {
      if (_prefs == null) return;

      final behaviorsString = _prefs!.getString('user_behaviors');
      if (behaviorsString != null) {
        final behaviorsJson =
            jsonDecode(behaviorsString) as Map<String, dynamic>;

        for (final entry in behaviorsJson.entries) {
          _userBehaviors[entry.key] = UserBehavior.fromJson(entry.value);
        }

        debugPrint('📦 Loaded ${_userBehaviors.length} user behaviors');
      }
    } catch (e) {
      debugPrint('❌ Error loading user behaviors: $e');
    }
  }

  /// Initialize prefetch strategies
  Future<void> _initializePrefetchStrategies() async {
    try {
      // Initialize default strategies
      _prefetchStrategies['restaurants'] = PrefetchStrategy(
        dataType: 'restaurants',
        priority: PrefetchPriority.medium,
        shouldPrefetch: true,
        prefetchCount: 30,
        cacheDuration: const Duration(hours: 1),
        conditions: ['default'],
      );

      _prefetchStrategies['categories'] = PrefetchStrategy(
        dataType: 'categories',
        priority: PrefetchPriority.low,
        shouldPrefetch: true,
        prefetchCount: 20,
        cacheDuration: const Duration(hours: 2),
        conditions: ['default'],
      );

      _prefetchStrategies['cuisines'] = PrefetchStrategy(
        dataType: 'cuisines',
        priority: PrefetchPriority.low,
        shouldPrefetch: true,
        prefetchCount: 20,
        cacheDuration: const Duration(hours: 2),
        conditions: ['default'],
      );

      debugPrint('✅ Prefetch strategies initialized');
    } catch (e) {
      debugPrint('❌ Error initializing prefetch strategies: $e');
    }
  }

  // ========================================
  // PUBLIC API
  // ========================================

  /// Get prefetched data
  T? getPrefetchedData<T>(String dataType) {
    try {
      final entry = _prefetchedData[dataType];
      if (entry != null && entry.isValid) {
        return entry.data as T;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting prefetched data: $e');
      return null;
    }
  }

  /// Get performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    return {
      'prefetchedItems': _prefetchedData.length,
      'userBehaviors': _userBehaviors.length,
      'accessCounts': Map<String, int>.from(_accessCounts),
      'prefetchStrategies': _prefetchStrategies.length,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Clear all data
  Future<void> clearAllData() async {
    try {
      _userBehaviors.clear();
      _accessCounts.clear();
      _lastAccessTimes.clear();
      _accessPatterns.clear();
      _prefetchedData.clear();
      _performanceMetrics.clear();

      if (_prefs != null) {
        await _prefs!.remove('user_behaviors');
      }

      debugPrint('🗑️ All intelligent prefetch data cleared');
    } catch (e) {
      debugPrint('❌ Error clearing all data: $e');
    }
  }
}

// ========================================
// DATA MODELS
// ========================================

/// User behavior model
class UserBehavior {
  final String dataType;
  final String? userId;
  int accessCount;
  DateTime lastAccess;
  final List<String> accessPattern;
  final Map<String, dynamic> context;

  UserBehavior({
    required this.dataType,
    required this.userId,
    required this.accessCount,
    required this.lastAccess,
    required this.accessPattern,
    required this.context,
  });

  Map<String, dynamic> toJson() {
    return {
      'dataType': dataType,
      'userId': userId,
      'accessCount': accessCount,
      'lastAccess': lastAccess.toIso8601String(),
      'accessPattern': accessPattern,
      'context': context,
    };
  }

  factory UserBehavior.fromJson(Map<String, dynamic> json) {
    return UserBehavior(
      dataType: json['dataType'] ?? '',
      userId: json['userId'],
      accessCount: json['accessCount'] ?? 0,
      lastAccess: DateTime.parse(
          json['lastAccess'] ?? DateTime.now().toIso8601String()),
      accessPattern: List<String>.from(json['accessPattern'] ?? []),
      context: Map<String, dynamic>.from(json['context'] ?? {}),
    );
  }
}

/// Prefetch strategy model
class PrefetchStrategy {
  final String dataType;
  final PrefetchPriority priority;
  final bool shouldPrefetch;
  final int prefetchCount;
  final Duration cacheDuration;
  final List<String> conditions;

  PrefetchStrategy({
    required this.dataType,
    required this.priority,
    required this.shouldPrefetch,
    required this.prefetchCount,
    required this.cacheDuration,
    required this.conditions,
  });

  PrefetchStrategy copyWith({
    String? dataType,
    PrefetchPriority? priority,
    bool? shouldPrefetch,
    int? prefetchCount,
    Duration? cacheDuration,
    List<String>? conditions,
  }) {
    return PrefetchStrategy(
      dataType: dataType ?? this.dataType,
      priority: priority ?? this.priority,
      shouldPrefetch: shouldPrefetch ?? this.shouldPrefetch,
      prefetchCount: prefetchCount ?? this.prefetchCount,
      cacheDuration: cacheDuration ?? this.cacheDuration,
      conditions: conditions ?? this.conditions,
    );
  }
}

/// Prefetch priority enum
enum PrefetchPriority {
  low,
  medium,
  high,
  critical,
}

/// Performance metrics model
class PerformanceMetrics {
  final String dataType;
  final int prefetchCount;
  final Duration averageResponseTime;
  final double cacheHitRate;
  final DateTime lastUpdated;

  PerformanceMetrics({
    required this.dataType,
    required this.prefetchCount,
    required this.averageResponseTime,
    required this.cacheHitRate,
    required this.lastUpdated,
  });
}

/// Cache entry model
class CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  final Duration duration;

  CacheEntry({
    required this.data,
    required this.timestamp,
    required this.duration,
  });

  bool get isValid {
    return DateTime.now().difference(timestamp) < duration;
  }
}
