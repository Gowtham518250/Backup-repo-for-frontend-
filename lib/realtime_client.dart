import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

typedef RealtimeMessageHandler = void Function(Map<String, dynamic> message);
typedef RealtimeStatusHandler = void Function(bool connected, String message);

class RealtimeClient {
  static WebSocket? _socket;
  static Timer? _heartbeatTimer;
  static Timer? _reconnectTimer;
  static RealtimeMessageHandler? _onMessage;
  static RealtimeStatusHandler? _onStatus;
  static bool _closing = false;

  static bool get isConnected =>
      _socket != null && _socket!.readyState == WebSocket.open;

  static Future<void> connect({
    required int userId,
    required int shopId,
    required RealtimeMessageHandler onMessage,
    required RealtimeStatusHandler onStatus,
  }) async {
    _onMessage = onMessage;
    _onStatus = onStatus;
    _closing = false;
    _cancelReconnect();

    if (kIsWeb) {
      _onStatus?.call(false, 'Live updates are not supported on web.');
      return;
    }

    final url = _buildWebSocketUrl(userId, shopId);
    _onStatus?.call(false, 'Connecting to live dashboard...');

    try {
      await _disconnectInternal();
      _socket = await WebSocket.connect(url).timeout(const Duration(seconds: 15));
      _socket!.listen(
        _handleRawMessage,
        onDone: _handleDone,
        onError: _handleError,
        cancelOnError: true,
      );

      _sendSubscribeAll();
      _startHeartbeat();
      _onStatus?.call(true, 'Live dashboard connected');
    } catch (error) {
      _onStatus?.call(false, 'Live connect failed');
      _scheduleReconnect(userId: userId, shopId: shopId);
    }
  }

  static Future<void> disconnect() async {
    _closing = true;
    _cancelHeartbeat();
    _cancelReconnect();
    if (_socket != null) {
      try {
        await _socket!.close(WebSocketStatus.normalClosure, 'Client disconnect');
      } catch (_) {}
      _socket = null;
    }
    _onStatus?.call(false, 'Realtime disconnected');
  }

  static String _buildWebSocketUrl(int userId, int shopId) {
    final baseUri = Uri.parse(ApiClient.baseUrl);
    final scheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : null,
      path: '/api/ws/live/$userId/$shopId',
    ).toString();
  }

  static void _handleRawMessage(dynamic raw) {
    if (raw == null) return;
    try {
      final payload = json.decode(raw.toString());
      if (payload is Map<String, dynamic>) {
        _onMessage?.call(payload);
      }
    } catch (_) {
      // ignore malformed realtime payloads
    }
  }

  static void _handleDone() {
    _onStatus?.call(false, 'Live dashboard disconnected');
    _cancelHeartbeat();
    if (!_closing) {
      _scheduleReconnect();
    }
  }

  static void _handleError(Object error) {
    _onStatus?.call(false, 'Realtime connection error');
    _cancelHeartbeat();
    if (!_closing) {
      _scheduleReconnect();
    }
  }

  static void _sendSubscribeAll() {
    if (_socket == null || _socket!.readyState != WebSocket.open) return;
    final message = json.encode({'action': 'subscribe', 'channel': 'all'});
    _socket!.add(message);
  }

  static void _sendPing() {
    if (_socket == null || _socket!.readyState != WebSocket.open) return;
    _socket!.add(json.encode({'action': 'ping'}));
  }

  static void _startHeartbeat() {
    _cancelHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _sendPing();
    });
  }

  static void _cancelHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  static void _scheduleReconnect({int? userId, int? shopId}) {
    if (_closing || _reconnectTimer != null) return;
    int attempt = 0;
    _reconnectTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      attempt++;
      final delaySeconds = attempt < 5 ? attempt * 2 : 30; // Exponential backoff
      if (attempt == 1 || timer.tick % delaySeconds == 0) {
        if (userId != null && shopId != null) {
          connect(
            userId: userId,
            shopId: shopId,
            onMessage: _onMessage!,
            onStatus: _onStatus!,
          );
        }
      }
      if (attempt >= 10) timer.cancel(); // Stop after 10 attempts
    });
  }

  static void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  static Future<void> _disconnectInternal() async {
    if (_socket != null) {
      try {
        await _socket!.close(WebSocketStatus.normalClosure, 'Reconnect');
      } catch (_) {}
      _socket = null;
    }
    _cancelHeartbeat();
  }
}
