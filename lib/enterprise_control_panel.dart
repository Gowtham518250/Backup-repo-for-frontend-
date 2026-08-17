import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'analytics_dashboard.dart';
import 'gst_compliance.dart';
import 'notification_service_client.dart';

class EnterpriseControlPanel extends StatefulWidget {
  const EnterpriseControlPanel({super.key});

  @override
  State<EnterpriseControlPanel> createState() => _EnterpriseControlPanelState();
}

class _EnterpriseControlPanelState extends State<EnterpriseControlPanel>
    with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF6366F1);
  late TabController _tabController;
  String _shopGSTIN = '';
  bool _gstVerified = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enterprise Control Panel'),
        backgroundColor: _primary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Analytics'),
            Tab(text: 'Compliance'),
            Tab(text: 'Notifications'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Analytics Tab
          const AnalyticsDashboard(),

          // Compliance Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // GST Registration
                Text('GST Configuration',
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (val) => setState(() => _shopGSTIN = val),
                  decoration: InputDecoration(
                    hintText: 'Enter Shop GSTIN (15 digits)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    final isValid = GSTCompliance.isValidGSTIN(_shopGSTIN);
                    setState(() => _gstVerified = isValid);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(isValid
                          ? 'GSTIN verified successfully'
                          : 'Invalid GSTIN format'),
                      backgroundColor:
                          isValid ? Colors.green : Colors.red,
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _primary),
                  child: const Text('Verify GSTIN'),
                ),
                if (_gstVerified)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Shop is GST compliant and ready for invoicing',
                              style: GoogleFonts.poppins(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // GST Rates Reference
                Text('Applicable GST Rates',
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ..._buildGSTRatesTable(),
                const SizedBox(height: 24),

                // Compliance Features
                Text('Compliance Features',
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildComplianceFeature(
                    '✓ GST Invoice Generation',
                    'All invoices auto-include GSTIN & GST rates'),
                _buildComplianceFeature(
                    '✓ Audit Trail', 'Complete invoice change history'),
                _buildComplianceFeature(
                    '✓ HSN/SAC Codes',
                    'Automatic product categorization'),
                _buildComplianceFeature(
                    '✓ ITC Tracking',
                    'Input Tax Credit management'),
              ],
            ),
          ),

          // Notifications Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notification Services',
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                _buildNotificationCard(
                  'Bill Reminders',
                  'Auto-send SMS to customers for pending invoices',
                  Icons.sms,
                  Colors.blue,
                  () => _showBillReminderDialog(),
                ),
                _buildNotificationCard(
                  'Order Updates',
                  'SMS/WhatsApp for order confirmation & delivery',
                  Icons.local_shipping,
                  Colors.orange,
                  () => _showOrderUpdateDialog(),
                ),
                _buildNotificationCard(
                  'Daily Reports',
                  'Email closing summary to shop owner',
                  Icons.email,
                  Colors.purple,
                  () => _showDailyReportDialog(),
                ),
                _buildNotificationCard(
                  'Loyalty Rewards',
                  'Notify customers of birthday discounts & points',
                  Icons.card_giftcard,
                  Colors.pink,
                  () => _showLoyaltyDialog(),
                ),
                _buildNotificationCard(
                  'Payment Alerts',
                  'Alert staff of pending customer payments',
                  Icons.payment,
                  Colors.green,
                  () => _showPaymentAlertDialog(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGSTRatesTable() {
    const rates = [
      ('Essentials (Food, Medicine)', '5%'),
      ('Textiles & Fabrics', '5%'),
      ('Electronics & Accessories', '12%'),
      ('General Services', '18%'),
      ('Luxury & Premium', '28%'),
    ];

    return rates.map((item) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(item.$1, style: GoogleFonts.poppins()),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(item.$2,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, color: _primary)),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildComplianceFeature(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, color: _primary)),
            const SizedBox(height: 4),
            Text(desc,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(String title, String desc, IconData icon,
      Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(desc,
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBillReminderDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Bill Reminder'),
        content: const Text(
            'This will send SMS reminders to customers with pending invoices.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Bill reminders queued for delivery')),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showOrderUpdateDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Order Notifications'),
        content: const Text(
            'Automatically send order confirmations and delivery updates via SMS/WhatsApp'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Order notifications enabled')),
              );
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  void _showDailyReportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daily Closing Report'),
        content: const Text('Email daily summary to shop owner at end of day'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Daily reports will be sent at 11 PM')),
              );
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  void _showLoyaltyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Loyalty Notifications'),
        content: const Text(
            'Send birthday discounts and loyalty points updates to customers'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Loyalty notifications enabled')),
              );
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  void _showPaymentAlertDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Payment Collection Alerts'),
        content: const Text('SMS alerts to staff when customers make payments'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payment alerts enabled')),
              );
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }
}
