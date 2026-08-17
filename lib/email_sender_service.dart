import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'email_secrets_defaults.dart';

/// Frontend Gmail SMTP service used by the working owner-authentication flow.
class EmailSenderService {
  static const _secureStorage = FlutterSecureStorage(
    wOptions: WindowsOptions(useBackwardCompatibility: true),
  );

  static const _kSenderEmail = 'sender_email';
  static const _kAppPassword = 'app_password';

  static String _senderEmail = '';
  static String _appPassword = '';

  static String _fallbackSender() =>
      emailSecretsSender.trim().isNotEmpty ? emailSecretsSender.trim() : '';

  static String _fallbackPassword() =>
      emailSecretsAppPassword.replaceAll(RegExp(r'\s+'), '');

  static Future<void> _loadCredentials() async {
    _senderEmail =
        (await _secureStorage.read(key: _kSenderEmail)) ?? _fallbackSender();
    _appPassword =
        (await _secureStorage.read(key: _kAppPassword)) ?? _fallbackPassword();
  }

  static Future<void> initialize() async {
    try {
      await _loadCredentials();
      if (kDebugMode) {
        if (_senderEmail.isNotEmpty && _appPassword.isNotEmpty) {
          debugPrint('✅ Email service initialized');
          debugPrint('   📧 Sender: $_senderEmail');
        } else {
          debugPrint(
            '⚠️ Email credentials missing — configure sender email + Gmail App Password.',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error loading email credentials: $e');
    }
  }

  static Future<bool> isConfigured() async {
    await initialize();
    return _senderEmail.isNotEmpty && _appPassword.isNotEmpty;
  }

  static Future<String?> getSenderEmail() async {
    await _loadCredentials();
    return _senderEmail.isEmpty ? null : _senderEmail;
  }

  static Future<bool> setCredentials({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password.replaceAll(RegExp(r'\s+'), '');
    if (normalizedEmail.isEmpty || normalizedPassword.isEmpty) return false;

    try {
      await _secureStorage.write(key: _kSenderEmail, value: normalizedEmail);
      await _secureStorage.write(key: _kAppPassword, value: normalizedPassword);
      _senderEmail = normalizedEmail;
      _appPassword = normalizedPassword;
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error storing credentials: $e');
      return false;
    }
  }

  static String _safeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  static Future<bool> sendOTPEmail({
    required String recipientEmail,
    required String otp,
    required String userName,
    String title = '🔐 Password Reset',
    String bodyText = 'You requested to reset your password. Use the OTP below:',
    String? confirmationUrl,
  }) async {
    final email =
        (await _secureStorage.read(key: _kSenderEmail)) ?? _fallbackSender();
    final password =
        (await _secureStorage.read(key: _kAppPassword)) ?? _fallbackPassword();

    if (email.isEmpty || password.isEmpty) {
      if (kDebugMode) debugPrint('❌ Email credentials not configured.');
      return false;
    }

    _senderEmail = email;
    _appPassword = password;

    try {
      final smtpServer = gmail(_senderEmail, _appPassword);
      final safeName = _safeHtml(userName);
      final safeTitle = _safeHtml(title);
      final safeBody = _safeHtml(bodyText);
      final safeOtp = _safeHtml(otp);

      final confirmationSection = (confirmationUrl == null || confirmationUrl.isEmpty)
          ? ''
          : '''
      <div style="margin:24px 0;padding:18px;background:#ECFDF5;border:1px solid #A7F3D0;border-radius:10px;">
        <p style="color:#065F46;font-size:13px;font-weight:700;margin:0 0 10px;">Confirm your email</p>
        <p style="color:#047857;font-size:12px;line-height:1.5;margin:0 0 12px;">Open this secure link to confirm mailbox access before the password can be changed.</p>
        <a href="${_safeHtml(confirmationUrl)}" style="display:inline-block;background:#10B981;color:#fff;text-decoration:none;padding:11px 16px;border-radius:8px;font-weight:700;font-size:13px;">CONFIRM EMAIL</a>
      </div>''';

      final htmlBody = '''<html>
  <body style="font-family:Arial,sans-serif;background:#f5f5f5;padding:20px;">
    <div style="max-width:520px;margin:0 auto;background:#fff;padding:30px;border-radius:12px;box-shadow:0 2px 10px rgba(0,0,0,.08);">
      <h2 style="color:#111827;text-align:center;">$safeTitle</h2>
      <p style="color:#374151;font-size:15px;">Hi $safeName,</p>
      <p style="color:#4B5563;font-size:14px;line-height:1.6;">$safeBody</p>
      <div style="background:#6366F1;color:#fff;padding:20px;text-align:center;border-radius:8px;margin:20px 0;">
        <p style="font-size:28px;font-weight:800;letter-spacing:5px;margin:0;">$safeOtp</p>
      </div>
      $confirmationSection
      <p style="color:#6B7280;font-size:12px;">⏱️ The OTP and confirmation link expire in 10 minutes.</p>
      <p style="color:#6B7280;font-size:12px;">If you did not request this, ignore this email.</p>
      <hr style="border:none;border-top:1px solid #E5E7EB;margin:20px 0;">
      <p style="color:#9CA3AF;font-size:11px;text-align:center;">© 2026 Retail Mind</p>
    </div>
  </body>
</html>''';

      final message = Message()
        ..from = Address(_senderEmail, 'Retail Mind')
        ..recipients.add(recipientEmail)
        ..subject = '$title OTP'
        ..html = htmlBody;

      await send(message, smtpServer);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Email sending failed: $e');
      return false;
    }
  }

  static Future<bool> sendStockAlertEmail({
    required String recipientEmail,
    required String productName,
    required int currentStock,
    required int minStock,
  }) async {
    final email =
        (await _secureStorage.read(key: _kSenderEmail)) ?? _fallbackSender();
    final password =
        (await _secureStorage.read(key: _kAppPassword)) ?? _fallbackPassword();
    if (email.isEmpty || password.isEmpty) return false;

    try {
      final smtpServer = gmail(email, password);
      final htmlBody = '''<html><body style="font-family:Arial;background:#f5f5f5;padding:20px;">
<div style="max-width:500px;margin:auto;background:white;padding:30px;border-radius:8px;">
<h2 style="color:#FF6B35;text-align:center;">⚠️ Low Stock Alert</h2>
<p>Product <strong>${_safeHtml(productName)}</strong>: $currentStock left (min $minStock)</p>
</div></body></html>''';
      final message = Message()
        ..from = Address(email, 'Retail Mind Inventory')
        ..recipients.add(recipientEmail)
        ..subject = '⚠️ Low Stock Alert: $productName'
        ..html = htmlBody;
      await send(message, smtpServer);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Stock alert email failed: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> testEmailConfiguration({
    required String recipientEmail,
  }) async {
    await initialize();
    if (_senderEmail.isEmpty || _appPassword.isEmpty) {
      return {
        'success': false,
        'message': 'Email credentials are not configured.',
      };
    }

    try {
      final smtpServer = gmail(_senderEmail, _appPassword);
      final message = Message()
        ..from = Address(_senderEmail, 'Retail Mind Test')
        ..recipients.add(recipientEmail)
        ..subject = '✅ Retail Mind Email Configuration Test'
        ..html = '<p>Your Retail Mind Gmail SMTP configuration is working.</p>';
      final sendReport = await send(message, smtpServer);
      return {
        'success': true,
        'message': 'Test email sent successfully to $recipientEmail',
        'details': sendReport.toString(),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to send test email: $e',
      };
    }
  }
}
