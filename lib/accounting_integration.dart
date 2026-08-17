import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AccountingSoftware {
  tally,
  quickBooks,
  gst,
  mitra,
  busy,
  fintech,
}

class AccountingIntegration {
  static String _escapeXml(String text) {
    return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
  }

  /// Generate Tally-compatible XML format
  static String generateTallyXML(List<Map<String, dynamic>> sales, {
    required String shopName,
    required String gstIn,
    String period = 'Monthly',
  }) {
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="utf-8"?>\n');
    buffer.write('<TALLYREQUEST>\n');
    buffer.write('  <COMPANYNAME>${_escapeXml(shopName)}</COMPANYNAME>\n');
    
    final totalAmount = sales.fold(0.0, (sum, sale) => sum + (sale['total'] as num? ?? 0));
    final taxable = totalAmount / 1.18; // Assuming 18% GST
    final taxAmount = totalAmount - taxable;

    buffer.write('  <INVOICES>\n');
    for (int i = 0; i < sales.length; i++) {
      final sale = sales[i];
      buffer.write('    <INVOICE>\n');
      buffer.write('      <INVOICENO>${i + 1}</INVOICENO>\n');
      buffer.write('      <DATE>${_formatDateDDMMYYYY(sale['date'])}</DATE>\n');
      buffer.write('      <PRODUCT>${_escapeXml(sale['product']?.toString() ?? 'N/A')}</PRODUCT>\n');
      buffer.write('      <QUANTITY>${sale['quantity'] ?? 0}</QUANTITY>\n');
      buffer.write('      <RATE>${(sale['price'] as num? ?? 0).toStringAsFixed(2)}</RATE>\n');
      buffer.write('      <GROSS>${(sale['total'] as num? ?? 0).toStringAsFixed(2)}</GROSS>\n');
      buffer.write('      <PAYMENTMODE>${_escapeXml(sale['paymentMethod']?.toString() ?? 'Cash')}</PAYMENTMODE>\n');
      buffer.write('    </INVOICE>\n');
    }
    buffer.write('  </INVOICES>\n');

    buffer.write('  <SUMMARY>\n');
    buffer.write('    <TOTALINVOICES>${sales.length}</TOTALINVOICES>\n');
    buffer.write('    <TOTALGROSS>${totalAmount.toStringAsFixed(2)}</TOTALGROSS>\n');
    buffer.write('    <TAXABLE>${taxable.toStringAsFixed(2)}</TAXABLE>\n');
    buffer.write('    <TAX>${taxAmount.toStringAsFixed(2)}</TAX>\n');
    buffer.write('    <GSTIN>${_escapeXml(gstIn)}</GSTIN>\n');
    buffer.write('    <PERIOD>${_escapeXml(period)}</PERIOD>\n');
    buffer.write('  </SUMMARY>\n');

    buffer.write('</TALLYREQUEST>\n');
    return buffer.toString();
  }

  /// Generate QuickBooks-compatible IIF format
  static String generateQuickBooksIIF(List<Map<String, dynamic>> sales, {
    required String companyName,
  }) {
    final buffer = StringBuffer();
    buffer.write('!ACCNT\tNAME\tACCNUM\tDESC\tACCNTTYPE\tDESC\tEXTRA\n');
    buffer.write('ACCNT\tSales\t4100\tProduct Sales\tINCOME\t\t\n');
    buffer.write('ENDACCNT\n\n');

    buffer.write('!TRNS\tTRNSID\tTRNSTYPE\tDATE\tACCNT\tNAME\tDESC\tAMOUNT\n');
    buffer.write('!SPL\tSPLID\tTRNSTYPE\tDATE\tACCNT\tAMOUNT\tDESC\n');
    buffer.write('!ENDTRNS\n\n');

    for (int i = 0; i < sales.length; i++) {
      final sale = sales[i];
      final amount = (sale['total'] as num? ?? 0).toStringAsFixed(2);
      final date = _formatDateMMDDYYYY(sale['date']);

      buffer.write('TRNS\tTRN$i\tCHECK\t$date\tSales\t$companyName\t${sale['product'] ?? 'Sale'}\t$amount\n');
      buffer.write('SPL\tSPL$i\tCHECK\t$date\tSales\t$amount\t${sale['paymentMethod'] ?? 'Cash'}\n');
      buffer.write('ENDTRNS\n');
    }

    return buffer.toString();
  }

