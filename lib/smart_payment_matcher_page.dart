import 'package:flutter/material.dart';
import 'payment_detection_system.dart';
import 'payment_confirmation_dialog.dart';
import 'smart_payment_matcher_service.dart';
import 'transaction_service.dart';

/// Demo page showing the smart payment matching system in action
/// - Simulates SMS/Notification reception
/// - Shows confidence scoring
/// - Handles conflicts (same amount at same time)
/// - Shows audit trail
class SmartPaymentMatcherPage extends StatefulWidget {
  const SmartPaymentMatcherPage({Key? key}) : super(key: key);

  @override
  State<SmartPaymentMatcherPage> createState() => _SmartPaymentMatcherPageState();
}

class _SmartPaymentMatcherPageState extends State<SmartPaymentMatcherPage> {
  late TransactionService _transactionService;
  List<Map<String, dynamic>> _auditTrail = [];
  Map<String, int> _stats = {
    'auto_confirmed': 0,
    'needs_confirmation': 0,
    'manual_review': 0,
    'total': 0,
  };

  @override
  void initState() {
    super.initState();
    _transactionService = TransactionService();
    _initializeSystem();
    _loadAuditTrail();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeSystem() async {
    await PaymentDetectionSystem.initialize(
      onPaymentDetected: (payment, confidence) {
        if (mounted) {
          _handlePaymentDetected(payment, confidence);
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
          );
        }
      },
    );
    _refreshStats();
  }

  Future<void> _loadAuditTrail() async {
    final trail = await SmartPaymentMatcherService.getMatchHistory(limit: 100);
    if (mounted) {
      setState(() => _auditTrail = trail);
    }
  }

  Future<void> _refreshStats() async {
    final stats = await SmartPaymentMatcherService.getConfirmationStats();
    if (mounted) {
      setState(() => _stats = stats);
    }
  }

  void _handlePaymentDetected(Transaction payment, PaymentConfidence confidence) {
    PaymentConfirmationDialog.show(
      context,
      payment,
      confidence,
      () => _onPaymentConfirmed(payment),
      () => _onPaymentDenied(payment),
    );
  }

  Future<void> _onPaymentConfirmed(Transaction payment) async {
    await TransactionService.saveTransaction(payment);
    _loadAuditTrail();
    _refreshStats();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Payment confirmed: ${payment.name} - ₹${payment.amount}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _onPaymentDenied(Transaction payment) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Payment denied: ${payment.name}'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _simulateBankSms() async {
    await PaymentDetectionSystem.recordSmsPayment(
      'Debit Alert: Rs 5000 debited from your account ending in 4321. Ref: TXN123456. At 3:45 PM. Balance: Rs 15000',
      '+919876543210',
      'HDFC Bank',
    );
  }

  void _simulateUpiPayment() async {
    await PaymentDetectionSystem.recordNotificationPayment(
      'Payment received',
      '₹1500 received from Priya Singh. Ref: UPI12345678. Google Pay',
      'com.google.android.apps.nbu.paytm',
    );
  }

  void _simulateConflict() async {
    // Same amount received twice at same time - conflict scenario
    await PaymentDetectionSystem.recordSmsPayment(
      'Debit Alert: Rs 1500 debited. Ref: ABC111',
      '+919999999999',
      'AXIS Bank',
    );
    await Future.delayed(const Duration(milliseconds: 100));
    await PaymentDetectionSystem.recordNotificationPayment(
      'Payment sent',
      '₹1500 transferred. Ref: DEF222',
      'com.phonepe.app',
    );
  }

