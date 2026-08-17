import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/accessibility_helper.dart';
import '../theme/spacing_utils.dart';

/// 🎓 Onboarding for New Users
/// Provides a guided tour of the app for first-time users
class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onOnboardingComplete;

  const OnboardingScreen({
    super.key,
    this.onOnboardingComplete,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  final List<OnboardingSlide> _slides = [
    OnboardingSlide(
      title: 'Welcome to RETAIL MIND',
      description: 'Your complete point of sale solution with inventory management, billing, and analytics.',
      icon: Icons.store_rounded,
      color: const Color(0xFF6366F1),
    ),
    OnboardingSlide(
      title: 'Quick Sales',
      description: 'Create sales in seconds with voice billing, product search, and instant inventory updates.',
      icon: Icons.speed_rounded,
      color: const Color(0xFF10B981),
    ),
    OnboardingSlide(
      title: 'Smart Inventory',
      description: 'Track stock in real-time, get low stock alerts, and manage your product catalog effortlessly.',
      icon: Icons.inventory_2_rounded,
      color: const Color(0xFFF59E0B),
    ),
    OnboardingSlide(
      title: 'Analytics Dashboard',
      description: 'Monitor your sales, revenue, and business growth with comprehensive analytics and reports.',
      icon: Icons.analytics_rounded,
      color: const Color(0xFF3B82F6),
    ),
    OnboardingSlide(
      title: 'Let\'s Get Started!',
      description: 'You\'re all set to transform your retail experience. Tap below to begin.',
      icon: Icons.rocket_launch_rounded,
      color: const Color(0xFF8B5CF6),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    
    HapticFeedback.mediumImpact();
    
    if (widget.onOnboardingComplete != null) {
      widget.onOnboardingComplete!();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _nextSlide() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      HapticFeedback.lightImpact();
    }
  }

  void _previousSlide() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  return _buildSlide(_slides[index]);
                },
              ),
            ),
            
            // Page indicators
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: _currentPage == index ? 24 : 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? _slides[_currentPage].color
                          : Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            
            // Navigation buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
              child: Row(
                children: [
                  Expanded(
                    child: _currentPage == 0
                        ? const SizedBox.shrink()
                        : AccessibilityHelper.accessibleButton(
                            semanticLabel: 'Previous',
                            child: const Icon(Icons.arrow_back),
                            onPressed: _previousSlide,
                          ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _currentPage == _slides.length - 1
                        ? AccessibleButton(
                            label: 'Get Started',
                            backgroundColor: _slides[_currentPage].color,
                            onPressed: _completeOnboarding,
                          )
                        : AccessibleButton(
                            label: 'Next',
                            backgroundColor: _slides[_currentPage].color,
                            onPressed: _nextSlide,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(OnboardingSlide slide) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: slide.color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      slide.icon,
                      size: 100,
                      color: slide.color,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  
                  // Title
                  Text(
                    slide.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  // Description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                    child: Text(
                      slide.description,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: const Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class OnboardingSlide {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingSlide({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

/// Onboarding completion check
class OnboardingCheck {
  static Future<bool> shouldShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('onboarding_completed') ?? true);
  }

  static Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('onboarding_completed');
  }
}

/// Feature highlight tooltip
class FeatureHighlight extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;
  final bool showOnce;

  const FeatureHighlight({
    super.key,
    required this.title,
    required this.description,
    required this.child,
    this.showOnce = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showFeatureTooltip(context),
      child: child,
    );
  }

  void _showFeatureTooltip(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lightbulb, color: const Color(0xFFF59E0B)),
            const SizedBox(width: AppSpacing.sm),
            Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          description,
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

/// Quick tip widget that shows helpful tips
class QuickTip extends StatefulWidget {
  final String tip;
  final IconData? icon;
  final VoidCallback? onDismiss;

  const QuickTip({
    super.key,
    required this.tip,
    this.icon,
    this.onDismiss,
  });

  @override
  State<QuickTip> createState() => _QuickTipState();
}

class _QuickTipState extends State<QuickTip> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      widget.onDismiss?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_slideAnimation.value * 300, 0),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              margin: const EdgeInsets.all(AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.icon ?? Icons.tips_and_updates,
                    color: const Color(0xFF6366F1),
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      widget.tip,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _dismiss,
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}