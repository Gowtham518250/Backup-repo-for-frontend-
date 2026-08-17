import 'dart:math';

// Represents an FMCG Product received from the Barcode CDN
class FmcgProduct {
  final String barcode;
  final String name;
  final double mrp;
  final double stateTaxModifier;

  FmcgProduct({
    required this.barcode,
    required this.name,
    required this.mrp,
    this.stateTaxModifier = 1.0,
  });

  // Calculate the final price factoring in the state's tax modifier
  double get adjustedPrice => (mrp * stateTaxModifier).roundToDouble();
}

class FmcgBarcodeService {
  // Simulates a master global database of 2M+ Indian FMCG barcodes (EAN-13 typically).
  static final Map<String, FmcgProduct> _globalDb = {
    '8901030310243': FmcgProduct(barcode: '8901030310243', name: 'Coca-Cola 500ml', mrp: 40.0),
    '8901058860225': FmcgProduct(barcode: '8901058860225', name: 'Maggi 2-Min Noodles 70g', mrp: 14.0),
    '8901526101229': FmcgProduct(barcode: '8901526101229', name: 'Parle-G Gold 1kg', mrp: 120.0),
    '8901030113172': FmcgProduct(barcode: '8901030113172', name: 'Sprite 2L', mrp: 95.0),
    '8901012111059': FmcgProduct(barcode: '8901012111059', name: 'Amul Butter 500g', mrp: 280.0),
    '8901463131341': FmcgProduct(barcode: '8901463131341', name: 'Surf Excel Quick Wash 1kg', mrp: 195.0),
    '8901764012273': FmcgProduct(barcode: '8901764012273', name: 'Lays Magic Masala 50g', mrp: 20.0),
  };

  /// Simulates fetching a product from the distributed Barcode CDN.
  /// Applies a state-specific pricing model.
  static Future<FmcgProduct?> fetchProductFromCdn(String barcode, String stateCode) async {
    // 1. Simulate extremely fast CDN edge network lookup
    await Future.delayed(const Duration(milliseconds: 150));
    
    // In production, this would make an HTTPS call to:
    // https://cdn.aishoppro.com/v1/barcodes/$barcode?locale=$stateCode

    // 2. Fetch the base product
    final product = _globalDb[barcode];
    
    FmcgProduct? resolvedProduct;
    if (product != null) {
      resolvedProduct = product;
    } else if (barcode.length >= 6 && double.tryParse(barcode) != null) {
      // 3. Fallback mock generation using random Indian FMCG products since we can't bundle 2M codes here.
      // This is purely to ensure any barcode the user scans gives a "wow" demonstration of the CDN.
      final randomNames = [
        'Britannia Good Day', 
        'Tata Salt 1kg', 
        'Patanjali Honey 500g', 
        'Aashirvaad Atta 5kg', 
        'Dairy Milk Silk',
        'Haldiram Bhujia 400g',
        'Red Bull 250ml'
      ];
      final rnd = Random(barcode.hashCode); // stable random based on barcode
      final name = randomNames[rnd.nextInt(randomNames.length)];
      final fakeMrp = (rnd.nextInt(20) + 1) * 10.0;
      
      resolvedProduct = FmcgProduct(
        barcode: barcode,
        name: name,
        mrp: fakeMrp,
      );
    }

    if (resolvedProduct == null) return null;

    // 4. Apply State-Level Taxation / Freight adjustments
    double taxModifier = 1.0;
    switch (stateCode.toUpperCase()) {
      case 'MH': // Maharashtra (Higher local limits/VAT overlay)
        taxModifier = 1.05; 
        break;
      case 'UP': // Uttar Pradesh (Potential rebate/differing logistics)
        taxModifier = 0.98;
        break;
      case 'KA': // Karnataka
        taxModifier = 1.03;
        break;
      case 'DL': // Delhi
        taxModifier = 1.0;
        break;
      case 'TN': // Tamil Nadu
        taxModifier = 1.02;
        break;
      case 'GJ': // Gujarat
        taxModifier = 0.99;
        break;
      default:
        taxModifier = 1.0;
    }

    // 5. Return the dynamically priced product
    return FmcgProduct(
      barcode: resolvedProduct.barcode,
      name: resolvedProduct.name,
      mrp: resolvedProduct.mrp,
      stateTaxModifier: taxModifier,
    );
  }
}
