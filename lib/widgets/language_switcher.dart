import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_localizations.dart';
import '../language_provider.dart';
import '../theme/spacing_utils.dart';
import 'accessibility_helper.dart';

/// 🌐 Seamless Language Switching
/// Provides smooth language transitions with persistence
class LanguageSwitcher extends StatefulWidget {
  final ValueChanged<String>? onLanguageChanged;
  final bool showLabel;

  const LanguageSwitcher({
    super.key,
    this.onLanguageChanged,
    this.showLabel = true,
  });

  @override
  State<LanguageSwitcher> createState() => _LanguageSwitcherState();
}

class _LanguageSwitcherState extends State<LanguageSwitcher> {
  late String _currentLanguage;
  bool _isChanging = false;

  final Map<String, LanguageInfo> _languages = {
    'en': LanguageInfo(
      code: 'en',
      name: 'English',
      flag: '🇺🇸',
      nativeName: 'English',
    ),
    'te': LanguageInfo(
      code: 'te',
      name: 'Telugu',
      flag: '🇮🇳',
      nativeName: 'తెలుగు',
    ),
    'hi': LanguageInfo(
      code: 'hi',
      name: 'Hindi',
      flag: '🇮🇳',
      nativeName: 'हिंदी',
    ),
    'ta': LanguageInfo(
      code: 'ta',
      name: 'Tamil',
      flag: '🇮🇳',
      nativeName: 'தமிழ்',
    ),
    'kn': LanguageInfo(
      code: 'kn',
      name: 'Kannada',
      flag: '🇮🇳',
      nativeName: 'ಕನ್ನಡ',
    ),
    'ml': LanguageInfo(
      code: 'ml',
      name: 'Malayalam',
      flag: '🇮🇳',
      nativeName: 'മലയാളം',
    ),
  };

  @override
  void initState() {
    super.initState();
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString('app_language') ?? 'en';
    if (mounted) setState(() {});
  }

  Future<void> _changeLanguage(String languageCode) async {
    if (_isChanging || languageCode == _currentLanguage) return;

    setState(() => _isChanging = true);
    HapticFeedback.lightImpact();

    // Save language preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', languageCode);

    // Simulate language change delay for smooth transition
    await Future.delayed(const Duration(milliseconds: 300));

    _currentLanguage = languageCode;
    setState(() => _isChanging = false);

    // Notify parent
    widget.onLanguageChanged?.call(languageCode);

    // Announce to screen readers
    if (mounted) {
      final langInfo = _languages[languageCode];
      AccessibilityHelper.announce(
        'Language changed to ${langInfo?.nativeName ?? languageCode}',
        context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showLanguageDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _languages[_currentLanguage]?.flag ?? '🌐',
              style: const TextStyle(fontSize: 20),
            ),
            if (widget.showLabel) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                _languages[_currentLanguage]?.name ?? 'English',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.expand_more,
                size: 16,
                color: Color(0xFF64748B),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _LanguageDialog(
        currentLanguage: _currentLanguage,
        languages: _languages,
        onLanguageSelected: _changeLanguage,
      ),
    );
  }
}

class _LanguageDialog extends StatelessWidget {
  final String currentLanguage;
  final Map<String, LanguageInfo> languages;
  final ValueChanged<String> onLanguageSelected;

  const _LanguageDialog({
    required this.currentLanguage,
    required this.languages,
    required this.onLanguageSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Select Language / భాష ఎంచుకోండి',
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: languages.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final langCode = languages.keys.elementAt(index);
            final langInfo = languages[langCode]!;
            final isSelected = langCode == currentLanguage;

            return ListTile(
              leading: Text(
                langInfo.flag,
                style: const TextStyle(fontSize: 24),
              ),
              title: Text(
                langInfo.name,
                style: GoogleFonts.poppins(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                langInfo.nativeName,
                style: GoogleFonts.poppins(fontSize: 12),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle, color: Color(0xFF10B981))
                  : null,
              onTap: () {
                onLanguageSelected(langCode);
                Navigator.pop(context);
              },
            );
          },
        ),
      ),
    );
  }
}

class LanguageInfo {
  final String code;
  final String name;
  final String flag;
  final String nativeName;

  LanguageInfo({
    required this.code,
    required this.name,
    required this.flag,
    required this.nativeName,
  });
}

/// Language persistence service
class LanguageService {
  static Future<String> getSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('app_language') ?? 'en';
  }

  static Future<void> saveLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', languageCode);
  }

  static Future<void> clearSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('app_language');
  }

  static Locale getLocale(String languageCode) {
    return Locale(languageCode);
  }

  static Map<String, String> getSupportedLanguages() {
    return {
      'en': 'English',
      'te': 'Telugu',
      'hi': 'Hindi',
      'ta': 'Tamil',
      'kn': 'Kannada',
      'ml': 'Malayalam',
    };
  }
}

/// Language transition overlay
class LanguageTransitionOverlay extends StatefulWidget {
  final Widget child;
  final String targetLanguage;

  const LanguageTransitionOverlay({
    super.key,
    required this.child,
    required this.targetLanguage,
  });

  @override
  State<LanguageTransitionOverlay> createState() => _LanguageTransitionOverlayState();
}

class _LanguageTransitionOverlayState extends State<LanguageTransitionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
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
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Container(
                    color: Colors.white,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Changing language...',
                            style: GoogleFonts.poppins(),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Language context helper
class LanguageContext extends InheritedWidget {
  final String currentLanguage;
  final Function(String) setLanguage;

  const LanguageContext({
    super.key,
    required this.currentLanguage,
    required this.setLanguage,
    required Widget child,
  }) : super(child: child);

  static LanguageContext? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LanguageContext>();
  }

  @override
  bool updateShouldNotify(LanguageContext oldWidget) {
    return oldWidget.currentLanguage != currentLanguage;
  }
}