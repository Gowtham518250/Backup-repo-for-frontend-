import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'otp_service.dart';
import 'visual_widgets.dart';
import 'customer_login_page.dart';
import 'api_client.dart';
import 'secure_token_storage.dart';
import 'scoped_shared_preferences.dart';
import 'security_service.dart';

class RoleSelectionPage extends StatefulWidget {
  final String email;
  const RoleSelectionPage({super.key, required this.email});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  bool _isVerifying = false;
  bool _sendingOTP = false;
  final TextEditingController _otpController = TextEditingController();
  String? _error;
  int _failedAttempts = 0;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _mainController, curve: Curves.easeIn);
    _slideAnimation = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeOutQuart),
    );
    _mainController.forward();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _selectStaff() async {
    final scopedPrefs = await SharedPreferences.getInstance();
    final userId = scopedPrefs.getInt('user_id') ?? scopedPrefs.getInt('userId') ?? 0;
    if (userId <= 0) {
      if (mounted) {
        setState(() => _error = 'Owner session is missing. Please log in again.');
      }
      return;
    }

    List<dynamic> workers = [];
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      final response = await ApiClient.getJson(
        '/api/attendance/workers?user_id=$userId',
        headers: token.isNotEmpty ? {'Authorization': 'Bearer $token'} : null,
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          workers = decoded;
          await ScopedSharedPreferences.setString('workers_json', jsonEncode(decoded));
        }
      }
    } catch (e) {
      final cached = await ScopedSharedPreferences.getString('workers_json');
      if (cached != null && cached.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(cached);
          if (decoded is List) workers = decoded;
        } catch (_) {}
      }
    }

    if (workers.isEmpty) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No Staff Accounts'),
          content: const Text(
            'No staff account is configured for this shop. The owner must create a worker with a staff PIN before Staff Mode can be used.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final controller = TextEditingController();
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(
            'Staff Login',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter your 4-digit Staff PIN',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 28,
                  letterSpacing: 10,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.black26,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
              child: const Text('LOGIN'),
            ),
          ],
        ),
      );

      if (!mounted || result == null || result.length != 4) return;

      Map<String, dynamic>? matchedWorker;
      for (final item in workers) {
        if (item is! Map) continue;
        final pin = item['pin']?.toString().trim() ?? '';
        if (pin.isNotEmpty && pin == result) {
          matchedWorker = Map<String, dynamic>.from(item);
          break;
        }
      }

      if (matchedWorker == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Invalid Staff PIN'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      await ScopedSharedPreferences.setBool('is_staff_mode', true);
      await ScopedSharedPreferences.setString(
        'active_staff_name',
        matchedWorker['name']?.toString() ?? 'Staff',
      );
      if (matchedWorker['id'] != null) {
        await ScopedSharedPreferences.setString(
          'active_staff_worker_id',
          matchedWorker['id'].toString(),
        );
      }
      // Never change the account role here. Staff Mode is a scoped UI mode
      // inside the owner's account, not a different authenticated account.
      if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
    } finally {
      controller.dispose();
    }
  }

  Future<void> _startOwnerVerification() async {
    // Check if biometric is available and enabled
    final bool biometricAvailable = await SecurityService.isBiometricHardwareAvailable();
    final bool biometricEnabled = await SecurityService.isBiometricEnabled();
    
    if (!mounted) return;
    
    // If biometric is available and enabled, show dialog with biometric option
    if (biometricAvailable && biometricEnabled) {
      _showOwnerAuthMethodDialog();
      return;
    }
    
    // Otherwise proceed with OTP verification
    _proceedWithOTPVerification();
  }

  void _showOwnerAuthMethodDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Owner Authentication',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'How would you like to verify your identity?',
          style: GoogleFonts.poppins(color: Colors.white60, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _proceedWithOTPVerification();
            },
            child: Text(
              'Email OTP',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _authenticateWithBiometric();
            },
            icon: const Icon(Icons.fingerprint_rounded),
            label: const Text('Biometric'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _authenticateWithBiometric() async {
    try {
      final bool authenticated = await SecurityService.authenticateBiometrically(
        reason: 'Verify your identity to access Owner Dashboard'
      );

      if (!mounted) return;

      if (authenticated) {
        // Biometric successful, set owner mode and navigate to dashboard
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_role', 'OWNER');
        await ScopedSharedPreferences.setBool('is_staff_mode', false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text(
                  '✓ Welcome back, Owner!',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
        
        if (mounted) {
          await Future.delayed(const Duration(milliseconds: 800));
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      } else {
        // Biometric failed, show error and offer OTP as fallback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Biometric verification failed. Using Email OTP instead.',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
            ),
          );
          
          await Future.delayed(const Duration(milliseconds: 1500));
          _proceedWithOTPVerification();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Biometric error: $e. Using Email OTP instead.',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
        
        await Future.delayed(const Duration(milliseconds: 1500));
        _proceedWithOTPVerification();
      }
    }
  }

  Future<void> _proceedWithOTPVerification() async {
    setState(() {
      _sendingOTP = true;
      _error = null;
    });

    final result = await OTPService.sendOwnerVerificationOTP(
      widget.email,
      title: '🔐 Identity Verification',
      bodyText:
          'To access the Owner Dashboard and financial analytics, please use the 6-digit OTP below.',
    );

    if (!mounted) return;

    if (result['success']) {
      setState(() {
        _isVerifying = true;
        _sendingOTP = false;
      });
      // Success Snackbar - confirm the dispatch!
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Verification PIN dispatched! Please check ${widget.email}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF6366F1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      setState(() {
        _sendingOTP = false;
        _error = result['message'] ?? 'Failed to send verification PIN';
      });
    }
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.length != 6) {
      setState(() => _error = 'Please enter 6-digit PIN');
      return;
    }

    setState(() => _sendingOTP = true);

    final result = await OTPService.verifyOwnerVerificationOTP(
      widget.email,
      _otpController.text,
    );

    if (!mounted) return;

    if (result['success']) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', 'OWNER');
      await ScopedSharedPreferences.setBool('is_staff_mode', false);
      if (!mounted) return;
      if (await SecurityService.shouldShowOwnerBiometricGate()) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/owner-biometric-register');
      } else {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } else {
      _failedAttempts++;
      if (_failedAttempts >= 3) {
        if (!mounted) return;
        setState(() {
          _sendingOTP = false;
          _isVerifying = false;
          _error = 'Too many invalid attempts. Owner verification was cancelled. Please request a new OTP.';
        });
      } else {
        setState(() {
          _sendingOTP = false;
          _error = 'Invalid PIN. ${_failedAttempts == 2 ? "Final attempt." : "Try again."}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Background decorations (borrowed from login)
          Positioned(
            top: -100,
            right: -50,
            child: _Circle(size: 300, color: Colors.indigo.withValues(alpha: 0.15)),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: _Circle(size: 250, color: Colors.purple.withValues(alpha: 0.15)),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: AnimatedBuilder(
                    animation: _slideAnimation,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: child,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // App Logo
                          Hero(
                            tag: 'app_logo',
                            child: Image.asset(
                              'assets/shop_logo.png',
                              width: 80,
                              height: 80,
                              errorBuilder: (c, e, s) => const Icon(Icons.shield_rounded, size: 80, color: Colors.indigo),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Identity Verification',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Are you the Owner or a Staff Member?',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 48),

                          if (!_isVerifying)
                            _buildRoleSelection()
                          else
                            _buildOTPInput(),

                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelection() {
    return Column(
      children: [
        _RoleCard(
          title: 'I am the Owner',
          subtitle: 'Full access to Analytics, Reports and Settings. (Requires Email Verification)',
          icon: Icons.admin_panel_settings_rounded,
          color: Colors.indigoAccent,
          onTap: _sendingOTP ? null : _startOwnerVerification,
          isLoading: _sendingOTP,
        ),
        const SizedBox(height: 20),
        _RoleCard(
          title: 'I am Staff / Worker',
          subtitle: 'Enter your staff PIN for restricted shop access.',
          icon: Icons.badge_rounded,
          color: Colors.teal,
          onTap: _sendingOTP ? null : _selectStaff,
          isLoading: false,
        ),
      ],
    );
  }

  Widget _buildOTPInput() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          const Icon(Icons.mail_outline_rounded, color: Colors.indigoAccent, size: 48),
          const SizedBox(height: 16),
          Text(
            'Check your Email',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'We sent a 6-digit PIN to ${widget.email}',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _otpController,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
            decoration: InputDecoration(
              counterText: '',
              hintText: '000000',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _sendingOTP ? null : _verifyOTP,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigoAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _sendingOTP
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Verify PIN'),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _isVerifying = false),
            child: const Text('Go Back', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoading
                  ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                  : Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  final double size;
  final Color color;
  const _Circle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}



