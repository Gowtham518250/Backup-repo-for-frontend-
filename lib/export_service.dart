import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'financial_math.dart';
import 'notification_service.dart';

class ExportService {
  /// Generate CSV from sales data
  static Future<String> generateCSV(List<Map<String, dynamic>> sales) async {
    try {
      // Sort sales by date ascending
      final sortedSales = List<Map<String, dynamic>>.from(sales);
      sortedSales.sort((a, b) {
        final dateAStr = a['date'] ?? a['sale_date'] ?? '';
        final dateBStr = b['date'] ?? b['sale_date'] ?? '';
        final dateA = DateTime.tryParse(dateAStr.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = DateTime.tryParse(dateBStr.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateA.compareTo(dateB);
      });

      List<List<dynamic>> csvData = [
        ['Date', 'Product', 'Quantity', 'Price', 'Total', 'Payment Method'],
      ];

      for (var sale in sortedSales) {
        final double price = double.tryParse(sale['price']?.toString() ?? '0') ?? 0;
        final double qty = double.tryParse(sale['quantity']?.toString() ?? sale['qty']?.toString() ?? '1') ?? 1;
        final double total = double.tryParse(sale['total']?.toString() ?? sale['total_with_tax']?.toString() ?? CurrencyManager.multiply(price, qty).toString()) ?? CurrencyManager.multiply(price, qty);
        
        csvData.add([
          _formatDate(sale['date'] ?? sale['sale_date'] ?? DateTime.now()),
          sale['product'] ?? sale['item'] ?? 'N/A',
          qty,
          'Rs.${price.toStringAsFixed(2)}',
          'Rs.${total.toStringAsFixed(2)}',
          sale['paymentMethod'] ?? sale['payment_method'] ?? 'Cash',
        ]);
      }

      String csv = const ListToCsvConverter().convert(csvData);
      return csv;
    } catch (e) {
      throw Exception('CSV generation failed: $e');
    }
  }

  /// Generate GSTR-1 CSV from sales data
  static Future<String> generateGSTR1CSV(List<Map<String, dynamic>> sales) async {
    try {
      List<List<dynamic>> csvData = [
        [
          'GSTIN/UIN of Recipient',
          'Receiver Name',
          'Invoice Number',
          'Invoice Date',
          'Invoice Value',
          'Place Of Supply',
          'Reverse Charge',
          'Applicable % of Tax Rate',
          'Invoice Type',
          'E-Commerce GSTIN',
          'Rate',
          'Taxable Value',
          'Cess Amount'
        ]
      ];

      for (var sale in sales) {
        final double price = double.tryParse(sale['price']?.toString() ?? '0') ?? 0;
        final double qty = double.tryParse(sale['quantity']?.toString() ?? sale['qty']?.toString() ?? '1') ?? 1;
        final double gstPercent = double.tryParse(sale['gstPercent']?.toString() ?? '18') ?? 18.0;
        
        final double invoiceValue = CurrencyManager.multiply(price, qty);
        final double taxableValue = invoiceValue / (1 + (gstPercent / 100));

        csvData.add([
          '', // GSTIN of Recipient
          sale['customerName'] ?? 'Walk-in', // Receiver Name
          sale['invoiceId'] ?? 'N/A', // Invoice Number
          _formatDate(sale['date'] ?? sale['sale_date'] ?? DateTime.now()), // Invoice Date
          invoiceValue.toStringAsFixed(2), // Invoice Value
          '', // Place Of Supply
          'N', // Reverse Charge
          '', // Applicable % of Tax Rate
          'Regular B2C', // Invoice Type
          '', // E-Commerce GSTIN
          gstPercent.toStringAsFixed(2), // Rate
          taxableValue.toStringAsFixed(2), // Taxable Value
          '0' // Cess Amount
        ]);
      }

      String csv = const ListToCsvConverter().convert(csvData);
      return csv;
    } catch (e) {
      throw Exception('GSTR-1 CSV generation failed: $e');
    }
  }

  /// Generate Tally Prime Sales Register CSV
  static Future<String> generateTallyCSV(List<Map<String, dynamic>> sales) async {
    try {
      List<List<dynamic>> csvData = [
        ['Date', 'Voucher Type', 'Voucher Number', 'Party Name', 'Sales Ledger', 'Item Name', 'Billed Qty', 'Rate', 'Amount']
      ];

      for (var sale in sales) {
        final double price = double.tryParse(sale['price']?.toString() ?? '0') ?? 0;
        final double qty = double.tryParse(sale['quantity']?.toString() ?? sale['qty']?.toString() ?? '1') ?? 1;
        final double total = CurrencyManager.multiply(price, qty);

        csvData.add([
          _formatDate(sale['date'] ?? sale['sale_date'] ?? DateTime.now()),
          'Sales',
          sale['invoiceId'] ?? 'N/A',
          sale['customerName'] ?? 'Walk-in',
          'Local Sales',
          sale['product'] ?? sale['item'] ?? 'General Item',
          qty.toString(),
          price.toStringAsFixed(2),
          total.toStringAsFixed(2)
        ]);
      }

      String csv = const ListToCsvConverter().convert(csvData);
      return csv;
    } catch (e) {
      throw Exception('Tally CSV generation failed: $e');
    }
  }

  /// Generate Excel from sales data
  static Future<List<int>> generateExcel(List<Map<String, dynamic>> sales) async {
    try {
      // Sort sales by date ascending
      final sortedSales = List<Map<String, dynamic>>.from(sales);
      sortedSales.sort((a, b) {
        final dateAStr = a['date'] ?? a['sale_date'] ?? '';
        final dateBStr = b['date'] ?? b['sale_date'] ?? '';
        final dateA = DateTime.tryParse(dateAStr.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = DateTime.tryParse(dateBStr.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateA.compareTo(dateB);
      });

      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sales Report'];
      excel.delete('Sheet1'); // Remove default sheet

      // Header row
      List<String> headers = ['Date', 'Product', 'Quantity', 'Price', 'Total', 'Payment Method'];
      sheetObject.appendRow(headers.map((h) => TextCellValue(h)).toList());

      // Data rows
      for (var sale in sortedSales) {
        final double price = double.tryParse(sale['price']?.toString() ?? '0') ?? 0;
        final double qty = double.tryParse(sale['quantity']?.toString() ?? sale['qty']?.toString() ?? '1') ?? 1;
        final double total = double.tryParse(sale['total']?.toString() ?? sale['total_with_tax']?.toString() ?? CurrencyManager.multiply(price, qty).toString()) ?? CurrencyManager.multiply(price, qty);
        
        sheetObject.appendRow([
          TextCellValue(_formatDate(sale['date'] ?? sale['sale_date'] ?? DateTime.now())),
          TextCellValue(sale['product'] ?? sale['item'] ?? 'N/A'),
          DoubleCellValue(qty),
          TextCellValue('Rs.${price.toStringAsFixed(2)}'),
          TextCellValue('Rs.${total.toStringAsFixed(2)}'),
          TextCellValue(sale['paymentMethod'] ?? sale['payment_method'] ?? 'Cash'),
        ]);
      }

      return excel.encode() ?? [];
    } catch (e) {
      print('Excel export error: $e');
      throw Exception('Excel generation failed: $e');
    }
  }

  static Future<Directory> _getPublicDirectory() async {
    if (Platform.isAndroid) {
      Directory dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) {
        dir = Directory('/storage/emulated/0/Downloads');
      }
      if (!await dir.exists()) {
         return await getApplicationDocumentsDirectory();
      }
      return dir;
    }
    return await getApplicationDocumentsDirectory();
  }

  /// Save Excel to file
  static Future<String> saveExcel(List<int> bytes, {String? fileName}) async {
    try {
      final directory = await _getPublicDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      String formattedFileName = fileName ?? 'retail_sales_$timestamp';
      if (!formattedFileName.endsWith('.xlsx')) formattedFileName += '.xlsx';
      
      final file = File('${directory.path}/$formattedFileName');
      await file.writeAsBytes(bytes);
      await _scanMediaFile(file.path);
      
      await NotificationService().showDownloadNotification(
        'Excel Export Complete',
        'Saved as $formattedFileName in Downloads',
        file.path,
      );

      return file.path;
    } catch (e) {
      throw Exception('Failed to save Excel: $e');
    }
  }

  /// Save CSV to file
  static Future<String> saveCSV(String csvContent, {String? fileName}) async {
    try {
      final directory = await _getPublicDirectory();
      final timestamp = DateTime.now().toString().replaceAll(RegExp(r'[^0-9]'), '');
      String formattedFileName = fileName ?? 'sales_$timestamp';
      if (!formattedFileName.endsWith('.csv')) formattedFileName += '.csv';
      
      final file = File('${directory.path}/$formattedFileName');
      
      await file.writeAsString(csvContent);
      await _scanMediaFile(file.path);
      
      // Show notification
      await NotificationService().showDownloadNotification(
        'Export Complete',
        'Sales CSV saved: $formattedFileName',
        file.path,
      );

      return file.path;
    } catch (e) {
      throw Exception('Failed to save CSV: $e');
    }
  }

  /// Generate PDF from sales data
  static Future<void> generateAndPrintPDF(
    List<Map<String, dynamic>> sales, {
    String? shopName,
    String? shopPhone,
    String? totalRevenue,
    String? dateRange,
  }) async {
    try {
      // Sort sales by date ascending
      final sortedSales = List<Map<String, dynamic>>.from(sales);
      sortedSales.sort((a, b) {
        final dateAStr = a['date'] ?? a['sale_date'] ?? '';
        final dateBStr = b['date'] ?? b['sale_date'] ?? '';
        final dateA = DateTime.tryParse(dateAStr.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = DateTime.tryParse(dateBStr.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateA.compareTo(dateB);
      });

      print('📄 Generating PDF for ${sortedSales.length} items...');
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            // Header
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    shopName ?? 'Sales Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Report Period: ${dateRange ?? 'Custom'}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  if (shopPhone != null)
                    pw.Text(
                      'Contact: $shopPhone',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  pw.SizedBox(height: 20),
                  pw.Divider(),
                  pw.SizedBox(height: 10),
                ],
              ),
            ),
            // Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Summary',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Transactions: ${sortedSales.length}'),
                      pw.Text('Total Revenue: ${totalRevenue ?? 'Rs.0.00'}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            // Table
            pw.Text(
              'Transaction Details',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Product', 'Qty', 'Price', 'Total', 'Method'],
              data: sortedSales.map((sale) {
                final double price = double.tryParse(sale['price']?.toString() ?? '0') ?? 0;
                final double qty = double.tryParse(sale['quantity']?.toString() ?? sale['qty']?.toString() ?? '1') ?? 1;
                final double total = double.tryParse(sale['total']?.toString() ?? sale['total_with_tax']?.toString() ?? CurrencyManager.multiply(price, qty).toString()) ?? CurrencyManager.multiply(price, qty);
                final String name = (sale['product'] ?? sale['item'] ?? 'N/A').toString();
                final String dateStr = _formatDate(sale['date'] ?? sale['sale_date'] ?? DateTime.now());
                
                return [
                  dateStr,
                  name,
                  qty.toString(),
                  price.toStringAsFixed(0),
                  total.toStringAsFixed(0),
                  sale['paymentMethod'] ?? sale['payment_method'] ?? 'Cash',
                ];
              }).toList(),
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              rowDecoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300),
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Text(
              'Retail Mind Intelligence – Automated Sales Report',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      );

      // Print or save
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      print('PDF print error: $e');
      throw Exception('PDF generation failed: $e');
    }
  }

  /// Generate PDF and save to file
  static Future<String> savePDF(
    List<Map<String, dynamic>> sales, {
    String? shopName,
    String? shopPhone,
    String? totalRevenue,
    String? dateRange,
  }) async {
    try {
      // Sort sales by date ascending
      final sortedSales = List<Map<String, dynamic>>.from(sales);
      sortedSales.sort((a, b) {
        final dateAStr = a['date'] ?? a['sale_date'] ?? '';
        final dateBStr = b['date'] ?? b['sale_date'] ?? '';
        final dateA = DateTime.tryParse(dateAStr.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = DateTime.tryParse(dateBStr.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateA.compareTo(dateB);
      });

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    shopName ?? 'Sales Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Report Period: ${dateRange ?? 'Custom'}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Divider(),
                  pw.SizedBox(height: 10),
                ],
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Summary',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Transactions: ${sortedSales.length}'),
                      pw.Text('Total Revenue: ${totalRevenue ?? 'Rs.0.00'}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Transaction Details',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Product', 'Qty', 'Price', 'Total', 'Method'],
              data: sortedSales.map((sale) {
                 final double price = double.tryParse(sale['price']?.toString() ?? '0') ?? 0;
                 final double qty = double.tryParse(sale['quantity']?.toString() ?? sale['qty']?.toString() ?? '1') ?? 1;
                 final double total = double.tryParse(sale['total']?.toString() ?? sale['total_with_tax']?.toString() ?? CurrencyManager.multiply(price, qty).toString()) ?? CurrencyManager.multiply(price, qty);
                 final String name = (sale['product'] ?? sale['item'] ?? 'N/A').toString();
                 final String dateStr = _formatDate(sale['date'] ?? sale['sale_date'] ?? DateTime.now());

                 return [
                  dateStr,
                  name,
                  qty.toString(),
                  price.toStringAsFixed(0),
                  total.toStringAsFixed(0),
                  sale['paymentMethod'] ?? sale['payment_method'] ?? 'Cash',
                ];
              }).toList(),
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            ),
          ],
        ),
      );

      final directory = await _getPublicDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final file = File('${directory.path}/report_$timestamp.pdf');
      
      await file.writeAsBytes(await pdf.save());
      await _scanMediaFile(file.path);
      
      // Show notification
      await NotificationService().showDownloadNotification(
        'PDF Report Generated',
        'Saved as report_$timestamp.pdf in Downloads',
        file.path,
      );

      return file.path;
    } catch (e) {
      print('PDF save error: $e');
      throw Exception('Failed to save PDF: $e');
    }
  }

  /// Trigger Android MediaScanner to make file visible in file manager
  static Future<void> _scanMediaFile(String filePath) async {
    try {
      if (Platform.isAndroid) {
        // Create a dummy read on the file to flush OS cache
        final f = File(filePath);
        await f.length();
      }
    } catch (_) {}
  }

  /// Open the exported file via Android share sheet (shows Open / Share options)
  static Future<void> openWithShareSheet(String filePath) async {
    try {
      final xFile = XFile(filePath);
      await Share.shareXFiles([xFile],
        text: 'Retail Mind – Sales Export',
        subject: 'Sales Data Export',
      );
    } catch (e) {
      throw Exception('Failed to open file: $e');
    }
  }

  static String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    if (date is DateTime) {
      return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
    }
    
    String str = date.toString().trim();
    if (str.isEmpty || str == 'null') return 'N/A';
    
    try {
       // Attempt direct parse (handles ISO8601 like 2026-04-03T...)
       DateTime? dt = DateTime.tryParse(str);
       
       // Fallback for non-ISO formats often found in manual entries
       if (dt == null && str.contains('-')) {
          // If it's something like "2026-04-03" (10 chars), try suffixing
          if (str.length == 10) str = '${str}T12:00:00';
          dt = DateTime.tryParse(str);
       }

       if (dt != null) {
         return DateFormat('dd/MM/yyyy').format(dt.toLocal());
       }
    } catch (_) {}
    
    return str.length > 10 ? str.substring(0, 10) : str;
  }
}
