import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'app_localizations.dart';
import 'responsive.dart';
import 'visual_widgets.dart';
import 'language_provider.dart';
import 'secure_token_storage.dart';
import 'session_management.dart';
import 'user_data_clear_service.dart';
import 'scoped_shared_preferences.dart';

/// NOTE: The previous version of this file was actually implemented as a
/// LOGIN form (it called POST /auth/login and never touched
/// POST /auth/register). That's why registration appeared to "succeed" for
/// already-registered emails (it was really just logging them in) and why
/// genuinely new emails never got created. This version calls the real
/// register endpoint and surfaces the backend's actual validation errors
/// (409 for duplicate email/username, 400 for missing email, etc.).
class DecentRegisterPage extends StatefulWidget {
  const DecentRegisterPage({super.key});

  @override
  State<DecentRegisterPage> createState() => _DecentRegisterPageState();
}

class _DecentRegisterPageState extends State<DecentRegisterPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController shopNameController = TextEditingController();

  bool isLoading = false;
  bool isPasswordVisible = false;
  String errorMessage = '';

  late AnimationController _cardController;
  late Animation<double> _cardScale;

  @override
  void initState() {
    super.initState();
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _cardScale = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutBack,
    );
    _cardController.forward();
  }

  @override
  void dispose() {
    _cardController.dispose();
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    shopNameController.dispose();
    super.dispose();
  }

  /// Decode response map safely, handling both JSON and non-JSON responses
  Map<String, dynamic> _decodeResponseMap(http.Response response) {
    try {
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) {
        return data;
      }
      return {};
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to decode response: $e');
      return {};
    }
  }

  Future<void> registerUser() async {
    final username = usernameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final shopName = shopNameController.text.trim();

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => errorMessage = 'Please fill in all required fields');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // This is the actual fix: call /auth/register with JSON data, not form data
      final response = await ApiClient.postJson('/auth/register', {
        'username': username,
        'email': email,
        'password': password,
        if (shopName.isNotEmpty) 'shop_name': shopName,
      });

      final data = _decodeResponseMap(response);

      if (response.statusCode == 200) {
        // Backend returns access_token directly on successful registration
        // (auto-login) — see the "return {...}" at the end of /register.
        final token = data['access_token']?.toString() ?? '';
        final userId = data['user_id'] is int
            ? data['user_id'] as int
            : int.tryParse(data['user_id']?.toString() ?? '') ?? 0;

        await UserDataClearService.clearAllUserData();
        await SessionManagementService.initializeSession(
          userId: userId,
          accessToken: token,
          userName: data['username']?.toString() ?? username,
          userEmail: email,
          role: data['role']?.toString() ?? 'OWNER',
        );

        final prefs = await SharedPreferences.getInstance();
        if (shopName.isNotEmpty) {
          await prefs.setString('shop_name', shopName);
          await ScopedSharedPreferences.setString('shop_name', shopName);
        }

        if (!mounted) return;
        // 🔧 FIX: After registration, send new users to shop setup page first.
        // Previously they went directly to the dashboard, skipping shop profile setup.
        Navigator.of(context).pushReplacementNamed('/shop-details');
      } else {
        // Surface the backend's real validation message, e.g.:
        // 409 "This email is already registered. Please login instead."
        // 409 "Username already registered. Please choose a different name."
        setState(() => errorMessage =
            data['detail']?.toString() ?? 
            data['message']?.toString() ??
            AppLocalizations.of(context).invalidCredentials);
      }
    } catch (e) {
      setState(() => errorMessage = 'Connection error: ${e.toString().replaceAll('Exception:', '').trim()}');
    }

    if (mounted) setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return BackendLoadingOverlay(
      isVisible: isLoading,
      title: 'Creating your account',
      subtitle: 'Securely registering your shop and syncing the backend',
      icon: Icons.person_add_alt_rounded,
      accentColor: const Color(0xFF1B3A6B),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF020617),
              Color(0xFF020617),
              Color(0xFF0B1120),
            ],
          ),
        ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    ClipOval(
                      child: Image.asset(
                        'assets/shop_logo.png',
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF111827),
                          ),
                          child: const Icon(
                            Icons.shopping_bag_outlined,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l.appTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.tagline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 20),

                    ScaleTransition(
                      scale: _cardScale,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827).withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 18,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l.createAccount,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      l.enterCredentials,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.65),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF6366F1),
                                        Color(0xFF10B981),
                                      ],
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.shield_moon_rounded,
                                          size: 14, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        'Secure',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            if (errorMessage.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0x33EF4444),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0x55EF4444)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded,
                                        color: Color(0xFFEF4444), size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        errorMessage,
                                        style: const TextStyle(
                                          color: Color(0xFFFCA5A5),
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 18),

                            TextField(
                              controller: usernameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _fieldDecoration(
                                label: 'Username',
                                hint: 'Choose a username',
                                icon: Icons.person_outline_rounded,
                              ),
                            ),

                            const SizedBox(height: 12),

                            TextField(
                              controller: shopNameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _fieldDecoration(
                                label: '${l.shopName} (optional)',
                                hint: 'Your shop\'s display name',
                                icon: Icons.storefront_outlined,
                              ),
                            ),

                            const SizedBox(height: 12),

                            TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: Colors.white),
                              decoration: _fieldDecoration(
                                label: l.email,
                                hint: l.enterEmail,
                                icon: Icons.email_outlined,
                              ),
                            ),

                            const SizedBox(height: 12),

                            TextField(
                              controller: passwordController,
                              obscureText: !isPasswordVisible,
                              style: const TextStyle(color: Colors.white),
                              decoration: _fieldDecoration(
                                label: l.password,
                                hint: l.enterPassword,
                                icon: Icons.lock_outline_rounded,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    isPasswordVisible
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                      () => isPasswordVisible = !isPasswordVisible),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : registerUser,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 6,
                                  shadowColor: AppColors.primary.withValues(alpha: 0.75),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        l.createAccount,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                l.signIn,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const _RegisterLanguageSelector(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
      filled: true,
      fillColor: const Color(0xFF020617),
      prefixIcon: Icon(icon, color: Colors.white70, size: 20),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
      ),
    );
  }
}

class _RegisterLanguageSelector extends StatelessWidget {
  const _RegisterLanguageSelector();

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentCode = languageProvider.locale.languageCode;
    final current = LanguageProvider.languages.firstWhere(
        (l) => l['code'] == currentCode,
        orElse: () => LanguageProvider.languages.first);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: PopupMenuButton<String>(
        onSelected: (code) => languageProvider.setLanguage(code),
        color: const Color(0xFF020617),
        itemBuilder: (context) => LanguageProvider.languages
            .map(
              (lang) => PopupMenuItem<String>(
                value: lang['code']!,
                child: Row(
                  children: [
                    Text(lang['nativeName']!, style: const TextStyle(color: Colors.white)),
                    const SizedBox(width: 6),
                    if (lang['code'] == currentCode)
                      const Icon(Icons.check, size: 16, color: Colors.white70),
                  ],
                ),
              ),
            )
            .toList(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context).language,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 6),
              Text(
                current['nativeName']!,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, size: 18, color: Colors.white.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}