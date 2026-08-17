import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

class PdfInvoiceService {
  static Future<File> generateInvoice({
    required String shopName,
    required String customerName,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double paidAmount,
    required String paymentMethod,
    required DateTime date,
  }) async {
    final pdf = pw.Document();
    
    // Load font for Unicode/Rupee support if needed, but we'll use a standard font for simplicity
    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(shopName, style: pw.TextStyle(font: fontBold, fontSize: 24, color: PdfColors.blue900)),
                      pw.SizedBox(height: 4),
                      pw.Text('TAX INVOICE', style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Date: ${date.day}/${date.month}/${date.year}', style: pw.TextStyle(font: font, fontSize: 12)),
                      pw.Text('Time: ${date.hour}:${date.minute.toString().padLeft(2, '0')}', style: pw.TextStyle(font: font, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Customer Details
              if (customerName.isNotEmpty) ...[
                pw.Text('Billed To:', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                pw.Text(customerName, style: pw.TextStyle(font: font, fontSize: 12)),
                pw.SizedBox(height: 20),
              ],

              // Table Header
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                color: PdfColors.grey200,
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 3, child: pw.Text('Item', style: pw.TextStyle(font: fontBold))),
                    pw.Expanded(flex: 1, child: pw.Text('Qty', style: pw.TextStyle(font: fontBold), textAlign: pw.TextAlign.center)),
                    pw.Expanded(flex: 2, child: pw.Text('Price', style: pw.TextStyle(font: fontBold), textAlign: pw.TextAlign.right)),
                    pw.Expanded(flex: 2, child: pw.Text('Total', style: pw.TextStyle(font: fontBold), textAlign: pw.TextAlign.right)),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),

              // Items
              ...items.map((item) {
                  final name = (item['product_name'] ?? item['description'] ?? item['name'] ?? item['item'] ?? item['product'] ?? 'Item').toString();
                  final qty = double.tryParse((item['qty']?.toString() ?? item['quantity']?.toString()) ?? '1') ?? 1.0;
                  final price = double.tryParse((item['price']?.toString() ?? item['unit_price']?.toString()) ?? '0') ?? 0.0;
                  final total = qty * price;

                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 3, child: pw.Text(name, style: pw.TextStyle(font: font))),
                      // FIX (Issue 3.3): toStringAsFixed(0) rounds 1.5 → "2", corrupting
                      // fractional quantities (e.g., 1.5 kg sold as 2 kg on the invoice).
                      // Use a conditional format: whole numbers show without decimals,
                      // fractional quantities show up to 3 significant decimal digits.
                      pw.Expanded(flex: 1, child: pw.Text(
                        qty == qty.truncateToDouble()
                            ? qty.toStringAsFixed(0)
                            : qty.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), ''),
                        style: pw.TextStyle(font: font),
                        textAlign: pw.TextAlign.center,
                      )),
                      pw.Expanded(flex: 2, child: pw.Text('Rs ${price.toStringAsFixed(2)}', style: pw.TextStyle(font: font), textAlign: pw.TextAlign.right)),
                      pw.Expanded(flex: 2, child: pw.Text('Rs ${total.toStringAsFixed(2)}', style: pw.TextStyle(font: font), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                );
              }),

              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 10),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Subtotal: Rs ${totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(font: font, fontSize: 14)),
                      pw.SizedBox(height: 4),
                      pw.Text('Paid ($paymentMethod): Rs ${paidAmount.toStringAsFixed(2)}', style: pw.TextStyle(font: font, fontSize: 14)),
                      pw.SizedBox(height: 4),
                      if (totalAmount > paidAmount)
                        pw.Text('Due: Rs ${(totalAmount - paidAmount).toStringAsFixed(2)}', style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.red800)),
                      pw.SizedBox(height: 8),
                      pw.Text('Grand Total: Rs ${totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.blue900)),
                    ],
                  ),
                ],
              ),
              
              pw.Spacer(),
              pw.Center(
                child: pw.Text('Thank you for your business!', style: pw.TextStyle(font: font, color: PdfColors.grey600)),
              ),
            ],
          );
        },
      ),
    );

    final output = await getApplicationDocumentsDirectory();
    final file = File('${output.path}/invoice_${DateTime.now().millisecondsSinceEpoch}.pdf');
    final bytes = await pdf.save();
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<void> generateAndShareInvoice({
    required String shopName,
    required String customerName,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double paidAmount,
    required String paymentMethod,
    required DateTime date,
  }) async {
    final file = await generateInvoice(
      shopName: shopName,
      customerName: customerName,
      items: items,
      totalAmount: totalAmount,
      paidAmount: paidAmount,
      paymentMethod: paymentMethod,
      date: date,
    );
    final bytes = await file.readAsBytes();
    await Printing.sharePdf(bytes: bytes, filename: 'Invoice_$customerName.pdf');
  }
}
