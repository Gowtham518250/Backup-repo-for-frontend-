/// Bank Reconciliation Service
/// Matches bank transactions with app sales for reconciliation
/// Simple approach: compare amounts and dates to find unmatched transactions

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;
import 'package:flutter/foundation.dart';

class BankEntry {
  final DateTime date;
  final double amount;
  final String reference;
  final String rawLine;

  BankEntry({
    required this.date,
    required this.amount,
    required this.reference,
    required this.rawLine,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'amount': amount,
    'reference': reference,
    'rawLine': rawLine,
  };
}

class BankStatementParser {
  /// Parse PDF bank statement and extract UPI transactions
  static Future<List<BankEntry>> parsePDFFile(String filepath) async {
    try {
      final file = File(filepath);
      if (!await file.exists()) {
        throw Exception('File not found: $filepath');
      }
      
      final bytes = await file.readAsBytes();
      final text = await _extractTextFromPDF(bytes);
      return _parseBankStatementText(text);
    } catch (e) {
      debugPrint('PDF parsing error: $e');
      throw Exception('PDF parsing failed: $e');
    }
  }

  static Future<String> _extractTextFromPDF(Uint8List bytes) async {
    try {
      final pdfDoc = sf_pdf.PdfDocument(inputBytes: bytes);
      final extractor = sf_pdf.PdfTextExtractor(pdfDoc);
      final text = extractor.extractText();
      pdfDoc.dispose();
      return text ?? '';
    } catch (e) {
      debugPrint('PDF text extraction error: $e');
      return '';
    }
  }

  static List<BankEntry> _parseBankStatementText(String text) {
    final entries = <BankEntry>[];
    final lines = text.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      BankEntry? entry;

      // Try HDFC format: "07/04/26 UPI-NAME-PHONE Cr 1500.00"
      entry ??= _parseHDFCFormat(trimmed);

      // Try SBI format: "07-04-2026 TO TRANSFER-UPI/CR/XXXXX 1500.00"
      entry ??= _parseSBIFormat(trimmed);

      // Try ICICI format: "07/04/2026 UPI/CR/412345/NAME 1,500.00"
      entry ??= _parseICICIFormat(trimmed);

      // Try AXIS format: "07/04/2026 UPI CREDIT 1500.00"
      entry ??= _parseAXISFormat(trimmed);

      // Try KOTAK format: "07-04-2026 UPI/CR/XXXXX 1500.00"
      entry ??= _parseKOTAKFormat(trimmed);

      if (entry != null) {
        entries.add(entry);
      }
    }

    return entries;
  }

  static BankEntry? _parseHDFCFormat(String line) {
    // HDFC: "07/04/26 UPI-NAME-PHONE Cr 1500.00"
    final hdfcRegex = RegExp(r'(\d{2}/\d{2}/\d{2})\s+(.+?)\s+(Cr|Dr)\s+([\d,]+\.?\d*)');
    final match = hdfcRegex.firstMatch(line);

    if (match != null) {
      final dateStr = match.group(1)!;
      final desc = match.group(2)!;
      final type = match.group(3)!;
      final amountStr = match.group(4)!.replaceAll(',', '');

      // Only process credit transactions (money coming in)
      if (type.toUpperCase() == 'CR') {
        try {
          final date = _parseDate(dateStr, 'dd/MM/yy');
          final amount = double.parse(amountStr);
          return BankEntry(
            date: date,
            amount: amount,
            reference: desc,
            rawLine: line,
          );
        } catch (_) {}
      }
    }
    return null;
  }

  static BankEntry? _parseSBIFormat(String line) {
    // SBI: "07-04-2026 TO TRANSFER-UPI/CR/XXXXX 1500.00"
    final sbiRegex = RegExp(r'(\d{2}-\d{2}-\d{4})\s+(.+?)\s+(\d+\.?\d*)');
    final match = sbiRegex.firstMatch(line);

    if (match != null && line.toUpperCase().contains('UPI')) {
      final dateStr = match.group(1)!;
      final desc = match.group(2)!;
      final amountStr = match.group(3)!;

      try {
        final date = _parseDate(dateStr, 'dd-MM-yyyy');
        final amount = double.parse(amountStr);
        return BankEntry(
          date: date,
          amount: amount,
          reference: desc,
          rawLine: line,
        );
      } catch (_) {}
    }
    return null;
  }

  static BankEntry? _parseICICIFormat(String line) {
    // ICICI: "07/04/2026 UPI/CR/412345/NAME 1,500.00"
    final iciciRegex = RegExp(r'(\d{2}/\d{2}/\d{4})\s+(.+?)\s+([\d,]+\.?\d*)');
    final match = iciciRegex.firstMatch(line);

    if (match != null && line.toUpperCase().contains('UPI')) {
      final dateStr = match.group(1)!;
      final desc = match.group(2)!;
      final amountStr = match.group(3)!.replaceAll(',', '');

      try {
        final date = _parseDate(dateStr, 'dd/MM/yyyy');
        final amount = double.parse(amountStr);
        return BankEntry(
          date: date,
          amount: amount,
          reference: desc,
          rawLine: line,
        );
      } catch (_) {}
    }
    return null;
  }

