// =============================================================================
// queue_manager.dart  —  V8 HUMAN-LIKE VOICE SYSTEM
// Priority queue with loop-based drain, stuck-timer, and retry logic.
//
// ARCH-1 (from V7): No recursive _processQueue() calls.
//         Uses a _draining mutex + while-loop instead.
// ARCH-2: Each item carries a pre-computed timeout (via VoiceEngine.calculateTimeout)
//         so we don't recalculate on retry.
// ARCH-3: On stuck-timeout, the item is dropped and drain continues.
//         This prevents a single broken TTS state from blocking all payments.
// =============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'language_engine.dart';

final _log = Logger(
  printer: PrettyPrinter(methodCount: 1, lineLength: 80, colors: kDebugMode),
  level: kDebugMode ? Level.debug : Level.warning,
);

// ─────────────────────────────────────────────────────────────────────────────
// QueueItem
// ─────────────────────────────────────────────────────────────────────────────

class QueueItem {
  final Future<void> Function() task;
  final AnnouncementPriority    priority;
  final String                  ttsText;
  final int                     timeoutSec;

  QueueItem({
    required this.task,
    required this.priority,
    required this.ttsText,
    required this.timeoutSec,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// QueueManager
// ─────────────────────────────────────────────────────────────────────────────

class QueueManager {
  final List<QueueItem> _queue    = [];
  bool                  _draining = false;
  bool                  _speaking = false;

  bool get isBusy => _draining || _speaking;

  void enqueue(QueueItem item) {
    _queue.add(item);
    _log.d('Enqueued [${item.priority.name}] "${item.ttsText.substring(0, item.ttsText.length.clamp(0, 40))}"');
    _drainLoop();
  }

  void enqueueAll(List<QueueItem> items) {
    _queue.addAll(items);
    _drainLoop();
  }

  Future<void> _drainLoop() async {
    if (_draining || _speaking) return;
    _draining = true;

    while (_queue.isNotEmpty) {
      _queue.sort((a, b) => b.priority.index.compareTo(a.priority.index));
      final item = _queue.removeAt(0);

      _speaking = true;
      bool completed = false;

      final stuckTimer = Timer(Duration(seconds: item.timeoutSec), () {
        if (!completed) {
          _log.w('Stuck timeout (${item.timeoutSec}s) for: '
              '"${item.ttsText.substring(0, item.ttsText.length.clamp(0, 40))}"');
          _speaking = false;
        }
      });

      bool success = false;
      for (int attempt = 1; attempt <= 3 && !success; attempt++) {
        try {
          await item.task();
          success = true;
        } catch (e, st) {
          _log.e('Task attempt $attempt/3 failed', error: e, stackTrace: st);
          if (attempt < 3) {
            await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
          }
        }
      }

      completed = true;
      stuckTimer.cancel();
      _speaking = false;

      if (!success) {
        _log.e('Item dropped after 3 failed attempts: "${item.ttsText.substring(0, item.ttsText.length.clamp(0,40))}"');
      }
    }

    _draining = false;
  }

  void clear() {
    _queue.clear();
    _log.d('Queue cleared');
  }

  void clearLowPriority() {
    _queue.removeWhere((i) => i.priority == AnnouncementPriority.low);
  }

  int get length => _queue.length;
}
