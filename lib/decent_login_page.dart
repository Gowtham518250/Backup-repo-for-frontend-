import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'app_localizations.dart';
import 'responsive.dart';
import 'visual_widgets.dart';
import 'language_provider.dart';
import 'sync_service.dart';
import 'sales_dedup_helper.dart';
import 'local_storage_service.dart';
import 'user_data_clear_service.dart';
import 'role_selection_page.dart';
import 'secure_token_storage.dart';
import 'security_service.dart';
import 'otp_service.dart';
import 'ltv_analytics_service.dart';
import 'session_management.dart';
import 'scoped_shared_preferences.dart';
import 'google_auth_service.dart';
import 'online_orders_listener.dart';
import 'inventory_sync_service.dart';
import 'sales_restore_service.dart';
import 'shop_profile_persistence_service.dart';


class DecentLoginPage extends StatefulWidget {
  const DecentLoginPage({super.key});

  @override
  State<DecentLoginPage> createState() => _DecentLoginPageState();
}

class _DecentLoginPageState extends State<DecentLoginPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool _isGoogleLoading = false;
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

  // ─── Google Sign-In ────────────────────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);

    final result = await GoogleAuthService.signIn();

    if (!mounted) return;

    if (result.success) {
      if (result.token == null || result.token!.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final hadOwner = (prefs.getInt('user_id') ?? prefs.getInt('userId') ?? 0) > 0;
        if (hadOwner) {
          await UserDataClearService.clearAllUserData();
          await SecureTokenStorage.clearAll();
          await LocalStorageService.clearOrphanSalesBoxes();
        } else {
          await SecureTokenStorage.clearAll();
        }
      }

      if (result.isFallback && result.email != null) {
        Navigator.pushNamed(context, '/register',
            arguments: {'email': result.email, 'name': result.name});
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (ctx) => RoleSelectionPage(email: result.email ?? ''),
        ),
      );
      return;
    }

    setState(() {
      errorMessage = result.error ?? 'Google Sign-In failed.';
      _isGoogleLoading = false;
    });
  }
  // ──────────────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _cardController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> loginUser() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      setState(() => errorMessage = 'Please fill in all fields');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // ✅ FIXED: Use centralized endpoint constant and 'email' field
      final response = await ApiClient.postJson(ApiClient.loginEndpoint, {
        'email': emailController.text.trim(),
        'password': passwordController.text.trim(),
      }).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // ✅ FIXED: Parse 'access_token' from response (not 'token')
        final accessToken = data['access_token']?.toString() ?? '';
        final refreshToken = data['refresh_token']?.toString() ?? '';
        final tokenType = data['token_type']?.toString() ?? 'bearer';
        final role = data['role']?.toString() ?? 'OWNER';
        
        if (accessToken.isEmpty) {
          setState(() {
            errorMessage = 'Login failed: No access token received';
          });
          return;
        }
        
        final userId = (() {
          try {
            final parts = accessToken.split('.');
            if (parts.length != 3) return data['user_id'] is int ? data['user_id'] as int : int.tryParse(data['user_id']?.toString() ?? '') ?? 0;
            String normalized = parts[1].replaceAll('-', '+').replaceAll('_', '/');
            while (normalized.length % 4 != 0) {
              normalized += '=';
            }
            final payload = json.decode(utf8.decode(base64.decode(normalized)));
            return int.tryParse(payload['sub']?.toString() ?? '') ?? (data['user_id'] is int ? data['user_id'] as int : int.tryParse(data['user_id']?.toString() ?? '') ?? 0);
          } catch (_) {
            return data['user_id'] is int ? data['user_id'] as int : int.tryParse(data['user_id']?.toString() ?? '') ?? 0;
          }
        })();

        // Clear stale session-only state only when an older local owner session
        // is still present. After a normal logout the token is already gone, so
        // repeating the full purge here can reopen/clear storage again and leave
        // the login overlay waiting indefinitely.
        final existingToken = await SecureTokenStorage.getToken();
        if ((existingToken ?? '').isNotEmpty && existingToken != accessToken) {
          if (kDebugMode) {
            debugPrint('🧹 Existing local session detected; clearing stale session data...');
          }
          try {
            await UserDataClearService.clearAllUserData().timeout(
              const Duration(seconds: 8),
            );
          } on TimeoutException {
            if (mounted) {
              setState(() {
                errorMessage =
                    'Local session cleanup timed out. Please retry login.';
              });
            }
            if (kDebugMode) {
              debugPrint('⏱️ Login aborted: local session cleanup timed out');
            }
            return;
          }
        }

        final deviceId = await SessionManagementService.getDeviceId();
        await SessionManagementService.initializeSession(
          userId: userId,
          accessToken: accessToken,
          refreshToken: refreshToken.isNotEmpty ? refreshToken : null,
          userName: data['user_name']?.toString() ?? '',
          userEmail: data['email']?.toString() ?? emailController.text.trim(),
          role: role,
          deviceId: deviceId,
        );

        final prefs = await SharedPreferences.getInstance();
        if (data['shop_name'] != null) {
          await prefs.setString('shop_name', data['shop_name'].toString());
          await ScopedSharedPreferences.setString('shop_name', data['shop_name'].toString());
        }
        if (data['location'] != null) {
          await prefs.setString('location', data['location'].toString());
          await ScopedSharedPreferences.setString('location', data['location'].toString());
        }
        if (data['shop_type'] != null) {
          await prefs.setString('shop_type', data['shop_type'].toString());
          await ScopedSharedPreferences.setString('shop_type', data['shop_type'].toString());
        }

        if (kDebugMode) {
          debugPrint('✅ Login successful');
          debugPrint('   Token Type: $tokenType');
          debugPrint('   Role: $role');
          debugPrint('   User ID: $userId');
        }

        // 🔧 FIX: Navigate IMMEDIATELY — don't await heavy sync operations before showing dashboard
        // Heavy sync (sales restore, inventory refresh) runs in background after navigation
        if (!mounted) return;
        final normalizedRole = role.trim().toUpperCase();
        if (normalizedRole == 'CUSTOMER') {
          Navigator.of(context).pushReplacementNamed('/customer-verification');
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (ctx) => RoleSelectionPage(email: emailController.text.trim()),
            ),
          );
        }

        // 🔧 FIX: Run sync in background (fire-and-forget) so it doesn't block navigation
        unawaited(_runPostLoginSyncInBackground(userId));

      } else {
        setState(() {
          errorMessage = _extractErrorMessage(response);
        });
        
        if (kDebugMode) debugPrint('❌ Login error: ${errorMessage} (Status: ${response.statusCode})');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Connection error: ${e.toString().replaceAll('Exception:', '').trim()}';
      });
      if (kDebugMode) debugPrint('❌ Login exception: $e');
    } finally {
      // 🔧 FIX: Always reset loading state so the UI doesn't get stuck spinning
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Extract error message from response body safely
  /// Handles both JSON and non-JSON responses
  String _extractErrorMessage(http.Response response) {
    try {
      final data = json.decode(response.body);
      if (data is Map) {
        return data['detail']?.toString() ?? 
               data['message']?.toString() ?? 
               data['error']?.toString() ?? 
               'Login failed (Status: ${response.statusCode})';
      }
      return 'Login failed (Status: ${response.statusCode})';
    } catch (e) {
      // If response is not JSON, return the body text or a generic error
      if (response.body.isNotEmpty && response.body.length < 200) {
        return response.body;
      }
      return 'Connection error: ${e.toString().replaceAll('Exception:', '').trim()}';
    }
  }

  /// Run heavy post-login sync in the background so the user reaches the dashboard quickly
  Future<void> _runPostLoginSyncInBackground(int userId) async {
    try {
      if (kDebugMode) debugPrint('🔄 [Background] Starting post-login sync flow...');

      // Restore shop profile
      try {
        final profileResult = await ShopProfilePersistenceService.restoreProfile();
        if (!profileResult['success']) {
          final localProfile = await ShopProfilePersistenceService.loadProfileLocally();
          if (localProfile != null) {
            await ShopProfilePersistenceService.applyProfileToPrefs(localProfile);
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ [Background] Shop profile restore error: $e');
      }

      // Upload pending offline sales
      try {
        await SyncService.processQueueSafe();
        await SyncService.downloadUserDataSafe();
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ [Background] Sync queue error: $e');
      }

      // Merge with backend sales — only run the full restore once per user.
      // Without this guard, completeRestoration() re-downloads and re-merges
      // backend sales on every single login, which is wasted work and an
      // unnecessary duplication risk surface.
      try {
        final alreadyRestored = await SalesRestoreService.wasRestorationCompleted();
        if (!alreadyRestored) {
          final restorationResult = await SalesRestoreService.completeRestoration();
          if (restorationResult['success']) {
            await SalesRestoreService.markRestorationComplete();
          }
        } else {
          if (kDebugMode) {
            debugPrint('ℹ️ [Background] Skipping sales restore — already completed for this user');
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ [Background] Sales restore error: $e');
      }

      // Refresh inventory
      try {
        await InventorySyncService.refreshAllInventory();
        await InventorySyncService.updateLastSyncTimestamp();
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ [Background] Inventory refresh error: $e');
      }

      // Start listeners
      try {
        await OnlineOrdersListener.instance.restartForCurrentUser();
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ [Background] Listener start error: $e');
      }

      if (kDebugMode) debugPrint('✅ [Background] Post-login sync complete');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [Background] Post-login sync failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return BackendLoadingOverlay(
      isVisible: isLoading || _isGoogleLoading,
      title: 'Welcome Back',
      subtitle: 'Securing your session...',
      icon: Icons.security_rounded,
      accentColor: const Color(0xFF6366F1),
      child: Scaffold(
      backgroundColor: const Color(0xFF0F2447),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F2447),
              Color(0xFF1B3A6B),
              Color(0xFF0A1628),
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
                    // App logo + branding
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 2),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/shop_logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.storefront_rounded, color: Colors.white, size: 36),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l.appTitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.tagline,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Animated white card
                    ScaleTransition(
                      scale: _cardScale,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 40,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l.signIn,
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF0F172A),
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        l.enterCredentials,
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF64748B),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1B3A6B).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFF1B3A6B).withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.lock_rounded, size: 12, color: Color(0xFF1B3A6B)),
                                      const SizedBox(width: 4),
                                      Text('Secure', style: GoogleFonts.inter(color: const Color(0xFF1B3A6B), fontSize: 11, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            if (errorMessage.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFCA5A5)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        errorMessage,
                                        style: GoogleFonts.inter(color: const Color(0xFFDC2626), fontSize: 12.5, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 18),

                            TextField(
                              controller: emailController,
                              enabled: !isLoading,
                              keyboardType: TextInputType.emailAddress,
                              style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 14),
                              decoration: InputDecoration(
                                labelText: l.email,
                                hintText: l.enterEmail,
                                labelStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
                                hintStyle: GoogleFonts.inter(color: const Color(0xFFCBD5E1), fontSize: 13),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF94A3B8), size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1B3A6B), width: 1.5)),
                              ),
                            ),

                            const SizedBox(height: 12),

                            TextField(
                              controller: passwordController,
                              enabled: !isLoading,
                              obscureText: !isPasswordVisible,
                              style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 14),
                              decoration: InputDecoration(
                                labelText: l.password,
                                hintText: l.enterPassword,
                                labelStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
                                hintStyle: GoogleFonts.inter(color: const Color(0xFFCBD5E1), fontSize: 13),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(isPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: const Color(0xFF94A3B8), size: 20),
                                  onPressed: isLoading ? null : () => setState(() => isPasswordVisible = !isPasswordVisible),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1B3A6B), width: 1.5)),
                              ),
                            ),

                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: isLoading ? null : () => Navigator.pushNamed(context, '/forgot-password'),
                                child: Text(l.forgotPassword, style: GoogleFonts.inter(color: const Color(0xFF1B3A6B), fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            ),

                            const SizedBox(height: 16),

                            ElevatedButton(
                              onPressed: isLoading ? null : loginUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1B3A6B),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: isLoading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Text(l.signIn, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.3)),
                            ),

                            const SizedBox(height: 10),

                            // Divider OR
                            Row(children: [
                              const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('OR', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                              const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                            ]),

                            const SizedBox(height: 10),

                            // Google Sign-In
                            _isGoogleLoading
                                ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF1B3A6B)))))
                                : OutlinedButton(
                                    onPressed: isLoading ? null : _signInWithGoogle,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 13),
                                      side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      backgroundColor: Colors.white,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(width: 20, height: 20, child: CustomPaint(painter: _GoogleLogoPainter())),
                                        const SizedBox(width: 10),
                                        Text('Continue with Google', style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 14)),
                                      ],
                                    ),
                                  ),

                            const SizedBox(height: 10),

                            TextButton(
                              onPressed: isLoading ? null : () => Navigator.pushNamed(context, '/register'),
                              child: RichText(
                                text: TextSpan(
                                  text: "Don't have an account? ",
                                  style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
                                  children: [TextSpan(text: 'Register', style: GoogleFonts.inter(color: const Color(0xFF1B3A6B), fontWeight: FontWeight.w700, fontSize: 13))],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    const _LoginLanguageSelector(),
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
}

class _LoginLanguageSelector extends StatelessWidget {
  const _LoginLanguageSelector();

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentCode = languageProvider.locale.languageCode;
    final current =
        LanguageProvider.languages.firstWhere((l) => l['code'] == currentCode,
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
                    Text(
                      lang['nativeName']!,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    if (lang['code'] == currentCode)
                      const Icon(Icons.check,
                          size: 16, color: Colors.white70),
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
              const Icon(Icons.language_rounded,
                  size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context).language,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                current['nativeName']!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down,
                  size: 18, color: Colors.white.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}


/// Draws the iconic Google 'G' logo using coloured arcs/paths.
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = Colors.white);
    _drawArc(canvas, cx, cy, r * 0.72, -30, -120, const Color(0xFFEA4335));
    _drawArc(canvas, cx, cy, r * 0.72, -30, 120, const Color(0xFF4285F4));
    _drawArc(canvas, cx, cy, r * 0.72, 90, 90, const Color(0xFFFBBC05));
    _drawArc(canvas, cx, cy, r * 0.72, 180, -90, const Color(0xFF34A853));
    canvas.drawCircle(Offset(cx, cy), r * 0.45, Paint()..color = Colors.white);
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - r * 0.13, r * 0.72, r * 0.26),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  void _drawArc(Canvas canvas, double cx, double cy, double r,
      double startDeg, double sweepDeg, Color color) {
    const double deg2rad = 3.14159265358979 / 180;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      startDeg * deg2rad,
      sweepDeg * deg2rad,
      true,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}