import 'package:flutter/material.dart';

/// Helper class for creating consistent Hero animations across the app
class HeroAnimationHelper {
  /// Create a unique hero tag for menu items
  static String menuItemTag(String menuItemId, {String suffix = ''}) {
    return 'menu_item_${menuItemId}_$suffix';
  }

  /// Create a unique hero tag for menu item images
  static String menuItemImageTag(String menuItemId) {
    return menuItemTag(menuItemId, suffix: 'image');
  }

  /// Create a unique hero tag for menu item titles
  static String menuItemTitleTag(String menuItemId) {
    return menuItemTag(menuItemId, suffix: 'title');
  }

  /// Create a unique hero tag for menu item prices
  static String menuItemPriceTag(String menuItemId) {
    return menuItemTag(menuItemId, suffix: 'price');
  }

  /// Create a unique hero tag for restaurants
  static String restaurantTag(String restaurantId, {String suffix = ''}) {
    return 'restaurant_${restaurantId}_$suffix';
  }

  /// Create a unique hero tag for restaurant images
  static String restaurantImageTag(String restaurantId) {
    return restaurantTag(restaurantId, suffix: 'image');
  }

  /// Default hero flight animation
  static Widget flightShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    return DefaultTextStyle(
      style: DefaultTextStyle.of(toHeroContext).style,
      child: toHeroContext.widget,
    );
  }

  /// Create a hero-wrapped widget with standard configuration
  static Widget wrap({
    required String tag,
    required Widget child,
    HeroFlightShuttleBuilder? flightShuttleBuilder,
  }) {
    return Hero(
      tag: tag,
      createRectTween: (Rect? begin, Rect? end) {
        return MaterialRectArcTween(begin: begin, end: end);
      },
      flightShuttleBuilder:
          flightShuttleBuilder ?? _defaultFlightShuttleBuilder,
      child: child,
    );
  }

  /// Default flight shuttle builder
  static Widget _defaultFlightShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    return DefaultTextStyle(
      style: DefaultTextStyle.of(toHeroContext).style,
      child: toHeroContext.widget,
    );
  }
}

/// Custom page route with hero animation
class HeroPageRoute<T> extends MaterialPageRoute<T> {
  HeroPageRoute({
    required super.builder,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
  });

  @override
  Duration get transitionDuration => const Duration(milliseconds: 350);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);
}

/// Fade-through page route (Material Design 3 style)
class FadeThroughPageRoute<T> extends PageRoute<T> {
  FadeThroughPageRoute({
    required this.builder,
    super.settings,
    this.maintainState = true,
    super.fullscreenDialog = false,
  });

  final WidgetBuilder builder;

  @override
  final bool maintainState;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }
}
