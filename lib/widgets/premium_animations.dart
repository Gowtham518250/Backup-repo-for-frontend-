import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 🎨 Premium Animations Helper
/// Provides ready-to-use premium animations for RETAIL MIND app
class PremiumAnimations {
  // Hero transitions with smooth animations
  static Widget heroTransition({
    required String tag,
    required Widget child,
    bool enabled = true,
  }) {
    if (!enabled) return child;
    
    return Hero(
      tag: tag,
      child: Material(
        type: MaterialType.transparency,
        child: child,
      ),
      flightShuttleBuilder: (flightContext, animation, direction, fromContext, toContext) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Transform.scale(
              scale: Tween<double>(begin: 0.8, end: 1.0).evaluate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: Opacity(
                opacity: animation.value,
                child: child,
              ),
            );
          },
          child: child,
        );
      },
    );
  }

  // Fade in animation
  static Widget fadeIn({
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
    Duration delay = Duration.zero,
    Curve curve = Curves.easeOut,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 20),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  // Scale on tap animation
  static Widget scaleOnTap({
    required Widget child,
    required VoidCallback onTap,
    double scaleDown = 0.95,
    Duration duration = const Duration(milliseconds: 200),
  }) {
    return GestureDetector(
      onTap: onTap,
      onTapDown: (_) => null, // Scale down handled by AnimatedScale
      onTapUp: (_) => null,
      onTapCancel: () => null,
      child: AnimatedScale(
        scale: 1.0,
        duration: duration,
        curve: Curves.easeInOut,
        child: child,
      ),
    );
  }

  // Ripple effect button
  static Widget rippleButton({
    required Widget child,
    required VoidCallback onTap,
    Color? splashColor,
    BorderRadius? borderRadius,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: splashColor ?? Colors.black.withValues(alpha: 0.1),
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        child: child,
      ),
    );
  }

  // Shimmer loading effect
  static Widget shimmer({
    required Widget child,
    Color? baseColor,
    Color? highlightColor,
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    return ShimmerAnimation(
      child: child,
      baseColor: baseColor ?? Colors.grey.shade300,
      highlightColor: highlightColor ?? Colors.grey.shade100,
      duration: duration,
    );
  }

  // Animated counter
  static Widget animatedCounter({
    required int value,
    Duration duration = const Duration(milliseconds: 500),
    TextStyle? style,
    String? prefix,
    String? suffix,
  }) {
    return _AnimatedCounter(
      value: value,
      duration: duration,
      style: style,
      prefix: prefix,
      suffix: suffix,
    );
  }

  // Slide in animation
  static Widget slideIn({
    required Widget child,
    Offset begin = const Offset(0, 1),
    Offset end = Offset.zero,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOut,
  }) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween<Offset>(begin: begin, end: end),
      duration: duration,
      curve: curve,
      builder: (context, offset, child) {
        return SlideTransition(
          position: AlwaysStoppedAnimation(offset),
          child: FadeTransition(
            opacity: AlwaysStoppedAnimation(1.0 - offset.distance),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  // Staggered animation for lists
  static List<Widget> staggeredList({
    required List<Widget> children,
    Duration duration = const Duration(milliseconds: 300),
    Duration staggerDelay = const Duration(milliseconds: 50),
    Offset begin = const Offset(0, 0.5),
  }) {
    return children.asMap().entries.map((entry) {
      final index = entry.key;
      final child = entry.value;
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: duration,
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: begin * (1 - value),
              child: child,
            ),
          );
        },
        child: child,
      );
    }).toList();
  }
}

/// Shimmer Animation Widget
class ShimmerAnimation extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  const ShimmerAnimation({
    super.key,
    required this.child,
    this.baseColor = Colors.grey,
    this.highlightColor = Colors.white,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<ShimmerAnimation> createState() => _ShimmerAnimationState();
}

class _ShimmerAnimationState extends State<ShimmerAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            widget.baseColor,
            widget.highlightColor,
            widget.baseColor,
          ],
          stops: const [0.0, 0.5, 1.0],
          transform: _SlidingGradientTransform(
            slidePercent: _animation.value,
          ),
        ).createShader(bounds);
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

/// Animated Counter Widget
class _AnimatedCounter extends StatefulWidget {
  final int value;
  final Duration duration;
  final TextStyle? style;
  final String? prefix;
  final String? suffix;

  const _AnimatedCounter({
    required this.value,
    required this.duration,
    this.style,
    this.prefix,
    this.suffix,
  });

  @override
  State<_AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<_AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = IntTween(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(_AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.reset();
      _animation = IntTween(begin: oldWidget.value, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          '${widget.prefix ?? ''}${_animation.value}${widget.suffix ?? ''}',
          style: widget.style,
        );
      },
    );
  }
}

/// Premium Page Transition
class PremiumPageTransition extends PageRouteBuilder {
  final Widget child;

  PremiumPageTransition({required this.child})
      : super(
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut),
              ),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.05),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
                child: child,
              ),
            );
          },
        );
}