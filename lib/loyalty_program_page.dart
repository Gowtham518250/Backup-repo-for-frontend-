import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'loyalty_program_service.dart';

class LoyaltyProgramPage extends StatefulWidget {
  final String customerId;
  final String customerName;
  
  const LoyaltyProgramPage({
    required this.customerId,
    required this.customerName,
    super.key,
  });

  @override
  State<LoyaltyProgramPage> createState() => _LoyaltyProgramPageState();
}

class _LoyaltyProgramPageState extends State<LoyaltyProgramPage> {
  late Future<Map<String, dynamic>?> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  void _loadDetails() {
    _detailsFuture = LoyaltyProgramService.getCustomerDetails(widget.customerId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Loyalty Program',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF635BFF),
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final details = snapshot.data!;
          final tier = details['tier'] as String;
          final points = details['points'] as int;
          final redeemValue = details['redeemValue'] as double;
          final benefits = details['tierBenefits'] as Map<String, dynamic>;
          final nextTier = details['nextTier'] as String;
          final pointsToNext = details['pointsToNextTier'] as int;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 👤 Customer Header
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF635BFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          widget.customerName[0].toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.customerName,
                              style: GoogleFonts.poppins(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getTierColor(tier),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(tier.toUpperCase(),
                                style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // ⭐ Points Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      const Color(0xFF635BFF),
                      const Color(0xFF635BFF).withOpacity(0.8),
                    ]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Available Points',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.white70)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$points',
                              style: GoogleFonts.poppins(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          Text('₹${redeemValue.toStringAsFixed(0)}',
                              style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  color: Colors.white70)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _showRedeemDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: Text('Redeem',
                                  style: GoogleFonts.poppins(
                                      color: const Color(0xFF635BFF),
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // 📊 Tier Progress
                Text('Tier Progress',
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(tier,
                            style: GoogleFonts.poppins(fontSize: 12)),
                        Text(nextTier,
                            style: GoogleFonts.poppins(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: pointsToNext > 0 ? 0.5 : 1.0,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF635BFF)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('$pointsToNext points to $nextTier',
                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 24),
                
                // 🎁 Tier Benefits
                Text('Your Benefits',
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ..._buildBenefitsList(benefits),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildBenefitsList(Map<String, dynamic> benefits) {
    final benefitItems = [
      {
        'icon': '✕',
        'title': 'Points Multiplier',
        'value': '${(benefits['pointsMultiplier'] as num).toStringAsFixed(1)}x',
      },
      {
        'icon': '🛍️',
        'title': 'Discount',
        'value': '${(benefits['discount'] as num).toInt()}%',
      },
      {
        'icon': '🚚',
        'title': 'Free Delivery',
        'value': benefits['freeDelivery'] == true ? '✓' : '✗',
      },
      {
        'icon': '🎂',
        'title': 'Birthday Bonus',
        'value': '${(benefits['birthdayBonus'] as num).toInt()} pts',
      },
    ];
    
    return benefitItems.map((item) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(item['icon']!, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Text(item['title']!,
                  style: GoogleFonts.poppins(fontSize: 12)),
            ],
          ),
          Text(item['value']!,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    )).toList();
  }

  Color _getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'bronze':
        return Colors.brown;
      case 'silver':
        return Colors.grey;
      case 'gold':
        return Colors.amber;
      case 'platinum':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  void _showRedeemDialog() {
    final pointsController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Redeem Points', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pointsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Points to redeem',
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
              final points = int.tryParse(pointsController.text) ?? 0;
              if (points > 0) {
                await LoyaltyProgramService.redeemPoints(
                  customerId: widget.customerId,
                  pointsToRedeem: points,
                );
                Navigator.pop(context);
                setState(() => _loadDetails());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF635BFF)),
            child: const Text('Redeem', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
