import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Production audit trail.
/// Critical rule: audit data is scoped to the authenticated local account.
/// This is a local companion log; the backend audit log remains authoritative.
class AuditLoggingService {
  static AuditLoggingService? _instance;
  static const String _auditLogKeyPrefix = 'audit_log_v2_';
  static const int _maxLogEntries = 1000;

  AuditLoggingService._();

  static AuditLoggingService get instance {
    _instance ??= AuditLoggingService._();
    return _instance!;
  }

  Future<String> _scopeKey() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? prefs.getInt('userId');
    final shopId = prefs.getInt('active_shop_id');
    return '$_auditLogKeyPrefix${userId ?? "anonymous"}_${shopId ?? "default"}';
  }

  Future<Map<String, dynamic>> _identity() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'user_id': prefs.getInt('user_id') ?? prefs.getInt('userId'),
      'shop_id': prefs.getInt('active_shop_id'),
    };
  }

  String _eventId(DateTime now, int index) =>
      '${now.microsecondsSinceEpoch}_$index';

  Future<void> logEvent(AuditEvent event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _scopeKey();
      final raw = prefs.getString(key) ?? '[]';

      final decoded = json.decode(raw);
      final log = decoded is List
          ? decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      final identity = await _identity();
      final now = DateTime.now();
      final enriched = event.copyWith(
        eventId: event.eventId ?? _eventId(now, log.length),
        timestamp: event.timestamp,
        userId: event.userId ?? identity['user_id'],
        shopId: event.shopId ?? identity['shop_id'],
      );

      log.add(enriched.toJson());

      if (log.length > _maxLogEntries) {
        log.removeRange(0, log.length - _maxLogEntries);
      }

      await prefs.setString(key, json.encode(log));

      if (kDebugMode) {
        debugPrint(
          '📝 Audit: ${enriched.eventId} [${enriched.type.name}] '
          '${enriched.action} user=${enriched.userId} shop=${enriched.shopId}',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error logging audit event: $e');
    }
  }

  Future<void> logDataOperation(
    String dataType,
    String operation,
    Map<String, dynamic> details, {
    int? recordId,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
  }) async {
    await logEvent(
      AuditEvent(
        type: AuditType.dataOperation,
        action: operation,
        description: '$operation on $dataType',
        details: {
          ...details,
          if (recordId != null) 'record_id': recordId,
          if (oldValues != null) 'old_values': oldValues,
          if (newValues != null) 'new_values': newValues,
        },
        dataType: dataType,
      ),
    );
  }

  Future<void> logSyncOperation(
    String syncType,
    bool success, {
    String? error,
  }) async {
    await logEvent(
      AuditEvent(
        type: AuditType.syncOperation,
        action: syncType,
        description: 'Sync: $syncType - ${success ? "Success" : "Failed"}',
        success: success,
        error: error,
      ),
    );
  }

  Future<void> logUserAction(
    String action,
    Map<String, dynamic> context,
  ) async {
    await logEvent(
      AuditEvent(
        type: AuditType.userAction,
        action: action,
        description: 'User action: $action',
        details: context,
      ),
    );
  }

  Future<void> logSystemEvent(
    String event,
    Map<String, dynamic> details,
  ) async {
    await logEvent(
      AuditEvent(
        type: AuditType.systemEvent,
        action: event,
        description: 'System event: $event',
        details: details,
      ),
    );
  }

  Future<void> logError(
    String error, {
    String? context,
    Map<String, dynamic>? details,
  }) async {
    await logEvent(
      AuditEvent(
        type: AuditType.error,
        action: 'error',
        description: 'Error: $error',
        error: error,
        context: context,
        details: details,
      ),
    );
  }

  Future<void> logSecurityEvent(
    String event,
    Map<String, dynamic> details,
  ) async {
    await logEvent(
      AuditEvent(
        type: AuditType.securityEvent,
        action: event,
        description: 'Security event: $event',
        details: details,
      ),
    );
  }

  Future<List<AuditEvent>> getAuditLog({
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _scopeKey();
      final raw = prefs.getString(key) ?? '[]';
      final decoded = json.decode(raw);

      final events = decoded is List
          ? decoded
              .whereType<Map>()
              .map((e) => AuditEvent.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList()
          : <AuditEvent>[];

      if (startDate != null || endDate != null) {
        events.removeWhere((event) {
          if (startDate != null && event.timestamp.isBefore(startDate)) {
            return true;
          }
          if (endDate != null && event.timestamp.isAfter(endDate)) {
            return true;
          }
          return false;
        });
      }

      events.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (limit != null && events.length > limit) {
        return events.sublist(0, limit);
      }

      return events;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting audit log: $e');
      return [];
    }
  }

  Future<List<AuditEvent>> getEventsByType(
    AuditType type, {
    int? limit,
  }) async {
    final all = await getAuditLog();
    final filtered = all.where((e) => e.type == type).toList();
    return limit != null && filtered.length > limit
        ? filtered.sublist(0, limit)
        : filtered;
  }

  Future<List<AuditEvent>> searchAuditLog(String query) async {
    final all = await getAuditLog();
    final q = query.toLowerCase();
    return all
        .where(
          (event) =>
              event.action.toLowerCase().contains(q) ||
              event.description.toLowerCase().contains(q) ||
              (event.error?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  Future<void> clearAuditLog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(await _scopeKey());
      if (kDebugMode) debugPrint('🗑️ Scoped audit log cleared');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error clearing audit log: $e');
    }
  }

  Future<String> exportAuditLog() async {
    final events = await getAuditLog();
    final lines = events.map((e) => e.toExportString()).join('\n');
    return 'AUDIT LOG EXPORT\n'
        'Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}\n\n'
        '$lines';
  }

  Future<AuditStatistics> getAuditStatistics() async {
    final events = await getAuditLog();
    final stats = AuditStatistics();

    for (final event in events) {
      stats.totalEvents++;
      switch (event.type) {
        case AuditType.dataOperation:
          stats.dataOperations++;
          break;
        case AuditType.syncOperation:
          stats.syncOperations++;
          if (event.success == false) stats.failedSyncs++;
          break;
        case AuditType.userAction:
          stats.userActions++;
          break;
        case AuditType.systemEvent:
          stats.systemEvents++;
          break;
        case AuditType.error:
          stats.errors++;
          break;
        case AuditType.securityEvent:
          stats.securityEvents++;
          break;
      }
    }

    return stats;
  }
}

class AuditEvent {
  final AuditType type;
  final String action;
  final String description;
  final DateTime timestamp;
  final bool? success;
  final String? error;
  final String? context;
  final Map<String, dynamic>? details;
  final String? dataType;
  final String? eventId;
  final int? userId;
  final int? shopId;

  AuditEvent({
    required this.type,
    required this.action,
    required this.description,
    DateTime? timestamp,
    this.success,
    this.error,
    this.context,
    this.details,
    this.dataType,
    this.eventId,
    this.userId,
    this.shopId,
  }) : timestamp = timestamp ?? DateTime.now();

  AuditEvent copyWith({
    String? eventId,
    int? userId,
    int? shopId,
    DateTime? timestamp,
  }) {
    return AuditEvent(
      type: type,
      action: action,
      description: description,
      timestamp: timestamp ?? this.timestamp,
      success: success,
      error: error,
      context: context,
      details: details,
      dataType: dataType,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      shopId: shopId ?? this.shopId,
    );
  }

  Map<String, dynamic> toJson() => {
        'event_id': eventId,
        'type': type.toString(),
        'action': action,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
        'success': success,
        'error': error,
        'context': context,
        'details': details,
        'data_type': dataType,
        'user_id': userId,
        'shop_id': shopId,
      };

  static AuditEvent fromJson(Map<String, dynamic> json) {
    return AuditEvent(
      type: _parseAuditType(json['type']?.toString()),
      action: json['action']?.toString() ?? 'unknown',
      description: json['description']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      success: json['success'] is bool ? json['success'] as bool : null,
      error: json['error']?.toString(),
      context: json['context']?.toString(),
      details: json['details'] is Map
          ? Map<String, dynamic>.from(json['details'] as Map)
          : null,
      dataType: json['data_type']?.toString(),
      eventId: json['event_id']?.toString(),
      userId: (json['user_id'] as num?)?.toInt(),
      shopId: (json['shop_id'] as num?)?.toInt(),
    );
  }

  String toExportString() {
    final buffer = StringBuffer();
    buffer.writeln(
      '[${DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp)}] '
      '${type.name.toUpperCase()}',
    );
    buffer.writeln('  Event ID: ${eventId ?? "N/A"}');
    buffer.writeln('  User ID: ${userId ?? "N/A"}');
    buffer.writeln('  Shop ID: ${shopId ?? "N/A"}');
    buffer.writeln('  Action: $action');
    buffer.writeln('  Description: $description');
    if (success != null) buffer.writeln('  Success: $success');
    if (error != null) buffer.writeln('  Error: $error');
    if (context != null) buffer.writeln('  Context: $context');
    if (details != null && details!.isNotEmpty) {
      buffer.writeln('  Details:');
      details!.forEach((key, value) {
        buffer.writeln('    $key: $value');
      });
    }
    return buffer.toString();
  }

  static AuditType _parseAuditType(String? typeString) {
    switch (typeString) {
      case 'AuditType.dataOperation':
        return AuditType.dataOperation;
      case 'AuditType.syncOperation':
        return AuditType.syncOperation;
      case 'AuditType.userAction':
        return AuditType.userAction;
      case 'AuditType.systemEvent':
        return AuditType.systemEvent;
      case 'AuditType.error':
        return AuditType.error;
      case 'AuditType.securityEvent':
        return AuditType.securityEvent;
      default:
        return AuditType.systemEvent;
    }
  }
}

enum AuditType {
  dataOperation,
  syncOperation,
  userAction,
  systemEvent,
  error,
  securityEvent,
}

class AuditStatistics {
  int totalEvents = 0;
  int dataOperations = 0;
  int syncOperations = 0;
  int failedSyncs = 0;
  int userActions = 0;
  int systemEvents = 0;
  int errors = 0;
  int securityEvents = 0;

  double get syncSuccessRate {
    if (syncOperations == 0) return 0.0;
    return ((syncOperations - failedSyncs) / syncOperations) * 100;
  }
}
