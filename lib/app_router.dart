import "package:flutter/material.dart";

import "screens/become_delivery_man_screen.dart";
import "screens/map_location_picker_screen.dart";
import "screens/menu_items_list_screen.dart";
import "screens/permissions_screen.dart";
import "screens/restaurant_details_screen.dart";
import "screens/restaurant_reviews_screen.dart";
import "services/transition_service.dart";
import "splash_screen.dart";
import "widgets/restaurant_dashboard_screen/manage_menu_screen.dart";
import "widgets/review_submission_widget.dart";

class AppRouter {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final name = settings.name;
    final args = settings.arguments;

    switch (name) {
      case "/":
        return TransitionService.fadeTransition(const SplashScreen());
      case "/become_delivery_man":
        return TransitionService.fadeTransition(
          const BecomeDeliveryManScreen(),
        );
      case "/manage-menu":
        return TransitionService.slideFromRight(
          const ManageMenuScreen(),
        );
      case "/menu-items-list":
        return TransitionService.premiumAppTransition(
          const MenuItemsListScreen(),
        );
      case "/restaurant-reviews":
        if (args is Map && args["restaurant"] != null) {
          return TransitionService.slideFromRight(
            RestaurantReviewsScreen(restaurant: args["restaurant"]),
          );
        }
        break;
      case "/review-submission":
        if (args is Map) {
          return TransitionService.slideFromBottom(
            ReviewSubmissionWidget(
              reviewType: args["reviewType"] ?? ReviewType.restaurant,
              restaurant: args["restaurant"],
              menuItem: args["menuItem"],
              order: args["order"],
            ),
          );
        }
        break;
      case "/restaurant-details":
        if (args is Map && args["restaurant"] != null) {
          return TransitionService.heroTransition(
            RestaurantDetailsScreen(restaurant: args["restaurant"]),
          );
        }
        break;
      case "/map-location-picker":
        return TransitionService.slideFromRight(
          const MapLocationPickerScreen(),
        );
      case "/permissions":
        return TransitionService.fadeTransition(
          const PermissionsScreen(),
        );
    }

    return null;
  }

  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return TransitionService.fadeTransition(const SplashScreen());
  }
}