  /// Generate GST-compliant JSON report
  static Map<String, dynamic> generateGSTReport(
    List<Map<String, dynamic>> sales, {
    required String gstIn,
    required String shopName,
    required String period,
  }) {
    // Categorize by GST rates (assuming 5%, 12%, 18%)
    final gst5 = <Map<String, dynamic>>[];
    final gst12 = <Map<String, dynamic>>[];
    final gst18 = <Map<String, dynamic>>[];

    for (var sale in sales) {
      final amount = sale['total'] as num? ?? 0;
      // Default to 18% GST (can be customized based on product)
      gst18.add(sale);
    }

    double calcTax(double amount, double rate) => (amount * rate) / (100 + rate);

    final total = sales.fold(0.0, (sum, s) => sum + (s['total'] as num? ?? 0));
    final tax5 = calcTax(gst5.fold(0.0, (sum, s) => sum + (s['total'] as num? ?? 0)), 5);
    final tax12 = calcTax(gst12.fold(0.0, (sum, s) => sum + (s['total'] as num? ?? 0)), 12);
    final tax18 = calcTax(gst18.fold(0.0, (sum, s) => sum + (s['total'] as num? ?? 0)), 18);

    return {
      'gstIn': gstIn,
      'period': period,
      'shopName': shopName,
      'summary': {
        'totalSales': total,
        'totalTax': tax5 + tax12 + tax18,
      },
      'breakdown': [
        {
          'gstRate': '5%',
          'taxableAmount': gst5.fold(0.0, (sum, s) => sum + (s['total'] as num? ?? 0)),
          'tax': tax5,
          'items': gst5.length,
        },
        {
          'gstRate': '12%',
          'taxableAmount': gst12.fold(0.0, (sum, s) => sum + (s['total'] as num? ?? 0)),
          'tax': tax12,
          'items': gst12.length,
        },
        {
          'gstRate': '18%',
          'taxableAmount': gst18.fold(0.0, (sum, s) => sum + (s['total'] as num? ?? 0)),
          'tax': tax18,
          'items': gst18.length,
        },
      ],
      'transactions': sales.map((s) => {
        'date': s['date'],
        'product': s['product'],
        'amount': s['total'],
        'gst': tax18, // Simplified
      }).toList(),
    };
  }

  /// Export to popular accounting software
  static Future<bool> exportToAccountingSoftware(
    AccountingSoftware software,
    List<Map<String, dynamic>> sales, {
    required String shopName,
    String? apiKey,
    String? apiUrl,
  }) async {
    try {
      // FIX-1: Load GSTIN from shop profile instead of hardcoded temp value
      final prefs = await SharedPreferences.getInstance();
      final gstIn = prefs.getString('gstin') ?? '';
      if (gstIn.isEmpty || !RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$').hasMatch(gstIn.toUpperCase())) {
        throw Exception('Valid GSTIN not configured. Please update shop profile in settings.');
      }
      
      switch (software) {
        case AccountingSoftware.tally:
          final xml = generateTallyXML(sales, shopName: shopName, gstIn: gstIn);
          return await _exportToService(apiUrl, xml, 'application/xml');

        case AccountingSoftware.quickBooks:
          final iif = generateQuickBooksIIF(sales, companyName: shopName);
          return await _exportToService(apiUrl, iif, 'text/plain');

        case AccountingSoftware.gst:
          final gstReport = generateGSTReport(
            sales,
            gstIn: gstIn,
            shopName: shopName,
            period: DateTime.now().toString(),
          );
          return await _exportToService(apiUrl, jsonEncode(gstReport), 'application/json');

        default:
          throw Exception('Unsupported accounting software');
      }
    } catch (e) {
      throw Exception('Export to accounting software failed: $e');
    }
  }

  /// Get supported integrations
  static List<AccountingIntegrationInfo> getSupportedIntegrations() {
    return [
      AccountingIntegrationInfo(
        name: 'Tally Prime',
        software: AccountingSoftware.tally,
        description: 'Popular in India, supports XML import',
        features: ['Invoice Import', 'GST Compliance', 'Multi-party Tracking'],
        icon: '📊',
      ),
      AccountingIntegrationInfo(
        name: 'QuickBooks',
        software: AccountingSoftware.quickBooks,
        description: 'Global accounting standard',
        features: ['IIF Format', 'Invoice Sync', 'Expense Tracking'],
        icon: '💼',
      ),
      AccountingIntegrationInfo(
        name: 'GST Compliance',
        software: AccountingSoftware.gst,
        description: 'Indian GST portal compatible',
        features: ['GSTR-1', 'Tax Calculation', 'Report Generation'],
        icon: '📋',
      ),
      AccountingIntegrationInfo(
        name: 'MITRA',
        software: AccountingSoftware.mitra,
        description: 'Indian e-invoicing system',
        features: ['e-Invoice', 'e-Way Bill', 'NETSMART'],
        icon: '🇮🇳',
      ),
      AccountingIntegrationInfo(
        name: 'Busy Software',
        software: AccountingSoftware.busy,
        description: 'Indian accounting software',
        features: ['XML Export', 'GST Ready', 'Multi-user Support'],
        icon: '⚙️',
      ),
    ];
  }

  static Future<bool> _exportToService(
    String? url,
    String data,
    String contentType,
  ) async {
    if (url == null || url.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': contentType},
        body: data,
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      throw Exception('Failed to export: $e');
    }
  }

  static String _formatDateDDMMYYYY(dynamic date) {
    if (date is DateTime) {
      return '${date.day.toString().padLeft(2, '0')}${date.month.toString().padLeft(2, '0')}${date.year}';
    }
    return '';
  }

  static String _formatDateMMDDYYYY(dynamic date) {
    if (date is DateTime) {
      return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
    }
    return '';
  }

  /// Test connection to accounting service
  static Future<bool> testConnection(String apiUrl) async {
    try {
      final response = await http
          .get(Uri.parse('$apiUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class AccountingIntegrationInfo {
  final String name;
  final AccountingSoftware software;
  final String description;
  final List<String> features;
  final String icon;

  AccountingIntegrationInfo({
    required this.name,
    required this.software,
    required this.description,
    required this.features,
    required this.icon,
  });
}
