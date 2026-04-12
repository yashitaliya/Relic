import 'package:flutter/material.dart';

/// Centralized animation configurations for the entire app
/// Ensures consistent, smooth, and calm animations throughout
class AppAnimations {
  // Durations - calm and not too fast
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration verySlow = Duration(milliseconds: 600);

  // Curves - smooth and natural
  static const Curve defaultCurve = Curves.easeInOutCubic;
  static const Curve entranceCurve = Curves.easeOut;
  static const Curve exitCurve = Curves.easeIn;
  static const Curve bounceCurve = Curves.elasticOut;
  static const Curve smoothCurve = Curves.easeInOutQuad;

  /// Fade transition for route navigation
  static PageRouteBuilder<T> fadeRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: medium,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: defaultCurve),
          child: child,
        );
      },
    );
  }

  /// Slide from bottom transition
  static PageRouteBuilder<T> slideUpRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: medium,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        final tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: defaultCurve));
        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  /// Scale and fade transition
  static PageRouteBuilder<T> scaleRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: medium,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: defaultCurve),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  /// Shimmer loading animation
  static Widget shimmerLoading({
    required double width,
    required double height,
    BorderRadius? borderRadius,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1500),
      builder: (context, value, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.grey[300]!, Colors.grey[100]!, Colors.grey[300]!],
              stops: [
                (value - 0.3).clamp(0.0, 1.0),
                value,
                (value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
      onEnd: () {
        // Loop animation
      },
    );
  }

  /// Smooth opacity animation widget
  static Widget fadeIn({
    required Widget child,
    Duration? duration,
    Curve? curve,
    Duration? delay,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration ?? medium,
      curve: curve ?? defaultCurve,
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      child: child,
    );
  }

  /// Slide and fade in animation
  static Widget slideAndFadeIn({
    required Widget child,
    Duration? duration,
    Offset? begin,
    Curve? curve,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration ?? medium,
      curve: curve ?? defaultCurve,
      builder: (context, value, child) {
        final slideValue = begin ?? const Offset(0, 0.1);
        return Transform.translate(
          offset: Offset(
            slideValue.dx * (1 - value),
            slideValue.dy * (1 - value),
          ),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: child,
    );
  }

  /// Scale animation on tap
  static Widget scaleOnTap({
    required Widget child,
    required VoidCallback onTap,
    double scaleValue = 0.95,
  }) {
    return _ScaleOnTapWidget(
      onTap: onTap,
      scaleValue: scaleValue,
      child: child,
    );
  }

  /// Animated container with smooth transitions
  static AnimatedContainer smoothContainer({
    required Duration duration,
    required Widget child,
    Color? color,
    double? width,
    double? height,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    BoxDecoration? decoration,
    Curve? curve,
  }) {
    return AnimatedContainer(
      duration: duration,
      curve: curve ?? defaultCurve,
      color: color,
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      decoration: decoration,
      child: child,
    );
  }
}

/// Internal widget for scale on tap animation
class _ScaleOnTapWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scaleValue;

  const _ScaleOnTapWidget({
    required this.child,
    required this.onTap,
    required this.scaleValue,
  });

  @override
  State<_ScaleOnTapWidget> createState() => _ScaleOnTapWidgetState();
}

class _ScaleOnTapWidgetState extends State<_ScaleOnTapWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.fast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleValue).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.smoothCurve),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

/// Smooth refresh indicator
class SmoothRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const SmoothRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: const Color(0xFFF37121),
      backgroundColor: Colors.white,
      displacement: 40,
      strokeWidth: 2.5,
      triggerMode: RefreshIndicatorTriggerMode.onEdge,
      child: child,
    );
  }
}
