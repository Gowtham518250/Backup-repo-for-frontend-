// ============================================================================
// SMS_BACKGROUND_RECEIVER.DART
// Native SMS receiver that survives OEM app kill on Xiaomi/Vivo/OPPO/Realme
// ============================================================================

import 'package:flutter/services.dart';
import 'package:telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'dart:convert';
import 'dart:math' as math;

/// Prefix used to identify SMS queue keys in SharedPreferences.
/// Each incoming SMS is stored under a unique key to avoid race conditions.
const String _kSmsQueuePrefix = 'bg_sms_';

const MethodChannel _nativeChannel = MethodChannel('com.retail_mind/sms_receiver');

/// This handler is invoked when SMS is received in the background
/// The @pragma annotation ensures this stays available even if app is killed
/// Telephony requires: void backgroundMessageHandler(SmsMessage message)
@pragma('vm:entry-point')
Future<void> smsBackgroundHandler(SmsMessage message) async {
  final sender = message.address ?? 'Unknown';
  final body   = message.body    ?? '';
  
  developer.log(
    'SMS received in background: from=$sender, length=${body.length}',
    name: 'sms_receiver',
  );

  try {
    // FIX (Issue 2.1): Store each SMS under a unique key to eliminate the
    // read-modify-write race condition between the background isolate (writer)
    // and the main isolate (reader/deleter).
    final prefs = await SharedPreferences.getInstance();
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = math.Random().nextInt(999999).toString().padLeft(6, '0');
    final uniqueKey = '$_kSmsQueuePrefix${timestamp}_$randomSuffix';
    
    final payload = jsonEncode({
      'sender': sender,
      'body': body,
      'time': timestamp,
    });
    
    await prefs.setString(uniqueKey, payload);
    
    developer.log(
      'SMS stored in background queue with key: $uniqueKey',
      name: 'sms_receiver',
    );
  } catch (e) {
    developer.log('Error caching SMS: $e', name: 'sms_receiver', error: e);
  }
}

/// Register the native SMS receiver
Future<bool> registerSmsBroadcastReceiver() async {
  try {
    final result = await _nativeChannel.invokeMethod<bool>(
      'registerSmsReceiver',
    );
    developer.log(
      'SMS BroadcastReceiver registered: $result',
      name: 'sms_receiver',
    );
    return result ?? false;
  } on PlatformException catch (e) {
    developer.log(
      'Failed to register SMS receiver: ${e.message}',
      name: 'sms_receiver',
      error: e,
    );
    return false;
  }
}

/// Unregister the native SMS receiver
Future<bool> unregisterSmsBroadcastReceiver() async {
  try {
    final result = await _nativeChannel.invokeMethod<bool>(
      'unregisterSmsReceiver',
    );
    developer.log(
      'SMS BroadcastReceiver unregistered: $result',
      name: 'sms_receiver',
    );
    return result ?? false;
  } on PlatformException catch (e) {
    developer.log(
      'Failed to unregister SMS receiver: ${e.message}',
      name: 'sms_receiver',
      error: e,
    );
    return false;
  }
}

/// Retrieve and clear pending background SMS
///
/// FIX (Issue 2.1): Uses atomic per-key reads to prevent data loss.
/// The reader:
///   1. Collects the set of keys that were present at call time.
///   2. Reads and decodes only those specific keys.
///   3. Deletes only the keys it successfully read.
/// Any key written by the background isolate *after* step 1 is left intact.
Future<List<Map<String, String>>> getPendingBackgroundSms() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Snapshot the current set of SMS queue keys.
    final allKeys = prefs.getKeys()
        .where((k) => k.startsWith(_kSmsQueuePrefix))
        .toList();
    
    if (allKeys.isEmpty) return [];
    
    // 2. Read and decode each key individually.
    final result = <Map<String, String>>[];
    final keysToRemove = <String>[];
    
    for (final key in allKeys) {
      try {
        final raw = prefs.getString(key);
        if (raw != null) {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          result.add({
            'sender': (decoded['sender'] ?? '').toString(),
            'body': (decoded['body'] ?? '').toString(),
          });
          keysToRemove.add(key);
        }
      } catch (e) {
        developer.log('Error decoding SMS key $key: $e', name: 'sms_receiver');
        // Still remove the malformed key to avoid it blocking future reads.
        keysToRemove.add(key);
      }
    }
    
    // 3. Delete only the keys we successfully processed.
    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
    
    developer.log(
      'Retrieved ${result.length} pending background SMS',
      name: 'sms_receiver',
    );
    
    return result;
  } catch (e) {
    developer.log(
      'Error retrieving pending SMS: $e',
      name: 'sms_receiver',
      error: e,
    );
    return [];
  }
}

/// Check if this is an OEM-restricted device (Xiaomi/Vivo/OPPO/Realme)
Future<bool> isOemRestrictedDevice() async {
  try {
    final result = await _nativeChannel.invokeMethod<bool>(
      'isOemRestrictedDevice',
    );
    return result ?? false;
  } catch (_) {
    return false;
  }
}

/// Request battery optimization exemption status
Future<bool> isIgnoringBatteryOptimizations() async {
  try {
    final result = await _nativeChannel.invokeMethod<bool>(
      'isIgnoringBatteryOptimizations',
    );
    return result ?? false;
  } catch (_) {
    return false;
  }
}

/// Request battery optimization exemption
Future<void> requestBatteryOptimizationExemption() async {
  try {
    await _nativeChannel.invokeMethod(
      'requestBatteryOptimizationExemption',
    );
  } catch (e) {
    developer.log(
      'Failed to request battery exemption: $e',
      name: 'sms_receiver',
      error: e,
    );
  }
}
