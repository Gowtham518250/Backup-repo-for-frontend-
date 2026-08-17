import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ✨ Advanced Animations with Micro-interactions, Particles, Spring Physics
class AdvancedAnimations {
  // Spring physics curves
  static const Curve springCurve = Cubic(0.175, 0.885, 0.32, 1.275);
  static const Curve bounceCurve = Cubic(0.68, -0.55, 0.265, 1.55);
  static const Curve elasticCurve = Cubic(0.36, 0.07, 0.19, 0.97);
  
  // Duration presets
  static const Duration microDuration = Duration(milliseconds: 150);
  static const Duration quickDuration = Duration(milliseconds: 200);
  static const Duration normalDuration = Duration(milliseconds: 300);
  static const Duration slowDuration = Duration(milliseconds: 500);
  static const Duration verySlowDuration = Duration(milliseconds: 800);
}

/// Micro-interaction wrapper for buttons and cards
class MicroInteractionWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressScale;
  final double hoverScale;
  final Color? splashColor;
  final bool enableHaptics;

  const MicroInteractionWidget({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressScale = 0.95,
    this.hoverScale = 1.02,
    this.splashColor,
    this.enableHaptics = true,
  });

  @override
  State<MicroInteractionWidget> createState() => _MicroInteractionWidgetState();
}

