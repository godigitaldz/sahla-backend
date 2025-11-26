import "package:provider/provider.dart";

import "../cart_provider.dart";
import "../config/injection_container.dart";
import "../providers/delivery_fee_provider.dart";
import "../providers/home_provider.dart";
import "../providers/location_provider.dart";
import "../providers/profile_provider.dart";
import "../services/accessibility_service.dart";
import "../services/auth_service.dart";
import "../services/cash_management_service.dart";
import "../services/comprehensive_earnings_service.dart";
import "../services/context_tracking_service.dart";
import "../services/deep_link_service.dart";
import "../services/delivery_earnings_service.dart";
import "../services/delivery_fee_service.dart";
import "../services/delivery_man_request_service.dart";
import "../services/delivery_service.dart";
import "../services/delivery_tracking_service.dart";
import "../services/enhanced_fcm_service.dart";
import "../services/enhanced_order_tracking_service.dart";
import "../services/error_handling_service.dart";
import "../services/error_logging_service.dart";
import "../services/geolocation_service.dart";
import "../services/image_loading_service.dart";
import "../services/image_picker_service.dart";
import "../services/image_upload_service.dart";
import "../services/integrated_task_delivery_service.dart";
import "../services/language_preference_service.dart";
import "../services/location_service.dart";
import "../services/location_tracking_service.dart";
import "../services/menu_item_display_service.dart";
import "../services/menu_item_favorites_service.dart";
import "../services/menu_item_image_service.dart";
import "../services/menu_item_service.dart";
import "../services/menu_service_coordinator.dart";
import "../services/notification_service.dart";
import "../services/optimized_api_client.dart";
import "../services/optimized_restaurant_favorites_service.dart";
import "../services/optimized_restaurant_search_service.dart";
import "../services/optimized_restaurant_service.dart";
import "../services/order_acceptance_service.dart";
import "../services/order_assignment_service.dart";
import "../services/order_service.dart";
import "../services/order_tracking_service.dart";
import "../services/performance_monitoring_service.dart";
import "../services/performance_optimization_service.dart";
import "../services/profile_service.dart";
import "../services/promo_code_service.dart";
import "../services/push_notification_service.dart";
import "../services/restaurant_favorites_service.dart";
import "../services/restaurant_request_service.dart";
import "../services/restaurant_service.dart";
import "../services/search_service.dart";
import "../services/service_fee_service.dart";
import "../services/session_manager.dart";
import "../services/settings_service.dart";
import "../services/smart_search_service.dart";
import "../services/socket_service.dart";
import "../services/system_config_service.dart";
import "../services/unified_performance_service.dart";

