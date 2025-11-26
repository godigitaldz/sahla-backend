import "package:flutter/material.dart";

import "../utils/animations.dart";

class TransitionService {
  factory TransitionService() => _instance;
  TransitionService._internal();

  static final TransitionService _instance = TransitionService._internal();

  // Slide transition from bottom
  static PageRouteBuilder slideFromBottom(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0, 1);
        const end = Offset.zero;
        const curve = AppAnimations.defaultCurve;
        final tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        final offsetAnimation = animation.drive(tween);
        return SlideTransition(position: offsetAnimation, child: child);
      },
      transitionDuration: AppAnimations.pageTransition,
    );
  }

  // Slide transition from right - OPTIMIZED for performance
  static PageRouteBuilder slideFromRight(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1, 0);
        const end = Offset.zero;
        const curve =
            Curves.easeOutCubic; // Smoother curve for better performance
        final tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        final offsetAnimation = animation.drive(tween);
        return SlideTransition(position: offsetAnimation, child: child);
      },
      transitionDuration:
          const Duration(milliseconds: 250), // Reduced from 300ms
      reverseTransitionDuration: const Duration(milliseconds: 200),
    );
  }

  // Slide transition from left
  static PageRouteBuilder slideFromLeft(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(-1, 0);
        const end = Offset.zero;
        const curve = AppAnimations.defaultCurve;
        final tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        final offsetAnimation = animation.drive(tween);
        return SlideTransition(position: offsetAnimation, child: child);
      },
      transitionDuration: AppAnimations.pageTransition,
    );
  }

  // Fade transition
  static PageRouteBuilder fadeTransition(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: AppAnimations.fast,
    );
  }

  // Scale transition
  static PageRouteBuilder scaleTransition(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = 0.0;
        const end = 1.0;
        const curve = AppAnimations.defaultCurve;
        final tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        final scaleAnimation = animation.drive(tween);
        return ScaleTransition(scale: scaleAnimation, child: child);
      },
      transitionDuration: AppAnimations.pageTransition,
    );
  }

  // Hero transition with custom curve - REMOVED DUPLICATE

  // Custom transition with multiple effects
  static PageRouteBuilder customTransition(
    Widget page, {
    Offset begin = const Offset(0, 1),
    Offset end = Offset.zero,
    Curve curve = AppAnimations.defaultCurve,
    Duration duration = AppAnimations.pageTransition,
    bool enableFade = true,
    bool enableScale = false,
    double scaleBegin = 0.8,
    double scaleEnd = 1.0,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation =
            CurvedAnimation(parent: animation, curve: curve);

        return AnimatedBuilder(
          animation: curvedAnimation,
          builder: (context, child) {
            final animationValue = curvedAnimation.value;

            // Calculate slide offset
            final slideOffset = Offset(
              begin.dx + (end.dx - begin.dx) * animationValue,
              begin.dy + (end.dy - begin.dy) * animationValue,
            );

            Widget result = child!;

            // Apply scale if enabled
            if (enableScale) {
              final scale =
                  scaleBegin + (scaleEnd - scaleBegin) * animationValue;
              result = Transform.scale(scale: scale, child: result);
            }

            // Apply fade if enabled
            if (enableFade) {
              result = Opacity(opacity: animationValue, child: result);
            }

            // Apply slide
            return FractionalTranslation(translation: slideOffset, child: result);
          },
          child: child,
        );
      },
      transitionDuration: duration,
    );
  }

  // Modal bottom sheet transition
  static PageRouteBuilder modalBottomSheet(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = AppAnimations.defaultCurve;
        final curvedAnimation =
            CurvedAnimation(parent: animation, curve: curve);

        return AnimatedBuilder(
          animation: curvedAnimation,
          builder: (context, child) {
            final animationValue = curvedAnimation.value;

            // Calculate slide offset (fractional) - from bottom
            final slideOffset = Offset(0, 1 - animationValue);

            return FractionalTranslation(
              translation: slideOffset,
              child: Opacity(
                opacity: animationValue,
                child: child,
              ),
            );
          },
          child: child,
        );
      },
      transitionDuration: AppAnimations.pageTransition,
      barrierColor: Colors.black54,
      barrierDismissible: true,
    );
  }

  // Card flip transition
  static PageRouteBuilder cardFlipTransition(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(animation.value * 3.14159),
              alignment: Alignment.center,
              child: child,
            );
          },
          child: child,
        );
      },
      transitionDuration: AppAnimations.slow,
    );
  }

  // Elastic transition
  static PageRouteBuilder elasticTransition(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0, 1);
        const end = Offset.zero;
        const curve = Curves.elasticOut;
        final tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        final offsetAnimation = animation.drive(tween);
        return SlideTransition(position: offsetAnimation, child: child);
      },
      transitionDuration: AppAnimations.slow,
    );
  }

  // Bounce transition
  static PageRouteBuilder bounceTransition(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0, 1);
        const end = Offset.zero;
        const curve = Curves.bounceOut;
        final tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        final offsetAnimation = animation.drive(tween);
        return SlideTransition(position: offsetAnimation, child: child);
      },
      transitionDuration: AppAnimations.medium,
    );
  }

  // Zoom transition
  static PageRouteBuilder zoomTransition(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = AppAnimations.defaultCurve;
        final curvedAnimation =
            CurvedAnimation(parent: animation, curve: curve);

        return AnimatedBuilder(
          animation: curvedAnimation,
          builder: (context, child) {
            final animationValue = curvedAnimation.value;

            return Transform.scale(
              scale: animationValue,
              child: Opacity(
                opacity: animationValue,
                child: child,
              ),
            );
          },
          child: child,
        );
      },
      transitionDuration: AppAnimations.pageTransition,
    );
  }

  // Hero transition - LIGHT PROBE APP ANIMATION (simple scale + fade)
  static PageRouteBuilder heroTransition(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Light probe app animation: subtle scale with fade using AnimatedBuilder
        const curve = Curves.easeOutCubic;
        final curvedAnimation =
            CurvedAnimation(parent: animation, curve: curve);

        return AnimatedBuilder(
          animation: curvedAnimation,
          builder: (context, child) {
            final animationValue = curvedAnimation.value;

            // Calculate scale from 0.95 to 1.0
            final scale = 0.95 + (0.05 * animationValue);

            return Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: animationValue,
                child: child,
              ),
            );
          },
          child: child,
        );
      },
      transitionDuration: const Duration(
          milliseconds: 250), // Faster to prevent heavy animation
      reverseTransitionDuration:
          const Duration(milliseconds: 200), // Even faster reverse
    );
  }

  // Navigate with transition
  static Future<T?> navigateWithTransition<T extends Object?>(
    BuildContext context,
    Widget page, {
    TransitionType transitionType = TransitionType.slideFromBottom,
    Duration? duration,
    bool fullscreenDialog = false,
  }) {
    PageRoute<T> route;

    switch (transitionType) {
      case TransitionType.slideFromBottom:
        route = slideFromBottom(page) as PageRoute<T>;
        break;
      case TransitionType.slideFromRight:
        route = slideFromRight(page) as PageRoute<T>;
        break;
      case TransitionType.slideFromLeft:
        route = slideFromLeft(page) as PageRoute<T>;
        break;
      case TransitionType.fade:
        route = fadeTransition(page) as PageRoute<T>;
        break;
      case TransitionType.scale:
        route = scaleTransition(page) as PageRoute<T>;
        break;
      case TransitionType.hero:
        route = heroTransition(page) as PageRoute<T>;
        break;
      case TransitionType.modalBottomSheet:
        route = modalBottomSheet(page) as PageRoute<T>;
        break;
      case TransitionType.cardFlip:
        route = cardFlipTransition(page) as PageRoute<T>;
        break;
      case TransitionType.elastic:
        route = elasticTransition(page) as PageRoute<T>;
        break;
      case TransitionType.bounce:
        route = bounceTransition(page) as PageRoute<T>;
        break;
      case TransitionType.zoom:
        route = zoomTransition(page) as PageRoute<T>;
        break;
      case TransitionType.smoothApp:
        route = smoothAppTransition(page) as PageRoute<T>;
        break;
      case TransitionType.premiumApp:
        route = premiumAppTransition(page) as PageRoute<T>;
        break;
    }

    return Navigator.of(context).push<T>(route);
  }

  static Future<T?>
      replaceWithTransition<T extends Object?, TO extends Object?>(
    BuildContext context,
    Widget page, {
    TransitionType transitionType = TransitionType.slideFromRight,
    TO? result,
  }) {
    final route = _routeForType<T>(page, transitionType);
    return Navigator.of(context).pushReplacement<T, TO>(route, result: result);
  }

  static PageRoute<T> _routeForType<T>(Widget page, TransitionType type) {
    switch (type) {
      case TransitionType.slideFromBottom:
        return slideFromBottom(page) as PageRoute<T>;
      case TransitionType.slideFromRight:
        return slideFromRight(page) as PageRoute<T>;
      case TransitionType.slideFromLeft:
        return slideFromLeft(page) as PageRoute<T>;
      case TransitionType.fade:
        return fadeTransition(page) as PageRoute<T>;
      case TransitionType.scale:
        return scaleTransition(page) as PageRoute<T>;
      case TransitionType.hero:
        return heroTransition(page) as PageRoute<T>;
      case TransitionType.modalBottomSheet:
        return modalBottomSheet(page) as PageRoute<T>;
      case TransitionType.cardFlip:
        return cardFlipTransition(page) as PageRoute<T>;
      case TransitionType.elastic:
        return elasticTransition(page) as PageRoute<T>;
      case TransitionType.bounce:
        return bounceTransition(page) as PageRoute<T>;
      case TransitionType.zoom:
        return zoomTransition(page) as PageRoute<T>;
      case TransitionType.smoothApp:
        return smoothAppTransition(page) as PageRoute<T>;
      case TransitionType.premiumApp:
        return premiumAppTransition(page) as PageRoute<T>;
    }
  }

  // Animated widget transitions
  static Widget animatedContainer({
    required Widget child,
    required bool isVisible,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
    Offset? slideOffset,
    double? scale,
  }) {
    return AnimatedContainer(
      duration: duration,
      curve: curve,
      child: AnimatedOpacity(
        opacity: isVisible ? 1.0 : 0.0,
        duration: duration,
        child: slideOffset != null
            ? AnimatedSlide(
                offset: isVisible ? Offset.zero : slideOffset,
                duration: duration,
                child: scale != null
                    ? AnimatedScale(
                        scale: isVisible ? 1.0 : scale,
                        duration: duration,
                        child: child,
                      )
                    : child,
              )
            : scale != null
                ? AnimatedScale(
                    scale: isVisible ? 1.0 : scale,
                    duration: duration,
                    child: child,
                  )
                : child,
      ),
    );
  }

  // Staggered animation for lists
  static List<Animation<double>> createStaggeredAnimations(
    AnimationController controller,
    int itemCount, {
    Duration interval = const Duration(milliseconds: 100),
  }) {
    final animations = <Animation<double>>[];

    for (int i = 0; i < itemCount; i++) {
      final delay = i * interval.inMilliseconds;
      final animation = Tween<double>(
        begin: 0,
        end: 1,
      ).animate(
        CurvedAnimation(
          parent: controller,
          curve: Interval(
            delay / controller.duration!.inMilliseconds,
            (delay + interval.inMilliseconds) /
                controller.duration!.inMilliseconds,
            curve: Curves.easeOutCubic,
          ),
        ),
      );
      animations.add(animation);
    }

    return animations;
  }

  // Smooth cart transition with scale and slide
  static PageRouteBuilder cartTransition(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Combine scale and slide using AnimatedBuilder for better lifecycle management
        final slideCurve =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        final scaleCurve =
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack);

        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final slideValue = slideCurve.value;
            final scaleValue = scaleCurve.value;

            // Calculate slide offset (fractional)
            final slideOffset = Offset(0, 0.3 * (1 - slideValue));

            // Calculate scale from 0.8 to 1.0
            final scale = 0.8 + (0.2 * scaleValue);

            // Fade animation
            final opacity = animation.value;

            return FractionalTranslation(
              translation: slideOffset,
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: child,
                ),
              ),
            );
          },
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 300),
    );
  }

  // Smooth app-like transition with subtle scale and fade
  static PageRouteBuilder smoothAppTransition(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Smooth app-like transition using AnimatedBuilder for better lifecycle management
        const curve = Curves.easeOutCubic;
        final curvedAnimation =
            CurvedAnimation(parent: animation, curve: curve);

        return AnimatedBuilder(
          animation: curvedAnimation,
          builder: (context, child) {
            final animationValue = curvedAnimation.value;

            // Calculate slide offset (fractional)
            final slideOffset = Offset(0.05 * (1 - animationValue), 0.0);

            // Calculate scale
            final scale = 0.98 + (0.02 * animationValue);

            // Calculate opacity
            final opacity = animationValue;

            return FractionalTranslation(
              translation: slideOffset,
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: child,
                ),
              ),
            );
          },
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
    );
  }

  // Premium app transition with parallax effect
  static PageRouteBuilder premiumAppTransition(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Premium transition with smooth curves - using AnimatedBuilder for better lifecycle management
        const curve = Curves.easeOutQuart;
        final curvedAnimation =
            CurvedAnimation(parent: animation, curve: curve);

        return AnimatedBuilder(
          animation: curvedAnimation,
          builder: (context, child) {
            final animationValue = curvedAnimation.value;

            // Calculate slide offset (fractional)
            final slideOffset = Offset(0.08 * (1 - animationValue), 0.0);

            // Calculate scale
            final scale = 0.96 + (0.04 * animationValue);

            // Calculate opacity
            final opacity = animationValue;

            return FractionalTranslation(
              translation: slideOffset,
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: child,
                ),
              ),
            );
          },
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 280),
    );
  }
}

enum TransitionType {
  slideFromBottom,
  slideFromRight,
  slideFromLeft,
  fade,
  scale,
  hero,
  modalBottomSheet,
  cardFlip,
  elastic,
  bounce,
  zoom,
  smoothApp,
  premiumApp,
}