class _MicroInteractionWidgetState extends State<MicroInteractionWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AdvancedAnimations.microDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AdvancedAnimations.springCurve),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    
    _controller
        .animateTo(widget.pressScale)
        .then((_) => _controller.animateTo(1.0));
    
    widget.onTap?.call();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.animateTo(widget.pressScale);
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.animateTo(1.0);
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.animateTo(1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            onTap: widget.onTap != null ? _handleTap : null,
            onLongPress: widget.onLongPress,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: _isPressed
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

/// Particle effect for celebrations
class ParticleEffect extends StatefulWidget {
  final Widget? child;
  final Color particleColor;
  final int particleCount;
  final Duration duration;
  final bool autoStart;

  const ParticleEffect({
    super.key,
    this.child,
    this.particleColor = const Color(0xFFFFD700),
    this.particleCount = 30,
    this.duration = const Duration(milliseconds: 1500),
    this.autoStart = false,
  });

  @override
  State<ParticleEffect> createState() => _ParticleEffectState();
}

class _ParticleEffectState extends State<ParticleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    _initializeParticles();
    
    if (widget.autoStart) {
      _controller.forward();
    }
  }

  void _initializeParticles() {
    for (int i = 0; i < widget.particleCount; i++) {
      _particles.add(Particle(
        x: 0,
        y: 0,
        velocityX: _random.nextDouble() * 4 - 2,
        velocityY: -_random.nextDouble() * 6 - 2,
        size: _random.nextDouble() * 8 + 4,
        opacity: 1.0,
      ));
    }
  }

  void trigger() {
    _controller.reset();
    _initializeParticles();
    _controller.forward();
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child ?? const SizedBox.shrink(),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              _updateParticles();
              return CustomPaint(
                painter: ParticlePainter(
                  particles: _particles,
                  color: widget.particleColor,
                  progress: _controller.value,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _updateParticles() {
    for (final particle in _particles) {
      particle.x += particle.velocityX;
      particle.y += particle.velocityY;
      particle.velocityY += 0.1; // Gravity
      particle.opacity = 1.0 - _controller.value;
    }
  }
}

class Particle {
  double x;
  double y;
  double velocityX;
  double velocityY;
  double size;
  double opacity;

  Particle({
    required this.x,
    required this.y,
    required this.velocityX,
    required this.velocityY,
    required this.size,
    required this.opacity,
  });
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final Color color;
  final double progress;

  ParticlePainter({
    required this.particles,
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final particle in particles) {
      if (particle.opacity > 0) {
        paint.color = color.withValues(alpha: particle.opacity);
        canvas.drawCircle(
          Offset(size.width / 2 + particle.x * 50, size.height - particle.y * 50),
          particle.size,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) => true;
}

/// Spring physics animation controller helper
class SpringAnimationHelper {
  static AnimationController createController({
    required TickerProvider vsync,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return AnimationController(
      duration: duration,
      vsync: vsync,
    );
  }

  static Animation<double> createSpringAnimation(
    AnimationController controller, {
    double begin = 0.0,
    double end = 1.0,
    Curve curve = AdvancedAnimations.springCurve,
  }) {
    return Tween<double>(begin: begin, end: end).animate(
      CurvedAnimation(parent: controller, curve: curve),
    );
  }

  static Future<void> animateWithSpring(
    AnimationController controller, {
    VoidCallback? onComplete,
  }) async {
    await controller.forward();
    onComplete?.call();
  }
}

/// Bounce animation for success states
class BounceSuccessAnimation extends StatefulWidget {
  final Widget child;
  final bool trigger;
  final VoidCallback? onAnimationComplete;

  const BounceSuccessAnimation({
    super.key,
    required this.child,
    this.trigger = false,
    this.onAnimationComplete,
  });

  @override
  State<BounceSuccessAnimation> createState() => _BounceSuccessAnimationState();
}

class _BounceSuccessAnimationState extends State<BounceSuccessAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AdvancedAnimations.normalDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: AdvancedAnimations.bounceCurve),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.1).animate(
      CurvedAnimation(parent: _controller, curve: AdvancedAnimations.elasticCurve),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete?.call();
        _controller.reverse();
      }
    });
  }

  @override
  void didUpdateWidget(BounceSuccessAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _controller.forward();
      HapticFeedback.heavyImpact();
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
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// Shake animation for error states
class ShakeErrorAnimation extends StatefulWidget {
  final Widget child;
  final bool trigger;
  final VoidCallback? onAnimationComplete;

  const ShakeErrorAnimation({
    super.key,
    required this.child,
    this.trigger = false,
    this.onAnimationComplete,
  });

  @override
  State<ShakeErrorAnimation> createState() => _ShakeErrorAnimationState();
}

class _ShakeErrorAnimationState extends State<ShakeErrorAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AdvancedAnimations.quickDuration,
      vsync: this,
    );

    _offsetAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticIn),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete?.call();
        _controller.reverse();
      }
    });
  }

  @override
  void didUpdateWidget(ShakeErrorAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _controller.forward();
      HapticFeedback.mediumImpact();
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
      animation: _offsetAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            _offsetAnimation.value * (Random().nextBool() ? 1 : -1),
            0,
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// Fade slide animation for lists
class FadeSlideAnimation extends StatefulWidget {
  final Widget child;
  final Offset beginOffset;
  final Offset endOffset;
  final Duration duration;
  final Curve curve;
  final bool trigger;

  const FadeSlideAnimation({
    super.key,
    required this.child,
    this.beginOffset = const Offset(0, 0.5),
    this.endOffset = Offset.zero,
    this.duration = AdvancedAnimations.normalDuration,
    this.curve = Curves.easeOut,
    this.trigger = false,
  });

  @override
  State<FadeSlideAnimation> createState() => _FadeSlideAnimationState();
}

class _FadeSlideAnimationState extends State<FadeSlideAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.beginOffset,
      end: widget.endOffset,
    ).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    if (widget.trigger) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(FadeSlideAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
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
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// Staggered list animation helper
class StaggeredListAnimation extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration staggerDelay;

  const StaggeredListAnimation({
    super.key,
    required this.index,
    required this.child,
    this.staggerDelay = const Duration(milliseconds: 50),
  });

  @override
  Widget build(BuildContext context) {
    return FadeSlideAnimation(
      trigger: true,
      beginOffset: const Offset(0, 0.3),
      duration: AdvancedAnimations.normalDuration,
      child: child,
    );
  }
}

/// Pulse animation wrapper
class PulseAnimation extends StatefulWidget {
  final Widget child;
  final bool trigger;
  final double minScale;
  final double maxScale;
  final Duration duration;
  final VoidCallback? onComplete;

  const PulseAnimation({
    super.key,
    required this.child,
    this.trigger = false,
    this.minScale = 0.95,
    this.maxScale = 1.05,
    this.duration = AdvancedAnimations.normalDuration,
    this.onComplete,
  });

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: widget.minScale, end: widget.maxScale)
        .animate(CurvedAnimation(
          parent: _controller,
          curve: AdvancedAnimations.springCurve,
        ));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });
  }

  @override
  void didUpdateWidget(PulseAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _controller.forward();
      if (mounted) _controller.reverse();
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
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: widget.child,
        );
      },
    );
  }
}