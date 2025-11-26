import 'package:flutter/material.dart';

class Floating3DCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? backgroundColor;
  final bool isPressed;
  final VoidCallback? onTap;
  final double elevation;
  final double? width;
  final double? height;

  const Floating3DCard({
    required this.child,
    super.key,
    this.margin,
    this.padding,
    this.borderRadius = 16,
    this.backgroundColor,
    this.isPressed = false,
    this.onTap,
    this.elevation = 1.0,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? Colors.white;
    final baseElevation = elevation * 12;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      width: width,
      height: height,
      margin:
          margin ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow:
            isPressed ? _getPressedShadows() : _getNormalShadows(baseElevation),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }

  List<BoxShadow> _getNormalShadows(double baseElevation) {
    return [
      // Primary shadow - sharp and close
      BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.13),
        blurRadius: baseElevation * 1.5,
        offset: Offset(0, baseElevation * 0.5),
        spreadRadius: 0,
      ),
      // Secondary shadow - medium depth
      BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.08),
        blurRadius: baseElevation * 2.5,
        offset: Offset(0, baseElevation * 0.8),
        spreadRadius: 0,
      ),
      // Tertiary shadow - soft and distant
      BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.06),
        blurRadius: baseElevation * 4,
        offset: Offset(0, baseElevation * 1.5),
        spreadRadius: 0,
      ),
      // Ambient shadow - overall depth
      BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.04),
        blurRadius: baseElevation * 6,
        offset: Offset(0, baseElevation * 2),
        spreadRadius: 0,
      ),
    ];
  }

  List<BoxShadow> _getPressedShadows() {
    return [
      // Minimal shadow when pressed
      BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.06),
        blurRadius: 4,
        offset: const Offset(0, 1),
        spreadRadius: 0,
      ),
    ];
  }
}

class Floating3DButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? width;
  final double? height;
  final bool enabled;

  const Floating3DButton({
    required this.child,
    super.key,
    this.onPressed,
    this.padding,
    this.borderRadius = 12,
    this.backgroundColor,
    this.foregroundColor,
    this.width,
    this.height,
    this.enabled = true,
  });

  @override
  State<Floating3DButton> createState() => _Floating3DButtonState();
}

class _Floating3DButtonState extends State<Floating3DButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? const Color(0xFF000000);
    final fgColor = widget.foregroundColor ?? Colors.white;

    return GestureDetector(
      onTapDown:
          widget.enabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp:
          widget.enabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel:
          widget.enabled ? () => setState(() => _isPressed = false) : null,
      onTap: widget.enabled ? widget.onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        width: widget.width,
        height: widget.height ?? 48,
        padding: widget.padding ??
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: widget.enabled ? bgColor : bgColor.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: _isPressed || !widget.enabled
              ? _getPressedShadows()
              : _getNormalShadows(),
        ),
        transform: Matrix4.identity()
          ..translateByDouble(0.0, _isPressed ? 2.0 : 0.0, 0.0, 0.0),
        child: Center(
          child: DefaultTextStyle(
            style: TextStyle(
              color: widget.enabled ? fgColor : fgColor.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }

  List<BoxShadow> _getNormalShadows() {
    return [
      // Primary shadow
      BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.25),
        blurRadius: 12,
        offset: const Offset(0, 6),
        spreadRadius: 0,
      ),
      // Secondary shadow
      BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.12),
        blurRadius: 24,
        offset: const Offset(0, 12),
        spreadRadius: 0,
      ),
    ];
  }

  List<BoxShadow> _getPressedShadows() {
    return [
      BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.16),
        blurRadius: 6,
        offset: const Offset(0, 2),
        spreadRadius: 0,
      ),
    ];
  }
}

class Floating3DContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? backgroundColor;
  final double elevation;
  final double? width;
  final double? height;
  final Gradient? gradient;

  const Floating3DContainer({
    required this.child,
    super.key,
    this.margin,
    this.padding,
    this.borderRadius = 16,
    this.backgroundColor,
    this.elevation = 1.0,
    this.width,
    this.height,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final baseElevation = elevation * 12;

    return Container(
      width: width,
      height: height,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: gradient == null ? (backgroundColor ?? Colors.white) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          // Primary shadow
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.15),
            blurRadius: baseElevation * 1.5,
            offset: Offset(0, baseElevation * 0.5),
            spreadRadius: 0,
          ),
          // Secondary shadow
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.10),
            blurRadius: baseElevation * 2.5,
            offset: Offset(0, baseElevation * 0.8),
            spreadRadius: 0,
          ),
          // Tertiary shadow
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.08),
            blurRadius: baseElevation * 4,
            offset: Offset(0, baseElevation * 1.5),
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}

class FloatingBottomBar extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? height;

  const FloatingBottomBar({
    required this.child,
    super.key,
    this.padding,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height ?? 80,
      margin: const EdgeInsets.all(16),
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          // Strong upward shadow for floating effect
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.18),
            blurRadius: 25,
            offset: const Offset(0, -8),
            spreadRadius: 0,
          ),
          // Secondary shadow
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.10),
            blurRadius: 40,
            offset: const Offset(0, -15),
            spreadRadius: 0,
          ),
          // Ambient shadow
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.06),
            blurRadius: 60,
            offset: const Offset(0, -25),
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}
