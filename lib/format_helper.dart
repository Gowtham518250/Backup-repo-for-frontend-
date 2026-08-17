import 'package:intl/intl.dart';

class FormatHelper {
  /// Formats a number into Indian style (Lakh, Crore) or K for shorter counts.
  /// Example: 150000 -> 1.5 Lakh, 10000000 -> 1 Crore
  static String formatRevenue(double amount) {
    if (amount < 1000) {
      return '₹${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}';
    }

    if (amount < 99999.5) {
      // Use K for values under 1 Lakh (rounded)
      double k = amount / 1000;
      return '₹${k.toStringAsFixed(k >= 10 ? 0 : 1)}K';
    }

    if (amount < 10000000) {
      // Lakh: 1,00,000 to 99,99,999
      double lakh = amount / 100000;
      return '₹${lakh.toStringAsFixed(lakh % 1 == 0 ? 0 : 1)} Lakh';
    }

    // Crore: 1,00,00,000+
    double crore = amount / 10000000;
    return '₹${crore.toStringAsFixed(crore % 1 == 0 ? 0 : 2)} Crore';
  }

  /// Simple comma separation for Indian currency format if requested.
  static String formatIndianCurrency(double amount) {
    final format = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return format.format(amount);
  }

  /// Normalizes product names for consistent matching (e.g. "Ghee" -> "ghee")
  static String normalizeName(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
  }
}