  static BankEntry? _parseAXISFormat(String line) {
    // AXIS: "07/04/2026 UPI CREDIT 1500.00"
    final axisRegex = RegExp(r'(\d{2}/\d{2}/\d{4})\s+(.+?)\s+(\d+\.?\d*)');
    final match = axisRegex.firstMatch(line);

    if (match != null && line.toUpperCase().contains('UPI') && line.toUpperCase().contains('CREDIT')) {
      final dateStr = match.group(1)!;
      final desc = match.group(2)!;
      final amountStr = match.group(3)!;

      try {
        final date = _parseDate(dateStr, 'dd/MM/yyyy');
        final amount = double.parse(amountStr);
        return BankEntry(
          date: date,
          amount: amount,
          reference: desc,
          rawLine: line,
        );
      } catch (_) {}
    }
    return null;
  }

  static BankEntry? _parseKOTAKFormat(String line) {
    // KOTAK: "07-04-2026 UPI/CR/XXXXX 1500.00"
    final kotakRegex = RegExp(r'(\d{2}-\d{2}-\d{4})\s+(.+?)\s+(\d+\.?\d*)');
    final match = kotakRegex.firstMatch(line);

    if (match != null && line.toUpperCase().contains('UPI')) {
      final dateStr = match.group(1)!;
      final desc = match.group(2)!;
      final amountStr = match.group(3)!;

      try {
        final date = _parseDate(dateStr, 'dd-MM-yyyy');
        final amount = double.parse(amountStr);
        return BankEntry(
          date: date,
          amount: amount,
          reference: desc,
          rawLine: line,
        );
      } catch (_) {}
    }
    return null;
  }

  static DateTime _parseDate(String dateStr, String format) {
    final parts = dateStr.split(RegExp(r'[-/]'));

    if (format == 'dd/MM/yy' && parts.length == 3) {
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = 2000 + int.parse(parts[2]); // Convert 2-digit year
      return DateTime(year, month, day);
    } else if (format == 'dd-MM-yyyy' && parts.length == 3) {
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      return DateTime(year, month, day);
    } else if (format == 'dd/MM/yyyy' && parts.length == 3) {
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      return DateTime(year, month, day);
    }

    throw FormatException('Invalid date format');
  }
}

class BankReconciliation {
  /// Reconciles bank transactions with app sales
  /// Returns list of unmatched transactions for manual review
  static List<Map<String, dynamic>> reconcile(
    List<Map<String, dynamic>> bankTransactions,
    List<Map<String, dynamic>> appSales,
  ) {
    final unmatched = <Map<String, dynamic>>[];

    for (final txn in bankTransactions) {
      final amount = txn['amount']?.toString() ?? '';
      final date = txn['date']?.toString() ?? '';

      // Try to match with app sales
      final matched = appSales.any((s) {
        final saleAmount = s['total']?.toString() ?? '';
        final saleDate = s['date']?.toString() ?? s['sale_date']?.toString() ?? '';

        return saleAmount == amount && saleDate.contains(date.split('T').first);
      });

      if (!matched) {
        unmatched.add({
          ...txn,
          'status': 'UNMATCHED',
          'reconciled_at': DateTime.now().toIso8601String(),
        });
      }
    }

    return unmatched;
  }

  /// Get reconciliation summary
  static Map<String, dynamic> getSummary(
    List<Map<String, dynamic>> bankTransactions,
    List<Map<String, dynamic>> appSales,
  ) {
    final unmatched = reconcile(bankTransactions, appSales);

    // Calculate totals
    double bankTotal = 0;
    double appTotal = 0;
    double unmatchedTotal = 0;

    for (final txn in bankTransactions) {
      bankTotal += double.tryParse(txn['amount']?.toString() ?? '0') ?? 0;
    }

    for (final sale in appSales) {
      appTotal += double.tryParse(sale['total']?.toString() ?? '0') ?? 0;
    }

    for (final um in unmatched) {
      unmatchedTotal += double.tryParse(um['amount']?.toString() ?? '0') ?? 0;
    }

    return {
      'bank_total': bankTotal,
      'app_total': appTotal,
      'matched_total': bankTotal - unmatchedTotal,
      'unmatched_total': unmatchedTotal,
      'unmatched_count': unmatched.length,
      'reconciliation_rate': ((bankTotal - unmatchedTotal) / bankTotal * 100).toStringAsFixed(2) + '%',
      'status': unmatchedTotal == 0 ? 'FULLY_RECONCILED' : 'PARTIAL_RECONCILIATION',
    };
  }

  /// Export unmatched transactions for review
  static Future<String> exportUnmatchedAsJSON(
    List<Map<String, dynamic>> bankTransactions,
    List<Map<String, dynamic>> appSales,
  ) async {
    final unmatched = reconcile(bankTransactions, appSales);
    final summary = getSummary(bankTransactions, appSales);

    final exportData = {
      'export_date': DateTime.now().toIso8601String(),
      'summary': summary,
      'unmatched_transactions': unmatched,
    };

    return jsonEncode(exportData);
  }
}
