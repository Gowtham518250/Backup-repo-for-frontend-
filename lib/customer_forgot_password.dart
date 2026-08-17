import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'otp_service.dart';

class CustomerForgotPasswordPage extends StatefulWidget {
  const CustomerForgotPasswordPage({super.key});
  @override
  State<CustomerForgotPasswordPage> createState() => _CustomerForgotPasswordPageState();
}

class _CustomerForgotPasswordPageState extends State<CustomerForgotPasswordPage> with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController(); // Added email field
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController()); // Changed to 6 digits
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  final _newPassController = TextEditingController();

  bool _isLoading = false;
  int _step = 0; // 0: Phone, 1: OTP, 2: New Password
  String? _error;
  int _timerSeconds = 30;
  Timer? _timer;
  bool _useEmail = true; // Added option to use email instead of phone

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
    // FIX: Dispose all controllers and focus nodes to prevent memory leaks.
    _phoneController.dispose();
    _emailController.dispose();
    _newPassController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
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
    final email = _emailController.text.trim(); // Use email field
    
    if (email.isEmpty || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address');
      HapticFeedback.heavyImpact();
      return;
    }
    
    setState(() { _isLoading = true; _error = null; });
    HapticFeedback.lightImpact();
    
    try {
      final result = await OTPService.sendOTPToEmail(
        email,
        title: '🔐 Password Reset',
        bodyText: 'Use the OTP below to reset your password:',
      );
      
      setState(() { _isLoading = false; });
      
      if (result['success'] == true) {
        setState(() { _step = 1; });
        _startTimer();
        HapticFeedback.mediumImpact();
        _animController.reset(); 
        _animController.forward();
        _otpFocusNodes[0].requestFocus();
      } else {
        setState(() => _error = result['message']?.toString() ?? 'Failed to send OTP');
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      setState(() { 
        _isLoading = false; 
        _error = 'Failed to send OTP: $e'; 
      });
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    final email = _emailController.text.trim();
    
    if (otp.length < 6) {
      setState(() => _error = 'Enter complete 6-digit OTP');
      HapticFeedback.heavyImpact();
      return;
    }
    
    setState(() { _isLoading = true; _error = null; });
    HapticFeedback.lightImpact();
    
    try {
      final result = await OTPService.verifyOTP(email, otp);
      
      setState(() { _isLoading = false; });
      
      if (result['success'] == true) {
        setState(() { _step = 2; });
        HapticFeedback.mediumImpact();
        _animController.reset(); 
        _animController.forward();
      } else {
        setState(() => _error = result['message']?.toString() ?? 'Invalid OTP');
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      setState(() { 
        _isLoading = false; 
        _error = 'Failed to verify OTP: $e'; 
      });
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _resetPassword() async {
    if (_newPassController.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 1000)); // Simulate API
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password Reset Successfully!'), backgroundColor: Colors.green));
    Navigator.pop(context);
  }

  Widget _buildStep0() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        children: [
          Text('Enter your registered email to receive an OTP.', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          TextField(
            controller: _emailController, 
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              hintText: 'Email Address', hintStyle: const TextStyle(color: Colors.white38),
              filled: true, fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.email, color: Colors.blueAccent),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendOtp,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text('Send OTP', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        children: [
          Text('Enter OTP sent to ${_emailController.text}', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) => SizedBox(
              width: 50, height: 60,
              child: TextField(
                controller: _otpControllers[index], focusNode: _otpFocusNodes[index],
                keyboardType: TextInputType.number, textAlign: TextAlign.center, maxLength: 1,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  counterText: '', filled: true, fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.blueAccent, width: 2)),
                ),
                onChanged: (val) {
                  HapticFeedback.lightImpact();
                  if (val.isNotEmpty) { if (index < 5) _otpFocusNodes[index + 1].requestFocus(); else _verifyOtp(); } 
                  else { if (index > 0) _otpFocusNodes[index - 1].requestFocus(); }
                },
              ),
            )),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text('Verify OTP', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          TextButton(
            onPressed: _timerSeconds == 0 ? () async {
              final result = await OTPService.resendOTP(_emailController.text.trim());
              if (result['success'] == true) {
                _startTimer();
                setState(() => _error = null);
              } else {
                setState(() => _error = result['message']?.toString() ?? 'Failed to resend OTP');
              }
            } : null,
            child: Text(_timerSeconds > 0 ? 'Resend OTP in ${_timerSeconds}s' : 'Resend OTP', style: GoogleFonts.poppins(color: _timerSeconds > 0 ? Colors.white38 : Colors.blueAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        children: [
          Text('Enter your new secure password.', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 24),
          TextField(
            controller: _newPassController, obscureText: true,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              hintText: 'New Password', hintStyle: const TextStyle(color: Colors.white38),
              filled: true, fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.blueAccent),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _resetPassword,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text('Reset Password', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_reset, size: 80, color: Colors.blueAccent),
                  const SizedBox(height: 16),
                  Text('Forgot Password', style: GoogleFonts.poppins(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 40),
                  
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _step == 0 ? _buildStep0() : _step == 1 ? _buildStep1() : _buildStep2(),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent.withOpacity(0.5))),
                      child: Text(_error!, style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 13)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
