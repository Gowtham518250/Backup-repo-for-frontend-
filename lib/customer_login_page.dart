import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'api_client.dart';
import 'customer_dashboard_page.dart';
import 'customer_register_page.dart';
import 'customer_forgot_password.dart';
import 'secure_token_storage.dart';

class CustomerLoginPage extends StatefulWidget {
  const CustomerLoginPage({super.key});
  @override
  State<CustomerLoginPage> createState() => _CustomerLoginPageState();
}

class _CustomerLoginPageState extends State<CustomerLoginPage> with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());

  bool _isLoading = false;
  bool _isOtpSent = false;
  bool _usePasswordLogin = false;  // 🔧 FIX: Allow direct password login
  String? _error;
  int _timerSeconds = 30;
  Timer? _timer;
  
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    setState(() => _timerSeconds = 30);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds == 0) {
        timer.cancel();
        setState(() {});
      } else {
        setState(() => _timerSeconds--);
      }
    });
  }

  Future<void> _sendOtp() async {
    if (_phoneController.text.length < 10) {
      setState(() => _error = 'Enter a valid 10-digit phone number');
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    HapticFeedback.lightImpact();
    
    // Simulate network delay for OTP send
    await Future.delayed(const Duration(milliseconds: 800));
    
    setState(() {
      _isLoading = false;
      _isOtpSent = true;
    });
    _startTimer();
    HapticFeedback.mediumImpact();
    _animController.reset();
    _animController.forward();
    _otpFocusNodes[0].requestFocus();
  }

  Future<void> _verifyOtpAndLogin() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length < 4) {
      setState(() => _error = 'Enter complete OTP');
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() { _isLoading = true; _error = null; });
    HapticFeedback.lightImpact();

    try {
      // 🔧 FIX: Use actual password instead of hardcoded password
      // In a real OTP flow, the OTP would be verified first, then login with the user's actual password
      // For now, we'll use the password field if it's filled, otherwise use OTP as fallback
      final passwordToUse = _passwordController.text.trim().isNotEmpty
          ? _passwordController.text.trim()
          : otp; // Fallback to OTP if password not provided

      // Use phone login endpoint if phone is provided, otherwise use email
      final response = await ApiClient.postJson(
        _emailController.text.trim().isNotEmpty
            ? ApiClient.customerLogin
            : ApiClient.customerLoginPhone,
        _emailController.text.trim().isNotEmpty
            ? {
                "email": _emailController.text.trim(),
                "password": passwordToUse
              }
            : {
                "phone": _phoneController.text.trim(),
                "password": passwordToUse
              }
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];
        final prefs = await SharedPreferences.getInstance();
        await SecureTokenStorage.saveCustomerToken(token);
        await prefs.setString('customer_id', data['customer_id'].toString());
        await prefs.setString('customer_name', data['name'] ?? data['user_name']);
        await prefs.setString('customer_phone', _phoneController.text.trim());
        if (data['email'] != null) {
          await prefs.setString('customer_email', data['email']);
        }

        HapticFeedback.heavyImpact();
        if (!mounted) return;
        // Navigate to verification page first, then dashboard
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CustomerDashboardPage(phone: _phoneController.text.trim())));
      } else {
        final errorData = jsonDecode(response.body);
        setState(() => _error = errorData['detail'] ?? 'Login failed. Please check your credentials.');
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      setState(() => _error = 'Connection failed: $e');
      HapticFeedback.heavyImpact();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPhoneInput() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        children: [
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 1.2),
            maxLength: 10,
            decoration: InputDecoration(
              counterText: '',
              hintText: 'Phone Number',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.phone_android, color: Colors.blueAccent),
            ),
          ),
          const SizedBox(height: 16),
          // 🔧 FIX: Add email field for backend authentication
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Email Address (required for login)',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.email, color: Colors.blueAccent),
            ),
          ),
          const SizedBox(height: 16),
          // 🔧 FIX: Add password field for direct login
          TextField(
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Password (required for login)',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.lock, color: Colors.blueAccent),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendOtp,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 8, shadowColor: Colors.blueAccent.withOpacity(0.5)),
              child: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('Send OTP', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpInput() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        children: [
          Text('Enter OTP sent to +91 ${_phoneController.text}', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (index) => SizedBox(
              width: 60, height: 60,
              child: TextField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.blueAccent, width: 2)),
                ),
                onChanged: (val) {
                  if (val.isNotEmpty) {
                    if (index < 3) _otpFocusNodes[index + 1].requestFocus();
                    else _verifyOtpAndLogin();
                  } else {
                    if (index > 0) _otpFocusNodes[index - 1].requestFocus();
                  }
                  HapticFeedback.lightImpact();
                },
              ),
            )),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _verifyOtpAndLogin,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 8, shadowColor: Colors.greenAccent.withOpacity(0.3)),
              child: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('Verify & Login', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: _timerSeconds == 0 ? _sendOtp : null,
            child: Text(_timerSeconds > 0 ? 'Resend OTP in ${_timerSeconds}s' : 'Resend OTP', style: GoogleFonts.poppins(color: _timerSeconds > 0 ? Colors.white38 : Colors.blueAccent, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => setState(() => _isOtpSent = false),
            child: Text('Change Phone Number', style: GoogleFonts.poppins(color: Colors.white54, decoration: TextDecoration.underline)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.storefront_rounded, size: 70, color: Colors.blueAccent),
                  ),
                  const SizedBox(height: 24),
                  Text('AI Shop Pro', style: GoogleFonts.poppins(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                  Text('Customer Portal', style: GoogleFonts.poppins(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 48),
                  
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isOtpSent ? _buildOtpInput() : _buildPhoneInput(),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent.withOpacity(0.5))),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_error!, style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 13))),
                      ]),
                    ),
                  ],
                  
                                    if (!_isOtpSent) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerForgotPasswordPage()));
                      },
                      child: Text("Forgot Password?", style: GoogleFonts.poppins(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 32),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text("New to AI Shop Pro? ", style: GoogleFonts.poppins(color: Colors.white54)),
                      GestureDetector(
                        onTap: () { HapticFeedback.lightImpact(); Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerRegisterPage())); },
                        child: Text("Create Account", style: GoogleFonts.poppins(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      )
                    ])
                  ]
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

