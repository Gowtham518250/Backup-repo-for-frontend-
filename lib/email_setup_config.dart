import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode, debugPrint;
import 'email_sender_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'email_secrets_defaults.dart';

// Frontend-only OTP: credentials from dart-define, Email Setup UI, or safe defaults.

/// Seeds Gmail SMTP credentials on app start (same idea as your old working build).
Future<void> setupEmailCredentialsOnce() async {
  if (await EmailSenderService.isConfigured()) {
    if (kDebugMode) debugPrint('✅ Email sender already configured');
    return;
  }

  var senderEmail = const String.fromEnvironment('EMAIL_SENDER', defaultValue: '');
  var appPassword = const String.fromEnvironment('EMAIL_APP_PASSWORD', defaultValue: '');

  // Never load disk secrets in release builds — use dart-define or in-app setup only.
  if (!kReleaseMode) {
    if (senderEmail.isEmpty) senderEmail = emailSecretsSender.trim();
    if (appPassword.isEmpty) {
      appPassword = emailSecretsAppPassword.replaceAll(RegExp(r'\s+'), '');
    }
  }

  if (senderEmail.isEmpty || appPassword.isEmpty) {
    if (kDebugMode) {
      debugPrint('⚠️ Email not seeded: use dart-define (EMAIL_SENDER, EMAIL_APP_PASSWORD)');
      debugPrint('   Or open /email-setup in the app after launch.');
    }
    return;
  }

  final ok = await EmailSenderService.setCredentials(
    email: senderEmail,
    password: appPassword,
  );

  if (kDebugMode) {
    debugPrint(ok ? '✅ Email credentials seeded for frontend OTP' : '❌ Failed to seed email credentials');
  }
}

/// Show secure setup dialog for manual credential entry (OnBoarding UI)
/// SECURITY: Credentials entered here are stored in SecureStorage only
/// They are NEVER logged, printed, or saved to files
Future<bool> setupEmailCredentialsUI(BuildContext context) async {
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  bool accepted = false;
  
  await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('🔐 Email Credentials (Secure Setup)'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '⚠️  Security Notice:\n'
              '• Use Gmail App Password (not your regular password)\n'
              '• Enable 2FA on Google Account first\n'
              '• Credentials stored encrypted, never logged\n'
              '• Never share this dialog screenshot',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Gmail Address',
                hintText: 'admin@company.com',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Gmail App Password',
                hintText: '16-character app password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (emailCtrl.text.isNotEmpty && passwordCtrl.text.isNotEmpty) {
              accepted = true;
              Navigator.pop(ctx, true);
            }
          },
          child: const Text('Save Securely'),
        ),
      ],
    ),
  );
  
  if (!accepted) return false;

  final ok = await EmailSenderService.setCredentials(
    email: emailCtrl.text,
    password: passwordCtrl.text,
  );

  if (kDebugMode) {
    print(ok ? '✅ Email credentials saved' : '❌ Email credentials save failed');
  }

  emailCtrl.dispose();
  passwordCtrl.dispose();

  return ok;
}

/// Test if email credentials are working
Future<bool> testEmailCredentials() async {
  try {
    if (kDebugMode) print('🧪 Testing email credentials...');
    
    const _secureStorage = FlutterSecureStorage();
    final email = await _secureStorage.read(key: 'sender_email');
    final password = await _secureStorage.read(key: 'app_password');
    
    if (email == null || password == null) {
      if (kDebugMode) print('❌ Email credentials not configured yet');
      return false;
    }
    
    if (kDebugMode) print('✓ Credentials found: $email');
    
    // Try sending a test email
    final sent = await EmailSenderService.sendOTPEmail(
      recipientEmail: email,
      otp: '123456',
      userName: 'Test User',
    );
    
    if (sent) {
      if (kDebugMode) print('✅ Test email sent successfully!');
      return true;
    } else {
      if (kDebugMode) print('❌ Test email failed to send');
      return false;
    }
  } catch (e) {
    if (kDebugMode) print('❌ Test failed: $e');
    return false;
  }
}

/// Widget to show setup status and test button
class EmailSetupWidget extends StatefulWidget {
  @override
  State<EmailSetupWidget> createState() => _EmailSetupWidgetState();
}

class _EmailSetupWidgetState extends State<EmailSetupWidget> {
  bool _loading = true;
  bool _hasCredentials = false;
  bool _isTesting = false;
  bool _testPassed = false;
  String _testMessage = '';
  
  @override
  void initState() {
    super.initState();
    _checkConfiguration();
  }
  
  Future<void> _checkConfiguration() async {
    await EmailSenderService.initialize();
    final hasCreds = await EmailSenderService.isConfigured();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _hasCredentials = hasCreds;
    });
  }
  
  Future<void> _runTest() async {
    setState(() {
      _isTesting = true;
      _testMessage = 'Testing email credentials...';
    });
    
    final result = await testEmailCredentials();
    
    setState(() {
      _isTesting = false;
      _testPassed = result;
      _testMessage = result 
        ? '✅ Email credentials working!' 
        : '❌ Email test failed. Check logs.';
    });
  }
  
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasCredentials) {
      return Text(
        'No credentials saved yet. Fill the form above and tap Save.',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
      );
    }
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _testPassed ? Colors.green.shade50 : Colors.yellow.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _testPassed ? Colors.green : Colors.orange,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                _testPassed ? Icons.check_circle : Icons.info,
                color: _testPassed ? Colors.green : Colors.orange,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _testPassed ? '✅ Email Service Ready' : '⚠️ Email Service Status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _testPassed ? Colors.green.shade700 : Colors.orange.shade700,
                      ),
                    ),
                    Text(
                      _testPassed 
                        ? 'OTP emails will send automatically'
                        : 'Click Test to verify email configuration',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_testMessage.isNotEmpty) ...[
            SizedBox(height: 12),
            Text(
              _testMessage,
              style: TextStyle(
                fontSize: 12,
                color: _testPassed ? Colors.green.shade700 : Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isTesting ? null : _runTest,
            icon: _isTesting 
              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(Icons.mail),
            label: Text(_isTesting ? 'Testing...' : 'Test Email Credentials'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _testPassed ? Colors.green : Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
