import 'dart:convert';
import 'session_management.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:http/http.dart' as http;
import 'package:synchronized/synchronized.dart';
import 'rate_limiter.dart';
import 'error_log_helper.dart';
import 'dart:io';
import 'secure_token_storage.dart';
import 'timeout_config.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'comprehensive_logger.dart';

class ApiClient {
  static dynamic _safeDecodeForLog(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return {'_raw_body': body.length > 2000 ? body.substring(0, 2000) : body};
    }
  }

  // FIX-1: Session expiry stream for 401 auto-refresh handling
  static StreamController<bool> _sessionExpiredController = StreamController<bool>.broadcast();
  static Stream<bool> get onSessionExpired => _sessionExpiredController.stream;

  // 🔒 CRITICAL: Lock for token refresh to prevent race conditions
  static final _tokenRefreshLock = Lock();
  static bool _isRefreshingToken = false;
  static Completer<bool>? _refreshCompleter; // Safe lock for race conditions
  static DateTime? _refreshStartTime; // Track refresh start time for timeout
  static const Duration _refreshTimeout = Duration(seconds: 15); // Refresh timeout

  // Order of addresses to try
  // Build with: flutter build apk --dart-define=API_BASE_URL=https://your-production-url.railway.app
  static String? _runtimeApiBaseUrl;

  static List<String> get _bases {
    if (_runtimeApiBaseUrl != null && _runtimeApiBaseUrl!.isNotEmpty) {
      return [_normalizeBaseUrl(_runtimeApiBaseUrl!)];
    }

    const prodUrl = String.fromEnvironment('API_BASE_URL');
    final selectedUrl = prodUrl.isNotEmpty ? prodUrl : 'https://retail-mind-vkbp.onrender.com';
    return [_normalizeBaseUrl(selectedUrl)];
  }

  static String _normalizeBaseUrl(String input) {
    var normalized = input.trim();
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }
    return normalized;
  }

  /// Set the API base URL at runtime.
  ///
  /// This is useful when running the app without a dart-define or when the
  /// backend is deployed to a custom host.
  static void setApiBaseUrl(String? apiBaseUrl) {
    _runtimeApiBaseUrl = apiBaseUrl?.trim();
    if (kDebugMode && _runtimeApiBaseUrl != null && _runtimeApiBaseUrl!.isNotEmpty) {
      debugPrint('🔧 ApiClient runtime API base URL set to: ${_normalizeBaseUrl(_runtimeApiBaseUrl!)}');
    }
  }

  // Get the primary base URL for requests
  static String get baseUrl {
    return _bases[0];
  }

  // API Endpoints
  // Master List Endpoints
  static const String healthEndpoint = '/health';
  static const String registerEndpoint = '/auth/register';
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpointApi = '/api/auth/register';
  static const String loginEndpointApi = '/api/auth/login';
  static const String customerLogin = '/store/customer/login';
  static const String customerLoginPhone = '/store/customer/login/phone';
  static const String customerRegister = '/store/customer/register';
  static const String myOrders = '/store/my-orders';
  static const String salesEndpoint = '/api/invoices/sync';
  
  // Sales Restore Service (NEW - Phase 1-10 Production Fixes)
  static const String salesRestoreRestoreAll = '/api/sales-restore/restore-all';
  static const String salesRestoreRestoreSummary = '/api/sales-restore/restore-summary';
  static const String salesRestoreRestoreCustomers = '/api/sales-restore/restore-customers';
  static const String authSendOtp = '/auth/send-otp';
  static const String authVerifyOtp = '/auth/verify-otp';
  static const String ragEndpoint = '/rag/upload';
  static const String ragListEndpoint = '/rag/list_files';
  static const String sqlAnalystEndpoint = '/sql_analyst/analysis/';
  static const String chatbotEndpoint = '/chatbot/';
  static const String billGenerateEndpoint = '/bill/Generate/Bill';
  static const String billScanEndpoint = '/bill/scan/';
  static const String billQrEndpoint = '/bill/qr/';
  static const String todayInsightEndpoint = '/today_insight/';
  
  // Inventory
  static const String inventoryPrefix = '/api/inventory';
  static const String inventoryProducts = '/api/inventory/products';
  static const String inventoryStockMovement = '/api/inventory/stock-movement';
  static const String inventoryLowStock = '/api/inventory/low-stock';
  static const String inventoryStockAlerts = '/api/inventory/stock-alerts';
  static const String inventoryBatches = '/api/inventory/batches';
  static const String inventoryExpiringBatches = '/api/inventory/expiring-batches';
  static const String inventoryStockValue = '/api/inventory/analytics/stock-value';
  static const String inventoryStatus = '/api/inventory/analytics/inventory-status';
  static String inventoryProductById(String productId) => '/api/inventory/products/$productId';
  static const String inventoryGeneratePurchaseOrders = '/api/inventory/generate-purchase-orders';
  static const String inventoryStockMovementsPrefix = '/api/inventory/stock-movements';
  static String inventoryStockMovements(String productId) => '/api/inventory/stock-movements/$productId';
  static String inventoryBatchByProduct(String productId) => '/api/inventory/batches/$productId';
  
  // Inventory Sync Service (NEW - Phase 1-10 Production Fixes)
  static const String inventorySyncDeductStock = '/api/inventory-sync/deduct-stock';
  static const String inventorySyncDeductStockBatch = '/api/inventory-sync/deduct-stock-batch';
  static const String inventorySyncReconcile = '/api/inventory-sync/reconcile';
  static String inventorySyncCurrentStock = '/api/inventory-sync/current-stock';
  static const String inventorySyncAllStock = '/api/inventory-sync/all-stock';
  static String inventorySyncCurrentStockById(String productId) => '/api/inventory-sync/current-stock/$productId';

  // Attendance
  static const String attendancePrefix = '/api/attendance';
  static const String attendanceWorkers = '/api/attendance/workers';
  static const String attendanceCheckIn = '/api/attendance/check-in';
  static const String attendanceCheckOut = '/api/attendance/check-out';
  static const String attendanceRecordManual = '/api/attendance/record-manual';
  static const String attendanceLeaveRequest = '/api/attendance/leave-request';
  static const String attendanceLeaveRequests = '/api/attendance/leave-requests';
  static const String attendanceSummary = '/api/attendance/analytics/summary';
  static String attendanceWorkerById(String workerId) => '/api/attendance/workers/$workerId';
  // 🔧 NEW ENDPOINTS (from backend /docs):
  static String attendanceEmployee(String employeeId) => '/api/attendance/employee/$employeeId';
  static String attendanceByDate(String dateStr) => '/api/attendance/date/$dateStr';
  static String attendanceLeaveApprove(String leaveId) => '/api/attendance/leave-request/$leaveId/approve';
  static String attendanceLeaveReject(String leaveId) => '/api/attendance/leave-request/$leaveId/reject';
  static String attendanceAnalyticsEmployee(String employeeId) => '/api/attendance/analytics/employee/$employeeId';
  static String attendanceWorkerUpdate(String workerId) => '/api/attendance/workers/$workerId';
  static String attendanceWorkerDelete(String workerId) => '/api/attendance/workers/$workerId';

  // Invoices & Billing
  static const String invoicesPrefix = '/api/invoices';
  static const String invoicesCreate = '/api/invoices/create';
  static const String invoicesSync = '/api/invoices/sync';
  static const String invoicesOverdue = '/api/invoices/overdue';
  static const String invoicesPayments = '/api/invoices/payments';
  static const String invoicesAnalyticsSummary = '/api/invoices/analytics/summary';
  static const String invoicesList = '/api/invoices';
  static String invoiceById(String invoiceId) => '/api/invoices/$invoiceId';
  static String invoiceDelete(String invoiceId) => '/api/invoices/$invoiceId';

  // Customers
  static const String customersPrefix = '/api/customers';
  static const String customersList = '/api/customers';
  static String customerById(String customerId) => '/api/customers/$customerId';
  static String customerSetContactPreference(String customerId) => '/api/customers/$customerId/set-contact-preference';
  static const String customerSearchByPhone = '/api/customers/search/by-phone';
  static const String customerSearchByName = '/api/customers/search/by-name';
  static String customerSoftDelete(String customerId) => '/api/customers/$customerId';

  // Session / Offline
  static const String authPrefix = '/api/auth';
  static const String utrCheckEndpoint = '/api/auth/utr/check';
  static const String utrRegisterEndpoint = '/api/auth/utr/register';
  static const String sessionRefresh = '/api/session/refresh';
  static const String sessionLogoutAll = '/api/session/logout-all';
  static const String sessionOfflineQueue = '/api/session/offline/queue';
  static const String sessionOfflineSync = '/api/session/offline/sync';
  static const String sessionLogout = '/api/session/logout';
  static const String sessionVerify = '/auth/health';
  static String sessionActive(String userId) => '/api/session/active/$userId';



  // Legacy / Special Features
  static const String counterAuthenticate = '/api/counter/authenticate';
  static const String deliveryCreate = '/api/delivery/create';
  static const String deliveryToday = '/api/delivery/today';
  static String deliveryUpdateStatus(String deliveryId) => '/api/delivery/$deliveryId/update-status';
  static const String loyaltyEarn = '/api/loyalty/earn';
  static const String loyaltyRedeem = '/api/loyalty/redeem';
  static const String festivalsUpcoming = '/api/festivals/upcoming';
  static const String occasionsToday = '/api/occasions/today';
  static const String templates = '/api/templates';
  static const String templatesSave = '/api/templates/save';
  static const String flashSaleSetup = '/api/flash-sale/setup';
  static const String creditScore = '/api/credit-score';
  static const String khataBalance = '/api/khata';
  static String khataBalanceByPhone(String customerPhone) => '/api/khata/$customerPhone';
  static const String khataUpdate = '/api/khata/update';
  static const String khataCustomers = '/api/khata/customers';
  static String khataWhatsappReminder(String customerPhone) => '/api/khata/whatsapp-reminder/$customerPhone';
  static const String expensesCreate = '/api/expenses/create';
  static const String expensesList = '/api/expenses';
  static const String expensesHistory = '/api/expenses/history';
  static const String khataHistory = '/api/khata-history';
  static String khataHistoryByPhone(String customerPhone) => '/api/khata-history/$customerPhone';
  static const String syncSales = '/api/sync/sales';
  static const String syncInvoices = '/api/sync/invoices';
  static const String syncKhataBalances = '/api/sync/khata-balances';
  static const String syncExpenses = '/api/sync/expenses';
  static const String syncInvoicesChunked = '/api/sync/invoices/chunked';
  static const String softDeleteProduct = '/api/products';
  static String softDeleteProductById(String productId) => '/api/products/$productId';
  static const String softDeleteCustomer = '/api/customers';
  static String softDeleteCustomerById(String customerId) => '/api/customers/$customerId';

  // Store / Online Shopping
  static const String storeCustomerRegister = '/store/customer/register';
  static const String storeCustomerLogin = '/store/customer/login';
  static const String storeNearbyShops = '/store/shops/nearby';
  static String storeShopProducts(String shopId) => '/store/shops/$shopId/products';
  static const String storeOrderPlace = '/store/order'; // FIXED: Changed from '/store/orderPlace' to match backend
  static const String storeMyOrders = '/store/my-orders';
  static String storeOrderTrack(String orderId) => '/store/order/$orderId/track';
  static const String storeOwnerOrders = '/store/owner/orders';
  static String storeOwnerOrderAction(String orderId) => '/store/owner/orders/$orderId/action';

  // Smart Remarketing
  static const String remarketing = '/api/intelligence/remarketing';

  // WhatsApp Orders Service
  static const String whatsappOrders = '/whatsapp-orders';
  static String whatsappOrderStatus(String orderId) => '/whatsapp-orders/$orderId/status';


  // Enterprise Intelligence
  static const String expensesAdd = '/expenses';
  static const String expensesListLegacy = '/expenses'; // FIXED: Changed from '/expensesList' to match backend
  static const String workersList = '/workers'; // FIXED: Changed from '/workersList' to match backend
  static const String workersAdd = '/workers'; // FIXED: Changed from '/workersAdd' to match backend (POST)
  static String workerById(String workerId) => '/workers/$workerId';
  static String workerPaySalary(String workerId) => '/workers/$workerId/pay-salary';
  static const String bankReconciliation = '/bank-recon';
  static const String enterprisePnl = '/enterprise/pnl';
  static const String enterpriseTransactions = '/enterprise/transactions';
  static const String retailStockAnalysis = '/retail/stock-analysis';

  // Gift Cards & GST
  static const String giftCards = '/gift-cards';
  static const String giftCardRedeem = '/gift-cards/redeem';
  static const String gstExportGstr1 = '/gst/export-gstr1';

  // Cache Management
  static const String cacheStats = '/api/cache/stats';
  static const String cacheWarmProducts = '/api/cache/warm/products';
  static const String cacheWarmAnalytics = '/api/cache/warm/analytics';
  static String cacheClearPattern(String pattern) => '/api/cache/clear/$pattern';
  static const String cacheClearAll = '/api/cache/clear-all';
  
  // Security Hardening Service (NEW - Phase 1-10 Production Fixes)
  static const String securityCheckInput = '/api/security/check-input';
  static const String securityRateLimitStatus = '/api/security/rate-limit-status';
  static const String securityValidatePassword = '/api/security/validate-password';
  static const String securitySecurityHeaders = '/api/security/security-headers';
  static const String securitySanitizeBatch = '/api/security/sanitize-batch';
  static const String securityCsrfToken = '/api/security/csrf-token';
  static const String securityCheckSqlInjection = '/api/security/check-sql-injection';
  
  // Observability Service (NEW - Phase 1-10 Production Fixes)
  static const String observabilityHealth = '/api/observability/health';
  static const String observabilityReady = '/api/observability/ready';
  static const String observabilityMetrics = '/api/observability/metrics';
  static const String observabilityLog = '/api/observability/log';
  static const String observabilityError = '/api/observability/error';
  static const String observabilityPerformanceSummary = '/api/observability/performance/summary';
  static const String observabilityPerformanceDatabase = '/api/observability/performance/database';
  static const String observabilityBusinessOverview = '/api/observability/business/overview';

  // Batch Operations
  static const String batchProductsImport = '/batch/api/batch/products/import';
  static const String batchProductsExport = '/batch/api/batch/products/export';
  static const String batchCustomersImport = '/batch/api/batch/customers/import';
  static String batchStatus(String operationId) => '/batch/api/batch/status/$operationId';
  static const String batchHistory = '/batch/api/batch/history';

  // Shop Config
  static const String shopBusinessHours = '/api/shop/business-hours';
  static const String shopTaxConfig = '/api/shop/tax-config';
  static const String shopUploadLogo = '/api/shop/upload-logo';
  static const String shopSettings = '/api/shop/profile';
  static const String shopProfile = '/api/shop/profile';
  static const String shopCreate = '/api/shop/create';
  static const String shopPublicProfile = '/shop/profile';
  static const String shopUpiQr = '/shop/upi-qr';
  static const String shopToggleOnlineStore = '/api/shop/toggle-online-store';
  static String shopPublicInfo(String shopId) => '/shop/public/$shopId';

  // Compatibility Aliases (to fix build errors in existing files)
  static const String checkIn = attendanceCheckIn;
  static const String checkOut = attendanceCheckOut;


  // Connection status tracking
  static String? _lastSuccessfulBase;
  static DateTime? _lastConnectionTime;
  
  // Rate limiting - max 10 requests per second per endpoint
  static final RateLimiter _rateLimiter = RateLimiter(
    window: const Duration(seconds: 1),
    maxRequests: 10,
  );

  // Auth specific strict rate limiter
  static final RateLimiter _authRateLimiter = RateLimiter(
    window: const Duration(minutes: 1),
    maxRequests: 5, // 5 requests per minute for auth endpoints
  );
  
  // Lock for thread-safe rate limiter operations
  static final _rateLimiterLock = Lock();

  /// Check if the path should skip auto-refresh (to prevent deadlocks)
  static bool _shouldSkipRefresh(String path) {
    return path == sessionRefresh ||
           path == sessionLogout ||
           path == sessionLogoutAll ||
           path == loginEndpoint ||
           path == registerEndpoint ||
           path == loginEndpointApi ||
           path == registerEndpointApi ||
           path == sessionVerify;
  }

  /// Generate candidate paths for auth endpoints to support both /auth/... and /api/auth/...
  static List<String> _candidatePaths(String path) {
    // For login/register, try both the original and /api/auth/... versions
    if (path == loginEndpoint) {
      return [loginEndpoint, loginEndpointApi];
    }
    if (path == registerEndpoint) {
      return [registerEndpoint, registerEndpointApi];
    }
    return [path];
  }

  /// Check if we should try the next auth path (for 404/405 responses)
  static bool _shouldTryNextAuthPath(int statusCode, String path, List<String> candidatePaths, int currentIndex) {
    // Only try next path for auth endpoints on 404/405
    if ((statusCode == 404 || statusCode == 405) && 
        (path == loginEndpoint || path == registerEndpoint) &&
        currentIndex < candidatePaths.length - 1) {
      return true;
    }
    return false;
  }

  static Future<void> dispose() async {
    try {
      // Close StreamController with proper error handling
      try {
        if (!_sessionExpiredController.isClosed) {
          await _sessionExpiredController.close();
          _sessionExpiredController = StreamController<bool>.broadcast();
          if (kDebugMode) debugPrint('✅ Session expired controller closed and reset');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Error closing session expired controller: $e');
      }
      
      // Reset refresh state
      await _resetRefreshState();
      
      if (kDebugMode) debugPrint('✅ ApiClient disposed successfully');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error disposing ApiClient: $e');
    }
  }

  /// Update connection status tracking
  static void _updateConnectionStatus(String base) {
    _lastSuccessfulBase = base;
    _lastConnectionTime = DateTime.now();
  }

  /// Get the last successful base URL
  static String? getLastWorkingBase() => _lastSuccessfulBase;

  /// Check if we have a recent successful connection
  static bool hasRecentConnection() {
    if (_lastConnectionTime == null) return false;
    final timeSinceLastConnection = DateTime.now().difference(_lastConnectionTime!);
    return timeSinceLastConnection.inMinutes < 5; // Consider connection fresh for 5 minutes
  }

  /// 🔒 NETWORK CONNECTIVITY VALIDATION: Check network before API calls
  static Future<bool> _checkNetworkConnectivity() async {
    // 🛡️ FIX: this used to hard-block every single API call (login,
    // register, everything) if this check reported "no connectivity" --
    // whether from a thrown plugin error OR a non-throwing but simply
    // wrong 'none' result, which connectivity_plus is documented to
    // return on some devices/VPN configurations even with full internet
    // access (see fluttercommunity/plus_plugins issue #3810, among
    // others). A client-side heuristic being wrong is not a good enough
    // reason to prevent the app from ever attempting the real request.
    // The actual HTTP call below has its own timeout/connection-error
    // handling, which is a strictly more trustworthy signal of real
    // reachability. This check is now purely diagnostic (logs a warning)
    // and never blocks a request on its own.
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isConnected = connectivityResult != ConnectivityResult.none;
      if (!isConnected && kDebugMode) {
        debugPrint('⚠️ Connectivity plugin reports no network (not blocking the request on this alone)');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Network check error (not blocking the request on this alone): $e');
    }
    return true;
  }
  
  /// 🔒 RESPONSE VALIDATION: Validate API response structure and content
  static bool _validateResponse(http.Response response) {
    try {
      // Check for valid status codes
      if (response.statusCode < 200 || response.statusCode >= 600) {
        if (kDebugMode) debugPrint('⚠️ Invalid status code: ${response.statusCode}');
        return false;
      }
      
      // Validate response body for JSON endpoints
      if (response.headers['content-type']?.contains('application/json') == true) {
        try {
          final body = json.decode(response.body);
          // Ensure response is a Map or List
          if (body is! Map && body is! List) {
            if (kDebugMode) debugPrint('⚠️ Invalid JSON response structure');
            return false;
          }
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Invalid JSON response: $e');
          return false;
        }
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Response validation error: $e');
      return false;
    }
  }
  
  /// 🔒 INPUT SANITIZATION: Sanitize user input before API calls
  ///
  /// FIX (Issue 3.1): Removed the regex that stripped `'` and `;` characters.
  /// That regex silently corrupted legitimate data such as customer names
  /// containing apostrophes (e.g., "O'Brien") and product descriptions
  /// containing semicolons. SQL injection is prevented by the backend using
  /// parameterised queries — client-side stripping is not a valid defence and
  /// causes data loss.
  static Map<String, dynamic> _sanitizeInput(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};
    
    data.forEach((key, value) {
      if (value is String) {
        sanitized[key] = value.trim();
      } else if (value is Map<String, dynamic>) {
        sanitized[key] = _sanitizeInput(value);
      } else {
        sanitized[key] = value;
      }
    });
    
    return sanitized;
  }
  
  /// 🔒 INPUT SANITIZATION: Sanitize form-encoded input
  ///
  /// FIX (Issue 3.1): Removed the regex that stripped `'` and `;` characters.
  /// See _sanitizeInput for the full rationale.
  static Map<String, String> _sanitizeFormInput(Map<String, String> data) {
    final sanitized = <String, String>{};
    
    data.forEach((key, value) {
      sanitized[key] = value.trim();
    });
    
    return sanitized;
  }
  
  /// 🔒 RETRY LOGIC: Implement exponential backoff retry for transient failures
  static Future<http.Response> _retryWithBackoff(
    Future<http.Response> Function() request, {
    int maxRetries = 3,
  }) async {
    int retryCount = 0;
    Duration delay = const Duration(seconds: 1);
    
    while (retryCount < maxRetries) {
      try {
        final response = await request();
        
        // Don't retry on client errors (4xx)
        if (response.statusCode >= 400 && response.statusCode < 500) {
          return response;
        }
        
        // Don't retry on success
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }
        
        // Retry on server errors (5xx) and network issues
        retryCount++;
        if (retryCount < maxRetries) {
          if (kDebugMode) debugPrint('⚠️ Retry $retryCount/$maxRetries after ${delay.inSeconds}s');
          await Future.delayed(delay);
          delay = Duration(seconds: delay.inSeconds * 2); // Exponential backoff
        }
      } catch (e) {
        retryCount++;
        if (retryCount < maxRetries) {
          if (kDebugMode) debugPrint('⚠️ Retry $retryCount/$maxRetries after error: $e');
          await Future.delayed(delay);
          delay = Duration(seconds: delay.inSeconds * 2);
        } else {
          rethrow;
        }
      }
    }
    
    // Final attempt
    return await request();
  }

  /// 🔒 SECURITY FIX: Redact sensitive fields from debug logs
  static String _redactSensitiveData(Map body) {
    final sensitivePatterns = [
      RegExp(r'password', caseSensitive: false),
      RegExp(r'token', caseSensitive: false),
      RegExp(r'pin', caseSensitive: false),
      RegExp(r'upi[_-]?id', caseSensitive: false),
      RegExp(r'card[_-]?number', caseSensitive: false),
      RegExp(r'cvv', caseSensitive: false),
      RegExp(r'secret', caseSensitive: false),
      RegExp(r'key', caseSensitive: false),
      RegExp(r'auth', caseSensitive: false),
      RegExp(r'credential', caseSensitive: false),
      RegExp(r'api[_-]?key', caseSensitive: false),
    ];
    
    final redacted = Map.from(body);
    
    redacted.forEach((key, value) {
      for (final pattern in sensitivePatterns) {
        if (pattern.hasMatch(key)) {
          redacted[key] = '***REDACTED***';
          break;
        }
      }
    });
    
    return redacted.toString();
  }

  // Try POST with JSON body
  static Future<http.Response> postJson(String path, Map<String, dynamic> body, {Map<String, String>? headers}) async {
    final startTime = DateTime.now();
    
    // Log API request
    ComprehensiveLogger.logApiRequest(
      method: 'POST',
      url: path,
      headers: headers,
      body: body,
    );
    
    if (kDebugMode) debugPrint('🔵 API: Attempting POST to $path');
    
    // 🔒 NETWORK CONNECTIVITY VALIDATION: Check network before API calls
    if (!await _checkNetworkConnectivity()) {
      throw Exception('No network connectivity available');
    }
    
    // 🔒 INPUT SANITIZATION: Sanitize input before sending
    final sanitizedBody = _sanitizeInput(Map<String, dynamic>.from(body));
    if (kDebugMode) debugPrint('🔵 Body: ${_redactSensitiveData(sanitizedBody)}');
    
    // Auth Strict Rate limiting
    if (path.startsWith('/auth/login') || path.startsWith('/auth/register') || path.startsWith('/auth/refresh') || path.startsWith('/api/session') || path.startsWith('/api/auth/')) {
      final allowed = await _rateLimiterLock.synchronized(() => _authRateLimiter.allowRequest(path));
      if (!allowed) {
        throw Exception('Rate limit exceeded. Please try again later.');
      }
    }

    // Standard Rate limiting check with thread safety
    final allowed = await _rateLimiterLock.synchronized(() => _rateLimiter.allowRequest(path));
    if (!allowed) {
      if (kDebugMode) debugPrint('⚠️ Rate limited on $path, waiting...');
      await _rateLimiterLock.synchronized(() => _rateLimiter.waitIfRateLimited(path));
    }

    // Generate candidate paths for auth endpoints
    final candidatePaths = _candidatePaths(path);
    Object? lastError;
    
    // Try last successful base first
    if (_lastSuccessfulBase != null && hasRecentConnection()) {
      try {
        if (kDebugMode) debugPrint('🟢 Trying last successful base: $_lastSuccessfulBase');
        
        // Try each candidate path
        for (int i = 0; i < candidatePaths.length; i++) {
          final currentPath = candidatePaths[i];
          try {
            if (kDebugMode) debugPrint('🟢 Trying path: $_lastSuccessfulBase$currentPath');
            final Future<http.Response> Function() req = () => _retryWithBackoff(() => _makePostJsonRequest(_lastSuccessfulBase!, currentPath, sanitizedBody, headers));
            final resp = await (_shouldSkipRefresh(currentPath) ? req() : _withTokenRefresh(req)).timeout(
              TimeoutConfig.getTimeoutForEndpoint(currentPath),
            );
            
            // 🔒 RESPONSE VALIDATION: Validate response before returning
            if (!_validateResponse(resp)) {
              if (kDebugMode) debugPrint('⚠️ Response validation failed for $_lastSuccessfulBase$currentPath');
              throw Exception('Invalid response format');
            }
            
            // Check if we should try next auth path
            if (_shouldTryNextAuthPath(resp.statusCode, currentPath, candidatePaths, i)) {
              if (kDebugMode) debugPrint('⏳ Auth path $currentPath returned ${resp.statusCode}, trying next candidate');
              continue;
            }
            
            if (resp.statusCode < 500) {
              _updateConnectionStatus(_lastSuccessfulBase!);
              final duration = DateTime.now().difference(startTime);
              
              // Log API response
              ComprehensiveLogger.logApiResponse(
                method: 'POST',
                url: '$_lastSuccessfulBase$currentPath',
                statusCode: resp.statusCode,
                headers: resp.headers,
                body: _safeDecodeForLog(resp.body),
                duration: duration,
              );
              
              if (kDebugMode) debugPrint('✅ Success on $_lastSuccessfulBase$currentPath - Status: ${resp.statusCode}');
              return resp;
            }
          } catch (e) {
            lastError = e;
            if (kDebugMode) debugPrint('⏳ Failed on $_lastSuccessfulBase$currentPath: $e');
            // Try next candidate path if available
            if (i < candidatePaths.length - 1) {
              continue;
            }
            break;
          }
        }
      } catch (e) {
        lastError = e;
        if (kDebugMode) debugPrint('⏳ Failed on last successful base: $e');
      }
    }

    // Try all bases with candidate paths
    for (final base in _bases) {
      try {
        if (kDebugMode) debugPrint('🟢 Trying base: $base');
        
        // Try each candidate path
        for (int i = 0; i < candidatePaths.length; i++) {
          final currentPath = candidatePaths[i];
          try {
            if (kDebugMode) debugPrint('🟢 Trying path: $base$currentPath');
            final Future<http.Response> Function() req = () => _retryWithBackoff(() => _makePostJsonRequest(base, currentPath, sanitizedBody, headers));
            final resp = await (_shouldSkipRefresh(currentPath) ? req() : _withTokenRefresh(req)).timeout(
              TimeoutConfig.getTimeoutForEndpoint(currentPath),
            );
            
            // 🔒 RESPONSE VALIDATION: Validate response before returning
            if (!_validateResponse(resp)) {
              if (kDebugMode) debugPrint('⚠️ Response validation failed for $base$currentPath');
              throw Exception('Invalid response format');
            }
            
            // Check if we should try next auth path
            if (_shouldTryNextAuthPath(resp.statusCode, currentPath, candidatePaths, i)) {
              if (kDebugMode) debugPrint('⏳ Auth path $currentPath returned ${resp.statusCode}, trying next candidate');
              continue;
            }
            
            _updateConnectionStatus(base);
            final duration = DateTime.now().difference(startTime);
            
            // Log API response
            ComprehensiveLogger.logApiResponse(
              method: 'POST',
              url: '$base$currentPath',
              statusCode: resp.statusCode,
              headers: resp.headers,
              body: _safeDecodeForLog(resp.body),
              duration: duration,
            );
            
            if (kDebugMode) debugPrint('✅ Connected to $base$currentPath - Status: ${resp.statusCode}');
            return resp;
          } catch (e) {
            lastError = e;
            if (kDebugMode) debugPrint('⏳ Failed on $base$currentPath: $e');
            ErrorLogHelper.logMessage(
              'Error on $base$currentPath',
              level: 'ERROR',
              attributes: {'endpoint': currentPath, 'error': e.toString()},
            );
            // Try next candidate path if available
            if (i < candidatePaths.length - 1) {
              continue;
            }
            break;
          }
        }
      } catch (e) {
        lastError = e;
        if (kDebugMode) debugPrint('❌ Exception on $base: $e');
        ErrorLogHelper.logMessage(
          'Exception on $base',
          level: 'ERROR',
          attributes: {'endpoint': path, 'error': e.toString()},
        );
      }
    }
    
    // Show real error instead of generic message
    final errorText = lastError?.toString() ?? 'Unknown error';
    final duration = DateTime.now().difference(startTime);
    
    // Log API error
    ComprehensiveLogger.logApiError(
      method: 'POST',
      url: path,
      error: errorText,
      duration: duration,
    );
    
    if (kDebugMode) debugPrint('🔴 All backends unreachable! Last error: $errorText');
    throw Exception('Connection failed: $errorText. Please check your internet connection and ensure the backend server is running.');
  }

  static Future<http.Response> _makePostJsonRequest(
    String base, 
    String path, 
    Map<String, dynamic> body, 
    Map<String, String>? headers,
  ) async {
    final uri = Uri.parse('$base$path');
    final token = await SecureTokenStorage.getToken();
    
    final deviceId = await SessionManagementService.getDeviceId();
    
    return http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Device-ID': deviceId,
        if (token != null) 'Authorization': 'Bearer $token',
        if (headers != null) ...headers,
      },
      body: json.encode(body),
    );
  }

  /// FIX-1: Auto-refresh on 401 Token Expired - OFFLINE-FIRST MODE
  /// Attempts silent refresh but doesn't force logout if offline
  /// Enhanced with proper race condition handling and timeout
  static Future<http.Response> _withTokenRefresh(
    Future<http.Response> Function() request,
  ) async {
    final response = await request();
    
    if (response.statusCode == 401) {
      if (kDebugMode) debugPrint('🔐 Token expired (401), attempting silent refresh...');
      
      bool success = false;
      
      // Check if refresh is already in progress
      if (_isRefreshingToken && _refreshCompleter != null && !_refreshCompleter!.isCompleted) {
        // Check if refresh has been running too long (deadlock detection)
        if (_refreshStartTime != null && 
            DateTime.now().difference(_refreshStartTime!) > _refreshTimeout) {
          if (kDebugMode) debugPrint('⚠️ Token refresh timeout detected, forcing reset');
          await _resetRefreshState();
        } else {
          // FIX (Issue 2.3): Capture _refreshCompleter in a local variable
          // before the await. The static field can be set to null by
          // _resetRefreshState() on another code path while we are suspended,
          // which would cause a null-dereference crash on the `!` operator.
          final pendingCompleter = _refreshCompleter;
          if (pendingCompleter != null) {
            try {
              success = await pendingCompleter.future.timeout(
                _refreshTimeout,
                onTimeout: () {
                  if (kDebugMode) debugPrint('⚠️ Token refresh wait timeout');
                  return false;
                },
              );
            } catch (e) {
              if (kDebugMode) debugPrint('⚠️ Token refresh wait failed: $e');
              success = false;
              await _resetRefreshState();
            }
          }
        }
      } else {
        // Start new refresh with proper locking
        await _tokenRefreshLock.synchronized(() async {
          // Double-check after acquiring lock
          if (_isRefreshingToken && _refreshCompleter != null && !_refreshCompleter!.isCompleted) {
            // Another thread started refresh while we waited for lock
            if (kDebugMode) debugPrint('⚠️ Refresh already in progress after lock acquisition');
            final pendingCompleter = _refreshCompleter;
            if (pendingCompleter != null) {
              try {
                success = await pendingCompleter.future.timeout(
                  _refreshTimeout,
                  onTimeout: () => false,
                );
              } catch (e) {
                if (kDebugMode) debugPrint('⚠️ Token refresh wait failed after lock: $e');
                success = false;
              }
            }
          } else if (!_isRefreshingToken) {
            // We can start the refresh
            _isRefreshingToken = true;
            _refreshStartTime = DateTime.now();
            _refreshCompleter = Completer<bool>();
            
            try {
              // Try to refresh with timeout - if offline, don't force logout
              final refreshed = await SessionManagementService.autoLogin().timeout(
                const Duration(seconds: 5),
                onTimeout: () => null,
              );
              success = (refreshed != null && refreshed['success'] == true);
              
              if (kDebugMode) {
                debugPrint(success ? '✅ Token refresh successful' : '⚠️ Token refresh failed');
              }
              
              _refreshCompleter!.complete(success);
            } catch (e) {
              success = false;
              if (kDebugMode) debugPrint('⚠️ Token refresh exception: $e');
              if (!_refreshCompleter!.isCompleted) {
                _refreshCompleter!.complete(false);
              }
            } finally {
              _isRefreshingToken = false;
              _refreshStartTime = null;
              _refreshCompleter = null;
            }
          } else if (_refreshCompleter != null) {
            // Refresh completed while waiting for lock
            try {
              success = await _refreshCompleter!.future;
            } catch (e) {
              if (kDebugMode) debugPrint('⚠️ Token refresh completion failed: $e');
              success = false;
            }
          }
        });
      }

      if (success) {
        if (kDebugMode) debugPrint('✅ Silent refresh successful, retrying request...');
        try {
          return await request();
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Retry request failed after refresh: $e');
          return response; // Return original response on retry failure
        }
      } else {
        // OFFLINE-FIRST: Don't force logout on refresh failure
        // User stays logged in with local session
        if (kDebugMode) debugPrint('⚠️ Refresh failed (offline or server error) - keeping local session');
        
        // However, if the refresh failed with an Auth error (401/403),
        // autoLogin() in SessionManagementService would have cleared the local tokens.
        // We MUST notify the app to log the user out to prevent a zombie state where sales crash.
        final hasLocalSession = await SecureTokenStorage.isSessionValid();
        if (!hasLocalSession) {
          if (kDebugMode) debugPrint('🔴 Refresh failure was an Auth Error (tokens cleared). Triggering session expiry...');
          if (!_sessionExpiredController.isClosed) {
            _sessionExpiredController.add(true);
          }
        }
        
        // Return the original 401 response instead of forcing logout
        // The calling code can handle the 401 appropriately
      }
    }
    
    return response;
  }
  
  /// Reset refresh state to handle deadlocks
  static Future<void> _resetRefreshState() async {
    await _tokenRefreshLock.synchronized(() async {
      _isRefreshingToken = false;
      _refreshStartTime = null;
      if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
        _refreshCompleter!.complete(false);
      }
      _refreshCompleter = null;
      if (kDebugMode) debugPrint('🔄 Token refresh state reset');
    });
  }

  // Try POST with form-encoded body
  static Future<http.Response> postForm(String path, Map<String, String> body, {Map<String, String>? headers}) async {
    // 🔒 NETWORK CONNECTIVITY VALIDATION: Check network before API calls
    if (!await _checkNetworkConnectivity()) {
      throw Exception('No network connectivity available');
    }
    
    // 🔒 INPUT SANITIZATION: Sanitize form input before sending
    final sanitizedBody = _sanitizeFormInput(body);
    if (kDebugMode) debugPrint('🔵 Form Body: ${_redactSensitiveData(sanitizedBody)}');
    
    // Try last successful base first
    if (_lastSuccessfulBase != null && hasRecentConnection()) {
      try {
        final Future<http.Response> Function() req = () => _makePostFormRequest(_lastSuccessfulBase!, path, sanitizedBody, headers);
        final resp = await (_shouldSkipRefresh(path) ? req() : _withTokenRefresh(req)).timeout(
          const Duration(seconds: 15),
        );
        
        // 🔒 RESPONSE VALIDATION: Validate response before returning
        if (!_validateResponse(resp)) {
          if (kDebugMode) debugPrint('⚠️ Response validation failed for $_lastSuccessfulBase$path');
          throw Exception('Invalid response format');
        }
        
        if (resp.statusCode < 500) {
          _updateConnectionStatus(_lastSuccessfulBase!);
          return resp;
        }
      } catch (_) {}
    }

    // Try all bases
    for (final base in _bases) {
      try {
        final Future<http.Response> Function() req = () => _makePostFormRequest(base, path, sanitizedBody, headers);
        final resp = await (_shouldSkipRefresh(path) ? req() : _withTokenRefresh(req)).timeout(
          const Duration(seconds: 15),
        );
        
        // 🔒 RESPONSE VALIDATION: Validate response before returning
        if (!_validateResponse(resp)) {
          if (kDebugMode) debugPrint('⚠️ Response validation failed for $base$path');
          throw Exception('Invalid response format');
        }
        
        _updateConnectionStatus(base);
        return resp;
      } on SocketException {
        continue;
      } on HttpException {
        continue;
      } on TimeoutException {
        continue;
      } on Exception {
        continue;
      }
    }
    throw Exception('All backends unreachable. Please check your internet connection and ensure the backend server is running.');
  }

  static Future<http.Response> _makePostFormRequest(
    String base, 
    String path, 
    Map<String, String> body, 
    Map<String, String>? headers,
  ) async {
    final uri = Uri.parse('$base$path');
    final token = await SecureTokenStorage.getToken();
    
    // Manually encode the form body to ensure FastAPI can parse it correctly
    final encodedParts = <String>[];
    body.forEach((key, value) {
      encodedParts.add('${Uri.encodeComponent(key)}=${Uri.encodeComponent(value)}');
    });
    final bodyString = encodedParts.join('&');
    
    final deviceId = await SessionManagementService.getDeviceId();
    
    return http.post(
      uri,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'X-Device-ID': deviceId,
        if (token != null) 'Authorization': 'Bearer $token',
        if (headers != null) ...headers,
      },
      body: bodyString,
    );
  }

  // Try multipart request (useful for RAG endpoint)
  static Future<http.StreamedResponse> postMultipart(
    String path, 
    Map<String, String> fields, 
    {Map<String, String>? headers, 
    List<http.MultipartFile>? files}
  ) async {
    // 🔒 NETWORK CONNECTIVITY VALIDATION: Check network before API calls
    if (!await _checkNetworkConnectivity()) {
      throw Exception('No network connectivity available');
    }
    
    // 🔒 INPUT SANITIZATION: Sanitize form fields before sending
    final sanitizedFields = _sanitizeFormInput(fields);
    if (kDebugMode) debugPrint('🔵 Multipart Fields: ${_redactSensitiveData(sanitizedFields)}');
    
    // Try last successful base first
    if (_lastSuccessfulBase != null && hasRecentConnection()) {
      try {
        final resp = await _makeMultipartRequest(_lastSuccessfulBase!, path, sanitizedFields, headers, files).timeout(
          const Duration(seconds: 30),
        );
        
        // 🔒 RESPONSE VALIDATION: Validate response before returning
        if (resp.statusCode < 200 || resp.statusCode >= 600) {
          if (kDebugMode) debugPrint('⚠️ Response validation failed for $_lastSuccessfulBase$path - Status: ${resp.statusCode}');
          throw Exception('Invalid response status code: ${resp.statusCode}');
        }
        
        _updateConnectionStatus(_lastSuccessfulBase!);
        return resp;
      } catch (_) {}
    }

    // Try all bases
    for (final base in _bases) {
      try {
        final resp = await _makeMultipartRequest(base, path, sanitizedFields, headers, files).timeout(
          const Duration(seconds: 30),
        );
        
        // 🔒 RESPONSE VALIDATION: Validate response before returning
        if (resp.statusCode < 200 || resp.statusCode >= 600) {
          if (kDebugMode) debugPrint('⚠️ Response validation failed for $base$path - Status: ${resp.statusCode}');
          throw Exception('Invalid response status code: ${resp.statusCode}');
        }
        
        _updateConnectionStatus(base);
        return resp;
      } on SocketException {
        continue;
      } on TimeoutException {
        continue;
      } on Exception {
        continue;
      }
    }
    throw Exception('All backends unreachable. Please check your internet connection.');
  }

  static Future<http.StreamedResponse> _makeMultipartRequest(
    String base,
    String path,
    Map<String, String> fields,
    Map<String, String>? headers,
    List<http.MultipartFile>? files,
  ) async {
    final uri = Uri.parse('$base$path');
    final token = await SecureTokenStorage.getToken();
    final req = http.MultipartRequest('POST', uri);
    
    final deviceId = await SessionManagementService.getDeviceId();
    
    // Inject headers
    req.headers.addAll({
      'X-Device-ID': deviceId,
      if (token != null) 'Authorization': 'Bearer $token',
      if (headers != null) ...headers,
    });
    
    req.fields.addAll(fields);
    if (files != null) req.files.addAll(files);
    return req.send();
  }

  // Try PUT with JSON body
  static Future<http.Response> putJson(String path, Map<String, dynamic> body, {Map<String, String>? headers}) async {
    if (kDebugMode) debugPrint('🔵 API: Attempting PUT to $path');
    
    // 🔒 NETWORK CONNECTIVITY VALIDATION: Check network before API calls
    if (!await _checkNetworkConnectivity()) {
      throw Exception('No network connectivity available');
    }
    
    // 🔒 INPUT SANITIZATION: Sanitize input before sending
    // 🔧 CRITICAL FIX: same root cause as postJson above — see that comment.
    final sanitizedBody = _sanitizeInput(Map<String, dynamic>.from(body));
    if (kDebugMode) debugPrint('🔵 Body: ${_redactSensitiveData(sanitizedBody)}');
    
    if (!_rateLimiter.allowRequest(path)) await _rateLimiter.waitIfRateLimited(path);
    
    if (_lastSuccessfulBase != null && hasRecentConnection()) {
      try {
        final Future<http.Response> Function() req = () => _makePutJsonRequest(_lastSuccessfulBase!, path, sanitizedBody, headers);
        final resp = await (_shouldSkipRefresh(path) ? req() : _withTokenRefresh(req)).timeout(
          const Duration(seconds: 15),
        );
        
        // 🔒 RESPONSE VALIDATION: Validate response before returning
        if (!_validateResponse(resp)) {
          if (kDebugMode) debugPrint('⚠️ Response validation failed for $_lastSuccessfulBase$path');
          throw Exception('Invalid response format');
        }
        
        if (resp.statusCode < 500) {
          _updateConnectionStatus(_lastSuccessfulBase!);
          return resp;
        }
      } catch (_) {}
    }

    for (final base in _bases) {
      try {
        final Future<http.Response> Function() req = () => _makePutJsonRequest(base, path, sanitizedBody, headers);
        final resp = await (_shouldSkipRefresh(path) ? req() : _withTokenRefresh(req)).timeout(
          const Duration(seconds: 15),
        );
        
        // 🔒 RESPONSE VALIDATION: Validate response before returning
        if (!_validateResponse(resp)) {
          if (kDebugMode) debugPrint('⚠️ Response validation failed for $base$path');
          throw Exception('Invalid response format');
        }
        
        _updateConnectionStatus(base);
        return resp;
      } on SocketException { continue; }
      on TimeoutException { continue; }
      on Exception { continue; }
    }
    throw Exception('All backends unreachable.');
  }

  static Future<http.Response> _makePutJsonRequest(String base, String path, Map body, Map<String, String>? headers) async {
    final token = await SecureTokenStorage.getToken();
    final deviceId = await SessionManagementService.getDeviceId();
    return http.put(Uri.parse('$base$path'),
      headers: {
        'Content-Type': 'application/json',
        'X-Device-ID': deviceId,
        if (token != null) 'Authorization': 'Bearer $token',
        if (headers != null) ...headers
      },
      body: json.encode(body),
    );
  }

  // Try DELETE
  static Future<http.Response> deleteJson(String path, {Map<String, String>? headers}) async {
    if (kDebugMode) debugPrint('🔵 API: Attempting DELETE to $path');
    
    // 🔒 NETWORK CONNECTIVITY VALIDATION: Check network before API calls
    if (!await _checkNetworkConnectivity()) {
      throw Exception('No network connectivity available');
    }
    
    if (!_rateLimiter.allowRequest(path)) await _rateLimiter.waitIfRateLimited(path);

    final token = await SecureTokenStorage.getToken();
    final deviceId = await SessionManagementService.getDeviceId();
    final authHeaders = {
      ...?headers,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      'X-Device-ID': deviceId,
    };

    if (_lastSuccessfulBase != null && hasRecentConnection()) {
      try {
        final resp = await http.delete(Uri.parse('$_lastSuccessfulBase$path'), headers: authHeaders).timeout(
          const Duration(seconds: 15),
        );
        
        // 🔒 RESPONSE VALIDATION: Validate response before returning
        if (!_validateResponse(resp)) {
          if (kDebugMode) debugPrint('⚠️ Response validation failed for $_lastSuccessfulBase$path');
          throw Exception('Invalid response format');
        }
        
        if (resp.statusCode < 500) {
          _updateConnectionStatus(_lastSuccessfulBase!);
          return resp;
        }
      } catch (_) {}
    }

    for (final base in _bases) {
      try {
        final resp = await http.delete(Uri.parse('$base$path'), headers: authHeaders).timeout(
          const Duration(seconds: 15),
        );
        
        // 🔒 RESPONSE VALIDATION: Validate response before returning
        if (!_validateResponse(resp)) {
          if (kDebugMode) debugPrint('⚠️ Response validation failed for $base$path');
          throw Exception('Invalid response format');
        }
        
        _updateConnectionStatus(base);
        return resp;
      } on SocketException { continue; }
      on TimeoutException { continue; }
      on Exception { continue; }
    }
    throw Exception('All backends unreachable.');
  }

  // Try GET and return response
  static Future<http.Response> getJson(String path, {Map<String, String>? headers}) async {
    final startTime = DateTime.now();
    
    // Log API request
    ComprehensiveLogger.logApiRequest(
      method: 'GET',
      url: path,
      headers: headers,
    );
    
    if (kDebugMode) debugPrint('🔵 API: Attempting GET to $path');
    
    // 🔒 NETWORK CONNECTIVITY VALIDATION: Check network before API calls
    if (!await _checkNetworkConnectivity()) {
      throw Exception('No network connectivity available');
    }
    
    final token = await SecureTokenStorage.getToken();
    
    final deviceId = await SessionManagementService.getDeviceId();
    
    // Try last successful base first
    if (_lastSuccessfulBase != null && hasRecentConnection()) {
      try {
        if (kDebugMode) debugPrint('🟢 Trying last successful base: $_lastSuccessfulBase$path');
        final Future<http.Response> Function() req = () => http.get(
          Uri.parse('$_lastSuccessfulBase$path'),
          headers: {
            'X-Device-ID': deviceId,
            if (headers != null) ...headers,
            if (token != null) 'Authorization': 'Bearer $token',
          },
        );
        final resp = await (_shouldSkipRefresh(path) ? req() : _withTokenRefresh(req)).timeout(const Duration(seconds: 15));
        
        // 🔒 RESPONSE VALIDATION: Validate response before returning
        if (!_validateResponse(resp)) {
          if (kDebugMode) debugPrint('⚠️ Response validation failed for $_lastSuccessfulBase$path');
          throw Exception('Invalid response format');
        }
        
        if (resp.statusCode < 500) {
          _updateConnectionStatus(_lastSuccessfulBase!);
          final duration = DateTime.now().difference(startTime);
          
          // Log API response
          ComprehensiveLogger.logApiResponse(
            method: 'GET',
            url: '$_lastSuccessfulBase$path',
            statusCode: resp.statusCode,
            headers: resp.headers,
            body: _safeDecodeForLog(resp.body),
            duration: duration,
          );
          
          if (kDebugMode) debugPrint('✅ Success on $_lastSuccessfulBase - Status: ${resp.statusCode}');
          return resp;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⏳ Failed on last successful base: $e');
      }
    }

    // Try all bases
    for (final base in _bases) {
      try {
        if (kDebugMode) debugPrint('🟢 Trying base: $base$path');
        final Future<http.Response> Function() req = () => http.get(
          Uri.parse('$base$path'),
          headers: {
            'X-Device-ID': deviceId,
            if (headers != null) ...headers,
            if (token != null) 'Authorization': 'Bearer $token',
          },
        );
        final resp = await (_shouldSkipRefresh(path) ? req() : _withTokenRefresh(req)).timeout(const Duration(seconds: 15));
        
        // 🔒 RESPONSE VALIDATION: Validate response before returning
        if (!_validateResponse(resp)) {
          if (kDebugMode) debugPrint('⚠️ Response validation failed for $base$path');
          throw Exception('Invalid response format');
        }
        
        _updateConnectionStatus(base);
        final duration = DateTime.now().difference(startTime);
        
        // Log API response
        ComprehensiveLogger.logApiResponse(
          method: 'GET',
          url: '$base$path',
          statusCode: resp.statusCode,
          headers: resp.headers,
          body: _safeDecodeForLog(resp.body),
          duration: duration,
        );
        
        if (kDebugMode) debugPrint('✅ Connected to $base - Status: ${resp.statusCode}');
        return resp;
      } on SocketException catch (e) {
        if (kDebugMode) debugPrint('❌ Socket error on $base: $e');
        continue;
      } on TimeoutException catch (e) {
        if (kDebugMode) debugPrint('❌ Timeout on $base: $e');
        continue;
      } on Exception catch (e) {
        if (kDebugMode) debugPrint('⏳ Exception on $base: $e');
        continue;
      }
    }
    if (kDebugMode) debugPrint('🔴 All backends unreachable!');
    throw Exception('All backends unreachable. Please check your internet connection.');
  }

  /// Reset connection status (useful for testing)
  static void resetConnectionStatus() {
    _lastSuccessfulBase = null;
    _lastConnectionTime = null;
  }

  /// Reset transient authentication/network state after an explicit logout.
  /// Does not clear tokens or user data; SessionLogoutService owns that cleanup.
  static Future<void> resetAuthRuntimeState() async {
    try {
      await _resetRefreshState();
      resetConnectionStatus();
      if (kDebugMode) {
        debugPrint('✅ ApiClient transient auth state reset');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ ApiClient transient auth reset failed: $e');
      }
    }
  }

  /// Upload a single file using multipart
  static Future<http.StreamedResponse> uploadFile(String path, File file) async {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final multipartFile = await http.MultipartFile.fromPath(
      'file',
      file.path,
      filename: fileName,
    );
    return postMultipart(path, {}, files: [multipartFile]);
  }
}