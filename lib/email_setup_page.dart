import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:google_fonts/google_fonts.dart';
import 'email_sender_service.dart';
import 'email_setup_config.dart';

/// Configure Gmail sender for frontend-only OTP delivery.
class EmailSetupPage extends StatefulWidget {
  const EmailSetupPage({super.key});

  @override
  State<EmailSetupPage> createState() => _EmailSetupPageState();
}

class _EmailSetupPageState extends State<EmailSetupPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool _configured = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    await EmailSenderService.initialize();
    final email = await EmailSenderService.getSenderEmail();
    setState(() {
      _configured = email != null && email.isNotEmpty;
      if (_configured) _emailCtrl.text = email!;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.replaceAll(RegExp(r'\s+'), '');

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _statusMessage = 'Enter a valid Gmail address.');
      return;
    }
    if (password.length < 8) {
      setState(() => _statusMessage = 'Enter your 16-character Gmail App Password (spaces are OK).');
      return;
    }

    setState(() {
      _saving = true;
      _statusMessage = null;
    });

    final ok = await EmailSenderService.setCredentials(email: email, password: password);
    if (!mounted) return;

    setState(() {
      _saving = false;
      _configured = ok;
      _statusMessage = ok
          ? 'Saved. Tap "Send test OTP email" to confirm delivery.'
          : 'Could not save credentials on this device. Try again or restart the app.';
    });

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email saved for $email'), backgroundColor: const Color(0xFF10B981)),
      );
    }
  }

  Future<void> _test() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _statusMessage = 'Save sender email first.');
      return;
    }

    setState(() {
      _testing = true;
      _statusMessage = 'Sending test email…';
    });

    final result = await EmailSenderService.testEmailConfiguration(recipientEmail: email);
    if (!mounted) return;

    setState(() {
      _testing = false;
      if (result['success'] == true) {
        _statusMessage = '✅ Test email sent successfully to $email. Check Inbox and Spam folders.';
      } else {
        _statusMessage = '❌ Test failed: ${result['message']}';
        if (result['troubleshooting'] != null) {
          _statusMessage = (_statusMessage ?? '') + '\n💡 ${result['troubleshooting']}';
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Email setup', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _configured ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _configured ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                ),
              ),
              child: Text(
                _configured
                    ? 'Sender is configured. OTP emails are sent from this device (no backend).'
                    : 'OTP is sent from THIS app using Gmail SMTP. You must set sender email + App Password once.',
                style: GoogleFonts.poppins(fontSize: 13, height: 1.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'How to get Gmail App Password',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              '1. Google Account → Security → 2-Step Verification ON\n'
              '2. App passwords → Mail → Other → copy 16-character password\n'
              '3. Paste below (with or without spaces)',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700], height: 1.5),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Sender Gmail',
                hintText: 'yourshop@gmail.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Gmail App Password',
                hintText: 'xxxx xxxx xxxx xxxx',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _statusMessage!,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: _statusMessage!.startsWith('Test email sent') || _statusMessage!.startsWith('Saved')
                      ? const Color(0xFF10B981)
                      : const Color(0xFFDC2626),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFF6366F1),
              ),
              child: Text(
                _saving ? 'Saving…' : 'Save credentials',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _testing || !_configured ? null : _test,
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(
                _testing ? 'Sending test…' : 'Send test OTP email',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 24),
            EmailSetupWidget(),
          ],
        ),
      ),
    );
  }
}
