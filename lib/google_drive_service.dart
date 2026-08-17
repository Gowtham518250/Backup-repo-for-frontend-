import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'local_storage_service.dart';

class GoogleDriveService {
  static final _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  static const String _backupFileName = 'ai_shop_backup.json';

  /// Authenticate and get Google Drive API Client
  static Future<drive.DriveApi?> _getDriveApi() async {
    try {
      var account = _googleSignIn.currentUser;
      account ??= await _googleSignIn.signInSilently();
      account ??= await _googleSignIn.signIn();

      if (account == null) {
        if (kDebugMode) debugPrint('Google Sign-In aborted or failed.');
        return null;
      }

      final httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) return null;

      return drive.DriveApi(httpClient);
    } catch (e) {
      if (kDebugMode) debugPrint('Error in _getDriveApi: $e');
      return null;
    }
  }

  /// Backup Local Data to Google Drive
  static Future<bool> backupToDrive() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return false;

      // 1. Export local data to a JSON file
      final localBackupPath = await LocalStorageService.exportSecureBackup();
      if (localBackupPath == null) return false;

      final backupFile = File(localBackupPath);
      final fileLength = await backupFile.length();

      // 2. Check if backup already exists
      final q = "name = '$_backupFileName' and trashed = false";
      final fileList = await driveApi.files.list(q: q, spaces: 'drive');
      
      final media = drive.Media(backupFile.openRead(), fileLength);
      
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        // Overwrite existing
        final existingFileId = fileList.files!.first.id!;
        await driveApi.files.update(
          drive.File(),
          existingFileId,
          uploadMedia: media,
        );
        if (kDebugMode) debugPrint('✅ Google Drive Backup Overwritten!');
      } else {
        // Create new
        final driveFile = drive.File()
          ..name = _backupFileName
          ..mimeType = 'application/json';
          
        await driveApi.files.create(
          driveFile,
          uploadMedia: media,
        );
        if (kDebugMode) debugPrint('✅ Google Drive Backup Created!');
      }

      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Backup to Drive Failed: $e');
      return false;
    }
  }

  /// Restore Local Data from Google Drive
  static Future<bool> restoreFromDrive() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return false;

      final q = "name = '$_backupFileName' and trashed = false";
      final fileList = await driveApi.files.list(q: q, spaces: 'drive');

      if (fileList.files == null || fileList.files!.isEmpty) {
        if (kDebugMode) debugPrint('No backup file found in Drive.');
        return false;
      }

      final fileId = fileList.files!.first.id!;
      
      final response = await driveApi.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      
      final bytes = await response.stream.expand((x) => x).toList();
      final jsonPayload = utf8.decode(bytes);

      // Import to LocalStorageService
      final success = await LocalStorageService.importSecureBackup(jsonPayload);
      if (success) {
        if (kDebugMode) debugPrint('✅ Restored from Drive successfully!');
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Restore from Drive Failed: $e');
      return false;
    }
  }
}