  void _simulateWhatsAppPayment() async {
    await PaymentDetectionSystem.recordNotificationPayment(
      'New WhatsApp message',
      'Bhaiya, sent ₹2000 through UPI. Transaction ID WHATSAPP123',
      'com.whatsapp',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔍 Smart Payment Matcher'),
        // subtitle removed - not supported in this context
        elevation: 2,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ========== STATS CARDS ==========
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      'Auto-Confirmed',
                      _stats['auto_confirmed'] ?? 0,
                      Colors.green,
                      Icons.verified,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      'Needs Verify',
                      _stats['needs_confirmation'] ?? 0,
                      Colors.orange,
                      Icons.help_outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      'Manual Review',
                      _stats['manual_review'] ?? 0,
                      Colors.red,
                      Icons.warning_amber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      'Total',
                      _stats['total'] ?? 0,
                      Colors.blue,
                      Icons.receipt_long,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ========== SIMULATION BUTTONS ==========
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Test Payment Detection',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _simulationButton(
                '📱 Bank SMS (₹5000)',
                'Simulates HDFC bank alert',
                Colors.blue,
                _simulateBankSms,
              ),
              const SizedBox(height: 8),
              _simulationButton(
                '🔗 UPI Payment (₹1500)',
                'Simulates Google Pay notification',
                Colors.green,
                _simulateUpiPayment,
              ),
              const SizedBox(height: 8),
              _simulationButton(
                '⚠️ Conflict Test (₹1500 x2)',
                'Same amount detected twice - shows conflict handling',
                Colors.orange,
                _simulateConflict,
              ),
              const SizedBox(height: 8),
              _simulationButton(
                '💬 WhatsApp Message (₹2000)',
                'Parses WhatsApp payment message',
                Colors.purple,
                _simulateWhatsAppPayment,
              ),

              const SizedBox(height: 24),

              // ========== HOW IT WORKS ==========
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'How Smart Matching Works',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _infoCard(
                '1️⃣ Detection',
                'SMS/Notification listener receives payment alert\n' +
                    'System auto-parses amount, phone, name, reference',
              ),
              const SizedBox(height: 8),
              _infoCard(
                '2️⃣ Matching',
                'Compares payment with today\'s sales\n' +
                    'Matches amount (±5 rupees) + time (±5 min) + phone/name',
              ),
              const SizedBox(height: 8),
              _infoCard(
                '3️⃣ Confidence Scoring',
                'Calculates 0-100 score based on:\n' +
                    '• Source verification (+25%)\n' +
                    '• Exact amount match (+30%)\n' +
                    '• Time match (+20%)\n' +
                    '• Phone/name match (+20-10%)',
              ),
              const SizedBox(height: 8),
              _infoCard(
                '4️⃣ Action',
                '✅ HIGH (≥85%): Auto-save transaction\n' +
                    '⚠️ MEDIUM (60-84%): Show popup for verification\n' +
                    '❌ LOW (<60%): Manual review, flag conflicts',
              ),

              const SizedBox(height: 24),

              // ========== CONFLICT HANDLING ==========
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Conflict Resolution (Same Amount + Time)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Problem: Multiple sales with ₹5000 at 3:45 PM',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Sale 1: Rahul - Customer (9876543210)\n'
                      '• Sale 2: Priya - Wholesale (9123456789)',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Solution: Popup shows both options + phone matching\n' +
                          'User taps to confirm which customer it is\n' +
                          'System saves to audit trail for learning',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ========== AUDIT TRAIL ==========
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Audit Trail (Last 10)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton.icon(
                      onPressed: () {
                        _loadAuditTrail();
                        _refreshStats();
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
              if (_auditTrail.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('No audit entries yet. Simulate payments above.'),
                  ),
                )
              else
                ..._auditTrail.take(10).map((entry) {
                  final score = entry['confidence']?.toStringAsFixed(0) ?? '-';
                  final status = entry['status'] ?? 'UNKNOWN';
                  final statusColor = status == 'AUTO_CONFIRMED'
                      ? Colors.green
                      : (status == 'NEEDS_CONFIRMATION' ? Colors.orange : Colors.red);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Payment ID: ${entry['payment_id']?.substring(0, 12) ?? '-'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$score%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Status: $status',
                            style: TextStyle(
                              fontSize: 11,
                              color: statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (entry['sale_id'] != null && entry['sale_id'].toString().isNotEmpty)
                            Text(
                              'Matched Sale: ${entry['sale_id']}',
                              style: const TextStyle(fontSize: 10, color: Colors.blue),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, int value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _simulationButton(
    String title,
    String subtitle,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.play_arrow),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        alignment: Alignment.centerLeft,
      ),
    );
  }

  Widget _infoCard(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border.all(color: Colors.blue[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
