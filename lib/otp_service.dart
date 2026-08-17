import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import 'email_sender_service.dart';

/// Frontend-owned OTP generation, Gmail delivery and local verification.
///
/// The backend is used only after the user has locally verified the OTP to
/// obtain a short-lived, one-time password-reset authorization token.
class OTPService {
  static const _storage = FlutterSecureStorage();

  static const _kEmail = 'password_reset_email';
  static const _kOtpHash = 'password_reset_otp_hash';
  static const _kOtpCreatedAt = 'password_reset_otp_created_at';
  static const _kChallengeId = 'password_reset_challenge_id';
  static const _kRegistrationSecret = 'password_reset_registration_secret';
  static const _kResetToken = 'password_reset_reset_token';
  static const _kAttempts = 'password_reset_otp_attempts';

  // Owner verification OTP is intentionally independent from password reset.
  // It is generated, emailed, and verified locally on the device.
  static const _kOwnerEmail = 'owner_verification_email';
  static const _kOwnerOtpHash = 'owner_verification_otp_hash';
  static const _kOwnerOtpCreatedAt = 'owner_verification_otp_created_at';
  static const _kOwnerAttempts = 'owner_verification_otp_attempts';

  static const Duration _otpValidity = Duration(minutes: 10);
  static const int _maxLocalAttempts = 5;

  static String _generateSecureOTP() {
    return (Random.secure().nextInt(900000) + 100000).toString();
  }

  static String _hashOtp(String otp) {
    return sha256.convert(utf8.encode(otp)).toString();
  }

  static Future<void> _clearOtpOnly() async {
    await _storage.delete(key: _kOtpHash);
    await _storage.delete(key: _kOtpCreatedAt);
    await _storage.delete(key: _kAttempts);
  }

  static Future<void> clearResetState() async {
    for (final key in const [
      _kEmail,
      _kOtpHash,
      _kOtpCreatedAt,
      _kChallengeId,
      _kRegistrationSecret,
      _kResetToken,
      _kAttempts,
    ]) {
      await _storage.delete(key: key);
    }
  }

  static Future<void> _clearOwnerVerificationState() async {
    for (final key in const [
      _kOwnerEmail,
      _kOwnerOtpHash,
      _kOwnerOtpCreatedAt,
      _kOwnerAttempts,
    ]) {
      await _storage.delete(key: key);
    }
  }

  /// Owner identity verification only.
  ///
  /// This path intentionally does NOT call any password-reset or backend OTP
  /// endpoint. The app generates the code locally and sends it through the
  /// configured Gmail SMTP sender.
  static Future<Map<String, dynamic>> sendOwnerVerificationOTP(
    String email, {
    String? title,
    String? bodyText,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      return {'success': false, 'message': 'Email is required'};
    }

    try {
      await _clearOwnerVerificationState();

      final otp = _generateSecureOTP();
      final otpHash = _hashOtp(otp);
      final createdAt = DateTime.now().millisecondsSinceEpoch;

      await _storage.write(key: _kOwnerEmail, value: normalizedEmail);
      await _storage.write(key: _kOwnerOtpHash, value: otpHash);
      await _storage.write(
        key: _kOwnerOtpCreatedAt,
        value: createdAt.toString(),
      );
      await _storage.write(key: _kOwnerAttempts, value: '0');

      final emailSent = await EmailSenderService.sendOTPEmail(
        recipientEmail: normalizedEmail,
        otp: otp,
        userName: 'Owner',
        title: title ?? '🔐 Retail Mind Owner Verification',
        bodyText: bodyText ??
            'Use this 6-digit OTP to verify that you are the Retail Mind shop owner.',
      );

      if (!emailSent) {
        await _clearOwnerVerificationState();
        return {
          'success': false,
          'message':
              'Failed to send verification OTP. Check the Gmail SMTP credentials configured for the app.',
        };
      }

      if (kDebugMode) {
        debugPrint('✅ Owner verification OTP sent to $normalizedEmail');
      }

      return {
        'success': true,
        'message': 'Verification OTP sent. Check your email inbox and spam folder.',
      };
    } catch (e) {
      await _clearOwnerVerificationState();
      if (kDebugMode) {
        debugPrint('❌ Owner verification OTP send failed: $e');
      }
      return {
        'success': false,
        'message': 'Failed to send owner verification OTP: $e',
      };
    }
  }

