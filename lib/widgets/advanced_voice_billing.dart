import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/spacing_utils.dart';
import '../widgets/accessibility_helper.dart';

/// 🎙️ Advanced Voice Billing with Waveform, Confidence, and Suggestions
class AdvancedVoiceBillingWidget extends StatefulWidget {
  final ValueChanged<String>? onVoiceResult;
  final VoidCallback? onStartListening;
  final VoidCallback? onStopListening;
  final VoidCallback? onError;

  const AdvancedVoiceBillingWidget({
    super.key,
    this.onVoiceResult,
    this.onStartListening,
    this.onStopListening,
    this.onError,
  });

  @override
  State<AdvancedVoiceBillingWidget> createState() => _AdvancedVoiceBillingWidgetState();
}

class _AdvancedVoiceBillingWidgetState extends State<AdvancedVoiceBillingWidget>
    with TickerProviderStateMixin {
  bool _isListening = false;
  bool _isProcessing = false;
  String _recognizedText = '';
  double _confidenceScore = 0.0;
  String _currentLanguage = 'en';
  bool _showSuggestions = false;
  final List<double> _waveformData = List.generate(50, (index) => 0.0);
  Timer? _waveformTimer;
  Timer? _simulationTimer;

  final Map<String, String> _languages = {
    'en': 'English',
    'te': 'Telugu (తెలుగు)',
    'hi': 'Hindi (हिंदी)',
    'ta': 'Tamil (தமிழ்)',
    'kn': 'Kannada (ಕನ್ನಡ)',
    'ml': 'Malayalam (മലയാളം)',
  };

  final List<VoiceCommand> _commands = [
    VoiceCommand(
      icon: Icons.shopping_cart,
      command: 'Add [product name] [quantity]',
      description: 'Add product to cart',
      examples: ['Add Rice 2 kg', 'Add Sugar 500g'],
    ),
    VoiceCommand(
      icon: Icons.remove_circle,
      command: 'Remove [product name]',
      description: 'Remove from cart',
      examples: ['Remove Rice', 'Remove Sugar'],
    ),
    VoiceCommand(
      icon: Icons.inventory_2,
      command: 'Show inventory',
      description: 'Display all products',
      examples: ['Show inventory', 'What do you have'],
    ),
    VoiceCommand(
      icon: Icons.calculate,
      command: 'Calculate total',
      description: 'Show cart total',
      examples: ['Calculate total', 'Total amount'],
    ),
    VoiceCommand(
      icon: Icons.receipt_long,
      command: 'Generate bill',
      description: 'Create invoice',
      examples: ['Generate bill', 'Create invoice'],
    ),
    VoiceCommand(
      icon: Icons.search,
      command: 'Search [product name]',
      description: 'Find product',
      examples: ['Search Rice', 'Find Sugar'],
    ),
  ];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _waveformTimer?.cancel();
    _simulationTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
      if (_isListening) {
        _startWaveformAnimation();
        _pulseController.repeat(reverse: true);
        widget.onStartListening?.call();
        HapticFeedback.heavyImpact();
        // Simulate voice recognition
        _simulationTimer = Timer(const Duration(seconds: 3), () {
          _simulateRecognitionResult();
        });
      } else {
        _stopWaveformAnimation();
        _pulseController.stop();
        _pulseController.reset();
        widget.onStopListening?.call();
        _simulationTimer?.cancel();
        HapticFeedback.lightImpact();
      }
    });
  }

  void _startWaveformAnimation() {
    _waveformTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        for (int i = 0; i < _waveformData.length; i++) {
          _waveformData[i] = Random().nextDouble() * 100;
        }
      });
    });
  }

  void _stopWaveformAnimation() {
    _waveformTimer?.cancel();
    setState(() {
      _waveformData.fillRange(0, _waveformData.length, 0.0);
    });
  }

  void _simulateRecognitionResult() {
    if (!_isListening) return;
    
    setState(() {
      _isListening = false;
      _isProcessing = true;
      _stopWaveformAnimation();
      _pulseController.stop();
      _pulseController.reset();
    });

    // Simulate processing
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _recognizedText = 'Add Rice 2 kg Sugar 500g';
          _confidenceScore = 0.95;
          widget.onVoiceResult?.call('Add Rice 2 kg Sugar 500g');
          HapticFeedback.heavyImpact();
        });
      }
    });
  }

  void _changeLanguage(String langCode) {
    setState(() {
      _currentLanguage = langCode;
    });
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with language selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.mic_rounded, color: const Color(0xFF6366F1)),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Voice Billing',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              // Language selector
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _currentLanguage,
                  underline: const SizedBox.shrink(),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF6366F1),
                    fontWeight: FontWeight.w600,
                  ),
                  icon: const Icon(Icons.expand_more, size: 16, color: Color(0xFF6366F1)),
                  items: _languages.entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) _changeLanguage(value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Voice command suggestions
          _buildCommandSuggestions(),
          const SizedBox(height: AppSpacing.md),

          // Waveform visualization
          _buildWaveform(),
          const SizedBox(height: AppSpacing.lg),

          // Microphone button with pulse animation
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _isListening ? _pulseAnimation.value : 1.0,
                  child: GestureDetector(
                    onTap: _toggleListening,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _isListening
                            ? const Color(0xFF6366F1)
                            : _isProcessing
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF6366F1).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isListening
                              ? const Color(0xFF6366F1)
                              : const Color(0xFF6366F1).withValues(alpha: 0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: _isListening ? 10 : 0,
                          ),
                        ],
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(
                              Icons.mic,
                              size: 36,
                              color: _isListening ? Colors.white : const Color(0xFF6366F1),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Status text
          Text(
            _isListening
                ? 'Listening... Say a command'
                : _isProcessing
                    ? 'Processing...'
                    : 'Tap to speak',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF64748B),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Recognized text
          if (_recognizedText.isNotEmpty) _buildRecognizedText(),
        ],
      ),
    );
  }

  Widget _buildWaveform() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_waveformData.length, (index) {
          return Container(
            width: 3,
            height: _isListening ? _waveformData[index] * 0.5 + 10 : 4,
            decoration: BoxDecoration(
              color: _isListening
                  ? Color.lerp(
                      const Color(0xFF6366F1),
                      const Color(0xFF10B981),
                      index / _waveformData.length,
                    )
                  : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildRecognizedText() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: const Color(0xFF10B981), size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Recognized',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10B981),
                ),
              ),
              const Spacer(),
              // Confidence indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Confidence: ${(_confidenceScore * 100).toInt()}%',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.trending_up, size: 12, color: const Color(0xFF10B981)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _recognizedText,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandSuggestions() {
    return GestureDetector(
      onTap: () {
        setState(() => _showSuggestions = !_showSuggestions);
        HapticFeedback.lightImpact();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF6366F1).withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.lightbulb, color: const Color(0xFF6366F1), size: 16),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Tap to see voice commands',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF6366F1),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              _showSuggestions ? Icons.expand_less : Icons.expand_more,
              color: const Color(0xFF6366F1),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandSuggestionsPanel() {
    if (!_showSuggestions) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Voice Commands',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ..._commands.map((command) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(command.icon, color: const Color(0xFF6366F1), size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            command.command,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            command.description,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: AppSpacing.sm,
                            children: command.examples.map((example) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '"$example"',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: const Color(0xFF64748B),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class VoiceCommand {
  final IconData icon;
  final String command;
  final String description;
  final List<String> examples;

  VoiceCommand({
    required this.icon,
    required this.command,
    required this.description,
    required this.examples,
  });
}

/// Confidence level indicator widget
class ConfidenceIndicator extends StatelessWidget {
  final double confidence;
  final String label;

  const ConfidenceIndicator({
    super.key,
    required this.confidence,
    this.label = 'Confidence',
  });

  @override
  Widget build(BuildContext context) {
    final color = confidence >= 0.8
        ? const Color(0xFF10B981)
        : confidence >= 0.5
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
            Text(
              '${(confidence * 100).toInt()}%',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            widthFactor: confidence,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Multi-language voice recognition indicator
class MultiLanguageIndicator extends StatelessWidget {
  final List<String> activeLanguages;

  const MultiLanguageIndicator({
    super.key,
    required this.activeLanguages,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.language, size: 16, color: const Color(0xFF6366F1)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Wrap(
              spacing: AppSpacing.xs,
              children: activeLanguages.map((lang) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    lang.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}