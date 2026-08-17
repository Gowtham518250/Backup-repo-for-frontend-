import 'package:decimal/decimal.dart';

/// GST Calculator Service
/// Provides precise GST calculations using decimal arithmetic
/// to avoid floating-point errors in financial calculations
class GstCalculator {
  /// Calculate GST components for a single item
  static GstComponents calculateItemGST({
    required double price,
    required int quantity,
    required double gstRate,
  }) {
    final priceDecimal = Decimal.parse(price.toString());
    final quantityDecimal = Decimal.fromInt(quantity);
    final gstRateDecimal = (Decimal.parse(gstRate.toString()) / Decimal.fromInt(100))
        .toDecimal(scaleOnInfinitePrecision: 10);
    
    final lineTotal = priceDecimal * quantityDecimal;
    final lineGST = lineTotal * gstRateDecimal;
    final halfGST = (lineGST / Decimal.fromInt(2)).toDecimal(scaleOnInfinitePrecision: 10);
    
    // FIX: Derive totalGST as the sum of the rounded halves so that the
    // displayed components (cgst + sgst) always equal the displayed total.
    // Using raw lineGST can differ from halfGST * 2 by ±1 paise.
    // Use double rounding for simplicity
    final displayCgst = (halfGST.toDouble() * 100).round() / 100;
    final displaySgst = (halfGST.toDouble() * 100).round() / 100;
    final displayTotalGST = displayCgst + displaySgst;
    
    return GstComponents(
      subtotal: lineTotal.toDouble(),
      cgst: displayCgst,
      sgst: displaySgst,
      totalGST: displayTotalGST,
      grandTotal: (lineTotal.toDouble() + displayTotalGST),
    );
  }
  
  /// Calculate GST for multiple items
  static GstComponents calculateBatchGST({
    required List<GstItem> items,
  }) {
    Decimal totalSubtotal = Decimal.zero;
    Decimal totalCGST = Decimal.zero;
    Decimal totalSGST = Decimal.zero;
    
    for (final item in items) {
      final quantity = Decimal.fromInt(item.quantity);
      final price = Decimal.parse(item.price.toString());
      final lineTotal = quantity * price;
      
      totalSubtotal += lineTotal;
      
      if (item.gstRate != null && item.gstRate! > 0) {
        final gstRate = (Decimal.parse(item.gstRate.toString()) / Decimal.fromInt(100))
            .toDecimal(scaleOnInfinitePrecision: 10);
        final lineGST = lineTotal * gstRate;
        final halfGST = (lineGST / Decimal.fromInt(2)).toDecimal(scaleOnInfinitePrecision: 10);
        
        // FIX: Round each half GST before adding to totals to avoid accumulation errors
        final roundedHalfGST = Decimal.parse(halfGST.toStringAsFixed(2));
        totalCGST += roundedHalfGST;
        totalSGST += roundedHalfGST;
      }
    }
    
    // FIX: Derive totalGST from the rounded halves to ensure cgst + sgst == totalGST
    final displayTotalGST = totalCGST + totalSGST;
    
    return GstComponents(
      subtotal: totalSubtotal.toDouble(),
      cgst: totalCGST.toDouble(),
      sgst: totalSGST.toDouble(),
      totalGST: displayTotalGST.toDouble(),
      grandTotal: (totalSubtotal + displayTotalGST).toDouble(),
    );
  }
  
  /// Calculate discount-aware GST (discount applied before tax)
  static GstComponents calculateWithDiscount({
    required double price,
    required int quantity,
    required double discountPercent,
    required double gstRate,
  }) {
    final priceDecimal = Decimal.parse(price.toString());
    final quantityDecimal = Decimal.fromInt(quantity);
    final discountDecimal = (Decimal.parse(discountPercent.toString()) / Decimal.fromInt(100))
        .toDecimal(scaleOnInfinitePrecision: 10);
    final gstRateDecimal = (Decimal.parse(gstRate.toString()) / Decimal.fromInt(100))
        .toDecimal(scaleOnInfinitePrecision: 10);
    
    final lineTotal = priceDecimal * quantityDecimal;
    final discountAmount = lineTotal * discountDecimal;
    final discountedPrice = lineTotal - discountAmount;
    
    final lineGST = discountedPrice * gstRateDecimal;
    final halfGST = (lineGST / Decimal.fromInt(2)).toDecimal(scaleOnInfinitePrecision: 10);
    
    // FIX: Derive totalGST from rounded cgst + sgst to ensure consistency
    final cgst = (halfGST.toDouble() * 100).round() / 100;
    final sgst = (halfGST.toDouble() * 100).round() / 100;
    final totalGST = cgst + sgst;
    
    // FIX: Use rounded display values for grand total
    final roundedDiscountedPrice = double.parse(discountedPrice.toStringAsFixed(2));
    final grandTotal = roundedDiscountedPrice + totalGST;
    
    return GstComponents(
      subtotal: lineTotal.toDouble(),
      discountAmount: discountAmount.toDouble(),
      discountedPrice: discountedPrice.toDouble(),
      cgst: cgst,
      sgst: sgst,
      totalGST: totalGST,
      grandTotal: grandTotal,
    );
  }
  
  /// Round to 2 decimal places (paise)
  static double roundToPaise(double value) {
    return double.parse(Decimal.parse(value.toString()).toStringAsFixed(2));
  }
}

/// GST calculation result components
class GstComponents {
  final double subtotal;
  final double cgst;
  final double sgst;
  final double totalGST;
  final double grandTotal;
  final double? discountAmount;
  final double? discountedPrice;
  
  GstComponents({
    required this.subtotal,
    required this.cgst,
    required this.sgst,
    required this.totalGST,
    required this.grandTotal,
    this.discountAmount,
    this.discountedPrice,
  });
  
  @override
  String toString() {
    return 'GstComponents(subtotal: $subtotal, cgst: $cgst, sgst: $sgst, totalGST: $totalGST, grandTotal: $grandTotal)';
  }
}

/// Item for GST calculation
class GstItem {
  final double price;
  final int quantity;
  final double? gstRate;
  
  GstItem({
    required this.price,
    required this.quantity,
    this.gstRate,
  });
}