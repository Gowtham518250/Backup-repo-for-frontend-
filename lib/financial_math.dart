import 'dart:math';

/// 🔒 SECURITY & PRECISION FIX: Financial math utility to prevent floating-point errors
/// 
/// ALL GST, discount, and invoice calculations MUST use these functions.
/// NEVER use direct arithmetic (e.g., price * 1.18) as it causes precision loss.
/// 
/// Example - WRONG:
///   final gst = 999.99 * 0.18;  // = 179.9982 instead of 180
/// 
/// Example - CORRECT:
///   final gst = CurrencyManager.calculateGstAmount(999.99, 18);  // = 180.00
class CurrencyManager {
  
  /// Secure addition (prevents floating-point drift)
  static double add(double a, double b) {
    return ((a * 100).round() + (b * 100).round()) / 100;
  }
  
  /// Secure subtraction (prevents floating-point drift)
  static double subtract(double a, double b) {
    return ((a * 100).round() - (b * 100).round()) / 100;
  }
  
  /// Secure multiplication (e.g., price * qty)
  /// Always use for price calculations
  static double multiply(double price, double qty) {
    // FIX: Round the final result to 2 decimal places (paise precision).
    // The original implementation rounded only the price operand which left
    // the product of a fractional qty unrounded, e.g. 99.99 * 3.5 produced
    // 349.96499999... instead of 349.97.
    return (((price * 100).round() * qty) / 100 * 100).round() / 100;
  }
  
  /// Calculate GST amount safely (uses integer math on paise)
  /// Works in 100ths of rupee to avoid floating-point errors
  /// 
  /// Example:
  /// ```dart
  /// final gst = CurrencyManager.calculateGstAmount(999.99, 18);  // 180.00
  /// final total = CurrencyManager.add(999.99, gst);  // 1179.99
  /// ```
  static double calculateGstAmount(double basePrice, double gstPercent) {
    final basePaise = (basePrice * 100).round();
    final gstPaise = (basePaise * gstPercent) / 100.0;
    return gstPaise.round() / 100.0;
  }

  /// Calculate base price from GST-inclusive price
  /// Example: If total is 1180 with 18% GST, base = 1000
  static double calculateBasePriceFromTotal(double totalPrice, double gstPercent) {
    final rate = (100 + gstPercent) / 100;
    return (totalPrice * 100 / (rate * 100)).round() / 100;
  }

  /// Calculates total safely from a list of amounts
  /// Always use for summing invoice items
  static double sum(Iterable<double> amounts) {
    int totalPaise = 0;
    for (var amount in amounts) {
      totalPaise += (amount * 100).round();
    }
    return totalPaise / 100.0;
  }

  /// Apply discount safely
  static double applyDiscount(double amount, double discountPercent) {
    final paise = (amount * 100).round();
    final discountPaise = (paise * discountPercent) / 100.0;
    return (paise - discountPaise.round()) / 100.0;
  }

  /// Calculate percentage of amount
  static double percentOf(double amount, double percent) {
    return ((amount * 100).round() * percent / 100.0).round() / 100.0;
  }

  /// Round to nearest rupee for display (does NOT affect calculations)
  static double displayRound(double amount) {
    return (amount * 100).round() / 100.0;
  }
}
