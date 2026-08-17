import 'package:flutter/foundation.dart';
import 'payment_detection_service.dart';
import 'whatsapp_message_service.dart';

/// Festival entry
class FestivalEntry {
  final String name;
  final DateTime date;
  final int daysWarningBefore;
  final String hindiName;
  final Map<String, int> productMultipliers;  // category -> multiplier
  
  FestivalEntry({
    required this.name,
    required this.date,
    this.daysWarningBefore = 15,
    required this.hindiName,
    required this.productMultipliers,
  });
  
  int get daysUntil {
    return date.difference(DateTime.now()).inDays;
  }
  
  bool get isUpcoming {
    return daysUntil >= 0 && daysUntil <= daysWarningBefore;
  }
}

/// Stock alert for festival
class StockAlert {
  final String itemName;
  final String itemCategory;
  final String festivalName;
  final int daysUntilFestival;
  final int currentStock;
  final int recommendedStock;
  final double estimatedDailyDemand;
  
  StockAlert({
    required this.itemName,
    required this.itemCategory,
    required this.festivalName,
    required this.daysUntilFestival,
    required this.currentStock,
    required this.recommendedStock,
    required this.estimatedDailyDemand,
  });
  
  int get stockShortage => (recommendedStock - currentStock).clamp(0, 9999);
  bool get isUrgent => stockShortage > 0;
}

/// Festival Calendar for Indian kirana shops
class FestivalCalendar {
  static const String _tag = '🪔 FESTIVAL_CALENDAR';
  
  static List<FestivalEntry> get festivals => [
    // Ganesh Chaturthi (August/September)
    FestivalEntry(
      name: 'Ganesh Chaturthi',
      hindiName: 'गणेश चतुर्थी',
      date: DateTime(2025, 9, 7),
      daysWarningBefore: 15,
      productMultipliers: {
        'coconut': 8,
        'flowers': 6,
        'modak_mix': 12,
        'incense': 5,
        'puja_items': 8,
      },
    ),
    
    // Diwali (October/November)
    FestivalEntry(
      name: 'Diwali',
      hindiName: 'दिवाली',
      date: DateTime(2025, 11, 1),
      daysWarningBefore: 20,
      productMultipliers: {
        'dry_fruits': 10,
        'sweets': 8,
        'candles': 15,
        'oil': 4,
        'gift_boxes': 10,
        'namkeen': 6,
      },
    ),
    
    // Eid
    FestivalEntry(
      name: 'Eid',
      hindiName: 'ईद',
      date: DateTime(2025, 4, 8),
      daysWarningBefore: 10,
      productMultipliers: {
        'vermicelli': 6,
        'dates': 5,
        'mutton': 4,
        'sweets': 6,
        'meat': 3,
      },
    ),
    
    // Holi (March/April)
    FestivalEntry(
      name: 'Holi',
      hindiName: 'होली',
      date: DateTime(2025, 3, 14),
      daysWarningBefore: 12,
      productMultipliers: {
        'colours': 20,
        'pichkari': 15,
        'sweets': 5,
        'dried_fruits': 6,
        'milk': 3,
      },
    ),
    
    // Navratri (September/October)
    FestivalEntry(
      name: 'Navratri',
      hindiName: 'नवरात्रि',
      date: DateTime(2025, 10, 3),
      daysWarningBefore: 15,
      productMultipliers: {
        'fasting_foods': 8,
        'fruits': 5,
        'sabudana': 10,
        'peanuts': 6,
        'potatoes': 4,
      },
    ),
    
    // Christmas (December)
    FestivalEntry(
      name: 'Christmas',
      hindiName: 'क्रिसमस',
      date: DateTime(2025, 12, 25),
      daysWarningBefore: 20,
      productMultipliers: {
        'cake_mix': 6,
        'dry_fruits': 4,
        'chocolate': 7,
        'almonds': 5,
        'gifts': 8,
      },
    ),
    
    // Pongal / Makar Sankranti (January)
    FestivalEntry(
      name: 'Makar Sankranti / Pongal',
      hindiName: 'मकर संक्रांति',
      date: DateTime(2025, 1, 14),
      daysWarningBefore: 15,
      productMultipliers: {
        'rice': 3,
        'jaggery': 5,
        'sesame': 8,
        'moong': 4,
        'groundnut': 6,
      },
    ),
  ];
  
