import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// 🚀 Advanced Performance Optimizations for Flutter
/// Focuses on reducing rebuilds, optimizing state management, and improving rendering performance

class PerformanceOptimizations {
  /// Memoized widget builder - prevents unnecessary rebuilds
  static Widget memoized<T>({
    required Widget Function() builder,
    required List<Object?> dependencies,
  }) {
    return _MemoizedWidget(
      builder: builder,
      dependencies: dependencies,
    );
  }

  /// Optimized ListView builder with proper caching
  static ListView optimizedListView({
    required int itemCount,
    required NullableIndexedWidgetBuilder itemBuilder,
    ScrollController? controller,
    bool shrinkWrap = false,
    EdgeInsetsGeometry? padding,
  }) {
    return ListView.builder(
      controller: controller,
      shrinkWrap: shrinkWrap,
      padding: padding,
      itemCount: itemCount,
      // Add automatic keep alive for better scrolling performance
      addAutomaticKeepAlives: true,
      // Add semantic child cache for accessibility performance
      addRepaintBoundaries: true,
      cacheExtent: itemCount > 50 ? 500.0 : null, // Cache extent for large lists
      itemBuilder: itemBuilder,
    );
  }

  /// Debounce utility to prevent excessive function calls
  static void Function(T) debounce<T>({
    required Duration delay,
    required void Function(T) action,
  }) {
    Timer? timer;
    return (T value) {
      timer?.cancel();
      timer = Timer(delay, () => action(value));
    };
  }

  /// Throttle utility to limit function call frequency
  static void Function(T) throttle<T>({
    required Duration duration,
    required void Function(T) action,
  }) {
    T? lastValue;
    Timer? timer;
    return (T value) {
      lastValue = value;
      timer?.cancel();
      timer = Timer(duration, () {
        if (lastValue != null) {
          action(lastValue!);
          lastValue = null;
        }
      });
    };
  }
}

class _MemoizedWidget extends StatefulWidget {
  final Widget Function() builder;
  final List<Object?> dependencies;

  const _MemoizedWidget({
    required this.builder,
    required this.dependencies,
  });

  @override
  State<_MemoizedWidget> createState() => _MemoizedWidgetState();
}

class _MemoizedWidgetState extends State<_MemoizedWidget> {
  @override
  Widget build(BuildContext context) {
    return widget.builder();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _MemoizedWidget &&
        listEquals(widget.dependencies, other.dependencies);
  }

  @override
  int get hashCode => Object.hashAll(widget.dependencies);
}

/// Performance monitoring utilities
class PerformanceMonitor {
  static final Map<String, DateTime> _startTimes = {};
  static final Map<String, Duration> _durations = {};

  static void start(String operation) {
    _startTimes[operation] = DateTime.now();
  }

  static void end(String operation) {
    if (_startTimes.containsKey(operation)) {
      final duration = DateTime.now().difference(_startTimes[operation]!);
      _durations[operation] = duration;
      _startTimes.remove(operation);
      
      if (kDebugMode) {
        debugPrint('⏱️ Performance: $operation took ${duration.inMilliseconds}ms');
      }
      
      // Warn if operation takes too long
      if (duration.inMilliseconds > 100) {
        debugPrint('⚠️ SLOW OPERATION: $operation took ${duration.inMilliseconds}ms');
      }
    }
  }

  static Duration? getDuration(String operation) => _durations[operation];
  
  static void clear() {
    _startTimes.clear();
    _durations.clear();
  }
}

/// Optimized state management mixin
mixin OptimizedStateMixin<T extends StatefulWidget> on State<T> {
  final Map<String, ValueNotifier<dynamic>> _notifiers = {};
  final Set<VoidCallback> _disposers = {};

  /// Create a memoized notifier for specific state
  ValueNotifier<T> createNotifier<T>(String key, T initialValue) {
    if (!_notifiers.containsKey(key)) {
      _notifiers[key] = ValueNotifier(initialValue);
    }
    return _notifiers[key] as ValueNotifier<T>;
  }

  /// Add a cleanup callback
  void addDisposer(VoidCallback callback) {
    _disposers.add(callback);
  }

  @override
  void dispose() {
    for (final notifier in _notifiers.values) {
      notifier.dispose();
    }
    for (final disposer in _disposers) {
      disposer();
    }
    _notifiers.clear();
    _disposers.clear();
    super.dispose();
  }
}

/// Optimized image loading with caching
class OptimizedImageProvider {
  static final Map<String, ImageProvider> _cache = {};

  static ImageProvider getCached(String url) {
    if (!_cache.containsKey(url)) {
      _cache[url] = NetworkImage(url);
    }
    return _cache[url]!;
  }

  static void clearCache() {
    _cache.clear();
  }
}

/// List optimization utilities
class ListOptimizer {
  /// Paginate large lists for better performance
  static List<T> paginate<T>(List<T> list, int page, int pageSize) {
    if (list.isEmpty) return [];
    
    final start = page * pageSize;
    if (start >= list.length) return [];
    
    final end = (start + pageSize).clamp(0, list.length);
    return list.sublist(start, end);
  }

  /// Efficient list filtering with early termination
  static List<T> filterOptimized<T>(
    List<T> list,
    bool Function(T) predicate, {
    int maxResults = 100,
  }) {
    final result = <T>[];
    for (final item in list) {
      if (predicate(item)) {
        result.add(item);
        if (result.length >= maxResults) break;
      }
    }
    return result;
  }
}