/// Centralized provider configuration for hot-reload stability
class AppProviders {
  /// All providers for MultiProvider - optimized for performance
  static List<dynamic> get allProviders => [
        // Core Services - SessionManager initialized early for auth persistence
        // NOTE: SessionManager will be initialized by StartupDataService (sync)
        // Don't initialize here to prevent duplicate initialization
        ChangeNotifierProvider<SessionManager>(
            create: (_) => SessionManager(),
            lazy: false),

        // AuthService for backward compatibility - delegates to SessionManager
        ChangeNotifierProvider<AuthService>(
            create: (_) => AuthService(), lazy: false),

        ChangeNotifierProvider<SettingsService>(
            create: (_) {
              final service = SettingsService();
              // Initialize asynchronously to prevent blocking
              Future.microtask(service.initialize);
              return service;
            },
            lazy: true),

        // Language Preference Service - integrates with user_profiles table
        ChangeNotifierProvider<LanguagePreferenceService>(
            create: (_) {
              final service = LanguagePreferenceService();
              // Initialize asynchronously to prevent blocking
              Future.microtask(service.initialize);
              return service;
            },
            lazy: true),

        ChangeNotifierProvider<ErrorLoggingService>(
            create: (_) => ErrorLoggingService(), lazy: true),
        Provider<ErrorHandlingService>(
            create: (_) => ErrorHandlingService(), lazy: true),
        ChangeNotifierProvider<UnifiedPerformanceService>(
            create: (_) => UnifiedPerformanceService(), lazy: true),
        ChangeNotifierProvider<ProfileProvider>(
            create: (_) {
              // Use DI if available, otherwise fallback to default
              final profileService = getIt.tryGet<ProfileService>();
              final authService = getIt.tryGet<AuthService>();
              return ProfileProvider(
                profileService: profileService,
                authService: authService,
              );
            }, lazy: true),
        ChangeNotifierProvider<PushNotificationService>(
            create: (_) => PushNotificationService(), lazy: true),
        ChangeNotifierProvider.value(value: AccessibilityService()),
        ChangeNotifierProvider<LocationProvider>(
            create: (_) => LocationProvider()),
        Provider<GeolocationService>(create: (_) => GeolocationService()),
        ChangeNotifierProvider<LocationService>(
            create: (_) {
              final service = LocationService();
              // Initialize asynchronously to prevent blocking
              Future.microtask(service.initialize);
              return service;
            },
            lazy: false), // Make it non-lazy so it loads immediately

        // Delivery Fee Provider - Shared cache for all restaurant cards
        ChangeNotifierProvider<DeliveryFeeProvider>(
            create: (_) => DeliveryFeeProvider(), lazy: true),

        // Home Provider - Fixed GlobalKey issue
        ChangeNotifierProvider<HomeProvider>(
            create: (_) => HomeProvider(), lazy: true),

        // Context Tracking Services - Lazy loading
        ChangeNotifierProvider<ContextTrackingService>(
            create: (_) => ContextTrackingService(), lazy: true),

        // Business Logic Services - 100% Performance Optimized - Lazy loading
        ChangeNotifierProvider<OptimizedRestaurantService>(
            create: (_) => OptimizedRestaurantService(), lazy: true),
        ChangeNotifierProvider<OptimizedRestaurantSearchService>(
            create: (_) => OptimizedRestaurantSearchService(), lazy: true),
        ChangeNotifierProvider<OptimizedRestaurantFavoritesService>(
            create: (_) {
              final service = OptimizedRestaurantFavoritesService();
              // Initialize asynchronously to prevent blocking
              Future.microtask(service.initialize);
              return service;
            },
            lazy: true),
        ChangeNotifierProvider<RestaurantFavoritesService>(
            create: (_) => RestaurantFavoritesService(), lazy: true),
        ChangeNotifierProvider<RestaurantService>(
            create: (_) => RestaurantService(), lazy: true),

        // Performance Optimization Services - Lazy loading
        ChangeNotifierProvider<PerformanceOptimizationService>(
            create: (_) {
              final service = PerformanceOptimizationService();
              // Initialize asynchronously to prevent blocking
              Future.microtask(service.initialize);
              return service;
            },
            lazy: true),

        // Ultra-Optimized API Client - Critical for performance
        Provider<OptimizedApiClient>(
            create: (_) {
              final client = OptimizedApiClient();
              // Initialize asynchronously to prevent blocking
              Future.microtask(client.initialize);
              return client;
            },
            lazy: false),

        // Performance Monitoring Service - Critical for monitoring
        Provider<PerformanceMonitoringService>(
            create: (_) {
              final service = PerformanceMonitoringService();
              // Initialize immediately for monitoring
              service.initialize();
              return service;
            },
            lazy: false),
        ChangeNotifierProvider<MenuItemFavoritesService>(
            create: (_) {
              final service = MenuItemFavoritesService();
              // Initialize asynchronously to prevent blocking
              Future.microtask(service.initialize);
              return service;
            },
            lazy: true),
        ChangeNotifierProvider<MenuItemService>(
            create: (_) => MenuItemService(), lazy: true),
        Provider<MenuItemImageService>(
            create: (_) => MenuItemImageService(), lazy: true),
        Provider<MenuItemDisplayService>(
            create: (_) => MenuItemDisplayService(), lazy: true),
        ChangeNotifierProvider<MenuServiceCoordinator>(
            create: (_) {
              final coordinator = MenuServiceCoordinator();
              // Initialize asynchronously to prevent blocking
              Future.microtask(coordinator.initialize);
              return coordinator;
            },
            lazy: true),
        // Food Ordering & Delivery Services - Critical services made non-lazy
        ChangeNotifierProvider<OrderService>(create: (_) {
          final service = OrderService();
          // Initialize asynchronously to prevent blocking
          Future.microtask(service.initialize);
          return service;
        }),
        ChangeNotifierProvider<DeliveryService>(
            create: (_) => DeliveryService(), lazy: true),
        ChangeNotifierProvider<DeliveryEarningsService>(
            create: (_) => DeliveryEarningsService(), lazy: true),
        ChangeNotifierProvider<DeliveryFeeService>(
            create: (_) {
              final service = DeliveryFeeService();
              // Initialize asynchronously to prevent blocking
              Future.microtask(service.initialize);
              return service;
            },
            lazy: false), // Make it non-lazy so it loads immediately
        ChangeNotifierProvider<LocationTrackingService>(
            create: (_) => LocationTrackingService(), lazy: true),
        ChangeNotifierProvider<OrderAssignmentService>(
            create: (_) {
              final service = OrderAssignmentService();
              // Initialize asynchronously to prevent blocking
              Future.microtask(service.initialize);
              return service;
            },
            lazy: true),
        ChangeNotifierProvider<OrderTrackingService>(
            create: (_) {
              final service = OrderTrackingService();
              // Initialize asynchronously to prevent blocking
              Future.microtask(service.initialize);
              return service;
            },
            lazy: true),
        Provider<OrderAcceptanceService>(
            create: (_) => OrderAcceptanceService(), lazy: true),

        // Enhanced Delivery System Services - Critical services made non-lazy
        ChangeNotifierProvider<DeliveryTrackingService>(create: (_) {
          final service = DeliveryTrackingService();
          // Initialize asynchronously to prevent blocking
          Future.microtask(service.initialize);
          return service;
        }),
        ChangeNotifierProvider<ServiceFeeService>(
            create: (_) {
              final service = ServiceFeeService();
              // Initialize asynchronously to prevent blocking
              Future.microtask(service.initialize);
              return service;
            },
            lazy: true),
        ChangeNotifierProvider<SystemConfigService>(
            create: (_) {
              final service = SystemConfigService();
              // Initialize asynchronously to prevent blocking
              Future.microtask(service.initialize);
              return service;
            },
            lazy: false), // Make it non-lazy so it loads immediately
        ChangeNotifierProvider<CashManagementService>(
            create: (_) {
              final service = CashManagementService();
              // Initialize asynchronously to prevent blocking
              Future.microtask(service.initialize);
              return service;
            },
            lazy: true),

        // Enhanced Real-Time Services - Critical services made non-lazy
        ChangeNotifierProvider.value(value: SocketService()),
        ChangeNotifierProvider<EnhancedOrderTrackingService>(create: (_) {
          final service = EnhancedOrderTrackingService();
          // Initialize asynchronously to prevent blocking
          Future.microtask(service.initialize);
          return service;
        }),
        ChangeNotifierProvider<EnhancedFCMService>(
            create: (_) {
              final service = EnhancedFCMService();
              // Initialize asynchronously to prevent blocking
              Future.microtask(service.initialize);
              return service;
            },
            lazy: true),
        ChangeNotifierProvider.value(value: SmartSearchService()),

        // Discount and Promo Code Services - Lazy loading
        ChangeNotifierProvider<PromoCodeService>(
            create: (_) => PromoCodeService(), lazy: true),

        // Restaurant Request Services - Lazy loading
        ChangeNotifierProvider<RestaurantRequestService>(
            create: (_) => RestaurantRequestService(), lazy: true),

        // Delivery Man Request Services - Lazy loading
        ChangeNotifierProvider<DeliveryManRequestService>(
            create: (_) => DeliveryManRequestService(), lazy: true),

        // UI & Interaction Services - Lazy loading
        ChangeNotifierProvider<SearchService>(
            create: (_) => SearchService(), lazy: true),
        ChangeNotifierProvider<NotificationService>(
            create: (_) => NotificationService(), lazy: true),
        // Image Services - Lazy loading
        Provider<ImagePickerService>(
            create: (_) => ImagePickerService(), lazy: true),
        Provider<ImageLoadingService>(
            create: (_) => ImageLoadingService(), lazy: true),
        ChangeNotifierProvider<ImageUploadService>(
            create: (_) => ImageUploadService(), lazy: true),

        // Cart Provider (global) - Keep immediate for cart functionality
        ChangeNotifierProvider<CartProvider>(create: (_) {
          final cartProvider = CartProvider();
          // Initialize asynchronously to prevent blocking
          Future.microtask(cartProvider.initialize);
          return cartProvider;
        }),

        // Comprehensive Services - Lazy loading
        ChangeNotifierProvider<ComprehensiveEarningsService>(
            create: (_) {
              final service = ComprehensiveEarningsService();
              // Initialize asynchronously to prevent blocking
              Future.microtask(service.initialize);
              return service;
            },
            lazy: true),

        // Integrated Task Delivery Service - Lazy loading
        Provider<IntegratedTaskDeliveryService>(
            create: (_) => IntegratedTaskDeliveryService.instance, lazy: true),

        // Share & Deep Link Services - Lazy loading
        Provider<DeepLinkService>(create: (_) => DeepLinkService(), lazy: true),
      ];
}
