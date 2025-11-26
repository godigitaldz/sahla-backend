import 'dart:async';

import 'package:flutter/foundation.dart';

import 'logging_service.dart';
import 'menu_item_display_service.dart';
import 'menu_item_favorites_service.dart';
import 'menu_item_image_service.dart';
import 'menu_item_service.dart';

/// Event types for cross-service communication
enum MenuServiceEventType {
  menuItemCreated,
  menuItemUpdated,
  menuItemDeleted,
  menuItemImageUploaded,
  menuItemImageDeleted,
  menuItemFavorited,
  menuItemUnfavorited,
  cacheInvalidated,
  performanceAlert,
  errorOccurred,
}

/// Event data for cross-service communication
class MenuServiceEvent {
  final MenuServiceEventType type;
  final String sourceService;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  MenuServiceEvent({
    required this.type,
    required this.sourceService,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'MenuServiceEvent(type: $type, source: $sourceService, data: $data, timestamp: $timestamp)';
  }
}

/// Coordinator service for managing cross-service communication
class MenuServiceCoordinator extends ChangeNotifier {
  static final MenuServiceCoordinator _instance =
      MenuServiceCoordinator._internal();
  factory MenuServiceCoordinator() => _instance;
  MenuServiceCoordinator._internal();

  // Logging service for coordination metrics
  final LoggingService _logger = LoggingService();

  // Event stream controller
  final StreamController<MenuServiceEvent> _eventController =
      StreamController<MenuServiceEvent>.broadcast();
  Stream<MenuServiceEvent> get eventStream => _eventController.stream;

  // Service references
  MenuItemService? _menuItemService;
  MenuItemImageService? _menuItemImageService;
  MenuItemDisplayService? _menuItemDisplayService;
  MenuItemFavoritesService? _menuItemFavoritesService;

  // Event listeners
  final Map<MenuServiceEventType, List<Function(MenuServiceEvent)>>
      _eventListeners = {};

  // Performance tracking
  final Map<String, DateTime> _operationStartTimes = {};
  final Map<String, int> _eventCounts = {};

  // Service health status
  final Map<String, bool> _serviceHealth = {};
  final Map<String, DateTime> _lastHealthCheck = {};

  /// Initialize the coordinator
  Future<void> initialize() async {
    try {
      _logger.startPerformanceTimer('menu_service_coordinator_init');

      // Register event listeners
      _registerEventListeners();

      // Start health monitoring
      _startHealthMonitoring();

      _logger.endPerformanceTimer('menu_service_coordinator_init',
          details: 'MenuServiceCoordinator initialized successfully');
      _logger.info('MenuServiceCoordinator initialized',
          tag: 'MENU_COORDINATOR');
    } catch (e) {
      _logger.error('Failed to initialize MenuServiceCoordinator',
          tag: 'MENU_COORDINATOR', error: e);
      rethrow;
    }
  }

  /// Register service references
  void registerServices({
    MenuItemService? menuItemService,
    MenuItemImageService? menuItemImageService,
    MenuItemDisplayService? menuItemDisplayService,
    MenuItemFavoritesService? menuItemFavoritesService,
  }) {
    _menuItemService = menuItemService;
    _menuItemImageService = menuItemImageService;
    _menuItemDisplayService = menuItemDisplayService;
    _menuItemFavoritesService = menuItemFavoritesService;

    _logger.info('Menu services registered',
        tag: 'MENU_COORDINATOR',
        additionalData: {
          'menu_item_service': _menuItemService != null,
          'menu_item_image_service': _menuItemImageService != null,
          'menu_item_display_service': _menuItemDisplayService != null,
          'menu_item_favorites_service': _menuItemFavoritesService != null,
        });
  }

  /// Emit an event to all listeners
  void emitEvent(MenuServiceEvent event) {
    try {
      _eventController.add(event);
      _eventCounts[event.type.name] = (_eventCounts[event.type.name] ?? 0) + 1;

      _logger.logUserAction(
        'menu_service_event_emitted',
        data: {
          'event_type': event.type.name,
          'source_service': event.sourceService,
          'event_data': event.data,
        },
      );

      // Notify specific listeners
      final listeners = _eventListeners[event.type];
      if (listeners != null) {
        for (final listener in listeners) {
          try {
            listener(event);
          } catch (e) {
            _logger.error('Error in event listener',
                tag: 'MENU_COORDINATOR', error: e);
          }
        }
      }
    } catch (e) {
      _logger.error('Error emitting event', tag: 'MENU_COORDINATOR', error: e);
    }
  }

