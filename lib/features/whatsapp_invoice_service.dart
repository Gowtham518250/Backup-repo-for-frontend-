import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class WhatsappInvoiceService {
  static Future<void> generateAndShareInvoice({
    required String invoiceId,
    required String customerName,
    required String customerPhone,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    double gstPercent = 18.0,
  }) async {
    try {
      final pdf = pw.Document();

      // Create PDF content
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Invoice No: $invoiceId'),
                pw.Text('Date: ${DateTime.now().toString().split('.')[0]}'),
                pw.SizedBox(height: 10),
                pw.Text('Customer: $customerName'),
                pw.Text('Phone: $customerPhone'),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Qty x Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Divider(),
                ...items.map((item) {
                  final name = item['product_name'] ?? 'Item';
                  final qty = item['qty'] ?? '1';
                  final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(name),
                        pw.Text('$qty x ${price.toStringAsFixed(2)}'),
                      ],
                    ),
                  );
                }),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text('TOTAL: Rs ${totalAmount.toStringAsFixed(2)}', 
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Spacer(),
                pw.Center(
                  child: pw.Text('Thank you for shopping with us!', style: const pw.TextStyle(fontSize: 14)),
                ),
              ],
            );
          },
        ),
      );

      // Save PDF locally
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/Invoice_$invoiceId.pdf');
      await file.writeAsBytes(await pdf.save());

      // Share via WhatsApp
      await Share.shareXFiles([XFile(file.path)],
        text: 'Hello $customerName, here is your invoice #$invoiceId from AI Shop.',
      );

    } catch (e) {
      if (kDebugMode) debugPrint('Error sharing invoice: $e');
    }
  }
}
