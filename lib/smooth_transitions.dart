import 'package:flutter/material.dart';
import 'package:flutter/services.dart' as services;
import 'dart:math' as math;

/// Custom page transitions for smooth navigation
class SlidePageTransition extends PageRouteBuilder {
  final Widget page;
  final Duration duration;

  SlidePageTransition({
    required this.page,
    this.duration = const Duration(milliseconds: 400),
  }) : super(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeInOut;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
  );
}

/// Fade + Scale transition
class FadeScalePageTransition extends PageRouteBuilder {
  final Widget page;
  final Duration duration;

  FadeScalePageTransition({
    required this.page,
    this.duration = const Duration(milliseconds: 400),
  }) : super(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut),
          ),
          child: child,
        ),
      );
    },
  );
}

/// Rotate + Fade transition
class RotateFadePageTransition extends PageRouteBuilder {
  final Widget page;
  final Duration duration;

  RotateFadePageTransition({
    required this.page,
    this.duration = const Duration(milliseconds: 500),
  }) : super(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: RotationTransition(
          turns: Tween<double>(begin: -0.1, end: 0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut),
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Blur + Slide transition
class BlurSlidePageTransition extends PageRouteBuilder {
  final Widget page;
  final Duration duration;

  BlurSlidePageTransition({
    required this.page,
    this.duration = const Duration(milliseconds: 500),
  }) : super(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0, 1.0);
      const end = Offset.zero;

      var tween = Tween(begin: begin, end: end).chain(
        CurveTween(curve: Curves.easeOut),
      );

      return SlideTransition(
        position: animation.drive(tween),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
  );
}

/// Shared axis transition (horizontal)
class SharedAxisHorizontalTransition extends PageRouteBuilder {
  final Widget page;
  final Duration duration;

  SharedAxisHorizontalTransition({
    required this.page,
    this.duration = const Duration(milliseconds: 400),
  }) : super(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
  );
}

/// Gestured base widget for swipe interactions
class GestureInteractionWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;
  final VoidCallback? onLongPress;
  final Duration longPressDuration;

  const GestureInteractionWrapper({
    Key? key,
    required this.child,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onSwipeUp,
    this.onSwipeDown,
    this.onLongPress,
    this.longPressDuration = const Duration(milliseconds: 500),
  }) : super(key: key);

  @override
  State<GestureInteractionWrapper> createState() =>
      _GestureInteractionWrapperState();
}

class _GestureInteractionWrapperState extends State<GestureInteractionWrapper> {
  Offset _startPosition = Offset.zero;
  final double _swipeThreshold = 50;

  void _handlePanStart(DragStartDetails details) {
    _startPosition = details.globalPosition;
  }

  void _handlePanEnd(DragEndDetails details) {
    final dx = _startPosition.dx - details.globalPosition.dx;
    final dy = _startPosition.dy - details.globalPosition.dy;

    if (dx.abs() > dy.abs()) {
      // Horizontal swipe
      if (dx > _swipeThreshold) {
        widget.onSwipeLeft?.call();
      } else if (dx < -_swipeThreshold) {
        widget.onSwipeRight?.call();
      }
    } else {
      // Vertical swipe
      if (dy > _swipeThreshold) {
        widget.onSwipeUp?.call();
      } else if (dy < -_swipeThreshold) {
        widget.onSwipeDown?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _handlePanStart,
      onPanEnd: _handlePanEnd,
      onLongPress: widget.onLongPress,
      child: widget.child,
    );
  }
}


/// Haptic feedback helper
class HapticHelper {
  static void light() {
    Future.microtask(() {
      try {
        services.HapticFeedback.vibrate();
      } catch (_) {}
    });
  }

  static void medium() {
    Future.microtask(() {
      try {
        services.HapticFeedback.vibrate();
        Future.delayed(const Duration(milliseconds: 100), () {
          services.HapticFeedback.vibrate();
        });
      } catch (_) {}
    });
  }

  static void heavy() {
    Future.microtask(() {
      try {
        services.HapticFeedback.vibrate();
        Future.delayed(const Duration(milliseconds: 100), () {
          services.HapticFeedback.vibrate();
        });
        Future.delayed(const Duration(milliseconds: 200), () {
          services.HapticFeedback.vibrate();
        });
      } catch (_) {}
    });
  }
}

/// Enhanced button with ripple and scale animation
class EnhancedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final double elevation;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final Duration animationDuration;

  const EnhancedButton({
    Key? key,
    required this.child,
    required this.onPressed,
    this.backgroundColor = const Color(0xFF6366F1),
    this.foregroundColor = Colors.white,
    this.elevation = 4,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.animationDuration = const Duration(milliseconds: 200),
  }) : super(key: key);

  @override
  State<EnhancedButton> createState() => _EnhancedButtonState();
}

class _EnhancedButtonState extends State<EnhancedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _elevation = Tween<double>(begin: widget.elevation, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPressed() {
    _controller.forward().then((_) {
      _controller.reverse();
    });
    widget.onPressed.call();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Material(
            elevation: _elevation.value,
            color: widget.backgroundColor,
            borderRadius: widget.borderRadius,
            child: InkWell(
              onTap: _onPressed,
              borderRadius: widget.borderRadius,
              child: Padding(
                padding: widget.padding,
                child: DefaultTextStyle(
                  style: TextStyle(color: widget.foregroundColor),
                  child: widget.child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Smooth floating action button with expanded menu
class ExpandableFAB extends StatefulWidget {
  final List<FABAction> actions;
  final Color backgroundColor;
  final Color foregroundColor;
  final Duration animationDuration;

  const ExpandableFAB({
    Key? key,
    required this.actions,
    this.backgroundColor = const Color(0xFF6366F1),
    this.foregroundColor = Colors.white,
    this.animationDuration = const Duration(milliseconds: 300),
  }) : super(key: key);

  @override
  State<ExpandableFAB> createState() => _ExpandableFABState();
}

class _ExpandableFABState extends State<ExpandableFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ...widget.actions.asMap().entries.map((entry) {
              final index = entry.key;
              final action = entry.value;
              final angle = widget.actions.length > 1 
                  ? (90 / (widget.actions.length - 1)) * index
                  : 0.0;

              return Transform.translate(
                offset: Offset(
                  -80 * _controller.value * math.cos(angle * math.pi / 180),
                  -80 * _controller.value * math.sin(angle * math.pi / 180),
                ),
                child: Opacity(
                  opacity: _controller.value,
                  child: FloatingActionButton.small(
                    onPressed: () {
                      action.onPressed.call();
                      _controller.reverse();
                    },
                    backgroundColor: action.backgroundColor,
                    child: Icon(action.icon, color: action.foregroundColor),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            FloatingActionButton(
              onPressed: () {
                if (_controller.isDismissed) {
                  _controller.forward();
                } else {
                  _controller.reverse();
                }
              },
              backgroundColor: widget.backgroundColor,
              foregroundColor: widget.foregroundColor,
              child: AnimatedIcon(
                icon: AnimatedIcons.menu_close,
                progress: _controller,
              ),
            ),
          ],
        );
      },
    );
  }
}

class FABAction {
  final IconData icon;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final String label;

  FABAction({
    required this.icon,
    required this.onPressed,
    this.backgroundColor = const Color(0xFF6366F1),
    this.foregroundColor = Colors.white,
    this.label = '',
  });
}
