import 'dart:convert';
import 'scoped_shared_preferences.dart';

/// Scheme/Offer Engine for auto-applying promotional discounts
/// Supports: PERCENT_OFF, FLAT_OFF, BOGO (Buy One Get One), MIN_QTY_FREE
class SchemeEngine {
  // Scheme types
  static const String PERCENT_OFF = 'PERCENT_OFF';
  static const String FLAT_OFF = 'FLAT_OFF';
  static const String BOGO = 'BOGO';
  static const String MIN_QTY_FREE = 'MIN_QTY_FREE';

  /// Load all active schemes from local storage
  static Future<List<Map<String, dynamic>>> loadSchemes() async {
    try {
      final raw = await ScopedSharedPreferences.getString('active_schemes') ?? '[]';
      final decoded = jsonDecode(raw) as List?;
      return decoded != null 
          ? List<Map<String, dynamic>>.from(decoded.map((e) => Map<String, dynamic>.from(e as Map)))
          : [];
    } catch (e) {
      return [];
    }
  }

  /// Save a new scheme (shopkeeper creates via UI)
  static Future<void> saveScheme(Map<String, dynamic> scheme) async {
    try {
      final schemes = await loadSchemes();
      schemes.add({
        ...scheme,
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'active': true,
        'created_at': DateTime.now().toIso8601String(),
      });
      await ScopedSharedPreferences.setString('active_schemes', jsonEncode(schemes));
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a scheme by ID
  static Future<void> deleteScheme(String schemeId) async {
    try {
      final schemes = await loadSchemes();
      schemes.removeWhere((s) => s['id'] == schemeId);
      await ScopedSharedPreferences.setString('active_schemes', jsonEncode(schemes));
    } catch (e) {
      rethrow;
    }
  }

  /// Apply best applicable scheme to cart items and return discount details (ASYNC)
  static Future<Map<String, dynamic>> applyBestSchemeAsync(
    List<Map<String, dynamic>> items,
    double subtotal,
  ) async {
    // Default: no discount
    Map<String, dynamic> bestResult = {
      'discount_amount': 0.0,
      'scheme_name': '',
      'scheme_type': '',
      'final_total': subtotal,
    };

    try {
      if (items.isEmpty || subtotal == 0) return bestResult;

      final schemes = await loadSchemes();
      double bestDiscount = 0.0;
      String bestName = '';
      String bestType = '';

      for (final scheme in schemes) {
        if (!isSchemeValid(scheme)) continue;

        double discount = 0.0;
        final type = scheme['type']?.toString() ?? '';

        // PERCENT_OFF: discount if minimum order met
        if (type == PERCENT_OFF) {
          final minOrder = (scheme['min_order'] as num?)?.toDouble() ?? 0;
          if (subtotal >= minOrder) {
            final percent = (scheme['percent'] as num?)?.toDouble() ?? 0;
            discount = applyPercentScheme(subtotal, percent);
          }
        }
        // FLAT_OFF: flat amount deduction
        else if (type == FLAT_OFF) {
          final minOrder = (scheme['min_order'] as num?)?.toDouble() ?? 0;
          if (subtotal >= minOrder) {
            final flatAmount = (scheme['flat_amount'] as num?)?.toDouble() ?? 0;
            discount = applyFlatScheme(subtotal, flatAmount);
          }
        }
        // BOGO: buy one get one free
        else if (type == BOGO) {
          final triggerQty = (scheme['trigger_qty'] as num?)?.toInt() ?? 0;
          final freeItemPrice = (scheme['free_item_price'] as num?)?.toDouble() ?? 0;
          discount = applyBogoScheme(
            items: items,
            triggerQty: triggerQty,
            freeItemPrice: freeItemPrice,
          );
        }
        // MIN_QTY_FREE: free items after minimum quantity
        else if (type == MIN_QTY_FREE) {
          final minQty = (scheme['min_qty'] as num?)?.toInt() ?? 0;
          final pricePerUnit = (scheme['price_per_unit'] as num?)?.toDouble() ?? 0;
          discount = applyMinQtyFreeScheme(
            items: items,
            minQty: minQty,
            pricePerUnit: pricePerUnit,
          );
        }

        // Keep best discount
        if (discount > bestDiscount) {
          bestDiscount = discount;
          bestName = scheme['name']?.toString() ?? '';
          bestType = type;
        }
      }

      if (bestDiscount > 0) {
        return {
          'discount_amount': bestDiscount,
          'scheme_name': bestName,
          'scheme_type': bestType,
          'final_total': subtotal - bestDiscount,
        };
      }

      return bestResult;
    } catch (e) {
      return bestResult;
    }
  }

  /// Legacy sync method - kept for backward compatibility
  /// Kept for backward compatibility
  @deprecated
  static Map<String, dynamic> applyBestScheme(
    List<Map<String, dynamic>> items,
    double subtotal,
  ) {
    // Default: no discount
    return {
      'discount_amount': 0.0,
      'scheme_name': '',
      'scheme_type': '',
      'final_total': subtotal,
    };
  }

  /// Apply percentage discount scheme
  static double applyPercentScheme(double subtotal, double percent) {
    return subtotal * (percent / 100);
  }

  /// Apply flat discount scheme
  static double applyFlatScheme(double subtotal, double flatAmount) {
    return flatAmount;
  }

  /// Apply BOGO (Buy One Get One) scheme - free item on bulk purchase
  static double applyBogoScheme({
    required List<Map<String, dynamic>> items,
    required int triggerQty,
    required double freeItemPrice,
  }) {
    final totalQty = items.fold<double>(0, (sum, item) {
      final qty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
      return sum + qty;
    });

    if (totalQty >= triggerQty) {
      return freeItemPrice; // Free item
    }
    return 0.0;
  }

  /// Apply minimum quantity free scheme
  static double applyMinQtyFreeScheme({
    required List<Map<String, dynamic>> items,
    required int minQty,
    required double pricePerUnit,
  }) {
    final totalQty = items.fold<double>(0, (sum, item) {
      final qty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
      return sum + qty;
    });

    if (totalQty >= minQty) {
      return (totalQty ~/ minQty) * pricePerUnit;
    }
    return 0.0;
  }

  /// Create a PERCENT_OFF scheme (template)
  static Map<String, dynamic> createPercentScheme({
    required String name,
    required double percent,
    required double minOrder,
    required DateTime validFrom,
    required DateTime validUpto,
  }) {
    return {
      'type': PERCENT_OFF,
      'name': name,
      'percent': percent,
      'min_order': minOrder,
      'valid_from': validFrom.toIso8601String(),
      'valid_upto': validUpto.toIso8601String(),
    };
  }

  /// Create a FLAT_OFF scheme (template)
  static Map<String, dynamic> createFlatScheme({
    required String name,
    required double flatAmount,
    required double minOrder,
    required DateTime validFrom,
    required DateTime validUpto,
  }) {
    return {
      'type': FLAT_OFF,
      'name': name,
      'flat_amount': flatAmount,
      'min_order': minOrder,
      'valid_from': validFrom.toIso8601String(),
      'valid_upto': validUpto.toIso8601String(),
    };
  }

  /// Create a BOGO scheme (template)
  static Map<String, dynamic> createBogoScheme({
    required String name,
    required int triggerQty,
    required double freeItemPrice,
    required DateTime validFrom,
    required DateTime validUpto,
  }) {
    return {
      'type': BOGO,
      'name': name,
      'trigger_qty': triggerQty,
      'free_item_price': freeItemPrice,
      'valid_from': validFrom.toIso8601String(),
      'valid_upto': validUpto.toIso8601String(),
    };
  }

  /// Check if scheme is valid for today
  static bool isSchemeValid(Map<String, dynamic> scheme) {
    try {
      final now = DateTime.now();
      final validFrom = DateTime.parse(scheme['valid_from']?.toString() ?? '');
      final validUpto = DateTime.parse(scheme['valid_upto']?.toString() ?? '');
      return now.isAfter(validFrom) && now.isBefore(validUpto);
    } catch (e) {
      return false;
    }
  }
}