  /// Verify the locally stored owner-verification OTP.
  /// No backend call is made on the owner verification path.
  static Future<Map<String, dynamic>> verifyOwnerVerificationOTP(
    String email,
    String enteredOTP,
  ) async {
    final normalizedEmail = email.trim().toLowerCase();
    final code = enteredOTP.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      return {'success': false, 'message': 'OTP must be 6 digits'};
    }

    final storedEmail = await _storage.read(key: _kOwnerEmail);
    final storedHash = await _storage.read(key: _kOwnerOtpHash);
    final createdAtRaw = await _storage.read(key: _kOwnerOtpCreatedAt);
    final attemptsRaw = await _storage.read(key: _kOwnerAttempts);

    if (storedEmail == null || storedHash == null || createdAtRaw == null) {
      return {
        'success': false,
        'message': 'No owner verification OTP pending. Request a new code.',
      };
    }

    if (storedEmail != normalizedEmail) {
      return {
        'success': false,
        'message': 'The verification OTP belongs to a different email address.',
      };
    }

    final createdAt = int.tryParse(createdAtRaw);
    if (createdAt == null) {
      await _clearOwnerVerificationState();
      return {
        'success': false,
        'message': 'Owner verification state is invalid. Request a new code.',
      };
    }

    if (DateTime.now().millisecondsSinceEpoch - createdAt >
        _otpValidity.inMilliseconds) {
      await _clearOwnerVerificationState();
      return {
        'success': false,
        'message': 'Owner verification OTP expired. Request a new code.',
      };
    }

    final attempts = int.tryParse(attemptsRaw ?? '0') ?? 0;
    if (attempts >= _maxLocalAttempts) {
      await _clearOwnerVerificationState();
      return {
        'success': false,
        'message':
            'Too many verification attempts. Request a new owner OTP.',
      };
    }

    final enteredHash = _hashOtp(code);
    if (!_constantTimeEquals(storedHash, enteredHash)) {
      await _storage.write(
        key: _kOwnerAttempts,
        value: '${attempts + 1}',
      );
      final left = _maxLocalAttempts - attempts - 1;
      return {
        'success': false,
        'message': left > 0
            ? 'Invalid verification OTP. $left attempt(s) remaining.'
            : 'Invalid verification OTP. Request a new code.',
      };
    }

    await _clearOwnerVerificationState();

