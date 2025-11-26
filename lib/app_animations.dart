import 'package:flutter/material.dart';

// Central application-wide animation configuration and helpers.
// This re-exports the existing AppAnimations utilities to provide a single
// import path for the whole app.

export 'utils/animations.dart';

// Global defaults to encourage consistent usage in widgets where durations/curves are needed.
class AppAnimationDefaults {
  static const Duration tabSwitchDuration = Duration(milliseconds: 325);
  static const Curve tabSwitchCurve = Curves.easeInOut;
}
