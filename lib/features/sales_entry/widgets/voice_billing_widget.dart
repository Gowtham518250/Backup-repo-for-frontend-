import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;

/// 🎨 Voice Billing Animation Widget
/// Premium animated microphone with pulsing rings and wave effects
enum VoiceState { idle, listening, processing, success, error }

class VoiceBillingAnimation extends StatefulWidget {
  final VoidCallback? onTap;
  final VoiceState state;

  const VoiceBillingAnimation({
    super.key,
    this.onTap,
    this.state = VoiceState.idle,
  });

  @override
  State<VoiceBillingAnimation> createState() => _VoiceBillingAnimationState();
}

class _VoiceBillingAnimationState extends State<VoiceBillingAnimation>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _rotateController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation for listening state
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Wave animation for listening state
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );

    // Rotate animation for processing state
    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _rotateAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );

    // Scale animation for tap feedback
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    _updateAnimationsForState(widget.state);
  }

  @override
  void didUpdateWidget(VoiceBillingAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateAnimationsForState(widget.state);
    }
  }

  void _updateAnimationsForState(VoiceState state) {
    switch (state) {
      case VoiceState.idle:
        _pulseController.stop();
        _waveController.stop();
        _rotateController.stop();
        break;
      case VoiceState.listening:
        _pulseController.repeat(reverse: true);
        _waveController.repeat();
        _rotateController.stop();
        break;
      case VoiceState.processing:
        _pulseController.stop();
        _waveController.stop();
        _rotateController.repeat();
        break;
      case VoiceState.success:
      case VoiceState.error:
        _pulseController.stop();
        _waveController.stop();
        _rotateController.stop();
        break;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _rotateController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Color _getStateColor() {
    switch (widget.state) {
      case VoiceState.idle:
        return const Color(0xFF6366F1); // Blue glow
      case VoiceState.listening:
        return const Color(0xFF8B5CF6); // Purple
      case VoiceState.processing:
        return const Color(0xFFF59E0B); // Orange
      case VoiceState.success:
        return const Color(0xFF10B981); // Green
      case VoiceState.error:
        return const Color(0xFFEF4444); // Red
    }
  }

  IconData _getStateIcon() {
    switch (widget.state) {
      case VoiceState.idle:
        return Icons.mic_rounded;
      case VoiceState.listening:
        return Icons.mic_rounded;
      case VoiceState.processing:
        return Icons.refresh_rounded;
      case VoiceState.success:
        return Icons.check_circle_rounded;
      case VoiceState.error:
        return Icons.error_rounded;
    }
  }

  String _getStateText() {
    switch (widget.state) {
      case VoiceState.idle:
        return 'Tap to start';
      case VoiceState.listening:
        return 'Listening...';
      case VoiceState.processing:
        return 'Processing...';
      case VoiceState.success:
        return 'Success!';
      case VoiceState.error:
        return 'Try again';
    }
  }

  void _handleTap() {
    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulsing rings
              if (widget.state == VoiceState.listening)
                ...List.generate(3, (index) {
                  return AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      final delay = index * 0.3;
                      final value = (_pulseAnimation.value + delay) % 1.0;
                      return Container(
                        width: 120 + value * 80,
                        height: 120 + value * 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _getStateColor().withOpacity(0.3 * (1 - value)),
                            width: 2,
                          ),
                        ),
                      );
                    },
                  );
                }),

              // Wave animation
              if (widget.state == VoiceState.listening)
                AnimatedBuilder(
                  animation: _waveAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(180, 180),
                      painter: WavePainter(
                        _waveAnimation.value,
                        _getStateColor(),
                      ),
                    );
                  },
                ),

              // Rotating ring for processing
              if (widget.state == VoiceState.processing)
                AnimatedBuilder(
                  animation: _rotateAnimation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotateAnimation.value,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _getStateColor(),
                            width: 3,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(_getStateColor()),
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    );
                  },
                ),

              // Main mic icon container
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _getStateColor(),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _getStateColor().withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  _getStateIcon(),
                  color: Colors.white,
                  size: 40,
                ),
              ),

              // Status text
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Text(
                  _getStateText(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wave painter for voice animation
class WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  WavePainter(this.animationValue, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw multiple wave circles
    for (int i = 0; i < 4; i++) {
      final waveRadius = radius * (0.5 + (animationValue + i * 0.25) % 0.5);
      final alpha = 1.0 - ((animationValue + i * 0.25) % 0.5) * 2;
      paint.color = color.withOpacity(0.3 * alpha);

      canvas.drawCircle(center, waveRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.color != color;
  }
}