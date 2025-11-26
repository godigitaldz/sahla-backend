import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  StreamSubscription? _subscription;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Initialize deep link handling
  Future<void> initialize() async {
    try {
      final appLinks = AppLinks();

      // Handle initial link if app was launched from a link
      final initialLink = await appLinks.getInitialAppLink();
      if (initialLink != null) {
        await handleDeepLink(initialLink.toString());
      }

      // Listen for incoming links when app is already running
      _subscription = appLinks.uriLinkStream.listen((Uri? uri) async {
        if (uri != null) {
          await handleDeepLink(uri.toString());
        }
      }, onError: (err) {
        debugPrint('Deep link error: $err');
      });
    } catch (e) {
      debugPrint('Error initializing deep links: $e');
    }
  }

  // Handle deep link navigation
  Future<void> handleDeepLink(String url) async {
    try {
      final uri = Uri.parse(url);

      if (uri.host == 'sahla-app.com' || uri.host == 'www.sahla-app.com') {
        final path = uri.pathSegments;

        if (path.isNotEmpty) {
          switch (path[0]) {
            case 'host':
              if (path.length > 1) {
                await _navigateToHostProfile(path[1]);
              }
              break;
            case 'car':
              if (path.length > 1) {
                await _navigateToCarDetails(path[1]);
              }
              break;
            case 'booking':
              if (path.length > 1) {
                await _navigateToBookingDetails(path[1]);
              }
              break;
            case 'favorites':
              if (path.length > 1) {
                await _navigateToFavoriteList(path[1]);
              }
              break;
            case 'search':
              await _navigateToSearch(uri.queryParameters);
              break;
          }
        }
      }
    } catch (e) {
      debugPrint('Error handling deep link: $e');
    }
  }

  // Navigate to host profile
  Future<void> _navigateToHostProfile(String hostId) async {
    try {
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        // Import the host profile screen and navigate
        // This will be implemented when we have the proper imports
        debugPrint('Navigate to host profile: $hostId');

        // Example navigation (uncomment when imports are available):
        // navigator.pushNamed('/host-profile', arguments: {'hostId': hostId});
      }
    } catch (e) {
      debugPrint('Error navigating to host profile: $e');
    }
  }

  // Navigate to car details
  Future<void> _navigateToCarDetails(String carId) async {
    try {
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        debugPrint('Navigate to car details: $carId');

        // Example navigation (uncomment when imports are available):
        // navigator.pushNamed('/car-details', arguments: {'carId': carId});
      }
    } catch (e) {
      debugPrint('Error navigating to car details: $e');
    }
  }

  // Navigate to booking details
  Future<void> _navigateToBookingDetails(String bookingId) async {
    try {
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        debugPrint('Navigate to booking details: $bookingId');

        // Example navigation (uncomment when imports are available):
        // navigator.pushNamed('/booking-details', arguments: {'bookingId': bookingId});
      }
    } catch (e) {
      debugPrint('Error navigating to booking details: $e');
    }
  }

  // Navigate to favorite list
  Future<void> _navigateToFavoriteList(String listName) async {
    try {
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        debugPrint('Navigate to favorite list: $listName');

        // Example navigation (uncomment when imports are available):
        // navigator.pushNamed('/favorites', arguments: {'listName': listName});
      }
    } catch (e) {
      debugPrint('Error navigating to favorite list: $e');
    }
  }

  // Navigate to search with parameters
  Future<void> _navigateToSearch(Map<String, String> parameters) async {
    try {
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        debugPrint('Navigate to search with parameters: $parameters');

        // Example navigation (uncomment when imports are available):
        // navigator.pushNamed('/search', arguments: parameters);
      }
    } catch (e) {
      debugPrint('Error navigating to search: $e');
    }
  }

  // Dispose resources
  void dispose() {
    _subscription?.cancel();
  }

  // Get navigator key for global navigation
  GlobalKey<NavigatorState> getNavigatorKey() {
    return navigatorKey;
  }
}
