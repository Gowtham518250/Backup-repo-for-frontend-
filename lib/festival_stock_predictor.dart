import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum FestivalType {
  ganeshChaturthi,
  diwali,
  eid,
  holi,
  navratri,
  christmas,
  pongalMakarSankranti,
  none
}

class Festival {
  final String name;
  final FestivalType type;
  final DateTime date;
  final int daysOffsetBefore;
  final int daysOffsetAfter;
  final Map<String, double> demandMultipliers; // product_category: multiplier

  Festival({
    required this.name,
    required this.type,
    required this.date,
    this.daysOffsetBefore = 7,
    this.daysOffsetAfter = 3,
    required this.demandMultipliers,
  });
}

class FestivalCalendar {
  static List<Festival> getFestivalsForYear(int year) {
    return [
      // Ganesh Chaturthi (August/September)
      Festival(
        name: 'Ganesh Chaturthi',
        type: FestivalType.ganeshChaturthi,
        date: DateTime(year, 8, 23),
        demandMultipliers: {
          'coconut': 8.0,
          'flowers': 6.0,
          'modak_mix': 12.0,
          'incense': 5.0,
          'oil': 2.0,
        },
      ),
      // Diwali (October/November)
      Festival(
        name: 'Diwali',
        type: FestivalType.diwali,
        date: DateTime(year, 11, 1),
        daysOffsetBefore: 14,
        demandMultipliers: {
          'dry_fruits': 10.0,
          'sweets': 8.0,
          'candles': 15.0,
          'oil': 4.0,
          'gift_boxes': 10.0,
          'snacks': 7.0,
        },
      ),
      // Eid (varies - using approximate date)
      Festival(
        name: 'Eid',
        type: FestivalType.eid,
        date: DateTime(year, 4, 10),
        daysOffsetBefore: 3,
        demandMultipliers: {
          'vermicelli': 6.0,
          'dates': 5.0,
          'mutton': 4.0,
          'sweets': 6.0,
          'dry_fruits': 4.0,
        },
      ),
      // Holi (March)
      Festival(
        name: 'Holi',
        type: FestivalType.holi,
        date: DateTime(year, 3, 25),
        daysOffsetBefore: 7,
        demandMultipliers: {
          'colours': 20.0,
          'pichkari': 15.0,
          'sweets': 5.0,
          'ghee': 3.0,
          'thandai_mix': 8.0,
        },
      ),
      // Navratri (September/October)
      Festival(
        name: 'Navratri',
        type: FestivalType.navratri,
        date: DateTime(year, 10, 3),
        daysOffsetBefore: 7,
        demandMultipliers: {
          'fasting_foods': 8.0,
          'fruits': 5.0,
          'milk': 3.0,
          'coconut': 4.0,
        },
      ),
      // Christmas (December)
      Festival(
        name: 'Christmas',
        type: FestivalType.christmas,
        date: DateTime(year, 12, 25),
        daysOffsetBefore: 14,
        demandMultipliers: {
          'cake_mix': 6.0,
          'dry_fruits': 4.0,
          'chocolates': 8.0,
          'flowers': 5.0,
        },
      ),
      // Pongal / Makar Sankranti (January)
      Festival(
        name: 'Pongal',
        type: FestivalType.pongalMakarSankranti,
        date: DateTime(year, 1, 14),
        daysOffsetBefore: 3,
        demandMultipliers: {
          'rice': 3.0,
          'jaggery': 5.0,
          'sesame': 8.0,
          'lentils': 2.0,
        },
      ),
    ];
  }

  static List<Festival> getUpcomingFestivals(DateTime now, {int daysAhead = 15}) {
    final year = now.year;
    final allFestivals = getFestivalsForYear(year);
    
    return allFestivals.where((f) {
      final daysUntilFestival = f.date.difference(now).inDays;
      return daysUntilFestival >= 0 && daysUntilFestival <= daysAhead;
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  static Festival? getNearestFestival(DateTime now) {
    final upcoming = getUpcomingFestivals(now, daysAhead: 365);
    return upcoming.isNotEmpty ? upcoming.first : null;
  }
}

class StockAlert {
  final String itemName;
  final String category;
  final String festivalName;
  final int daysUntilFestival;
  final int currentStock;
  final int recommendedReorderQty;
  final double expectedDemandMultiplier;

  StockAlert({
    required this.itemName,
    required this.category,
    required this.festivalName,
    required this.daysUntilFestival,
    required this.currentStock,
    required this.recommendedReorderQty,
    required this.expectedDemandMultiplier,
  });
}

class FestivalStockAlerts {
  static List<StockAlert> generateAlerts(
    List<Map<String, dynamic>> inventory,
    List<Map<String, dynamic>> salesHistory,
  ) {
    final alerts = <StockAlert>[];
    final now = DateTime.now();
    final upcomingFestivals = FestivalCalendar.getUpcomingFestivals(now, daysAhead: 15);

    for (final festival in upcomingFestivals) {
      final daysUntilFestival = festival.date.difference(now).inDays;

      for (final item in inventory) {
        final category = item['category']?.toString().toLowerCase() ?? '';
        final currentStock = item['quantity'] as int? ?? 0;
        final itemName = item['name']?.toString() ?? '';

        // Get multiplier for this category
        final multiplier = festival.demandMultipliers[category] ?? 0.0;
        if (multiplier == 0.0) continue;

        // Calculate average daily sales for this category
        final categoryAvgDaily = _calculateCategoryAverage(category, salesHistory);
        
        // Expected demand for 7 days
        final expectedDemand = (categoryAvgDaily * multiplier * 7).toInt();
        
        // Alert if current stock is less than 50% of expected demand
        if (currentStock < (expectedDemand * 0.5).toInt()) {
          alerts.add(
            StockAlert(
              itemName: itemName,
              category: category,
              festivalName: festival.name,
              daysUntilFestival: daysUntilFestival,
              currentStock: currentStock,
              recommendedReorderQty: expectedDemand - currentStock,
              expectedDemandMultiplier: multiplier,
            ),
          );
        }
      }
    }

    return alerts..sort((a, b) => a.daysUntilFestival.compareTo(b.daysUntilFestival));
  }

  static double _calculateCategoryAverage(String category, List<Map<String, dynamic>> salesHistory) {
    if (salesHistory.isEmpty) return 10.0; // Default fallback

    double total = 0;
    int count = 0;

    for (final sale in salesHistory) {
      if (sale['category']?.toString().toLowerCase() == category) {
        total += (sale['quantity'] as int? ?? 0).toDouble();
        count++;
      }
    }

    return count > 0 ? total / count : 10.0;
  }
}

class FestivalAlertsWidget extends StatelessWidget {
  final List<StockAlert> alerts;
  final VoidCallback onRefresh;

  const FestivalAlertsWidget({
    super.key,
    required this.alerts,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🪔 Festival Stock Alerts',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: onRefresh,
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...alerts.take(3).map((alert) => _buildAlertTile(alert)),
          if (alerts.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+ ${alerts.length - 3} more alert${alerts.length - 3 > 1 ? 's' : ''}',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.amber.shade700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAlertTile(StockAlert alert) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.itemName,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${alert.festivalName} (${alert.daysUntilFestival}d) • Need ${alert.recommendedReorderQty}',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.amber.shade800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.shade200,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${alert.currentStock}',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
