import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_storage_service.dart';

class CSVImportService {
  /// Allows users to import sales data from Khatabook/Excel exported CSVs.
  /// Expects columns mapping: [Product Name, Price, Quantity/Date]
  static Future<Map<String, dynamic>> importKhatabookCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return {'success': false, 'message': 'No file selected'};
      }

      final bytes = result.files.first.bytes;
      if (bytes == null) return {'success': false, 'message': 'File is empty'};

      final String csvContent = utf8.decode(bytes);
      final List<List<dynamic>> rows = const CsvToListConverter().convert(csvContent);

      if (rows.length < 2) {
        return {'success': false, 'message': 'Empty CSV file or invalid format'};
      }

      // Skip header if first row contains non-numeric strings where numbers expected
      int startAt = 0;
      if (rows[0].any((cell) => cell.toString().toLowerCase().contains('name') || cell.toString().toLowerCase().contains('item'))) {
        startAt = 1;
      }

      final List<dynamic> allSales = await LocalStorageService.loadSales();

      int importedCount = 0;
      for (int i = startAt; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 2) continue;

        // Smart Mapping: [Item Name, Amount/Price, Qty/Date]
        final String itemName = row[0].toString().trim();
        final double amount = double.tryParse(row[1].toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        
        if (itemName.isEmpty || amount <= 0) continue;

        // Create a compliant sale record
        final saleRecord = {
          'sale_date': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'total': amount,
          'paid_amount': amount,
          'payment_status': 'PAID',
          'items': [
            {
              'item': itemName,
              'product': itemName,
              'qty': 1,
              'price': amount,
              'total': amount,
              'total_with_tax': amount,
            }
          ]
        };

        allSales.add(saleRecord);
        importedCount++;
      }

      await LocalStorageService.saveSales(allSales);
      return {
        'success': true, 
        'message': 'Successfully imported $importedCount records from your file!',
        'count': importedCount
      };
    } catch (e) {
      return {'success': false, 'message': 'Import Error: ${e.toString()}'};
    }
  }
}