  /// Subscribe to specific event types
  void subscribeToEvent(
      MenuServiceEventType eventType, Function(MenuServiceEvent) listener) {
    _eventListeners.putIfAbsent(eventType, () => []).add(listener);

    _logger.info('Subscribed to event type',
        tag: 'MENU_COORDINATOR',
        additionalData: {
          'event_type': eventType.name,
          'total_listeners': _eventListeners[eventType]?.length ?? 0,
        });
  }

  /// Unsubscribe from event type
  void unsubscribeFromEvent(
      MenuServiceEventType eventType, Function(MenuServiceEvent) listener) {
    _eventListeners[eventType]?.remove(listener);

    _logger.info('Unsubscribed from event type',
        tag: 'MENU_COORDINATOR',
        additionalData: {
          'event_type': eventType.name,
          'remaining_listeners': _eventListeners[eventType]?.length ?? 0,
        });
  }

  /// Register event listeners for cross-service communication
  void _registerEventListeners() {
    // Menu item creation events
    subscribeToEvent(MenuServiceEventType.menuItemCreated, (event) {
      _logger.logUserAction(
        'menu_item_created_coordination',
        data: {
          'menu_item_id': event.data['menu_item_id'],
          'restaurant_id': event.data['restaurant_id'],
          'source_service': event.sourceService,
        },
      );

      // Invalidate display cache
      _menuItemDisplayService?.clearPerformanceCache();

      // Preload for better performance
      _menuItemDisplayService?.preloadPopularMenuItems();
    });

    // Menu item update events
    subscribeToEvent(MenuServiceEventType.menuItemUpdated, (event) {
      _logger.logUserAction(
        'menu_item_updated_coordination',
        data: {
          'menu_item_id': event.data['menu_item_id'],
          'restaurant_id': event.data['restaurant_id'],
          'source_service': event.sourceService,
        },
      );

      // Invalidate relevant caches
      _menuItemService?.clearCache();
      _menuItemDisplayService?.clearPerformanceCache();
    });

    // Menu item deletion events
    subscribeToEvent(MenuServiceEventType.menuItemDeleted, (event) {
      _logger.logUserAction(
        'menu_item_deleted_coordination',
        data: {
          'menu_item_id': event.data['menu_item_id'],
          'restaurant_id': event.data['restaurant_id'],
          'source_service': event.sourceService,
        },
      );

      // Remove from favorites if needed
      _menuItemFavoritesService
          ?.removeMenuItemFromFavorites(event.data['menu_item_id']);

      // Clear all caches
      _clearAllCaches();
    });

    // Image upload events
    subscribeToEvent(MenuServiceEventType.menuItemImageUploaded, (event) {
      _logger.logUserAction(
        'menu_item_image_uploaded_coordination',
        data: {
          'menu_item_id': event.data['menu_item_id'],
          'restaurant_id': event.data['restaurant_id'],
          'image_count': event.data['image_count'],
          'source_service': event.sourceService,
        },
      );

      // Preload images for better performance
      final imageUrls = event.data['uploaded_urls'] as List<String>?;
      if (imageUrls != null) {
        _menuItemImageService?.preloadImages(imageUrls);
      }
    });

    // Favorite events
    subscribeToEvent(MenuServiceEventType.menuItemFavorited, (event) {
      _logger.logUserAction(
        'menu_item_favorited_coordination',
        data: {
          'menu_item_id': event.data['menu_item_id'],
          'user_id': event.data['user_id'],
          'source_service': event.sourceService,
        },
      );

      // Update display cache
      _menuItemDisplayService?.clearPerformanceCache();
    });

    // Error events
    subscribeToEvent(MenuServiceEventType.errorOccurred, (event) {
      _logger.error(
        'Cross-service error occurred',
        tag: 'MENU_COORDINATOR',
        error: event.data['error'],
        additionalData: {
          'source_service': event.sourceService,
          'error_context': event.data['context'],
        },
      );

      // Implement error recovery strategies
      _handleServiceError(event.sourceService, event.data);
    });
  }

  /// Start health monitoring for all services
  void _startHealthMonitoring() {
    Timer.periodic(const Duration(minutes: 5), (timer) {
      _checkServiceHealth();
    });
  }