  /// Get upcoming festivals within N days
  static List<FestivalEntry> getUpcomingFestivals({int days = 15}) {
    return festivals
        .where((f) => f.isUpcoming && f.daysUntil <= days)
        .toList()
        ..sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
  }
  
  /// Get stock alerts for inventory items
  static List<StockAlert> getFestivalAlerts({
    required List<InventoryItem> stock,
    required List<Sale> salesHistory,
  }) {
    final alerts = <StockAlert>[];
    final upcoming = getUpcomingFestivals();
    
    if (upcoming.isEmpty) return alerts;
    
    for (final festival in upcoming) {
      for (final item in stock) {
        // Check if item category has multiplier for this festival
        final multiplier = festival.productMultipliers[item.category ?? 'general'] ?? 0;
        if (multiplier == 0) continue;
        
        // Calculate average daily sales from history
        final avgDailySales = _calculateAvgDailySales(item.sku, salesHistory);
        
        // Expected demand = avg × multiplier × 7 days (typical festive week)
        final expectedDemand = avgDailySales * multiplier * 7;
        final minSafeStock = (expectedDemand * 0.5).toInt();  // 50% as minimum safe
        
        if (item.currentStock < minSafeStock) {
          alerts.add(StockAlert(
            itemName: item.name,
            itemCategory: item.category ?? 'general',
            festivalName: festival.name,
            daysUntilFestival: festival.daysUntil,
            currentStock: item.currentStock,
            recommendedStock: minSafeStock,
            estimatedDailyDemand: avgDailySales * multiplier,
          ));
        }
      }
    }
    
    // Sort by urgency and days
    alerts.sort((a, b) {
      if (a.isUrgent && !b.isUrgent) return -1;
      if (!a.isUrgent && b.isUrgent) return 1;
      return a.daysUntilFestival.compareTo(b.daysUntilFestival);
    });
    
    return alerts;
  }
  
  /// Calculate average daily sales for an item
  static double _calculateAvgDailySales(
    String sku,
    List<Sale> salesHistory,
  ) {
    if (salesHistory.isEmpty) return 1.0;
    
    final relevant = salesHistory
        .where((s) => s.sku == sku)
        .toList();
    
    if (relevant.isEmpty) return 1.0;
    
    final total = relevant.fold<int>(0, (sum, s) => sum + (s.quantity ?? 1));
    final days = relevant
        .map((s) => (s.date as DateTime).day)
        .toSet()
        .length
        .clamp(1, 365);
    
    return total / days;
  }
  
  /// Build festival alert message for UI
  static String buildAlertMessage(
    StockAlert alert,
    VoiceLanguage language,
  ) {
    switch (language) {
      case VoiceLanguage.hindi:
        return '🎉 ${alert.festivalName} में ${alert.daysUntilFestival} दिन बाकी\n'
            '${alert.itemName} स्टॉक करें!\n'
            'अभी: ${alert.currentStock}, सुझाव: ${alert.recommendedStock}\n'
            'रोज़ाना की उम्मीद: ${alert.estimatedDailyDemand.toStringAsFixed(0)} यूनिट';
      
      case VoiceLanguage.tamil:
        return '🎉 ${alert.festivalName}க்கு ${alert.daysUntilFestival} நாட்கள் உள்ளது\n'
            '${alert.itemName} சேகரிக்க வேண்டும்!\n'
            'தற்போது: ${alert.currentStock}, பரிந்துரை: ${alert.recommendedStock}\n'
            'நாளை: ${alert.estimatedDailyDemand.toStringAsFixed(0)} யூனிட்';
      
      default:
        return '🎉 ${alert.festivalName} in ${alert.daysUntilFestival} days\n'
            'Stock up ${alert.itemName}!\n'
            'Now: ${alert.currentStock}, Recommended: ${alert.recommendedStock}\n'
            'Daily Expected: ${alert.estimatedDailyDemand.toStringAsFixed(0)} units';
    }
  }
}

/// Models used by Festival Calendar
class InventoryItem {
  final String sku;
  final String name;
  final String? category;
  final int currentStock;
  
  InventoryItem({
    required this.sku,
    required this.name,
    this.category,
    required this.currentStock,
  });
}

class Sale {
  final String sku;
  final int? quantity;
  final DateTime date;
  
  Sale({
    required this.sku,
    this.quantity = 1,
    required this.date,
  });
}
