import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Privacy Policy',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('Why we read your SMS',
              'We read SMS messages ONLY to detect payment '
              'notifications from your bank (UPI/NEFT/IMPS). '
              'We never read personal messages. Detection '
              'happens entirely on your device — messages '
              'are never uploaded to our servers.'),
            _section('Why we use Notification Access',
              'We listen for payment notifications from '
              'GPay, PhonePe, Paytm to auto-confirm sales. '
              'We never read notifications from other apps.'),
            _section('Why we use Accessibility Service',
              'Only used as a fallback for payment detection '
              'when SMS is unavailable. We never capture '
              'passwords, OTPs, or personal data.'),
            _section('Your data rights',
              'You can export all your data anytime from '
              'Settings → Export Data. You can delete your '
              'account and all data from Settings → '
              'Delete Account.'),
            _section('Contact',
              'Questions? Email us at privacy@yourapp.com'),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.poppins(
            fontSize: 15, fontWeight: FontWeight.w700,
            color: const Color(0xFF111827))),
          const SizedBox(height: 6),
          Text(body, style: GoogleFonts.poppins(
            fontSize: 13, height: 1.7,
            color: const Color(0xFF4B5563))),
        ],
      ),
    );
  }
}