  /// Check health of all registered services
  Future<void> _checkServiceHealth() async {
    final services = {
      'MenuItemService': _menuItemService,
      'MenuItemImageService': _menuItemImageService,
      'MenuItemDisplayService': _menuItemDisplayService,
      'MenuItemFavoritesService': _menuItemFavoritesService,
    };

    for (final entry in services.entries) {
      try {
        final serviceName = entry.key;
        final service = entry.value;

        if (service != null) {
          // Check if service is responsive
          final isHealthy = await _checkServiceResponsiveness(service);
          _serviceHealth[serviceName] = isHealthy;
          _lastHealthCheck[serviceName] = DateTime.now();

          if (!isHealthy) {
            _logger.warning('Service health check failed',
                tag: 'MENU_COORDINATOR',
                additionalData: {
                  'service_name': serviceName,
                  'last_check':
                      _lastHealthCheck[serviceName]?.toIso8601String(),
                });

            emitEvent(MenuServiceEvent(
              type: MenuServiceEventType.errorOccurred,
              sourceService: 'MenuServiceCoordinator',
              data: {
                'error': 'Service health check failed',
                'context': 'health_monitoring',
                'service_name': serviceName,
              },
            ));
          }
        }
      } catch (e) {
        _logger.error('Error checking service health',
            tag: 'MENU_COORDINATOR', error: e);
      }
    }
  }

  /// Check if a service is responsive
  Future<bool> _checkServiceResponsiveness(dynamic service) async {
    try {
      // Simple responsiveness check - try to call a method
      if (service is MenuItemService) {
        service.getPerformanceAnalytics();
      } else if (service is MenuItemImageService) {
        service.getPerformanceAnalytics();
      } else if (service is MenuItemDisplayService) {
        service.getPerformanceAnalytics();
      } else if (service is MenuItemFavoritesService) {
        service.getPerformanceAnalytics();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Handle service errors
  void _handleServiceError(String serviceName, Map<String, dynamic> errorData) {
    try {
      _logger.logUserAction(
        'service_error_handled',
        data: {
          'service_name': serviceName,
          'error_context': errorData['context'],
          'recovery_attempted': true,
        },
      );

      // Implement recovery strategies based on service type
      switch (serviceName) {
        case 'MenuItemService':
          _menuItemService?.clearPerformanceCache();
          break;
        case 'MenuItemImageService':
          _menuItemImageService?.clearPerformanceCache();
          break;
        case 'MenuItemDisplayService':
          _menuItemDisplayService?.clearPerformanceCache();
          break;
        case 'MenuItemFavoritesService':
          _menuItemFavoritesService?.clearPerformanceCache();
          break;
      }
    } catch (e) {
      _logger.error('Error handling service error',
          tag: 'MENU_COORDINATOR', error: e);
    }
  }

  /// Clear all service caches
  void _clearAllCaches() {
    _menuItemService?.clearPerformanceCache();
    _menuItemImageService?.clearPerformanceCache();
    _menuItemDisplayService?.clearPerformanceCache();
    _menuItemFavoritesService?.clearPerformanceCache();

    _logger.info('All service caches cleared', tag: 'MENU_COORDINATOR');
  }

  /// Get performance analytics for the coordinator
  Map<String, dynamic> getPerformanceAnalytics() {
    final now = DateTime.now();
    final analytics = <String, dynamic>{
      'total_events_emitted':
          _eventCounts.values.fold<int>(0, (sum, count) => sum + count),
      'event_types': _eventCounts.keys.toList(),
      'active_listeners': _eventListeners.values
          .fold<int>(0, (sum, listeners) => sum + listeners.length),
      'service_health': _serviceHealth,
      'last_health_checks': _lastHealthCheck
          .map((key, value) => MapEntry(key, value.toIso8601String())),
      'service_uptime': now
          .difference(_operationStartTimes.isNotEmpty
              ? _operationStartTimes.values
                  .reduce((a, b) => a.isBefore(b) ? a : b)
              : now)
          .inMinutes,
    };

    _logger.info('MenuServiceCoordinator performance analytics',
        tag: 'MENU_COORDINATOR', additionalData: analytics);
    return analytics;
  }

  /// Get service health status
  Map<String, dynamic> getServiceHealthStatus() {
    final status = <String, dynamic>{
      'services': _serviceHealth.map((key, value) => MapEntry(key, {
            'healthy': value,
            'last_check': _lastHealthCheck[key]?.toIso8601String(),
          })),
      'overall_health': _serviceHealth.values.every((healthy) => healthy),
    };

    _logger.info('Service health status',
        tag: 'MENU_COORDINATOR', additionalData: status);
    return status;
  }

  /// Dispose resources
  @override
  void dispose() {
    _eventController.close();
    _eventListeners.clear();
    _operationStartTimes.clear();
    _eventCounts.clear();
    _serviceHealth.clear();
    _lastHealthCheck.clear();
    super.dispose();
  }
}
