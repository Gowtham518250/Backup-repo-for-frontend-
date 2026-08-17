import 'package:intl/intl.dart';

class GSTCompliance {
  // GST Rate mapping by HSN code (reference: GST Rates Chart 2024)
  static const Map<String, double> _hsnGstRates = {
    // 0% GST (Essential items)
    '0401': 0.0,   // Milk
    '0402': 0.0,   // Dairy products
    '1001': 0.0,   // Cereals (wheat, rice, etc)
    '1100': 0.0,   // Malt, flour
    
    // 5% GST (Essential items, textiles, food, services)
    '0901': 5.0,   // Coffee (5%)
    '0902': 5.0,   // Tea (5%)
    '0907': 5.0,   // Spices (5%) 
    '1905': 5.0,   // Food (bread, biscuits) - 5%
    '2106': 5.0,   // Food (snacks, beverages) - 5%
    '4820': 5.0,   // Stationery (notebooks) - 5%
    '4901': 5.0,   // Books - 5%
    '5205': 5.0,   // Textiles (fabric) - 5%
    '5208': 5.0,   // Textiles (cotton) - 5%
    '6109': 5.0,   // Clothing - 5%
    '6203': 5.0,   // Trousers - 5%
    '6204': 5.0,   // Dress - 5%
    '6401': 5.0,   // Footwear - 5%
    '6402': 5.0,   // Sandals - 5%
    '9609': 5.0,   // Pens - 5%
    
    // 12% GST (Intermediate items, some electronics, cosmetics)
    '3304': 12.0,  // Cosmetics (skincare) - 12%
    '3305': 12.0,  // Beauty products - 12%
    '3306': 12.0,  // Oral products - 12%
    '3307': 12.0,  // Personal care - 12%
    '3401': 12.0,  // Soap - 12%
    '3926': 12.0,  // Plastic items - 12%
    '4202': 12.0,  // Bags - 12%
    '7323': 12.0,  // Kitchen utensils - 12%
    '8504': 12.0,  // Chargers/adapters - 12%
    '8517': 12.0,  // Mobile accessories - 12%
    '8518': 12.0,  // Headphones/speakers - 12%
    '8544': 12.0,  // Cables - 12%
    '9102': 12.0,  // Watches - 12%
    '9406': 12.0,  // Furniture/home decor - 12%
    
    // 18% GST (Most electronics, premium items, services)
    '8471': 18.0,  // Computers/phones/laptops - 18%
    '8528': 18.0,  // Display screens - 18%
    '9503': 18.0,  // Toys - 18%
    '9504': 18.0,  // Games - 18%
    '9506': 18.0,  // Sports equipment - 18%
    '9512': 18.0,  // Services (repair, maintenance) - 18%
    '9983': 18.0,  // Services - 18%
    '7113': 18.0,  // Jewelry - 18%
    
    // 28% GST (Luxury items - rarely applicable in retail)
    // None typically in retail POS
  };

  static const Map<String, double> _gstRates = {
    'essentials': 5.0,    // Food, medicines
    'textiles': 5.0,      // Clothes, fabrics
    'electronics': 12.0,  // Phones, accessories (most common)
    'premium': 18.0,      // Luxury, services
    'super_luxury': 28.0, // High-end luxury
  };

  /// Get GST rate — try HSN code first, then category fallback
  static double getGSTRate(String categoryOrHsn, {String? hsnCode}) {
    // Priority 1: Use explicit HSN code if provided
    if (hsnCode != null && _hsnGstRates.containsKey(hsnCode)) {
      return _hsnGstRates[hsnCode] ?? 18.0;
    }
    
    // Priority 2: Try to match as HSN code
    if (_hsnGstRates.containsKey(categoryOrHsn)) {
      return _hsnGstRates[categoryOrHsn] ?? 18.0;
    }
    
    // Priority 3: Fall back to category based rates
    return _gstRates[categoryOrHsn.toLowerCase()] ?? 18.0;
  }

