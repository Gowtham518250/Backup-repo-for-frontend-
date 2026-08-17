import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// Generates a professional single-transaction bill PDF and returns the file path.
class BillGeneratorService {
  /// Build a professional A5-sized bill PDF and save to Downloads.
  /// Returns the saved file path.
  static Future<String> generateAndSaveBill({
    required String invoiceId,
    required String shopName,
    required String shopPhone,
    required String customerName,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double paidAmount,
    String? shopAddress,
    String? gstNumber,
    bool withTax = false,
  }) async {
    final pdf = pw.Document();

    final now = DateTime.now();
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(now);
    final paymentStatus = paidAmount >= totalAmount - 0.5 ? 'PAID' : (paidAmount > 0 ? 'PARTIAL' : 'UNPAID');
    final due = totalAmount - paidAmount;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── HEADER ──
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    shopName.toUpperCase(),
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
                  if (shopAddress != null && shopAddress.isNotEmpty)
                    pw.Text(shopAddress, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.Text(shopPhone, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  if (gstNumber != null && gstNumber.isNotEmpty)
                    pw.Text('GST: $gstNumber', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.Divider(thickness: 1.5),
            pw.SizedBox(height: 6),

            // ── BILL INFO ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Bill No: $invoiceId', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Text('Customer: ${customerName.isNotEmpty ? customerName : "Guest"}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(dateStr, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: pw.BoxDecoration(
                        color: paymentStatus == 'PAID' ? PdfColors.green100 : PdfColors.red100,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        paymentStatus,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: paymentStatus == 'PAID' ? PdfColors.green800 : PdfColors.red800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(),

            // ── ITEMS TABLE ──
            pw.TableHelper.fromTextArray(
              headers: ['#', 'Item', 'Qty', 'Rate', 'Total'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
              },
              data: items.asMap().entries.map((e) {
                final i = e.key;
                final item = e.value;
                final name = (item['product_name'] ?? item['item'] ?? 'Item').toString();
                final qty = double.tryParse(item['qty']?.toString() ?? '1') ?? 1.0;
                final rate = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
                final total = qty * rate;
                return [
                  '${i + 1}',
                  name,
                  qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(2),
                  '₹${rate.toStringAsFixed(0)}',
                  '₹${total.toStringAsFixed(0)}',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 8),

            // ── TOTALS ──
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Divider(thickness: 0.5),
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text('GRAND TOTAL:  ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      pw.Text('₹${totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  if (paidAmount > 0 && paidAmount < totalAmount) ...[
                    pw.Text('Paid: ₹${paidAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.green700)),
                    pw.Text('Balance Due: ₹${due.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.red700)),
                  ],
                ],
              ),
            ),
            pw.Spacer(),

            // ── FOOTER ──
            pw.Divider(thickness: 0.5),
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text('Thank you for shopping with us!', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.Text('Powered by Retail Mind', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Save to Downloads
    final dir = await _getDownloadsDir();
    final fileName = 'Bill_${invoiceId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    print('✅ Bill saved: ${file.path}');
    return file.path;
  }

  /// Share the generated bill as a PDF file (WhatsApp, email, etc.)
  static Future<void> shareBill(String filePath, {String? customerName}) async {
    try {
      final xFile = XFile(filePath, mimeType: 'application/pdf');
      await Share.shareXFiles([xFile],
        subject: 'Your Bill – AI Shop Pro',
        text: customerName != null && customerName.isNotEmpty
            ? '🛍️ Dear $customerName, thank you for shopping with us!\nPlease find your digital bill attached.\n\n---\n🚀 *Powered by AI Shop Pro*\nThe #1 Smart Billing App for Retailers.\nGet it here: https://aishoppro.com/app'
            : '🛍️ Thank you for shopping with us!\nPlease find your digital bill attached.\n\n---\n🚀 *Powered by AI Shop Pro*\nThe #1 Smart Billing App for Retailers.\nGet it here: https://aishoppro.com/app',
      );
    } catch (e) {
      print('Share bill error: $e');
    }
  }

  /// Print the bill directly to a connected printer via system dialog
  static Future<void> printBill(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      print('Print bill error: $e');
    }
  }

  static Future<Directory> _getDownloadsDir() async {
    if (Platform.isAndroid) {
      final d = Directory('/storage/emulated/0/Download/RetailMind');
      if (!await d.exists()) await d.create(recursive: true);
      return d;
    }
    return await getApplicationDocumentsDirectory();
  }
}
