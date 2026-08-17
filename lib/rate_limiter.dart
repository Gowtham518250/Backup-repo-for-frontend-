import 'package:flutter/foundation.dart';

/// Rate limiting helper to prevent API abuse
class RateLimiter {
  static const Duration defaultWindow = Duration(seconds: 1);
  static const int defaultMaxRequests = 10; // 10 requests per second max
  
  final Map<String, List<DateTime>> _requestLog = {};
  final Duration window;
  final int maxRequests;

  RateLimiter({
    this.window = defaultWindow,
    this.maxRequests = defaultMaxRequests,
  });

  /// Check if request is allowed (returns true if within limits)
  bool allowRequest(String endpoint) {
    final now = DateTime.now();
    
    // Initialize if first request
    if (!_requestLog.containsKey(endpoint)) {
      _requestLog[endpoint] = [];
    }
    
    final log = _requestLog[endpoint]!;
    
    // Remove old requests outside the window
    log.removeWhere((time) => now.difference(time) > window);
    
    // Check if we've exceeded the limit
    if (log.length >= maxRequests) {
    if (kDebugMode) debugPrint('⚠️ Rate limit exceeded for $endpoint (${log.length}/$maxRequests requests)');
      return false;
    }
    
    // Record this request
    log.add(now);
    return true;
  }

  /// Get current request count for endpoint
  int getRequestCount(String endpoint) {
    final log = _requestLog[endpoint];
    if (log == null) return 0;
    
    final now = DateTime.now();
    log.removeWhere((time) => now.difference(time) > window);
    return log.length;
  }

  /// Reset rate limiter for specific endpoint
  void reset(String endpoint) {
    _requestLog.remove(endpoint);
  }

  /// Reset all endpoints
  void resetAll() {
    _requestLog.clear();
  }

  /// Get wait time in milliseconds if rate limited
  int getWaitTimeMs(String endpoint) {
    final log = _requestLog[endpoint];
    if (log == null || log.isEmpty || log.length < maxRequests) return 0;
    
    final now = DateTime.now();
    final oldestRequest = log.first;
    final timeUntilExpiry = oldestRequest.add(window).difference(now);
    
    return timeUntilExpiry.inMilliseconds.clamp(0, window.inMilliseconds);
  }

  /// Wait until rate limit allows (blocks until ready)
  Future<void> waitIfRateLimited(String endpoint) async {
    int waitMs = getWaitTimeMs(endpoint);
    if (waitMs > 0) {
    if (kDebugMode) debugPrint('⏳ Rate limited, waiting $waitMs...');
      await Future.delayed(Duration(milliseconds: waitMs));
    }
  }
}



