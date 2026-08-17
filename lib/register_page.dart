import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'app_localizations.dart';
import 'visual_widgets.dart';
import 'language_provider.dart';
import 'security_service.dart';
import 'secure_token_storage.dart';
import 'session_management.dart';
import 'production_security_suite.dart';
import 'google_auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController shopNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();

  bool isLoading = false;
  bool _isGoogleLoading = false;
  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;
  bool _enableBiometric = false;
  bool _biometricAvailable = false;
  String errorMessage = '';
  String successMessage = '';
  
  // Retry mechanism for connection issues
  int _retryCount = 0;
  static const int _maxRetries = 3;
  Future<void>? _registrationFuture;

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
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final available = await SecurityService.isBiometricHardwareAvailable();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
      });
    }
  }

  @override
  void dispose() {
    _cardController.dispose();
    nameController.dispose();
    shopNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  // ─── Google Sign-In ──────────────────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      errorMessage = '';
      successMessage = '';
    });

    final result = await GoogleAuthService.signIn();

    if (!mounted) return;

    if (result.success) {
      if (result.isNewUser) {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getInt('user_id') ?? prefs.getInt('userId') ?? 0;
        if (userId > 0) {
          await prefs.setBool('shop_details_required_$userId', true);
          await prefs.setBool('shop_details_completed_$userId', false);
        }
      }

      // Backend authenticated — new users go to the existing Shop Details page;
      // existing Google users continue without reopening onboarding.
      Navigator.pushReplacementNamed(
        context,
        result.isNewUser ? '/shop-details' : '/dashboard',
      );
      return;
    }

    if (result.isFallback && result.email != null) {
      // Pre-fill fields with Google profile
      nameController.text = result.name ?? '';
      emailController.text = result.email!;
      setState(() {
        successMessage =
            '✅ Google profile loaded! Fill in the remaining fields to complete registration.';
        _isGoogleLoading = false;
      });
      return;
    }

    setState(() {
      errorMessage = result.error ?? 'Google Sign-In failed. Please try again.';
      _isGoogleLoading = false;
    });
  }
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _checkConnectionAndRegister() async {
    setState(() => isLoading = true);
    await _registerUserWithRetry();
  }

  Future<void> _registerUserWithRetry() async {
    _retryCount = 0;
    
    while (_retryCount < _maxRetries) {
      try {
        if (kDebugMode) debugPrint('📝 Registration attempt ${_retryCount + 1}/$_maxRetries');
        
        // ✅ FIXED: Use correct field names (username, and include shop_name)
        if (kDebugMode) debugPrint('📝 Calling /auth/register with: ${{
          'username': nameController.text.trim(),
          'shop_name': shopNameController.text.trim(),
          'email': emailController.text.trim(),
          'password': '***'
        }}');
        
        final response = await ApiClient.postJson('/auth/register', {
          'username': nameController.text.trim(),  // Backend expects 'username'
          'shop_name': shopNameController.text.trim(),
          'email': emailController.text.trim(),
          'password': passwordController.text.trim(),
        }).timeout(
          const Duration(seconds: 45),
          onTimeout: () => throw TimeoutException('Server took too long to respond'),
        );

        if (!mounted) return;

        if (response.statusCode == 200 || response.statusCode == 201) {
          await _handleRegistrationSuccess(response);
          return; // Success - exit retry loop
        } else if (response.statusCode == 400 || response.statusCode == 409) {
          // Client validation error or conflict - don't retry.
          // This should surface the backend message directly instead of falling back to login.
          await _handleRegistrationError(response);
          return;
        } else {
          // Server error - may retry
          throw Exception('Server error: ${response.statusCode}');
        }
      } on TimeoutException catch (e) {
        _retryCount++;
        if (kDebugMode) debugPrint('⏱️ Timeout on attempt $_retryCount: $e');
        
        if (_retryCount < _maxRetries) {
          // Wait before retry - exponential backoff
          await Future.delayed(Duration(seconds: 2 * _retryCount));
          continue; // Retry
        } else {
          // All retries exhausted
          if (mounted) {
            setState(() {
              isLoading = false;
              errorMessage = '⏱️ Server is responding slowly.\n\n💡 Solutions:\n'
                  '1️⃣ Check your internet speed\n'
                  '2️⃣ Move closer to WiFi router\n'
                  '3️⃣ Wait a moment and try again';
              successMessage = '';
            });
          }
          return;
        }
      } on SocketException catch (e) {
        _retryCount++;
        if (kDebugMode) debugPrint('🌐 Network error on attempt $_retryCount: $e');
        
        if (_retryCount < _maxRetries) {
          await Future.delayed(Duration(seconds: 2 * _retryCount));
          continue; // Retry
        } else {
          if (mounted) {
            setState(() {
              isLoading = false;
              errorMessage = '🌐 Network connection lost.\n\n💡 Please check:\n'
                  '• WiFi/mobile data is enabled\n'
                  '• You have an active connection\n'
                  '• Server is reachable';
              successMessage = '';
            });
          }
          return;
        }
      } catch (e) {
        _retryCount++;
        final errorStr = e.toString();
        if (kDebugMode) debugPrint('❌ Error on attempt $_retryCount: $e');
        
        if (_retryCount < _maxRetries && 
            (errorStr.contains('Connection') || 
             errorStr.contains('refused') || 
             errorStr.contains('reset'))) {
          await Future.delayed(Duration(seconds: 2 * _retryCount));
          continue; // Retry on connection errors
        } else {
          // Non-retryable error
          if (mounted) {
            setState(() {
              isLoading = false;
              if (errorStr.contains('Connection refused')) {
                errorMessage = '🔌 Server connection refused.\n\n⚠️ The server might be:\n'
                    '• Down for maintenance\n'
                    '• Not running\n\n💡 Please contact support';
              } else {
                errorMessage = 'Registration error: $errorStr';
              }
              successMessage = '';
            });
          }
          return;
        }
      }
    }
  }

  Future<void> _handleRegistrationSuccess(http.Response response) async {
    try {
      final data = json.decode(response.body);
      
      // ✅ FIXED: Parse 'access_token' from response (not 'token')
      final accessToken = data['access_token'] as String? ?? '';
      final tokenType = data['token_type'] as String? ?? 'bearer';
      final role = data['role'] as String? ?? 'OWNER';
      final userId = data['user_id'] as int? ?? 0;
      final username = data['username'] as String? ?? nameController.text.trim();

      if (accessToken.isEmpty) {
        setState(() {
          isLoading = false;
          errorMessage = 'Registration failed: No access token received from server';
        });
        return;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final language = prefs.getString('languageCode');
      final pdsEnabled = prefs.getBool('payment_sound_enabled');
      final pdsSoundLang = prefs.getString('payment_sound_lang');
      
      await prefs.clear();
      
      if (language != null) await prefs.setString('languageCode', language);
      if (pdsEnabled != null) await prefs.setBool('payment_sound_enabled', pdsEnabled);
      if (pdsSoundLang != null) await prefs.setString('payment_sound_lang', pdsSoundLang);
      
      final extractedUserId = userId > 0 ? userId : (() {
        try {
          final parts = accessToken.split('.');
          if (parts.length != 3) return 0;
          String normalized = parts[1].replaceAll('-', '+').replaceAll('_', '/');
          while (normalized.length % 4 != 0) {
            normalized += '=';
          }
          final payload = json.decode(utf8.decode(base64.decode(normalized)));
          return int.tryParse(payload['sub']?.toString() ?? '') ?? 0;
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Error extracting user ID from JWT: $e');
          return 0;
        }
      })();

      final deviceId = await SessionManagementService.getDeviceId();
      await SessionManagementService.initializeSession(
        userId: extractedUserId,
        accessToken: accessToken,
        refreshToken: data['refresh_token']?.toString(),
        userName: username,
        userEmail: emailController.text.trim(),
        role: role,
        deviceId: deviceId,
      );

      await prefs.setString('user_name', username);
      await prefs.setString('email', emailController.text.trim());

      // Registration-only onboarding gate. Existing logins must not be sent
      // back to Shop Details; only a freshly registered account is flagged.
      if (extractedUserId > 0) {
        await prefs.setBool('shop_details_required_$extractedUserId', true);
        await prefs.setBool('shop_details_completed_$extractedUserId', false);
      }
      
      if (kDebugMode) {
        debugPrint('✅ Registration successful');
        debugPrint('   Token Type: $tokenType');
        debugPrint('   Role: $role');
      }

      if (mounted) {
        setState(() {
          successMessage = 'Registration successful! Welcome aboard! 🎉';
          errorMessage = '';
        });
      }

      // Setup biometric if enabled
      if (_enableBiometric) {
        try {
          if (await SecurityService.isBiometricHardwareAvailable()) {
            await SecurityService.authenticateBiometrically(
              reason: 'Enable biometric login',
            );
          }
        } catch (e) {
          if (kDebugMode) debugPrint('Biometric setup: $e');
        }
      }

      if (mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/shop-details');
          }
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Registration success handler error: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Error processing registration: $e';
          successMessage = '';
        });
      }
    }
  }

  Future<void> _handleRegistrationError(http.Response response) async {
    try {
      final body = response.body;
      final decoded = json.decode(body);
      final detail = (decoded is Map<String, dynamic>
              ? (decoded['detail'] ?? decoded['message'] ?? 'Registration failed. Please try again.')
              : body)
          .toString();

      if (mounted) {
        setState(() {
          isLoading = false;

          final lowerDetail = detail.toLowerCase();
          if (lowerDetail.contains('username or email')) {
            errorMessage = '👤📧 This shop name or email is already taken. Please try another.';
          } else if (lowerDetail.contains('email already') && !lowerDetail.contains('username')) {
            errorMessage = '📧 This email is already registered.\n\n💡 Try logging in instead, or use a different email address.';
          } else if (lowerDetail.contains('username already') || lowerDetail.contains('shop name')) {
            errorMessage = '👤 This owner/shop name is already taken.\n\n💡 Please choose a different name.';
          } else if (lowerDetail.contains('email is required')) {
            errorMessage = '📧 Email address is required. Please enter your email.';
          } else if (lowerDetail.contains('password')) {
            errorMessage = '🔒 Password issue: $detail';
          } else {
            errorMessage = detail;
          }
          successMessage = '';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Server error: ${response.statusCode}.\n\n💡 Please try again in a moment.';
          successMessage = '';
        });
      }
    }
  }

  Future<void> registerUser() async {
    if (isLoading) return; // Prevent double-taps
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      isLoading = true;
      errorMessage = '';
      successMessage = '';
    });
    
    await _checkConnectionAndRegister();
    
    if (mounted) setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
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
                    // App logo
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

                    // Animated glass card
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
                        child: Form(
                          key: _formKey,
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
                                        l.joinCommunity,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.65),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Small accent pill
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
                                    border: Border.all(
                                        color: const Color(0x55EF4444)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withValues(alpha: 0.1),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Show retry button for connection errors
                                      if (errorMessage.contains('connection') ||
                                          errorMessage.contains('internet') ||
                                          errorMessage.contains('network') ||
                                          errorMessage.contains('timeout') ||
                                          errorMessage.contains('server')) ...[
                                        const SizedBox(height: 10),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            icon: const Icon(Icons.refresh, size: 16),
                                            label: const Text('Retry Registration'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFEF4444),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(
                                                vertical: 8,
                                                horizontal: 12,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                            ),
                                            onPressed: isLoading ? null : registerUser,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],

                              if (successMessage.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0x3310B981),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: const Color(0x5510B981)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_outline_rounded,
                                          color: Color(0xFF10B981), size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          successMessage,
                                          style: const TextStyle(
                                            color: Color(0xFFA7F3D0),
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

                              _buildTextField(
                                controller: nameController,
                                labelText: l.fullName,
                                hintText: 'Enter your full name',
                                icon: Icons.person_outline_rounded,
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'Please enter your name'
                                    : null,
                              ),

                              const SizedBox(height: 12),

                              _buildTextField(
                                controller: shopNameController,
                                labelText: 'Shop Name',
                                hintText: 'Enter your shop or business name',
                                icon: Icons.storefront_outlined,
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'Please enter your shop name'
                                    : null,
                              ),

                              const SizedBox(height: 12),

                              _buildTextField(
                                controller: emailController,
                                labelText: l.emailAddress,
                                hintText: l.enterEmail,
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) => ProductionSecuritySuite.validateEmail(v),
                              ),

                              const SizedBox(height: 12),

                              _buildTextField(
                                controller: phoneController,
                                labelText: l.phoneNumber,
                                hintText: '9876543210 (10 digits)',
                                icon: Icons.phone_rounded,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                validator: (v) => ProductionSecuritySuite.validatePhone(v),
                              ),

                              const SizedBox(height: 12),

                              _buildTextField(
                                controller: passwordController,
                                labelText: l.password,
                                hintText: l.enterPassword,
                                icon: Icons.lock_outline_rounded,
                                obscureText: !isPasswordVisible,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    isPasswordVisible
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() =>
                                      isPasswordVisible = !isPasswordVisible),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Password is required';
                                  }
                                  if (v.trim().length < 8) {
                                    return 'Password must be at least 8 characters';
                                  }
                                  if (!v.contains(RegExp(r'[A-Z]'))) {
                                    return 'Password must contain uppercase letter (A-Z)';
                                  }
                                  if (!v.contains(RegExp(r'[a-z]'))) {
                                    return 'Password must contain lowercase letter (a-z)';
                                  }
                                  if (!v.contains(RegExp(r'[0-9]'))) {
                                    return 'Password must contain number (0-9)';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 12),

                              _buildTextField(
                                controller: confirmController,
                                labelText: 'Confirm Password',
                                hintText: 'Re-enter your password',
                                icon: Icons.lock_outline_rounded,
                                obscureText: !isConfirmPasswordVisible,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    isConfirmPasswordVisible
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() =>
                                      isConfirmPasswordVisible = !isConfirmPasswordVisible),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Please confirm your password';
                                  }
                                  if (v.trim() != passwordController.text.trim()) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 24),

                              // Optional Biometric Registration
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF020617),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.fingerprint,
                                          color: Color(0xFF10B981),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Enable Biometric Login (Optional)',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.9),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Register fingerprint or face unlock for faster login. You can enable this later from Shop Profile.',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: _enableBiometric,
                                          onChanged: _biometricAvailable
                                              ? (value) => setState(() => _enableBiometric = value ?? false)
                                              : null,
                                          activeColor: const Color(0xFF10B981),
                                          checkColor: Colors.white,
                                        ),
                                        Expanded(
                                          child: Text(
                                            _biometricAvailable
                                                ? 'I want to use fingerprint/face unlock for login'
                                                : 'Biometric support not available on this device',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.8),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              // 🔐 Register Button with enhanced loading
                              ElevatedButton(
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
                                child: SizedBox(
                                  height: 24,
                                  child: isLoading
                                      ? Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              'Creating Account...',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white.withValues(alpha: 0.9),
                                              ),
                                            ),
                                          ],
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

                              const SizedBox(height: 16),

                              // 🚀 Google Sign-In Button — Real Implementation
                              _isGoogleLoading
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(vertical: 14),
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                                          ),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.2),
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withValues(alpha: 0.07),
                                            Colors.white.withValues(alpha: 0.03),
                                          ],
                                        ),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: isLoading ? null : _signInWithGoogle,
                                          borderRadius: BorderRadius.circular(12),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                              horizontal: 16,
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                // Google "G" logo using coloured squares
                                                SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CustomPaint(painter: _GoogleLogoPainter()),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  'Continue with Google',
                                                  style: TextStyle(
                                                    color: Colors.white.withValues(alpha: 0.9),
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                              const SizedBox(height: 8),

                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  l.alreadyHaveAccount + ' ' + l.signIn,
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
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    FormFieldValidator<String>? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
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
        errorStyle: const TextStyle(color: Color(0xFFFCA5A5)),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
        ),
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

    // Background circle
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = Colors.white,
    );

    // Red top-left arc
    _drawArc(canvas, cx, cy, r * 0.72, -30, -120, const Color(0xFFEA4335));
    // Blue right arc
    _drawArc(canvas, cx, cy, r * 0.72, -30, 120, const Color(0xFF4285F4));
    // Yellow bottom-left arc
    _drawArc(canvas, cx, cy, r * 0.72, 90, 90, const Color(0xFFFBBC05));
    // Green bottom-right arc
    _drawArc(canvas, cx, cy, r * 0.72, 180, -90, const Color(0xFF34A853));

    // White inner circle
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.45,
      Paint()..color = Colors.white,
    );

    // Blue right bar (horizontal G arm)
    final barPaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - r * 0.13, r * 0.72, r * 0.26),
      barPaint,
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