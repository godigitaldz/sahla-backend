import 'package:get_it/get_it.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';

/// Service locator pattern using get_it for dependency injection
final getIt = GetIt.instance;

/// Initialize dependency injection container
Future<void> initializeDependencyInjection() async {
  // Register services as singletons (created once)
  getIt.registerLazySingleton<AuthService>(() => AuthService());
  getIt.registerLazySingleton<ProfileService>(() => ProfileService());

  // Services can also be registered as factories (created new each time)
  // Example: getIt.registerFactory<ProfileProvider>(() => ProfileProvider(...));

  // Initialize lazy services if needed
  await Future.wait([
    if (getIt.isRegistered<AuthService>())
      Future.microtask(() => getIt<AuthService>()),
  ]);
}

/// Dispose all registered services (useful for testing)
Future<void> disposeDependencyInjection() async {
  await getIt.reset();
}

/// Extension methods for easier access
extension GetItExtension on GetIt {
  /// Get a service with null safety
  T? tryGet<T extends Object>() {
    if (isRegistered<T>()) {
      return get<T>();
    }
    return null;
  }

  /// Check if service is registered
  bool isRegisteredSafe<T extends Object>() {
    return isRegistered<T>();
  }
}
