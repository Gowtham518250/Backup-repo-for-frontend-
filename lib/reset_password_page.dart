import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'app_localizations.dart';
import 'dart:convert';
import 'email_sender_service.dart';
import 'otp_service.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool isLoading = false;
  bool otpSent = false;
  bool showPassword = false;
  String errorMessage = '';
  String successMessage = '';

  @override
  void dispose() {
    emailController.dispose();
    otpController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  /// Step 1: Request password reset OTP to email.
  /// Uses the hardened password-reset challenge, while OTP delivery itself
  /// remains frontend-owned through the configured Gmail SMTP sender.
  Future<void> sendResetOTP() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      setState(() => errorMessage = 'Please enter email');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
      successMessage = '';
    });

    try {
      final result = await OTPService.sendOTPToEmail(
        email,
        title: '🔐 Retail Mind Password Reset',
        bodyText:
            'Use the 6-digit OTP below to reset your Retail Mind owner password. '
            'Also confirm the secure email link before resetting the password.',
      );

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          otpSent = true;
          successMessage =
              result['message']?.toString() ??
              'OTP sent. Check your inbox and spam folder.';
        });
      } else {
        setState(() {
          errorMessage =
              result['message']?.toString() ?? 'Failed to send reset OTP.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => errorMessage = 'Failed to send reset OTP: $e');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  /// Step 2: Verify the password-reset OTP, obtain the one-time reset
  /// authorization token, and then use that token to change the password.
  Future<void> resetPassword() async {
    final email = emailController.text.trim();
    final otp = otpController.text.trim();
    final newPass = newPasswordController.text;
    final confirmPass = confirmPasswordController.text;

    if (email.isEmpty || otp.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      setState(() => errorMessage = 'All fields are required');
      return;
    }

    if (newPass != confirmPass) {
      setState(() => errorMessage = '❌ Passwords do not match');
      return;
    }

    if (newPass.length < 8 ||
        !RegExp(r'[A-Z]').hasMatch(newPass) ||
        !RegExp(r'[a-z]').hasMatch(newPass) ||
        !RegExp(r'\d').hasMatch(newPass)) {
      setState(() => errorMessage =
          'Password must be at least 8 characters and contain uppercase, lowercase, and a number.');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
      successMessage = '';
    });

    try {
      // Local OTP verification + hardened backend authorization.
      final verifyResult = await OTPService.verifyOTP(email, otp);

      if (!mounted) return;

      if (verifyResult['success'] != true) {
        setState(() {
          errorMessage =
              verifyResult['message']?.toString() ??
              'Invalid or expired OTP.';
        });
        return;
      }

      // OTP is generated and verified locally first. The backend then
      // performs the actual password write and re-validates the OTP.
      final response = await ApiClient.postJson(
        '/auth/verify-reset-otp',
        {
          'email': email,
          'otp': otp,
          'password': newPass,
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        await OTPService.clearResetState();

        setState(() {
          successMessage =
              '✅ Password reset successful! Redirecting to login...';
        });

        await Future.delayed(const Duration(seconds: 1));

        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
        }
      } else {
        Map<String, dynamic> data = {};
        try {
          final decoded = json.decode(response.body);
          if (decoded is Map<String, dynamic>) {
            data = decoded;
          }
        } catch (_) {}

        setState(() {
          errorMessage =
              data['detail']?.toString() ??
              'Password reset failed. Please request a new OTP.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => errorMessage = '❌ Password reset failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            const SizedBox(height: 20),
            Text(
              'Forgot Password?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your email to receive a password reset code',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Error Message
            if (errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),

            // Success Message
            if (successMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.green),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    successMessage,
                    style: const TextStyle(color: Colors.green),
                  ),
                ),
              ),

            // Step 1: Email Input
            if (!otpSent) ...[
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabled: !isLoading,
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: isLoading ? null : sendResetOTP,
                icon: const Icon(Icons.send),
                label: isLoading ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ) : const Text('Send Reset Code'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],

            // Step 2: OTP & Password Reset
            if (otpSent) ...[
              // Email display (read-only)
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabled: false,
                ),
                readOnly: true,
              ),
              const SizedBox(height: 16),

              // OTP Input
              TextField(
                controller: otpController,
                decoration: InputDecoration(
                  labelText: 'Enter Reset Code (OTP)',
                  prefixIcon: const Icon(Icons.code),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabled: !isLoading,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // New Password
              TextField(
                controller: newPasswordController,
                obscureText: !showPassword,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(showPassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => showPassword = !showPassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabled: !isLoading,
                ),
              ),
              const SizedBox(height: 16),

              // Confirm Password
              TextField(
                controller: confirmPasswordController,
                obscureText: !showPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(showPassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => showPassword = !showPassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabled: !isLoading,
                ),
              ),
              const SizedBox(height: 24),

              // Reset Button
              ElevatedButton.icon(
                onPressed: isLoading ? null : resetPassword,
                icon: isLoading ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ) : const Icon(Icons.check),
                label: const Text('Reset Password'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              // Request new OTP
              TextButton(
                onPressed: isLoading ? null : () => setState(() {
                  otpSent = false;
                  otpController.clear();
                  newPasswordController.clear();
                  confirmPasswordController.clear();
                  errorMessage = '';
                  successMessage = '';
                }),
                child: const Text('Request a new code?'),
              ),
            ],

            const SizedBox(height: 32),

            // Back to Login
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to Login'),
            ),
          ],
        ),
      ),
    );
  }
}
