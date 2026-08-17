import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;

/// Bank entry from parsed statement
class BankEntry {
  final DateTime date;
  final double amount;
  final String reference;  // UTR or transaction ID
  final String rawLine;     // Original text for debugging
  final String bankName;
  final String? description;  // Optional description
  
  BankEntry({
    required this.date,
    required this.amount,
    required this.reference,
    required this.rawLine,
    required this.bankName,
    this.description,
  });
  
  @override
  String toString() => 'BankEntry($bankName, ₹$amount, ref=$reference, date=${date.toString().split(' ')[0]})';
}

/// Bank Statement Parser - Extracts UPI transactions from bank PDF statements
class BankStatementParser {
  static const String _tag = '🏦 BANK_PARSER';
  
  // Bank format regex patterns
  static final Map<String, RegExp> bankPatterns = {
    'HDFC': RegExp(
      r'(\d{2}/\d{2}/\d{2})\s+UPI-([A-Z0-9@\.\-]+)\s+Cr\s+([\d,]+\.?\d*)',
      caseSensitive: false,
    ),
    'SBI': RegExp(
      r'(\d{2}-\d{2}-\d{4})\s+TO\s+TRANSFER-UPI/CR/(\w+)\s+([\d,]+\.?\d*)',
      caseSensitive: false,
    ),
    'ICICI': RegExp(
      r'(\d{2}/\d{2}/\d{4})\s+UPI/CR/(\d+)/([A-Z0-9]+)\s+([\d,]+\.?\d*)',
      caseSensitive: false,
    ),
    'AXIS': RegExp(
      r'(\d{2}-\d{2}-\d{2})\s+UPI\s+([A-Z0-9]+)\s+([\d,]+\.?\d*)',
      caseSensitive: false,
    ),
    'KOTAK': RegExp(
      r'(\d{2}/\d{2}/\d{4})\s+UPI-REC-([A-Z0-9]+)\s+([\d,]+\.?\d*)',
      caseSensitive: false,
    ),
  };
  
  /// Pick and parse PDF file
  static Future<List<BankEntry>> pickAndParsePDF() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      
      if (result == null || result.files.isEmpty) {
        debugPrint('$_tag No file selected');
        return [];
      }
      
      final filepath = result.files.single.path;
      if (filepath == null) return [];
      
      debugPrint('$_tag Selected: $filepath');
      
      // Parse PDF using Syncfusion PDF extraction
      return await parsePDFFile(filepath);
    } catch (e) {
      debugPrint('$_tag Error picking PDF: $e');
      return [];
    }
  }
  
  /// Parse PDF file
  static Future<List<BankEntry>> parsePDFFile(String filepath) async {
    try {
      final file = File(filepath);
      if (!await file.exists()) {
        throw 'File not found: $filepath';
      }
      
      debugPrint('$_tag Parsing PDF: $filepath');
      
      final bytes = await file.readAsBytes();
      final text = await _extractTextFromPDF(bytes);
      debugPrint('$_tag Extracted text length: ${text.length} characters');
      
      return parseText(text);
    } catch (e) {
      debugPrint('$_tag Error parsing PDF: $e');
      return [];
    }
  }
  
  /// Extract text from PDF using Syncfusion
  static Future<String> _extractTextFromPDF(Uint8List bytes) async {
    try {
      final pdfDoc = sf_pdf.PdfDocument(inputBytes: bytes);
      final extractor = sf_pdf.PdfTextExtractor(pdfDoc);
      final text = extractor.extractText();
      pdfDoc.dispose();
      return text ?? '';
    } catch (e) {
      debugPrint('$_tag PDF text extraction error: $e');
      return '';
    }
  }
  
  /// Parse statement text
  static List<BankEntry> parseText(String text) {
    final List<BankEntry> entries = [];
    final unrecognized = <String>[];
    
    final lines = text.split('\n');
    
    for (final line in lines) {
      bool matched = false;
      
      for (final entry in bankPatterns.entries) {
        final match = entry.value.firstMatch(line);
        if (match != null) {
          try {
            final bankEntry = _parseMatch(line, match, entry.key);
            if (bankEntry != null) {
              entries.add(bankEntry);
              matched = true;
              debugPrint('$_tag Matched ${entry.key}: $bankEntry');
              break;
            }
          } catch (e) {
            debugPrint('$_tag Parse error for ${entry.key}: $e');
          }
        }
      }
      
      if (!matched && line.contains('UPI')) {
        unrecognized.add(line);
      }
    }
    
    if (unrecognized.isNotEmpty) {
      debugPrint('$_tag Unrecognized lines: $unrecognized');
    }
    
    return entries;
  }
  
  /// Parse regex match into BankEntry
  static BankEntry? _parseMatch(String rawLine, RegExpMatch match, String bankName) {
    try {
      String dateStr = match.group(1) ?? '';
      String reference = match.group(2) ?? '';
      
      // Find amount - last matched group or before last group
      String amountStr = '';
      for (int i = match.groupCount; i >= 1; i--) {
        final group = match.group(i);
        if (group != null && _isAmountLike(group)) {
          amountStr = group;
          break;
        }
      }
      
      amountStr = amountStr.replaceAll(',', '').trim();
      final amount = double.tryParse(amountStr) ?? 0.0;
      
      final date = _parseDate(dateStr, bankName);
      
      return BankEntry(
        date: date,
        amount: amount,
        reference: reference,
        rawLine: rawLine,
        bankName: bankName,
      );
    } catch (e) {
      debugPrint('$_tag Error parsing match: $e');
      return null;
    }
  }
  
  /// Parse date based on bank format
  static DateTime _parseDate(String dateStr, String bankName) {
    try {
      switch (bankName) {
        case 'HDFC':
        case 'AXIS':
          // DD/MM/YY
          final parts = dateStr.split('/');
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          final fullYear = year < 50 ? 2000 + year : 1900 + year;
          return DateTime(fullYear, month, day);
        
        case 'SBI':
        case 'KOTAK':
          // DD-MM-YYYY
          final parts = dateStr.split('-');
          return DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        
        case 'ICICI':
          // DD/MM/YYYY
          final parts = dateStr.split('/');
          return DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        
        default:
          return DateTime.now();
      }
    } catch (e) {
      debugPrint('$_tag Date parse error: $e');
      return DateTime.now();
    }
  }
  
  /// Check if string looks like amount
  static bool _isAmountLike(String str) {
    final cleaned = str.replaceAll(',', '').replaceAll(' ', '');
    return RegExp(r'^\d+\.?\d*$').hasMatch(cleaned);
  }
  
  /// Get parsed text representation
  static String getParseReport(List<BankEntry> entries) {
    if (entries.isEmpty) return 'No transactions found.';
    
    final buffer = StringBuffer();
    buffer.writeln('📊 Parsed ${entries.length} transactions:');
    buffer.writeln('');
    
    double total = 0;
    for (final entry in entries) {
      buffer.writeln('${entry.date.toString().split(' ')[0]} | '
          '${entry.bankName} | '
          '₹${entry.amount.toStringAsFixed(2)} | '
          '${entry.reference}');
      total += entry.amount;
    }
    
    buffer.writeln('');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Total: ₹${total.toStringAsFixed(2)}');
    
    return buffer.toString();
  }
}
