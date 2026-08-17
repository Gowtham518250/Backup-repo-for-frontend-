import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'festival_stock_predictor.dart';
import 'local_storage_service.dart';

class FestivalAlertsPage extends StatefulWidget {
  const FestivalAlertsPage({super.key});

  @override
  State<FestivalAlertsPage> createState() => _FestivalAlertsPageState();
}

class _FestivalAlertsPageState extends State<FestivalAlertsPage> {
  List<StockAlert> _alerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    // Load inventory and sales data
    final inventory = await LocalStorageService.loadInventory();
    final sales = await LocalStorageService.loadSales();

    // Generate alerts
    final alerts = FestivalStockAlerts.generateAlerts(
      (inventory as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      (sales as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );

    setState(() {
      _alerts = alerts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text('Festival Stock Alerts', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAlerts,
          ),
        ],
      ),
      body: _alerts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 60, color: Colors.green.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'All stocks are well-stocked!',
                    style: GoogleFonts.poppins(fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _alerts.length,
              itemBuilder: (context, index) {
                final alert = _alerts[index];
                return _buildAlertCard(alert);
              },
            ),
    );
  }

  Widget _buildAlertCard(StockAlert alert) {
    final isUrgent = alert.daysUntilFestival <= 3;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUrgent ? Colors.red.shade50 : Colors.amber.shade50,
        border: Border.all(color: isUrgent ? Colors.red.shade200 : Colors.amber.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  alert.itemName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isUrgent ? Colors.red.shade900 : Colors.amber.shade900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isUrgent ? Colors.red : Colors.amber,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isUrgent ? 'URGENT' : 'ALERT',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '🪔 ${alert.festivalName} (in ${alert.daysUntilFestival} days)',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isUrgent ? Colors.red.shade700 : Colors.amber.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Stock',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    '${alert.currentStock} units',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Recommended Reorder',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    '+${alert.recommendedReorderQty} units',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Demand multiplier for ${alert.category} during ${alert.festivalName}: ${alert.expectedDemandMultiplier}x',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // FIX-6: Navigate to inventory page with low stock filter
                Navigator.pushNamed(context, '/inventory', arguments: {
                  'filter': 'low_stock',
                  'festival': alert.festivalName,
                  'recommended_qty': alert.recommendedReorderQty,
                  'item_name': alert.itemName,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
              ),
              child: Text(
                'Reorder Now',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
