import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:flutter/services.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: Text('Terms of Service', style: GoogleFonts.poppins(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('1. Acceptance of Terms', '''
By downloading, accessing, or using the Retail Mind application, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use our application.

Retail Mind reserves the right to modify these terms at any time. Your continued use of the application after such modifications constitutes your acceptance of the updated terms.
'''),
            _buildSection('2. Description of Service', '''
Retail Mind is a comprehensive Point of Sale (POS) and business management application designed for retail businesses. The application provides features including:

- Sales and invoice management
- Inventory tracking and management
- Customer relationship management
- Employee attendance and payroll
- Business analytics and reporting
- Online store integration
- Payment processing and tracking

The service is provided "as is" without warranties of any kind.
'''),
            _buildSection('3. User Responsibilities', '''
As a user of Retail Mind, you agree to:

- Provide accurate and complete information during registration
- Maintain the security of your account credentials
- Use the application only for legitimate business purposes
- Comply with all applicable laws and regulations
- Not attempt to reverse engineer, hack, or exploit the application
- Report any security vulnerabilities or bugs promptly
'''),
            _buildSection('4. Data and Privacy', '''
Your privacy is important to us. Please refer to our Privacy Policy for detailed information about how we collect, use, and protect your data.

Key points:
- We collect data necessary to provide our services
- We implement industry-standard security measures
- We do not sell your personal data to third parties
- You can request data deletion at any time
- We use data to improve our services and prevent fraud
'''),
            _buildSection('5. Intellectual Property', '''
Retail Mind and its original content, features, and functionality are owned by Retail Mind and are protected by international copyright, trademark, and other intellectual property laws.

You may not:
- Copy, modify, or distribute the application
- Use the application for competitive purposes
- Remove or alter any proprietary notices
'''),
            _buildSection('6. Payment and Subscription', '''
Certain features of Retail Mind may require payment or subscription. You agree to:

- Provide accurate payment information
- Pay all applicable fees and charges
- Understand that subscription fees are non-refundable unless otherwise stated
- Cancel subscriptions before the next billing cycle to avoid charges
'''),
            _buildSection('7. Limitation of Liability', '''
Retail Mind shall not be liable for any indirect, incidental, special, or consequential damages resulting from:

- Use or inability to use the service
- Unauthorized access to your account
- Data loss or corruption
- Business interruption

Our total liability shall not exceed the amount you paid for the service in the past 12 months.
'''),
            _buildSection('8. Termination', '''
Retail Mind reserves the right to:

- Suspend or terminate your account for violation of these terms
- Discontinue the service with or without notice
- Modify or discontinue features at any time

Upon termination, your right to use the service will immediately cease.
'''),
            _buildSection('9. Governing Law', '''
These terms shall be governed by and construed in accordance with the laws of India. Any disputes arising under these terms shall be subject to the exclusive jurisdiction of the courts in India.
'''),
            _buildSection('10. Contact Information', '''
For questions about these Terms of Service, please contact:

Email: support@retailmind.com
Address: [Your Business Address]
Phone: [Your Business Phone Number]

Last Updated: ${DateTime.now().year}
'''),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: Text('I Accept', style: GoogleFonts.poppins(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          content,
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 25),
      ],
    );
  }
}