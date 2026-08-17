import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for managing file downloads and device storage
class FileDownloadService {
  // Get the Downloads directory on device
  static Future<Directory?> getDownloadsDirectory() async {
    try {
      // Request permission if needed
      final status = await Permission.storage.request();
      
      if (!status.isGranted) {
        debugPrint('❌ Storage permission denied');
        return null;
      }

      if (Platform.isAndroid) {
        // For Android, use Downloads folder
        final dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      } else if (Platform.isIOS) {
        // For iOS, use Documents directory
        return await getApplicationDocumentsDirectory();
      }
      
      return await getApplicationDocumentsDirectory();
    } catch (e) {
      debugPrint('❌ Error getting downloads directory: $e');
      return null;
    }
  }

  // Save PDF file to Downloads
  static Future<String?> savePDFToDownloads({
    required String fileName,
    required List<int> fileBytes,
  }) async {
    try {
      final downloadDir = await getDownloadsDirectory();
      
      if (downloadDir == null) {
        debugPrint('❌ Could not access downloads directory');
        return null;
      }

      // Ensure filename has .pdf extension
      String finalFileName = fileName;
      if (!fileName.toLowerCase().endsWith('.pdf')) {
        finalFileName = '$fileName.pdf';
      }

      final filePath = '${downloadDir.path}/$finalFileName';
      final file = File(filePath);

      // Write file to disk
      await file.writeAsBytes(fileBytes);

      debugPrint('✅ PDF saved to: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('❌ Error saving PDF: $e');
      return null;
    }
  }

  // Save CSV file to Downloads
  static Future<String?> saveCSVToDownloads({
    required String fileName,
    required String csvContent,
  }) async {
    try {
      final downloadDir = await getDownloadsDirectory();
      
      if (downloadDir == null) {
        debugPrint('❌ Could not access downloads directory');
        return null;
      }

      // Ensure filename has .csv extension
      String finalFileName = fileName;
      if (!fileName.toLowerCase().endsWith('.csv')) {
        finalFileName = '$fileName.csv';
      }

      final filePath = '${downloadDir.path}/$finalFileName';
      final file = File(filePath);

      // Write file to disk
      await file.writeAsString(csvContent);

      debugPrint('✅ CSV saved to: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('❌ Error saving CSV: $e');
      return null;
    }
  }

  // Get list of downloaded files
  static Future<List<File>> getDownloadedFiles() async {
    try {
      final downloadDir = await getDownloadsDirectory();
      
      if (downloadDir == null) {
        return [];
      }

      final files = downloadDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.pdf') || f.path.endsWith('.csv'))
          .toList();

      return files;
    } catch (e) {
      debugPrint('❌ Error listing downloaded files: $e');
      return [];
    }
  }

  // Delete a downloaded file
  static Future<bool> deleteDownloadedFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('✅ File deleted: $filePath');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error deleting file: $e');
      return false;
    }
  }

  // Get file size in human-readable format
  static String getFileSizeString(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
