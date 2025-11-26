import 'package:flutter/material.dart';

/// Custom scroll physics for highly responsive pull-to-refresh
///
/// Reduces the drag distance needed to trigger refresh by:
/// - Amplifying pull-down gestures by 1.8x
/// - Lowering fling velocity threshold
/// - Increasing sensitivity to initial drag
class ResponsiveRefreshScrollPhysics extends AlwaysScrollableScrollPhysics {
  const ResponsiveRefreshScrollPhysics({super.parent});

  @override
  ResponsiveRefreshScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ResponsiveRefreshScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // When pulling down (negative offset) at the top, amplify the movement
    // This makes the refresh indicator appear faster with less drag
    if (position.pixels <= 0 && offset < 0) {
      // Amplify pull-down gesture by 1.8x for faster refresh triggering
      return offset * 1.8;
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  double get minFlingVelocity => 50.0; // Lower threshold for fling

  @override
  double get dragStartDistanceMotionThreshold =>
      3.5; // More sensitive to initial drag
}
