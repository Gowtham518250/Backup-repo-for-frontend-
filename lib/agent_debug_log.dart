import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Debug-mode NDJSON logger for agent session 6d3a75.
class AgentDebugLog {
  static const _sessionId = '6d3a75';
  static const _ingestUrl =
      'http://127.0.0.1:7817/ingest/3cd149fe-a024-438c-8b3e-5fc0263c00d7';
  static const _winLogPath = r'd:\AI_Shop_Latest_Source_June2\lib\debug-6d3a75.log';

  static void log({
    required String location,
    required String message,
    required String hypothesisId,
    Map<String, dynamic>? data,
    String runId = 'post-fix',
  }) {
    // 🔧 FIX: Prevent release builds from sending debug logs to hardcoded localhost debug endpoint
    if (!kDebugMode) return;
    
    final payload = {
      'sessionId': _sessionId,
      'runId': runId,
      'hypothesisId': hypothesisId,
      'location': location,
      'message': message,
      'data': data ?? {},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    final line = jsonEncode(payload);
    debugPrint('[DBG-6d3a75] $line');
    _appendFile(line);
    http
        .post(
          Uri.parse(_ingestUrl),
          headers: {
            'Content-Type': 'application/json',
            'X-Debug-Session-Id': _sessionId,
          },
          body: line,
        )
        .timeout(const Duration(seconds: 2))
        .catchError((_) => http.Response('', 0));
  }

  static void _appendFile(String line) {
    if (kIsWeb) return;
    Future<void>(() async {
      try {
        io.File(_winLogPath).writeAsStringSync('$line\n', mode: io.FileMode.append);
        return;
      } catch (_) {}
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = io.File('${dir.path}/debug-6d3a75.log');
        await file.writeAsString('$line\n', mode: io.FileMode.append);
      } catch (_) {}
    });
  }
}
