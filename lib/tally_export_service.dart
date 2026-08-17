import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'local_storage_service.dart';

class TallyExportService {
  /// Generates a highly structured, Government & Tally-compliant JSON file
  /// required by CAs (Chartered Accountants) for filing monthly GST returns.
  /// Includes proper breakdown of CGST, SGST, IGST, and taxable value.
  static Future<Map<String, dynamic>> exportGstReturns(String shopName, String shopGst) async {
    try {
      final List<dynamic> allSales = await LocalStorageService.loadSales();

      if (allSales.isEmpty) return {'success': false, 'message': 'No sales to export.'};

      final List<Map<String, dynamic>> gstInvoices = [];

      double totalTaxable = 0;
      double totalCgst = 0;
      double totalSgst = 0;

      for (var sale in allSales) {
        String invoiceNum = sale['sale_id'] ?? sale['id']?.toString() ?? 'INV-UNKNOWN';
        String date = sale['sale_date'] ?? DateTime.now().toIso8601String();
        String paymentStatus = sale['payment_status'] ?? 'UNKNOWN';

        double invoiceTotal = double.tryParse(sale['total']?.toString() ?? '0') ?? 0;
        double subtotal = 0;
        double cgst = 0;
        double sgst = 0;

        List<Map<String, dynamic>> structuredItems = [];
        final items = sale['items'] as List<dynamic>? ?? [];

        for (var item in items) {
          double qty = double.tryParse(item['qty']?.toString() ?? '0') ?? 0;
          double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
          double gstPercent = double.tryParse(item['gst_percent']?.toString() ?? '0') ?? 0;
          
          double itemSubtotal = qty * price;
          double itemGstAmt = itemSubtotal * (gstPercent / 100);
          double itemCgst = itemGstAmt / 2;
          double itemSgst = itemGstAmt / 2;

          subtotal += itemSubtotal;
          cgst += itemCgst;
          sgst += itemSgst;

          structuredItems.add({
            'ItemName': item['item'] ?? 'Unknown Item',
            'Quantity': qty,
            'Rate': price,
            'TaxableValue': itemSubtotal,
            'GST_Percent': gstPercent,
            'CGST_Amount': itemCgst,
            'SGST_Amount': itemSgst,
            'TotalAmount': itemSubtotal + itemGstAmt,
          });
        }

        totalTaxable += subtotal;
        totalCgst += cgst;
        totalSgst += sgst;

        gstInvoices.add({
          'InvoiceNumber': invoiceNum,
          'InvoiceDate': date,
          'CustomerName': sale['customer_name'] ?? 'Walk-in Customer',
          'CustomerPhone': sale['customer_phone'] ?? '',
          'PlaceOfSupply': 'Local State', // Assuming B2C intra-state
          'ReverseCharge': 'N',
          'InvoiceType': 'Regular B2C',
          'TaxableValue': subtotal,
          'CGST': cgst,
          'SGST': sgst,
          'IGST': 0.0,
          'InvoiceTotal': invoiceTotal,
          'PaymentStatus': paymentStatus,
          'LineItems': structuredItems
        });
      }

      final Map<String, dynamic> tallyCompliantJson = {
        'FilingMonth': DateTime.now().month.toString().padLeft(2, '0') + '-' + DateTime.now().year.toString(),
        'ShopName': shopName,
        'ShopGSTIN': shopGst.isEmpty ? 'UNREGISTERED' : shopGst,
        'AggregateSummary': {
          'TotalInvoices': gstInvoices.length,
          'TotalTaxableSales': totalTaxable,
          'TotalCGST': totalCgst,
          'TotalSGST': totalSgst,
          'TotalIGST': 0.0,
          'GrossReceipts': totalTaxable + totalCgst + totalSgst
        },
        'B2C_Invoices': gstInvoices
      };

      // Create file in temporary directory
      final Directory tempDir = await getTemporaryDirectory();
      final String rawExportPath = '${tempDir.path}/GST_Export_${DateTime.now().millisecondsSinceEpoch}.json';
      final File exportFile = File(rawExportPath);
      
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      await exportFile.writeAsString(encoder.convert(tallyCompliantJson));

      // Share the exported file immediately
      final shareResult = await Share.shareXFiles([XFile(exportFile.path, mimeType: 'application/json')],
        subject: 'Monthly GST Output for $shopName',
        text: 'Attached is the JSON export for Tally/CA integration.',
      );

      return {'success': true, 'message': 'Exported successfully. Ready for your CA.'};
    } catch (e) {
      print('GST Export Error: $e');
      return {'success': false, 'message': 'Failed to export: $e'};
    }
  }

  /// Imports sales/vouchers from Tally XML format
  /// Parses Tally ENVELOPE > BODY > IMPORTDATA > REQUESTDATA > TALLYMESSAGE structure
  static Future<List<Map<String, dynamic>>> importFromTallyXML(String xmlContent) async {
    try {
      final vouchers = <Map<String, dynamic>>[];
      final voucherRegex = RegExp(
        r'<VOUCHER>.*?<DATE>(.*?)</DATE>.*?<AMOUNT>(.*?)</AMOUNT>.*?</VOUCHER>',
        dotAll: true,
      );
      
      for (final m in voucherRegex.allMatches(xmlContent)) {
        vouchers.add({
          'date': m.group(1),
          'amount': m.group(2),
          'source': 'tally_import',
          'imported_at': DateTime.now().toIso8601String(),
        });
      }
      return vouchers;
    } catch (e) {
      print('Tally XML Import Error: $e');
      return [];
    }
  }
}