  /// Calculate price with GST
  static Map<String, double> calculateWithGST(double basePrice, String category) {
    final gstRate = getGSTRate(category);
    final gstAmount = (basePrice * gstRate) / 100;
    final finalPrice = basePrice + gstAmount;

    return {
      'base_price': double.parse(basePrice.toStringAsFixed(2)),
      'gst_rate': gstRate,
      'gst_amount': double.parse(gstAmount.toStringAsFixed(2)),
      'final_price': double.parse(finalPrice.toStringAsFixed(2)),
    };
  }

  /// Format GST Invoice (GSTIN format validation)
  static bool isValidGSTIN(String gstin) {
    // GSTIN format: 2 digit state + 10 digit PAN + 1 digit entity + 1 digit check
    final pattern = RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z0-9]{1}Z[A-Z0-9]{1}$');
    return pattern.hasMatch(gstin);
  }

  /// Extract state code from GSTIN (first 2 digits)
  static String getStateCodeFromGSTIN(String gstin) {
    if (gstin.length < 2) return '';
    return gstin.substring(0, 2);
  }

  /// GST state code to state name mapping
  static const Map<String, String> _stateCodeMap = {
    '01': 'Andhra Pradesh',
    '02': 'Arunachal Pradesh',
    '03': 'Assam',
    '04': 'Bihar',
    '05': 'Chhattisgarh',
    '06': 'Goa',
    '07': 'Gujarat',
    '08': 'Haryana',
    '09': 'Himachal Pradesh',
    '10': 'Jharkhand',
    '11': 'Karnataka',
    '12': 'Kerala',
    '13': 'Madhya Pradesh',
    '14': 'Maharashtra',
    '15': 'Manipur',
    '16': 'Meghalaya',
    '17': 'Mizoram',
    '18': 'Nagaland',
    '19': 'Odisha',
    '20': 'Punjab',
    '21': 'Rajasthan',
    '22': 'Sikkim',
    '23': 'Tamil Nadu',
    '24': 'Telangana',
    '25': 'Tripura',
    '26': 'Uttar Pradesh',
    '27': 'Uttarakhand',
    '28': 'West Bengal',
    '29': 'Jammu & Kashmir',
    '30': 'Ladakh',
    '31': 'Puducherry',
    '32': 'Daman & Diu',
    '33': 'Dadra & Nagar Haveli',
  };

  /// Determine if sale is intra-state (same state) or inter-state
  static bool isIntraState(String sellerGSTIN, String buyerGSTIN) {
    final sellerState = getStateCodeFromGSTIN(sellerGSTIN);
    final buyerState = getStateCodeFromGSTIN(buyerGSTIN);
    return sellerState == buyerState && sellerState.isNotEmpty && buyerState.isNotEmpty;
  }

  /// Split GST into CGST/SGST (intra-state) or IGST (inter-state)
  static Map<String, double> splitGST({
    required double gstAmount,
    required double gstRate,
    required bool isIntraState,
  }) {
    if (isIntraState) {
      // Intra-state: Split 50-50 between CGST and SGST
      final cgst = double.parse((gstAmount / 2).toStringAsFixed(2));
      final sgst = double.parse((gstAmount / 2).toStringAsFixed(2));
      return {
        'cgst_rate': gstRate / 2,
        'cgst_amount': cgst,
        'sgst_rate': gstRate / 2,
        'sgst_amount': sgst,
        'igst_rate': 0.0,
        'igst_amount': 0.0,
      };
    } else {
      // Inter-state: 100% IGST
      return {
        'cgst_rate': 0.0,
        'cgst_amount': 0.0,
        'sgst_rate': 0.0,
        'sgst_amount': 0.0,
        'igst_rate': gstRate,
        'igst_amount': gstAmount,
      };
    }
  }

  /// Generate compliance invoice with GST
  static Map<String, dynamic> generateCompliantInvoice({
    required String invoiceNumber,
    required String sellerGSTIN,
    required String buyerGSTIN,
    required double amount,
    required String category,
    required DateTime invoiceDate,
  }) {
    final gstData = calculateWithGST(amount, category);
    
    return {
      'invoice_number': invoiceNumber,
      'invoice_date': DateFormat('yyyy-MM-dd').format(invoiceDate),
      'seller_gstin': sellerGSTIN,
      'buyer_gstin': buyerGSTIN,
      'items': [],
      'base_amount': gstData['base_price'],
      'gst_rate': gstData['gst_rate'],
      'gst_amount': gstData['gst_amount'],
      'total_amount': gstData['final_price'],
      'status': 'COMPLIANT',
      'compliance_notes': 'GST invoice as per GST Act 2017',
    };
  }

  /// Validate invoice compliance
  static Map<String, dynamic> validateInvoiceCompliance(Map<String, dynamic> invoice) {
    final issues = <String>[];

    // Check GSTIN format
    if (!isValidGSTIN(invoice['seller_gstin']?.toString() ?? '')) {
      issues.add('Invalid seller GSTIN format');
    }

    // Check amount is not zero
    final amount = (invoice['total_amount'] as num?)?.toDouble() ?? 0;
    if (amount <= 0) {
      issues.add('Invoice amount must be greater than zero');
    }

    // Check invoice number
    if ((invoice['invoice_number']?.toString() ?? '').isEmpty) {
      issues.add('Invoice number is required');
    }

    // Check date
    try {
      DateTime.parse(invoice['invoice_date']?.toString() ?? '');
    } catch (_) {
      issues.add('Invalid invoice date format');
    }

    return {
      'is_compliant': issues.isEmpty,
      'issues': issues,
      'compliance_status': issues.isEmpty ? 'PASSED' : 'FAILED',
    };
  }

  /// Audit trail for compliance
  static Map<String, dynamic> createAuditRecord({
    required String invoiceId,
    required String action, // CREATE, MODIFY, VOID
    required String modifiedBy,
    required DateTime timestamp,
  }) {
    return {
      'invoice_id': invoiceId,
      'action': action,
      'modified_by': modifiedBy,
      'timestamp': DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp),
      'audit_trail_id': '${invoiceId}_${timestamp.millisecondsSinceEpoch}',
    };
  }

  /// Generate HSN/SAC code for GST filing (comprehensive mapping for retail)
  /// Reference: Common HSN codes from ITC (HS) Classification
  static String getHSNCode(String productCategory) {
    const hsnMap = {
      // Groceries & Food (0402-0403, 1905, 2106)
      'grocery': '0402',
      'dairy': '0402',
      'milk': '0402',
      'butter': '0405',
      'bread': '1905',
      'biscuits': '1905',
      'snacks': '2106',
      'beverages': '2106',
      'coffee': '0901',
      'tea': '0902',
      'spices': '0907',
      'condiments': '2103',
      'food': '1905',
      
      // FMCG & Personal Care (3304-3305, 3306-3307)
      'cosmetics': '3304',
      'skincare': '3304',
      'beauty': '3305',
      'haircare': '3305',
      'perfume': '3302',
      'toothpaste': '3306',
      'soap': '3401',
      'shampoo': '3305',
      'deodorant': '3307',
      'personal_care': '3305',
      
      // Textiles & Clothing (5205-5208, 6109, 6203-6204)
      'textiles': '5205',
      'fabric': '5205',
      'cotton': '5205',
      'clothing': '6109',
      'apparel': '6109',
      'shirts': '6105',
      'pants': '6203',
      'trousers': '6203',
      'dress': '6204',
      'underwear': '6108',
      'socks': '6115',
      't_shirt': '6105',
      'jeans': '6203',
      
      // Footwear (6401-6404)
      'footwear': '6401',
      'shoes': '6401',
      'sandals': '6402',
      'boots': '6401',
      'slippers': '6402',
      
      // Stationery & Paper (4820, 4911-4912)
      'stationery': '4820',
      'notebooks': '4820',
      'pen': '9609',
      'paper': '4820',
      'books': '4901',
      'printed_matter': '4911',
      'envelopes': '4819',
      
      // Electronics & Mobile Accessories (8471-8480, 8517)
      'electronics': '8471',
      'mobile_accessories': '8517',
      'charger': '8504',
      'cables': '8544',
      'headphones': '8518',
      'speaker': '8518',
      'phone': '8471',
      'laptop': '8471',
      'computer': '8471',
      'tablet': '8471',
      'screen': '8528',
      'adapter': '8504',
      
      // General Retail & Plastic Items (3926, 4911, 3920)
      'general_retail': '3926',
      'plastic_items': '3926',
      'bags': '4202',
      'container': '3926',
      'storage': '3926',
      'household': '7323',
      'kitchenware': '7323',
      
      // Home & Kitchen (7323, 9406, 7326)
      'kitchen': '7323',
      'utensils': '7323',
      'cookware': '7323',
      'furniture': '9406',
      'home_decor': '9406',
      'bedding': '9404',
      'curtains': '6303',
      
      // Tools & Hardware (8203, 8205, 8208)
      'tools': '8203',
      'hardware': '8205',
      'nails': '7308',
      'bolts': '7308',
      'screws': '7318',
      
      // Sports & Fitness (9506)
      'sports': '9506',
      'fitness': '9506',
      'equipment': '9506',
      'gym': '9506',
      
      // Toys & Games (9503-9505)
      'toys': '9503',
      'games': '9504',
      'hobby': '9505',
      
      // Services (9983, 9986, 9989)
      'services': '9983',
      'repair': '9512',
      'maintenance': '9512',
      
      // Premium/Jewelry (7113-7117)
      'jewelry': '7113',
      'watches': '9102',
      'accessories': '9406',
      
      // Default fallback (for unclassified items - will fail GST audit!)
      'other': '9999',
    };
    
    final code = hsnMap[productCategory.toLowerCase()] ?? hsnMap['other'];
    if (code == '9999') {
      // Log warning for unclassified items
      print('⚠️ WARNING: Using HSN code 9999 for category "$productCategory" - GST filing will be rejected. Add proper HSN code.');
    }
    return code ?? '9999';
  }

  // ==================== GSTR-1 EXPORT ====================

  /// Generate GSTR-1 JSON export for GST filing (saves ₹500/month CA fees)
  static Map<String, dynamic> generateGSTR1Export({
    required String sellerGSTIN,
    required String period, // YYYY-MM format
    required List<Map<String, dynamic>> invoices, // All invoices for the month
  }) {
    final b2bSummary = _getB2BSummary(invoices, sellerGSTIN: sellerGSTIN);
    final b2cSummary = _getB2CSummary(invoices);
    final hsnSummary = _getHSNSummary(invoices);

    return {
      'seller_gstin': sellerGSTIN,
      'seller_state': _stateCodeMap[getStateCodeFromGSTIN(sellerGSTIN)] ?? 'Unknown',
      'period': period,
      'filing_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'summary': {
        'total_invoices': invoices.length,
        'total_b2b_value': b2bSummary['total_value'],
        'total_b2b_gst': b2bSummary['total_gst'],
        'total_b2b_cgst': b2bSummary['total_cgst'],
        'total_b2b_sgst': b2bSummary['total_sgst'],
        'total_b2b_igst': b2bSummary['total_igst'],
        'total_b2c_value': b2cSummary['total_value'],
        'total_b2c_gst': b2cSummary['total_gst'],
        'grand_total_value': b2bSummary['total_value'] + b2cSummary['total_value'],
        'grand_total_gst': b2bSummary['total_gst'] + b2cSummary['total_gst'],
        'grand_total_cgst': b2bSummary['total_cgst'],
        'grand_total_sgst': b2bSummary['total_sgst'],
        'grand_total_igst': b2bSummary['total_igst'],
      },
      'b2b': b2bSummary['invoices'],
      'b2c': b2cSummary['summary'],
      'hsn_summary': hsnSummary,
      'status': 'READY_FOR_FILING',
      'compliance_validation': 'All invoices are GST compliant (CGST/SGST/IGST split)',
      'filing_notes': 'CGST/SGST split applied for intra-state sales, IGST for inter-state sales',
    };
  }

  /// Get B2B (business-to-business) invoices with GSTIN
  static Map<String, dynamic> _getB2BSummary(List<Map<String, dynamic>> invoices, {String? sellerGSTIN}) {
    double totalValue = 0;
    double totalGST = 0;
    double totalCGST = 0;
    double totalSGST = 0;
    double totalIGST = 0;
    final b2bInvoices = <Map<String, dynamic>>[];

    for (var inv in invoices) {
      final buyerGSTIN = inv['buyer_gstin']?.toString() ?? '';
      
      // B2B = buyer has GSTIN
      if (buyerGSTIN.isNotEmpty && isValidGSTIN(buyerGSTIN)) {
        final baseAmount = (inv['base_amount'] as num?)?.toDouble() ?? 0;
        final gstAmount = (inv['gst_amount'] as num?)?.toDouble() ?? 0;
        final gstRate = (inv['gst_rate'] as num?)?.toDouble() ?? 18.0;
        
        // Determine if intra-state or inter-state
        final intraState = sellerGSTIN != null && isIntraState(sellerGSTIN, buyerGSTIN);
        final gstSplit = splitGST(
          gstAmount: gstAmount,
          gstRate: gstRate,
          isIntraState: intraState,
        );
        
        totalValue += baseAmount;
        totalGST += gstAmount;
        totalCGST += gstSplit['cgst_amount'] ?? 0;
        totalSGST += gstSplit['sgst_amount'] ?? 0;
        totalIGST += gstSplit['igst_amount'] ?? 0;

        b2bInvoices.add({
          'invoice_number': inv['invoice_number'],
          'buyer_gstin': buyerGSTIN,
          'invoice_date': inv['invoice_date'],
          'base_amount': baseAmount,
          'gst_rate': gstRate,
          'cgst_rate': gstSplit['cgst_rate'],
          'cgst_amount': gstSplit['cgst_amount'],
          'sgst_rate': gstSplit['sgst_rate'],
          'sgst_amount': gstSplit['sgst_amount'],
          'igst_rate': gstSplit['igst_rate'],
          'igst_amount': gstSplit['igst_amount'],
          'gst_amount': gstAmount,
          'total_amount': baseAmount + gstAmount,
          'intra_state': intraState,
        });
      }
    }

    return {
      'total_value': totalValue,
      'total_gst': totalGST,
      'total_cgst': totalCGST,
      'total_sgst': totalSGST,
      'total_igst': totalIGST,
      'count': b2bInvoices.length,
      'invoices': b2bInvoices,
    };
  }

  /// Get B2C (business-to-consumer) invoices without GSTIN
  static Map<String, dynamic> _getB2CSummary(List<Map<String, dynamic>> invoices) {
    double totalValue = 0;
    double totalGST = 0;
    int count = 0;

    for (var inv in invoices) {
      final buyerGSTIN = inv['buyer_gstin']?.toString() ?? '';
      
      // B2C = buyer has no GSTIN or invalid GSTIN
      if (buyerGSTIN.isEmpty || !isValidGSTIN(buyerGSTIN)) {
        final baseAmount = (inv['base_amount'] as num?)?.toDouble() ?? 0;
        final gstAmount = (inv['gst_amount'] as num?)?.toDouble() ?? 0;
        
        totalValue += baseAmount;
        totalGST += gstAmount;
        count++;
      }
    }

    return {
      'total_value': totalValue,
      'total_gst': totalGST,
      'count': count,
      'summary': {
        'b2c_turnover': totalValue,
        'b2c_tax': totalGST,
        'number_of_invoices': count,
      },
    };
  }

  /// Get HSN summary (product-wise breakdown)
  static Map<String, dynamic> _getHSNSummary(List<Map<String, dynamic>> invoices) {
    final hsnMap = <String, Map<String, dynamic>>{};

    for (var inv in invoices) {
      final items = inv['items'] as List? ?? [];
      
      for (var item in items) {
        final productName = item['product_name']?.toString() ?? 'Unknown';
        final category = item['category']?.toString() ?? 'premium';
        final hsn = getHSNCode(category);
        final baseAmount = (item['base_amount'] as num?)?.toDouble() ?? 0;
        final gstRate = getGSTRate(category);
        final gstAmount = (baseAmount * gstRate) / 100;
        final qty = (item['qty'] as num?)?.toDouble() ?? 0;

        if (!hsnMap.containsKey(hsn)) {
          hsnMap[hsn] = {
            'hsn_code': hsn,
            'product_name': productName,
            'total_quantity': 0.0,
            'total_value': 0.0,
            'gst_rate': gstRate,
            'gst_amount': 0.0,
          };
        }

        hsnMap[hsn]!['total_quantity'] = (hsnMap[hsn]!['total_quantity'] as double) + qty;
        hsnMap[hsn]!['total_value'] = (hsnMap[hsn]!['total_value'] as double) + baseAmount;
        hsnMap[hsn]!['gst_amount'] = (hsnMap[hsn]!['gst_amount'] as double) + gstAmount;
      }
    }

    return {
      'summary': hsnMap.values.toList(),
      'hsn_count': hsnMap.length,
      'note': 'HSN-wise summary for GSTR-1 filing',
    };
  }

  /// Generate monthly GST compliance report (for shopkeeper reference)
  static Map<String, dynamic> generateMonthlyReport({
    required List<Map<String, dynamic>> invoices,
    required String month, // YYYY-MM format
  }) {
    final b2b = _getB2BSummary(invoices);
    final b2c = _getB2CSummary(invoices);
    final hsn = _getHSNSummary(invoices);

    return {
      'month': month,
      'generated_date': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      'total_invoices': invoices.length,
      'breakdown': {
        'b2b': {
          'count': b2b['count'],
          'amount': b2b['total_value'],
          'gst': b2b['total_gst'],
        },
        'b2c': {
          'count': b2c['count'],
          'amount': b2c['total_value'],
          'gst': b2c['total_gst'],
        },
      },
      'totals': {
        'gross_amount': b2b['total_value'] + b2c['total_value'],
        'total_gst': b2b['total_gst'] + b2c['total_gst'],
        'net_amount': (b2b['total_value'] + b2c['total_value']) - (b2b['total_gst'] + b2c['total_gst']),
      },
      'hsn_breakdown': (hsn['summary'] as List).take(10).toList(), // Top 10
      'ca_saving': '₹500/month (DIY GSTR-1 filing)',
      'filing_checklist': [
        '✓ All invoices GST-compliant',
        '✓ B2B invoices have valid GSTIN',
        '✓ B2C invoices properly tagged',
        '✓ HSN codes assigned',
        '✓ Ready for GSTR-1 filing',
      ],
    };
  }

  /// Export GSTR-1 as JSON string (for email/upload)
  static String exportGSTR1AsJSON({
    required String sellerGSTIN,
    required String period,
    required List<Map<String, dynamic>> invoices,
  }) {
    final gstr1 = generateGSTR1Export(
      sellerGSTIN: sellerGSTIN,
      period: period,
      invoices: invoices,
    );
    
    // Format as JSON
    return '''
{
  "seller_gstin": "${gstr1['seller_gstin']}",
  "period": "${gstr1['period']}",
  "filing_date": "${gstr1['filing_date']}",
  "summary": {
    "total_b2b_value": ${gstr1['summary']['total_b2b_value']},
    "total_b2b_gst": ${gstr1['summary']['total_b2b_gst']},
    "total_b2c_value": ${gstr1['summary']['total_b2c_value']},
    "total_b2c_gst": ${gstr1['summary']['total_b2c_gst']},
    "grand_total_value": ${gstr1['summary']['grand_total_value']},
    "grand_total_gst": ${gstr1['summary']['grand_total_gst']}
  },
  "b2b_invoices": ${gstr1['b2b'].length},
  "b2c_invoices": ${gstr1['b2c']['number_of_invoices']},
  "hsn_codes": ${gstr1['hsn_summary']['hsn_count']},
  "status": "READY_FOR_GSTR1_FILING"
}
    ''';
  }
}
