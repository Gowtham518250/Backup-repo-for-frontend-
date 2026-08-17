import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Beautiful loading states with animations
class AnimatedLoadingWidget extends StatefulWidget {
  final String? message;
  final bool showMessage;
  final LoadingType type;

  const AnimatedLoadingWidget({
    Key? key,
    this.message,
    this.showMessage = true,
    this.type = LoadingType.pulse,
  }) : super(key: key);

  @override
  State<AnimatedLoadingWidget> createState() => _AnimatedLoadingWidgetState();
}

enum LoadingType { pulse, spin, bounce, wave, dots }

class _AnimatedLoadingWidgetState extends State<AnimatedLoadingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLoader(),
          if (widget.showMessage && widget.message != null) ...[
            const SizedBox(height: 24),
            Text(
              widget.message!,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoader() {
    switch (widget.type) {
      case LoadingType.pulse:
        return _PulseLoader(controller: _controller);
      case LoadingType.spin:
        return _SpinLoader(controller: _controller);
      case LoadingType.bounce:
        return _BounceLoader(controller: _controller);
      case LoadingType.wave:
        return _WaveLoader(controller: _controller);
      case LoadingType.dots:
        return _DotsLoader(controller: _controller);
    }
  }
}

/// Pulse loading animation
class _PulseLoader extends StatelessWidget {
  final AnimationController controller;

  const _PulseLoader({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.2)
              .animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut)),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            ),
            child: const Icon(
              Icons.shopping_bag_rounded,
              color: Color(0xFF6366F1),
              size: 32,
            ),
          ),
        );
      },
    );
  }
}

/// Spinning loader
class _SpinLoader extends StatelessWidget {
  final AnimationController controller;

  const _SpinLoader({required this.controller});

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: controller,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            width: 4,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
          strokeWidth: 2,
        ),
      ),
    );
  }
}

/// Bouncing dots loader
class _BounceLoader extends StatelessWidget {
  final AnimationController controller;

  const _BounceLoader({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final delay = (index * 0.15);
        final curveInterval = Interval(delay, delay + 0.4);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.5, end: 1.0).animate(
              CurvedAnimation(parent: controller, curve: curveInterval),
            ),
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF6366F1),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Wave loader
class _WaveLoader extends StatelessWidget {
  final AnimationController controller;

  const _WaveLoader({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(5, (index) {
          final delay = (index * 0.1);
          final curveInterval = Interval(delay, delay + 0.5);

          return Transform.translate(
            offset: Offset(
              0,
              Tween<double>(begin: 0, end: -15)
                  .evaluate(CurvedAnimation(parent: controller, curve: curveInterval)),
            ),
            child: Container(
              width: 8,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Animated dots loader
class _DotsLoader extends StatelessWidget {
  final AnimationController controller;

  const _DotsLoader({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        final delay = (index * 0.12);
        final curveInterval = Interval(delay, delay + 0.4);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              final opacity = Tween<double>(begin: 0.3, end: 1.0)
                  .evaluate(CurvedAnimation(parent: controller, curve: curveInterval));

              return Opacity(
                opacity: opacity,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF6366F1),
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}

/// Success animation
class SuccessAnimation extends StatefulWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onComplete;
  final Duration duration;

  const SuccessAnimation({
    Key? key,
    this.title = 'Success!',
    this.subtitle,
    this.onComplete,
    this.duration = const Duration(milliseconds: 1500),
  }) : super(key: key);

  @override
  State<SuccessAnimation> createState() => _SuccessAnimationState();
}

class _SuccessAnimationState extends State<SuccessAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
            ),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xFF10B981),
                size: 60,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.title,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.subtitle!,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Error/Failure animation
class ErrorAnimation extends StatefulWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onRetry;
  final Duration duration;

  const ErrorAnimation({
    Key? key,
    this.title = 'Error!',
    this.subtitle,
    this.onRetry,
    this.duration = const Duration(milliseconds: 500),
  }) : super(key: key);

  @override
  State<ErrorAnimation> createState() => _ErrorAnimationState();
}

class _ErrorAnimationState extends State<ErrorAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
            ),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Color(0xFFEF4444),
                size: 60,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.title,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                widget.subtitle!,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (widget.onRetry != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: widget.onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
              ),
              child: Text(
                'Try Again',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
