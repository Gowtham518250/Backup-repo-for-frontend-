import 'dart:async';

/// Timeout Configuration Class
/// Centralizes timeout values for different operations
class TimeoutConfig {
  // Default timeouts increased for Render cold starts (takes ~55s)
  static const Duration defaultTimeout = Duration(seconds: 65);
  static const Duration syncTimeout = Duration(seconds: 65);
  static const Duration quickTimeout = Duration(seconds: 15);
  static const Duration longTimeout = Duration(seconds: 120);
  static const Duration authTimeout = Duration(seconds: 65);
  static const Duration uploadTimeout = Duration(seconds: 120);
  static const Duration downloadTimeout = Duration(seconds: 120);
  
  /// Get timeout for specific operation type
  static Duration getTimeoutForOperation(String operation) {
    switch (operation.toLowerCase()) {
      case 'sync':
      case 'synchronization':
        return syncTimeout;
      case 'quick':
      case 'validation':
      case 'health_check':
        return quickTimeout;
      case 'long':
      case 'report_generation':
      case 'export':
        return longTimeout;
      case 'auth':
      case 'login':
      case 'register':
      case 'token_refresh':
        return authTimeout;
      case 'upload':
      case 'file_upload':
      case 'image_upload':
        return uploadTimeout;
      case 'download':
      case 'file_download':
        return downloadTimeout;
      default:
        return defaultTimeout;
    }
  }
  
  /// Get timeout for specific API endpoint
  static Duration getTimeoutForEndpoint(String endpoint) {
    // Auth endpoints
    if (endpoint.contains('/auth/login') || 
        endpoint.contains('/auth/register') ||
        endpoint.contains('/auth/refresh')) {
      return authTimeout;
    }
    
    // Sync endpoints
    if (endpoint.contains('/sync') || 
        endpoint.contains('/invoices/sync')) {
      return syncTimeout;
    }
    
    // Upload endpoints
    if (endpoint.contains('/upload') || 
        endpoint.contains('/import')) {
      return uploadTimeout;
    }
    
    // Export endpoints
    if (endpoint.contains('/export') || 
        endpoint.contains('/report')) {
      return longTimeout;
    }
    
    // Quick operations
    if (endpoint.contains('/health') || 
        endpoint.contains('/validate')) {
      return quickTimeout;
    }
    
    return defaultTimeout;
  }
  
  /// Apply timeout to a Future with operation-specific timeout
  static Future<T> withTimeout<T>(
    Future<T> future, 
    String operation, {
    Duration? customTimeout,
  }) {
    final timeout = customTimeout ?? getTimeoutForOperation(operation);
    return future.timeout(timeout);
  }
  
  /// Apply timeout to a Future with endpoint-specific timeout
  static Future<T> withEndpointTimeout<T>(
    Future<T> future, 
    String endpoint, {
    Duration? customTimeout,
  }) {
    final timeout = customTimeout ?? getTimeoutForEndpoint(endpoint);
    return future.timeout(timeout);
  }
}