    return {
      'success': true,
      'message': 'Owner identity verified successfully.',
    };
  }

  static Future<Map<String, dynamic>> sendOTPToEmail(
    String email, {
    String? title,
    String? bodyText,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      return {'success': false, 'message': 'Email is required'};
    }

    try {
      await clearResetState();

      final otp = _generateSecureOTP();
      final otpHash = _hashOtp(otp);
      final createdAt = DateTime.now().millisecondsSinceEpoch;

      // Frontend owns OTP generation, local verification and email delivery.
      await _storage.write(key: _kEmail, value: normalizedEmail);
      await _storage.write(key: _kOtpHash, value: otpHash);
      await _storage.write(key: _kOtpCreatedAt, value: createdAt.toString());
      await _storage.write(key: _kAttempts, value: '0');

      // Backend stores only the reset OTP proof needed for the final password
      // change. It no longer starts the OTP flow.
      final registerResponse = await ApiClient.postJson(
        '/auth/store-reset-otp',
        {
          'email': normalizedEmail,
          'otp': otp,
        },
      );

      if (registerResponse.statusCode < 200 ||
          registerResponse.statusCode >= 300) {
        await clearResetState();
        return {
          'success': false,
          'message':
              'Unable to prepare the password reset. Please try again.',
        };
      }

      final emailSent = await EmailSenderService.sendOTPEmail(
        recipientEmail: normalizedEmail,
        otp: otp,
        userName: 'Owner',
        title: title ?? '🔐 Password Reset',
        bodyText: bodyText ??
            'Use the 6-digit OTP below to reset your Retail Mind owner password.',
      );

      if (!emailSent) {
        await clearResetState();
        return {
          'success': false,
          'message':
              'Failed to send OTP email. Please check the email service and try again.',
        };
      }

      return {
        'success': true,
        'message': 'OTP sent. Check your email inbox and spam folder.',
      };
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Password-reset OTP send failed: $e');
      return {
        'success': false,
        'message': 'Failed to send OTP: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> verifyOTP(
    String email,
    String enteredOTP,
  ) async {
    final normalizedEmail = email.trim().toLowerCase();
    final code = enteredOTP.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      return {'success': false, 'message': 'OTP must be 6 digits'};
    }

    final storedEmail = await _storage.read(key: _kEmail);
    final storedHash = await _storage.read(key: _kOtpHash);
    final createdAtRaw = await _storage.read(key: _kOtpCreatedAt);
    final attemptsRaw = await _storage.read(key: _kAttempts);

    if (storedEmail == null || storedHash == null || createdAtRaw == null) {
      return {'success': false, 'message': 'No OTP pending. Request a new code.'};
    }

    if (storedEmail != normalizedEmail) {
      return {
        'success': false,
        'message': 'The OTP belongs to a different email address.',
      };
    }

    final createdAt = int.tryParse(createdAtRaw);
    if (createdAt == null) {
      await clearResetState();
      return {'success': false, 'message': 'Reset verification state is invalid.'};
    }

    if (DateTime.now().millisecondsSinceEpoch - createdAt >
        _otpValidity.inMilliseconds) {
      await clearResetState();
      return {'success': false, 'message': 'OTP expired. Request a new code.'};
    }

    final attempts = int.tryParse(attemptsRaw ?? '0') ?? 0;
    if (attempts >= _maxLocalAttempts) {
      await clearResetState();
      return {
        'success': false,
        'message': 'Too many OTP attempts. Request a new code.',
      };
    }

    final enteredHash = _hashOtp(code);
    if (!_constantTimeEquals(storedHash, enteredHash)) {
      await _storage.write(key: _kAttempts, value: '${attempts + 1}');
      final left = _maxLocalAttempts - attempts - 1;
      return {
        'success': false,
        'message': left > 0
            ? 'Invalid OTP. $left attempt(s) remaining.'
            : 'Invalid OTP. Request a new code.',
      };
    }

    return {
      'success': true,
      'message': 'OTP verified successfully.',
    };
  }

  static Future<bool> _hasStoredResetToken() async {
    final token = await _storage.read(key: _kResetToken);
    return token != null && token.isNotEmpty;
  }

  static Future<String?> getResetToken() async {
    return _storage.read(key: _kResetToken);
  }

  static Future<Map<String, dynamic>> resendOTP(String email) async {
    return sendOTPToEmail(
      email,
      title: '🔄 Retail Mind Password Reset',
      bodyText: 'A new password-reset code was requested. Use the OTP below and confirm the secure email link.',
    );
  }

  static Future<int> getRemainingTime() async {
    final createdAtRaw = await _storage.read(key: _kOtpCreatedAt);
    if (createdAtRaw == null) return 0;
    final createdAt = int.tryParse(createdAtRaw);
    if (createdAt == null) return 0;
    final remaining = _otpValidity - Duration(milliseconds: DateTime.now().millisecondsSinceEpoch - createdAt);
    return remaining.isNegative ? 0 : remaining.inSeconds;
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

