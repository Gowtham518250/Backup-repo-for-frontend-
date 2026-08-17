import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────
class _Slide {
  final String titleTelugu;
  final String titleEnglish;
  final String subtitleTelugu;
  final String subtitleEnglish;
  final String descTelugu;
  final String descEnglish;
  final IconData icon;
  final Color accent;
  final List<Color> gradient;

  const _Slide({
    required this.titleTelugu,
    required this.titleEnglish,
    required this.subtitleTelugu,
    required this.subtitleEnglish,
    required this.descTelugu,
    required this.descEnglish,
    required this.icon,
    required this.accent,
    required this.gradient,
  });
}

const _slides = [
  _Slide(
    titleTelugu: 'మీ దుకాణానికి స్వాగతం',
    titleEnglish: 'Welcome to Your Shop',
    subtitleTelugu: 'AI Shop Pro — మీ వ్యాపారం, మీ నియంత్రణ',
    subtitleEnglish: 'AI Shop Pro — Your Business, Your Control',
    descTelugu: 'భారతీయ చిన్న వ్యాపారుల కోసం ప్రత్యేకంగా తయారైన యాప్. అన్నీ ఒకే చోట.',
    descEnglish: 'Built specially for Indian small shop owners. Everything in one place.',
    icon: Icons.shopping_bag_rounded,
    accent: Color(0xFF6366F1),
    gradient: [Color(0xFF312E81), Color(0xFF4F46E5)],
  ),
  _Slide(
    titleTelugu: 'UPI డబ్బు వినిపిస్తుంది',
    titleEnglish: 'Hear Your UPI Payments',
    subtitleTelugu: 'Paytm, PhonePe, GPay — అన్నీ వినిపిస్తాయి',
    subtitleEnglish: 'Paytm, PhonePe, GPay — All Detected Automatically',
    descTelugu: 'కస్టమర్ పేమెంట్ చేసిన వెంటనే మీ ఫోన్ చెప్తుంది "రూపాయలు వచ్చాయి". Soundbox కొనుక్కోవాల్సిన అవసరం లేదు!',
    descEnglish: 'Your phone announces every payment instantly. No need to buy a Soundbox device!',
    icon: Icons.volume_up_rounded,
    accent: Color(0xFF10B981),
    gradient: [Color(0xFF064E3B), Color(0xFF059669)],
  ),
  _Slide(
    titleTelugu: 'బిల్లు చేయడం చాలా సులభం',
    titleEnglish: 'Billing Made Super Easy',
    subtitleTelugu: '10 సెకన్లలో బిల్లు తయారు',
    subtitleEnglish: 'Make a Bill in Under 10 Seconds',
    descTelugu: 'బార్కోడ్ స్కాన్ చేయండి లేదా పేరు టైప్ చేయండి. బిల్లు రెడీ. WhatsApp కి పంపించండి.',
    descEnglish: 'Scan barcode or type item name. Bill is ready. Share on WhatsApp instantly.',
    icon: Icons.receipt_long_rounded,
    accent: Color(0xFFF59E0B),
    gradient: [Color(0xFF78350F), Color(0xFFD97706)],
  ),
  _Slide(
    titleTelugu: 'అప్పుల లెక్క సులభం',
    titleEnglish: 'Track Credit Easily',
    subtitleTelugu: 'ఎవరు ఎంత అప్పు చేశారో తెలుసుకోండి',
    subtitleEnglish: 'Know Who Owes You and How Much',
    descTelugu: 'కస్టమర్ల అప్పు రికార్డ్ చేయండి. వారికి WhatsApp రిమైండర్ పంపించండి. డబ్బు సేకరించండి.',
    descEnglish: 'Record customer dues. Send WhatsApp reminders. Collect your money.',
    icon: Icons.account_balance_wallet_rounded,
    accent: Color(0xFF8B5CF6),
    gradient: [Color(0xFF3B0764), Color(0xFF7C3AED)],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Onboarding widget
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingPage extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingPage({Key? key, required this.onComplete}) : super(key: key);

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Continuous background animations
  late AnimationController _bgController; // aurora blobs
  late AnimationController _particleController; // floating particles
  late AnimationController _iconController; // icon pulse + rotate

  // Per-slide enter animations
  late AnimationController _slideController;
  late Animation<double> _slideFade;
  late Animation<Offset> _slideOffset;

  // Particle positions (randomised once)
  late List<_Particle> _particles;
  final math.Random _rng = math.Random(42);

  @override
  void initState() {
    super.initState();

    // Aurora blobs — slow, infinite loop
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // Particles — medium speed, infinite
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Icon float
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // Slide-in animation
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideFade = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    );
    _slideOffset = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _slideController.forward();

    // Generate particles
    _particles = List.generate(
      22,
      (i) => _Particle(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        size: 1.5 + _rng.nextDouble() * 3,
        speed: 0.05 + _rng.nextDouble() * 0.12,
        phase: _rng.nextDouble() * math.pi * 2,
      ),
    );
  }

  @override
  void dispose() {
    _bgController.dispose();
    _particleController.dispose();
    _iconController.dispose();
    _slideController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onComplete();
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _slideController.reset();
    _slideController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentPage];
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Stack(
        children: [
          // ── Layer 1: Animated aurora background ──────────────────────────
          AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) => CustomPaint(
              size: size,
              painter: _AuroraPainter(_bgController.value, slide.gradient),
            ),
          ),

          // ── Layer 2: Floating particles ───────────────────────────────────
          AnimatedBuilder(
            animation: _particleController,
            builder: (_, __) => CustomPaint(
              size: size,
              painter: _ParticlePainter(
                _particles,
                _particleController.value,
                slide.accent,
              ),
            ),
          ),

          // ── Layer 3: Page content ─────────────────────────────────────────
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _slides.length,
            itemBuilder: (_, i) => _SlideContent(
              slide: _slides[i],
              isCurrent: i == _currentPage,
              fadeTween: _slideFade,
              offsetTween: _slideOffset,
              iconController: _iconController,
            ),
          ),

          // ── Layer 4: Skip button ──────────────────────────────────────────
          if (_currentPage < _slides.length - 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 20,
              child: FadeTransition(
                opacity: _slideFade,
                child: TextButton(
                  onPressed: widget.onComplete,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white60,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                  ),
                  child: Text(
                    'Skip',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

          // ── Layer 5: Bottom controls ──────────────────────────────────────
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 32,
            left: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dot indicators
                _DotRow(
                  count: _slides.length,
                  current: _currentPage,
                  accent: slide.accent,
                ),

                const SizedBox(height: 28),

                // Back + Next row
                Row(
                  children: [
                    if (_currentPage > 0)
                      Expanded(
                        flex: 1,
                        child: _OutlineButton(
                          label: 'Back',
                          onPressed: () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          ),
                        ),
                      ),
                    if (_currentPage > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _GradientButton(
                        label: _currentPage == _slides.length - 1
                            ? 'Get Started'
                            : 'Next',
                        gradient: slide.gradient,
                        onPressed: _goNext,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slide content
// ─────────────────────────────────────────────────────────────────────────────
class _SlideContent extends StatelessWidget {
  final _Slide slide;
  final bool isCurrent;
  final Animation<double> fadeTween;
  final Animation<Offset> offsetTween;
  final AnimationController iconController;

  const _SlideContent({
    required this.slide,
    required this.isCurrent,
    required this.fadeTween,
    required this.offsetTween,
    required this.iconController,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with animated glow
          SlideTransition(
            position: offsetTween,
            child: FadeTransition(
              opacity: fadeTween,
              child: AnimatedBuilder(
                animation: iconController,
                builder: (_, __) {
                  final pulse = 0.95 + iconController.value * 0.1;
                  final glow = 0.5 + iconController.value * 0.5;
                  return Transform.scale(
                    scale: pulse,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            slide.accent.withValues(alpha: 0.35 * glow),
                            slide.accent.withValues(alpha: 0.0),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: slide.accent.withValues(alpha: 0.55 * glow),
                            blurRadius: 50,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: slide.gradient,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: slide.accent.withValues(alpha: 0.6 * glow),
                                blurRadius: 30,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(slide.icon, size: 36, color: Colors.white),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Telugu Title (Primary — big, bold)
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.25),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: fadeTween, curve: Curves.easeOut)),
            child: FadeTransition(
              opacity: fadeTween,
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [Colors.white, slide.accent],
                ).createShader(bounds),
                child: Text(
                  slide.titleTelugu,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 4),

          // English Title (Secondary — smaller)
          FadeTransition(
            opacity: fadeTween,
            child: Text(
              slide.titleEnglish,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.55),
                height: 1.2,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Telugu Subtitle (colored)
          FadeTransition(
            opacity: fadeTween,
            child: Text(
              slide.subtitleTelugu,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: slide.accent,
                letterSpacing: 0.2,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Description box — bilingual
          FadeTransition(
            opacity: fadeTween,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: slide.accent.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    slide.descTelugu,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Divider(color: slide.accent.withValues(alpha: 0.2), height: 1),
                  const SizedBox(height: 8),
                  Text(
                    slide.descEnglish,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.5),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dot indicators
// ─────────────────────────────────────────────────────────────────────────────
class _DotRow extends StatelessWidget {
  final int count;
  final int current;
  final Color accent;

  const _DotRow({
    required this.count,
    required this.current,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: active ? accent : Colors.white.withValues(alpha: 0.22),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.6),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Buttons
// ─────────────────────────────────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  final String label;
  final List<Color> gradient;
  final VoidCallback onPressed;

  const _GradientButton({
    required this.label,
    required this.gradient,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.last.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _OutlineButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          color: Colors.white.withValues(alpha: 0.06),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom painters
// ─────────────────────────────────────────────────────────────────────────────
class _AuroraPainter extends CustomPainter {
  final double t;
  final List<Color> palette;

  _AuroraPainter(this.t, this.palette);

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF020617),
    );

    // Draw 3 morphing blobs
    _drawBlob(canvas, size,
        cx: size.width * (0.2 + 0.15 * math.sin(t * math.pi * 2)),
        cy: size.height * (0.25 + 0.08 * math.cos(t * math.pi * 2)),
        radius: size.width * 0.45,
        color: palette[0].withValues(alpha: 0.22));

    _drawBlob(canvas, size,
        cx: size.width * (0.75 + 0.1 * math.cos(t * math.pi * 2 + 1)),
        cy: size.height * (0.55 + 0.1 * math.sin(t * math.pi * 2 + 1)),
        radius: size.width * 0.40,
        color: palette[1].withValues(alpha: 0.18));

    _drawBlob(canvas, size,
        cx: size.width * (0.5 + 0.12 * math.sin(t * math.pi * 2 + 2)),
        cy: size.height * (0.78 + 0.06 * math.cos(t * math.pi * 2 + 2)),
        radius: size.width * 0.35,
        color: palette[0].withValues(alpha: 0.14));
  }

  void _drawBlob(Canvas canvas, Size size,
      {required double cx,
      required double cy,
      required double radius,
      required Color color}) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, Colors.transparent],
      ).createShader(Rect.fromCircle(
          center: Offset(cx, cy), radius: radius))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
    canvas.drawCircle(Offset(cx, cy), radius, paint);
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) => oldDelegate.t != t;
}

class _Particle {
  final double x; // 0..1 normalised initial x
  final double y; // 0..1 normalised initial y
  final double size;
  final double speed;
  final double phase;

  const _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.phase,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  final Color accent;

  _ParticlePainter(this.particles, this.t, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final dy = (t * p.speed + p.phase / (math.pi * 2)) % 1.0;
      final x = p.x * size.width +
          math.sin((t + p.phase) * math.pi * 2) * 18;
      final y = size.height - dy * size.height * 1.1;

      final alpha = (0.15 + 0.35 * math.sin((t + p.phase) * math.pi));

      canvas.drawCircle(
        Offset(x, y),
        p.size,
        Paint()
          ..color = accent.withValues(alpha: alpha.clamp(0.0, 1.0))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}
