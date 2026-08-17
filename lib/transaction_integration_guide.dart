import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:google_fonts/google_fonts.dart';
import 'transaction_service.dart';
import 'sms_notification_reader_service.dart';

/// Transaction Integration Guide & Examples
/// 
/// This page explains how to use the transaction features:
/// 1. Manual transaction recording
/// 2. SMS parsing from bank/UPI notifications
/// 3. WhatsApp message parsing
/// 4. Transaction history viewing
///
/// Setup in pubspec.yaml:
/// ```yaml
/// sms_advanced: ^4.0.0              # For reading SMS
/// permission_handler: ^11.0.0        # For SMS permissions
/// ```
///
/// Setup in AndroidManifest.xml:
/// ```xml
/// <uses-permission android:name="android.permission.READ_SMS" />
/// <uses-permission android:name="android.permission.RECEIVE_SMS" />
/// ```

class TransactionIntegrationGuide extends StatefulWidget {
  const TransactionIntegrationGuide({super.key});

  @override
  State<TransactionIntegrationGuide> createState() => _TransactionIntegrationGuideState();
}

class _TransactionIntegrationGuideState extends State<TransactionIntegrationGuide> {
  static const Color _primary = Color(0xFF6366F1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Transaction Integration', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: _primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Integration Examples',
              [
                _buildCode('1. Parse Bank SMS', '''
// Bank SMS from ICICI Bank
String smsBody = "A/C xx1234 Debit ₹500 to SHOP MAIN - Ref: TXN123";
Transaction? txn = TransactionService.parseSmsBanking(smsBody);
if (txn != null) {
  await TransactionService.saveTransaction(txn);
}
'''),
                _buildCode('2. Parse UPI Notification', '''
// From Google Pay
String message = "₹500 transferred to 9876543210";
Transaction? txn = TransactionService.parseUpiNotification(
  message, 
  'GooglePay'
);
'''),
                _buildCode('3. Parse WhatsApp Message', '''
// From customer on WhatsApp
await SmsNotificationReaderService.parseWhatsAppMessage(
  "Hi, I sent you ₹1000 for your service",
  "Raj Kumar",
  "9876543210"
);
'''),
                _buildCode('4. Manual Transaction Recording', '''
// Create and save manually
final txn = Transaction(
  id: DateTime.now().millisecondsSinceEpoch.toString(),
  source: 'Manual',
  name: 'Rahul Singh',
  phone: '9876543210',
  amount: 2500,
  type: 'RECEIVED',
  createdAt: DateTime.now(),
);
await TransactionService.saveTransaction(txn);
'''),
              ],
            ),
            const SizedBox(height: 20),
            _buildSection(
              'Supported Formats',
              [
                _buildFormatItem('Bank SMS', 
                  '₹500 transferred | Debit ₹1000 | Credit ₹500\nRef: TXN123 | Ref: ABC789'),
                _buildFormatItem('Google Pay',
                  '₹500 transferred to 9876543210\n₹1000 received from Rahul'),
                _buildFormatItem('PhonePe/Paytm',
                  'Payment received from Shop - ₹2000\nYou sent ₹500 to 9876543210'),
                _buildFormatItem('WhatsApp',
                  'Sent you ₹1000 | Received ₹500\nPayment of ₹250 to your account'),
              ],
            ),
            const SizedBox(height: 20),
            _buildSection(
              'Transaction Fields',
              [
                _buildFieldItem('name', 'Customer or sender name (extracted or manual)'),
                _buildFieldItem('phone', '10-digit phone number (optional)'),
                _buildFieldItem('amount', 'Transaction amount in rupees'),
                _buildFieldItem('type', 'PAID, RECEIVED, or PENDING'),
                _buildFieldItem('source', 'Manual, SMS_BANK, UPI, GooglePay, PhonePe, WhatsApp'),
                _buildFieldItem('created_at', 'Transaction date/time'),
                _buildFieldItem('reference', 'Unique transaction ID from payment app'),
              ],
            ),
            const SizedBox(height: 20),
            _buildSection(
              'Features',
              [
                Text('Transaction history with filters (type, source, date)'),
                Text('Manual transaction recording form'),
                Text('Automatic SMS parsing from banks'),
                Text('UPI notification parsing'),
                Text('WhatsApp message parsing'),
                Text('Transaction details view'),
                Text('Export to sales/invoices'),
                Text('Duplicate detection by reference ID'),
                Text('Today/period totals calculation'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: _primary)),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildCode(String label, String code) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12, color: _primary)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              code,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatItem(String label, String formats) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            formats,
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldItem(String field, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              field,
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: _primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Usage Examples Section
class TransactionUsageExamples {
  /// Example 1: Load all transactions
  static Future<void> loadAllTransactions() async {
    final txns = await TransactionService.loadTransactions();
    if (kDebugMode) debugPrint('Total transactions: ${txns.length}');
    for (var txn in txns) {
      if (kDebugMode) debugPrint('${txn.name} - ₹${txn.amount} (${txn.type})');
    }
  }

  /// Example 2: Get today's total
  static Future<void> getTodayTotal() async {
    final total = await TransactionService.getTodayTotal();
    if (kDebugMode) debugPrint('Today total: ₹$total');
  }

  /// Example 3: Filter by type
  static Future<void> getReceivedTransactions() async {
    final txns = await TransactionService.loadTransactions();
    final received = txns.where((t) => t.type == 'RECEIVED').toList();
    if (kDebugMode) debugPrint('Received today: ${received.length} transactions');
  }

  /// Example 4: Delete transaction
  static Future<void> deleteTransaction(String id) async {
    await TransactionService.deleteTransaction(id);
    if (kDebugMode) debugPrint('Transaction deleted: $id');
  }

  /// Example 5: Parse SMS batch
  static Future<void> parseBankSms() async {
    final smsList = <Map<String, String>>[
      {
        'sender': 'ICICIBANK',
        'body': 'A/C xx1234 Debit ₹500 to SHOP MAIN - Ref: TXN123'
      },
      {
        'sender': 'SBIALERTS',
        'body': 'A/C xx5678 Credit ₹1000 from CUSTOMER - Ref: ABC789'
      },
    ];

    final txns = await SmsNotificationReaderService.parseMultipleSms(smsList);
    if (kDebugMode) debugPrint('Parsed ${txns.length} SMS transactions');
  }
}
