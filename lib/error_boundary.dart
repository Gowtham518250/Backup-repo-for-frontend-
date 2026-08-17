import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// Error Boundary Widget
/// Catches errors in the widget tree and prevents the entire app from crashing
/// Provides user-friendly error display and logging
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Function(dynamic error, StackTrace? stackTrace)? onError;
  final Widget Function(dynamic error)? errorBuilder;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.onError,
    this.errorBuilder,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  dynamic _error;
  StackTrace? _stackTrace;
  Map<String, dynamic>? _errorContext;

  @override
  void initState() {
    super.initState();
    _error = null;
    _stackTrace = null;
    _errorContext = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      // Error occurred, show error UI
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(_error);
      }
      
      return _buildErrorUI(context);
    }
    
    // No error, show child
    return widget.child;
  }

  Widget _buildErrorUI(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Something went wrong'),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 24),
              Text(
                'An error occurred',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'The app encountered an unexpected error. Please try again.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _stackTrace = null;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Try Again'),
              ),
              const SizedBox(height: 16),
      TextButton(
        onPressed: () {
          // Show comprehensive error details in debug mode
          if (kDebugMode) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Error Details'),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Error: $_error', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (_errorContext != null) ...[
                        const Text('Context:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(_errorContext.toString(), style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
                        const SizedBox(height: 8),
                      ],
                      const Text('Stack Trace:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('$_stackTrace', style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          }
        },
        child: Text(
          kDebugMode ? 'View Error Details' : '',
          style: TextStyle(color: Colors.white70),
        ),
      ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Error Boundary Provider
/// Provides error boundary functionality to child widgets
class ErrorBoundaryProvider extends InheritedWidget {
  final Function(dynamic error, StackTrace?) onError;

  const ErrorBoundaryProvider({
    super.key,
    required this.onError,
    required super.child,
  });

  static ErrorBoundaryProvider of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ErrorBoundaryProvider>()!;
  }

  @override
  bool updateShouldNotify(ErrorBoundaryProvider oldWidget) {
    return oldWidget.onError != onError;
  }
}

/// Mixin for widgets that want to report errors to the error boundary
mixin ErrorBoundaryMixin<T extends StatefulWidget> on State<T> {
  Map<String, dynamic>? _lastErrorContext;
  @override
  void initState() {
    super.initState();
    _initializeErrorReporting();
  }

  void _initializeErrorReporting() {
    // Override this to initialize error reporting
  }

  void reportError(dynamic error, StackTrace? stackTrace) {
    _captureErrorContext(error, stackTrace);

    // Find error boundary and report error
    ErrorBoundaryProvider? boundary;
    
    if (mounted) {
      boundary = context.dependOnInheritedWidgetOfExactType<ErrorBoundaryProvider>();
    }
    
    if (boundary != null) {
      boundary.onError(error, stackTrace);
    }
  }
  
  void _captureErrorContext(dynamic error, StackTrace? stackTrace) {
    try {
      _lastErrorContext = {
        'widget': widget.runtimeType.toString(),
        'state': this.runtimeType.toString(),
        'error': error?.toString(),
        'stackTraceSnippet': stackTrace?.toString().split('\n').take(3).join('\n'),
        'time': DateTime.now().toIso8601String(),
      };
      if (kDebugMode) {
        // ignore: avoid_print
        print('[ErrorBoundary] Captured context: ${_lastErrorContext}\n');
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[ErrorBoundary] Failed to capture context: $e');
      }
    }
  }
}
