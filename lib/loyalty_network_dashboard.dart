import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

import 'inter_shop_loyalty_service.dart';
import 'tier_benefits_service.dart';

class LoyaltyNetworkDashboard extends StatefulWidget {
  final int customerId;

  const LoyaltyNetworkDashboard({
    Key? key,
    required this.customerId,
  }) : super(key: key);

  @override
  State<LoyaltyNetworkDashboard> createState() =>
      _LoyaltyNetworkDashboardState();
}

class _LoyaltyNetworkDashboardState extends State<LoyaltyNetworkDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
        backgroundColor: const Color(0xAA03030D),
        title: Text(
          '🌐 Loyalty Network & Tier Benefits',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF6366F1),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF6366F1),
          tabs: const [
            Tab(text: '🛍️ Network', icon: Icon(Icons.public)),
            Tab(text: '⭐ Benefits', icon: Icon(Icons.card_giftcard)),
            Tab(text: '📊 Moat', icon: Icon(Icons.analytics)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNetworkTab(),
          _buildBenefitsTab(),
          _buildMoatTab(),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: INTER-SHOP NETWORK
  // ==========================================

  Widget _buildNetworkTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: InterShopLoyaltyService.getNetworkShops(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final shops = snapshot.data ?? [];
        final metrics =
            InterShopLoyaltyService.getNetworkMetrics().then((m) => m);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Network Overview Card
            _buildNetworkOverviewCard(shops),
            const SizedBox(height: 20),

            // Participating Shops
            Text(
              'Participating Shops (${shops.length})',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 12),

            ...shops.map((shop) => _buildShopCard(shop)),

            const SizedBox(height: 20),

            // Transfer History
            Text(
              'Recent Transfers',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 12),

            FutureBuilder<List<Map<String, dynamic>>>(
              future: InterShopLoyaltyService.getTransferHistory(
                  widget.customerId),
              builder: (context, histSnapshot) {
                if (!histSnapshot.hasData || histSnapshot.data!.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'No transfers yet. Start earning and transfer points across the network!',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  );
                }

                final transfers = histSnapshot.data ?? [];
                return Column(
                  children: transfers.take(5).map((t) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${t['points']} points → Shop ${t['to_shop_id']}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${t['tier']} • -${t['network_fee']} fee',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '+${t['effective_points']}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildNetworkOverviewCard(List<Map<String, dynamic>> shops) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF6F46E0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Loyalty Network',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${shops.length} shops • 45K+ customers',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatPill('68%', 'Adoption'),
              _buildStatPill('82%', 'Retention'),
              _buildStatPill('15%', 'Growth'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildShopCard(Map<String, dynamic> shop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop['shop_name'] ?? 'Shop',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      shop['category'] ?? 'General',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: shop['tier_discount'] == 0
                      ? const Color(0xFFF5F7FA)
                      : const Color(0xFFDEF7EC),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '+${shop['tier_discount']}%',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: shop['tier_discount'] == 0
                        ? const Color(0xFF6B7280)
                        : const Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${shop['customers_using_loyalty'] ?? 0} customers',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
              ElevatedButton(
                onPressed: () => _showTransferDialog(shop),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(
                  'Transfer',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTransferDialog(Map<String, dynamic> shop) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Transfer Points',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Transfer loyalty points to ${shop['shop_name']}?',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: const Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '✅ Transfer initiated to ${shop['shop_name']}',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
            ),
            child: Text(
              'Transfer',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: TIER BENEFITS & LOCK-IN
  // ==========================================

  Widget _buildBenefitsTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: TierBenefitsService.getTierProgress(widget.customerId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final progress = snapshot.data ?? {};
        final currentTier = progress['current_tier'] as String? ?? 'BRONZE';
        final totalPoints = progress['total_points'] as int? ?? 0;
        final pointsToNext = progress['points_to_next'] as int? ?? 500;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Tier progression card
            _buildTierProgressCard(currentTier, totalPoints, pointsToNext),
            const SizedBox(height: 20),

            // Tier lock-in status
            FutureBuilder<Map<String, dynamic>>(
              future:
                  InterShopLoyaltyService.checkTierLock(widget.customerId, currentTier),
              builder: (context, lockSnapshot) {
                if (!lockSnapshot.hasData) return const SizedBox();
                final lock = lockSnapshot.data ?? {};
                return _buildLockStatusCard(lock);
              },
            ),
            const SizedBox(height: 20),

            // Benefits list
            Text(
              'Your Benefits',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 12),

            FutureBuilder<List<Map<String, dynamic>>>(
              future: TierBenefitsService.getTierBenefits(currentTier),
              builder: (context, benefitSnapshot) {
                if (!benefitSnapshot.hasData) return const SizedBox();
                final benefits = benefitSnapshot.data ?? [];
                return Column(
                  children: benefits
                      .map((benefit) => _buildBenefitTile(benefit))
                      .toList(),
                );
              },
            ),

            const SizedBox(height: 20),

            // Benefit redemption history
            Text(
              'Redemption History',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 12),

            FutureBuilder<List<Map<String, dynamic>>>(
              future: TierBenefitsService.getBenefitRedemptions(
                  widget.customerId),
              builder: (context, redemptionSnapshot) {
                if (!redemptionSnapshot.hasData ||
                    redemptionSnapshot.data!.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'No redemptions yet. Activate a benefit to get started!',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  );
                }

                final redemptions = redemptionSnapshot.data ?? [];
                return Column(
                  children: redemptions
                      .take(5)
                      .map((r) => _buildRedemptionTile(r))
                      .toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildTierProgressCard(
      String currentTier, int totalPoints, int pointsToNext) {
    final tiers = ['BRONZE', 'SILVER', 'GOLD'];
    final currentIndex = tiers.indexOf(currentTier);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getTierColors(currentTier),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🏆 Current Tier',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currentTier,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress to next',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  Text(
                    '$totalPoints / ${totalPoints + pointsToNext} points',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: totalPoints / (totalPoints + pointsToNext).toDouble(),
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Color> _getTierColors(String tier) {
    switch (tier) {
      case 'GOLD':
        return [const Color(0xFFFFBF00), const Color(0xFFFFA500)];
      case 'SILVER':
        return [const Color(0xFFC0C0C0), const Color(0xFFAA99AA)];
      default:
        return [const Color(0xFF8B4513), const Color(0xFFA0522D)];
    }
  }

  Widget _buildLockStatusCard(Map<String, dynamic> lock) {
    final isLocked = lock['is_locked'] as bool? ?? false;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isLocked ? const Color(0xFFFEF3C7) : const Color(0xFFDEF7EC),
        border: Border.all(
          color:
              isLocked ? const Color(0xFFFCD34D) : const Color(0xFF6EE7B7),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isLocked ? Icons.lock : Icons.lock_open,
            color: isLocked ? const Color(0xFFB45309) : const Color(0xFF047857),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLocked ? '🔐 Tier Locked' : '🔓 Lock Expired',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isLocked
                        ? const Color(0xFFB45309)
                        : const Color(0xFF047857),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isLocked
                      ? 'Expires ${lock['lock_expires_at']?.toString().split('T')[0]}'
                      : 'Tier can be downgraded',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isLocked
                        ? const Color(0xFF92400E)
                        : const Color(0xFF065F46),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitTile(Map<String, dynamic> benefit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            benefit['icon'] ?? '✓',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  benefit['name'] ?? 'Benefit',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  benefit['description'] ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedemptionTile(Map<String, dynamic> redemption) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                redemption['benefit_id']?.toString().replaceAll('_', ' ') ??
                    'Benefit',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                redemption['redeemed_at']?.toString().split('T')[0] ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
          Text(
            '+${redemption['value']} value',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: RETENTION MOAT ANALYSIS
  // ==========================================

  Widget _buildMoatTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future:
          TierBenefitsService.analyzeRetentionMoat(widget.customerId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final moat = snapshot.data ?? {};
        final moatScore = moat['moat_score'] as int? ?? 0;
        final moatStrength = moat['moat_strength'] as String? ?? 'WEAK';

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Moat Score Card
            _buildMoatScoreCard(moatScore, moatStrength),
            const SizedBox(height: 20),

            // Moat Factors Breakdown
            Text(
              'Moat Factors',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 12),

            _buildMoatFactorsChart(moat),
            const SizedBox(height: 20),

            // Lock Status
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                border: Border.all(color: const Color(0xFFFCD34D)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tier Lock Status',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFB45309),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lock expires in ${moat['lock_days_remaining']} days',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Switching Cost
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFFCA5A5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Switching Cost',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${moat['switching_cost'] ?? 0} points',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'to switch',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMoatScoreCard(int score, String strength) {
    final scoreColor = _getScoreColor(score);
    final scoreEmoji = _getScoreEmoji(strength);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scoreColor.withValues(alpha: 0.8), scoreColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$scoreEmoji Your Retention Moat',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$score',
                    style: GoogleFonts.poppins(
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    strength,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                child: Center(
                  child: Text(
                    _getMoatStrengthBars(strength),
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 100) return const Color(0xFF059669);
    if (score >= 70) return const Color(0xFF0891B2);
    if (score >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _getScoreEmoji(String strength) {
    switch (strength) {
      case 'VERY_STRONG':
        return '🏰';
      case 'STRONG':
        return '🛡️';
      case 'MODERATE':
        return '⚔️';
      default:
        return '🎯';
    }
  }

  String _getMoatStrengthBars(String strength) {
    switch (strength) {
      case 'VERY_STRONG':
        return '████';
      case 'STRONG':
        return '███';
      case 'MODERATE':
        return '██';
      default:
        return '█';
    }
  }

  Widget _buildMoatFactorsChart(Map<String, dynamic> moat) {
    final factors = {
      'Tier': (moat['tier_depth_points'] as int?) ?? 0,
      'Benefits': (moat['benefit_depth_points'] as int?) ?? 0,
      'Investment': (moat['investment_depth_points'] as int?) ?? 0,
      'Points': (moat['points_depth_points'] as int?) ?? 0,
    };

    final maxValue = factors.values.reduce((a, b) => a > b ? a : b).toDouble();

    return Column(
      children: factors.entries.map((entry) {
        final percentage = (entry.value / (maxValue > 0 ? maxValue : 1)) * 100;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${entry.value} pts',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6366F1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF6366F1),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
