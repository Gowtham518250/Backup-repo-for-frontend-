import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'commission_tracking_service.dart';

class CommissionDashboardPage extends StatefulWidget {
  final String staffId;
  final String staffName;
  
  const CommissionDashboardPage({
    this.staffId = 'current_staff',
    this.staffName = 'Staff Member',
    super.key,
  });

  @override
  State<CommissionDashboardPage> createState() => _CommissionDashboardPageState();
}

class _CommissionDashboardPageState extends State<CommissionDashboardPage> {
  late Future<Map<String, dynamic>> _metricsFuture;
  late Future<List<Map<String, dynamic>>> _commissionsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _metricsFuture = CommissionTrackingService.getStaffMetrics(widget.staffId);
    _commissionsFuture = CommissionTrackingService.getPendingCommissions(widget.staffId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('${widget.staffName} - Commissions',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF635BFF),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 📊 Metrics Cards
            FutureBuilder<Map<String, dynamic>>(
              future: _metricsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return SizedBox(
                    height: 150,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }
                
                final metrics = snapshot.data!;
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Today\'s Earnings',
                            value: '₹${(metrics['todayEarned'] ?? 0).toStringAsFixed(0)}',
                            icon: '💰',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Today\'s Sales',
                            value: '${metrics['todayCount'] ?? 0}',
                            icon: '📦',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Pending Amount',
                            value: '₹${(metrics['pendingAmount'] ?? 0).toStringAsFixed(0)}',
                            icon: '⏳',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Pending Count',
                            value: '${metrics['pendingCount'] ?? 0}',
                            icon: '📋',
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            
            // 📄 Pending Commissions List
            Text('Pending Commissions',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _commissionsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final commissions = snapshot.data!;
                if (commissions.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('No pending commissions',
                        style: GoogleFonts.poppins(color: Colors.grey)),
                  );
                }
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: commissions.length,
                  itemBuilder: (context, index) {
                    final commission = commissions[index];
                    return _buildCommissionCard(commission);
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            
            // 💳 Request Payout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _showPayoutDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF635BFF),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Request Payout',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCommissionCard(Map<String, dynamic> commission) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sale #${(commission['saleId'] as String).substring(0, 6)}',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
              Text(
                '₹${(commission['totalCommission'] as num).toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF635BFF)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sale: ₹${(commission['saleAmount'] as num).toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
              Text('Rate: ${(commission['commissionRate'] as num).toStringAsFixed(1)}%',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }

  void _showPayoutDialog() {
    final bankController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Request Payout', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: bankController,
              decoration: InputDecoration(
                hintText: 'Bank Account (Last 4 digits)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Amount (₹)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount > 0) {
                await CommissionTrackingService.requestPayout(
                  staffId: widget.staffId,
                  staffName: widget.staffName,
                  bankAccount: bankController.text,
                  amount: amount,
                );
                Navigator.pop(context);
                setState(() => _loadData());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF635BFF)),
            child: const Text('Request', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
