import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:google_fonts/google_fonts.dart';
import 'otp_service.dart';
import 'loading_states.dart';

/// OTP Verification Screen with email and OTP input
class OTPVerificationPage extends StatefulWidget {
  final String email;
  final VoidCallback onSuccess;
  final VoidCallback? onBack;

  const OTPVerificationPage({
    Key? key,
    required this.email,
    required this.onSuccess,
    this.onBack,
  }) : super(key: key);

  @override
  State<OTPVerificationPage> createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage>
    with SingleTickerProviderStateMixin {
  final _otpController = TextEditingController();
  late AnimationController _timerController;

  bool _isLoading = false;
  bool _isResending = false;
  String _message = '';
  String _messageType = ''; // success, error, info
  int _remainingTime = 0;
  bool _otpSent = false;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _sendOTP();
    _startTimer();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timerController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    setState(() => _isLoading = true);

    final result = await OTPService.sendOTPToEmail(
      widget.email,
      title: '🔐 Account Verification',
      bodyText: 'To complete your verification, please use the OTP below:',
    );

    setState(() {
      _isLoading = false;
      _otpSent = true;
      final msg = result['message']?.toString() ?? 'OTP sent';
      final debugOtp = result['debugOtp']?.toString();
      _message = (kDebugMode && debugOtp != null && debugOtp.isNotEmpty)
          ? '$msg\n\n(DEBUG) OTP: $debugOtp'
          : msg;
      _messageType = result['success'] ? 'success' : 'error';
    });

    if (!result['success'] &&
        mounted &&
        (result['message']?.toString().toLowerCase().contains('not configured') ?? false)) {
      await Navigator.pushNamed(context, '/email-setup');
      if (!mounted) return;
      final retry = await OTPService.sendOTPToEmail(
        widget.email,
        title: '🔐 Account Verification',
        bodyText: 'To complete your verification, please use the OTP below:',
      );
      setState(() {
        _message = retry['message']?.toString() ?? _message;
        _messageType = retry['success'] ? 'success' : 'error';
      });
      if (retry['success']) return;
    }

    // Handle successful send
    if (result['success'] && mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PIN dispatched to ${widget.email}. Check Inbox/Spam.'),
            backgroundColor: const Color(0xFF6366F1),
            duration: const Duration(seconds: 4),
          ),
       );
    }

    // Start timer
    _updateTimer();
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.isEmpty) {
      setState(() {
        _message = 'Please enter the OTP';
        _messageType = 'error';
      });
      return;
    }

    if (_otpController.text.length != 6) {
      setState(() {
        _message = 'OTP must be 6 digits';
        _messageType = 'error';
      });
      return;
    }

    setState(() => _isLoading = true);

    final result = await OTPService.verifyOTP(widget.email, _otpController.text);

    setState(() => _isLoading = false);

    if (result['success']) {
      setState(() {
        _message = 'Email verified successfully!';
        _messageType = 'success';
      });

      // Show success animation
      await Future.delayed(const Duration(milliseconds: 500));
      widget.onSuccess();
    } else {
      setState(() {
        _message = result['message'] ?? 'Verification failed';
        _messageType = 'error';
      });
    }
  }

  Future<void> _resendOTP() async {
    setState(() => _isResending = true);

    final result = await OTPService.resendOTP(widget.email);

    setState(() => _isResending = false);

    setState(() {
      _message = result['message'] ?? 'OTP resent';
      _messageType = result['success'] ? 'success' : 'error';
      if (result['success']) {
        _otpController.clear();
        _updateTimer();
      }
    });

    // Success message is already shown via _message state
    if (result['success'] && mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(
           content: Text('Verification code resent successfully! 📧'),
           backgroundColor: Color(0xFF6366F1),
           duration: Duration(seconds: 4),
         ),
       );
    }
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _updateTimer();
        _startTimer();
      }
    });
  }

  Future<void> _updateTimer() async {
    final remaining = await OTPService.getRemainingTime();
    setState(() => _remainingTime = remaining);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        body: AnimatedLoadingWidget(
          message: 'Sending OTP to ${widget.email}...',
          type: LoadingType.pulse,
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text(
          'Verify Email',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        elevation: 0,
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: widget.onBack,
              )
            : null,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Header
              Text(
                'Enter OTP',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit code to ${widget.email}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'If you don’t receive it in 1–2 minutes, check Spam/Junk, then tap Resend.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: isDarkMode ? Colors.grey[500] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 32),

              // OTP Input
              _buildOTPInput(isDarkMode),
              const SizedBox(height: 24),

              // Message
              if (_message.isNotEmpty) _buildMessageBox(isDarkMode),
              if (_messageType == 'error' &&
                  _message.toLowerCase().contains('not configured'))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        await Navigator.pushNamed(context, '/email-setup');
                        if (!mounted) return;
                        await _sendOTP();
                      },
                      child: const Text('Setup Email & Send OTP'),
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Timer
              if (_remainingTime > 0)
                Center(
                  child: Text(
                    'Valid for $_remainingTime ${_remainingTime == 0 ? "0s" : ""}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: _remainingTime < 2
                          ? Colors.red
                          : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 32),

              // Verify Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _otpController.text.length == 6 ? _verifyOTP : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    disabledBackgroundColor: Colors.grey[400],
                  ),
                  child: Text(
                    'Verify OTP',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Resend Button
              if (_remainingTime == 0)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isResending ? null : _resendOTP,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF6366F1)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      _isResending ? 'Resending...' : 'Resend OTP',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[400]!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Resend OTP',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOTPInput(bool isDarkMode) {
    return TextField(
      controller: _otpController,
      maxLength: 6,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        letterSpacing: 8,
        color: isDarkMode ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: '000000',
        hintStyle: GoogleFonts.poppins(
          color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF6366F1),
            width: 2,
          ),
        ),
        filled: true,
        fillColor: isDarkMode ? Colors.grey[900] : Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
      ),
      onChanged: (value) {
        setState(() {});
      },
    );
  }

  Widget _buildMessageBox(bool isDarkMode) {
    final Color boxColor;
    final IconData icon;

    if (_messageType == 'success') {
      boxColor = const Color(0xFF10B981).withValues(alpha: 0.1);
      icon = Icons.check_circle_rounded;
    } else {
      boxColor = const Color(0xFFEF4444).withValues(alpha: 0.1);
      icon = Icons.error_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: boxColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _messageType == 'success'
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : const Color(0xFFEF4444).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: _messageType == 'success'
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _message,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: _messageType == 'success'
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

