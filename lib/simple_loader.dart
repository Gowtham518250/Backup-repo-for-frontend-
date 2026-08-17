import 'package:flutter/material.dart';

/// Lightweight, reusable loading indicator for async button actions
/// (create/update/logout, etc). Shows a small non-dismissible dialog with a
/// spinner + message, and guarantees it gets dismissed even if the action
/// throws, so buttons can never get stuck showing a spinner forever.
///
/// Usage:
///   await SimpleLoader.run(context, 'Saving...', () async {
///     await someAsyncAction();
///   });
class SimpleLoader {
  static bool _visible = false;

  /// Runs [action] while showing a small loading dialog with [message].
  /// The dialog is always dismissed afterwards, whether [action] succeeds,
  /// throws, or the widget is unmounted by the time it finishes. Rethrows
  /// any error from [action] so callers can still show their own error UI.
  static Future<T> run<T>(
    BuildContext context,
    String message,
    Future<T> Function() action,
  ) async {
    _show(context, message);
    try {
      return await action();
    } finally {
      _hide(context);
    }
  }

  static void _show(BuildContext context, String message) {
    if (_visible) return;
    _visible = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 16),
              Flexible(child: Text(message)),
            ],
          ),
        ),
      ),
    );
  }

  static void _hide(BuildContext context) {
    if (!_visible) return;
    _visible = false;
    if (context.mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}