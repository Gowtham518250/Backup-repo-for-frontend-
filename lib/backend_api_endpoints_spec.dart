/// Backend API Endpoints Specification
/// For CommissionTracking, SmartNotifications, DeliveryTracking, and Loyalty
/// 
/// BASE_URL: https://retail-mind-vkbp.onrender.com/
/// All endpoints require JWT Bearer token in Authorization header

// ============================================================================
// COMMISSION TRACKING ENDPOINTS
// ============================================================================

/// 1. Record Sale with Commission
/// POST /api/staff/commissions/record
/// 
/// Request:
/// {
///   "staffId": "staff_123",
///   "staffName": "Rajesh Kumar",
///   "saleId": "sale_5001",
///   "saleAmount": 2499.50,
///   "isPremiumStaff": true,
///   "timestamp": "2026-06-18T10:30:00Z"
/// }
/// 
/// Response (200 OK):
/// {
///   "success": true,
///   "commissionId": "comm_1001",
///   "baseCommission": 187.46,
///   "bonus": 500.0,
///   "totalCommission": 687.46,
///   "tier": "premium"
/// }

/// 2. Get Staff Commission Summary
/// GET /api/staff/commissions/summary?staffId=staff_123&startDate=2026-06-01&endDate=2026-06-18
/// 
/// Response (200 OK):
/// {
///   "staffId": "staff_123",
///   "staffName": "Rajesh Kumar",
///   "today": {
///     "sales": 5,
///     "totalAmount": 12450.0,
///     "totalCommission": 1237.50,
///     "bonus": 500.0
///   },
///   "pending": {
///     "count": 3,
///     "amount": 3700.0
///   },
///   "thisPeriod": {
///     "totalSales": 25,
///     "totalAmount": 45600.0,
///     "totalCommission": 2850.0
///   },
///   "lastCommission": {
///     "saleId": "sale_5001",
///     "amount": 2499.50,
///     "commission": 687.46,
///     "timestamp": "2026-06-18T10:30:00Z"
///   }
/// }

/// 3. Get Pending Commission Payouts
/// GET /api/staff/commissions/pending?staffId=staff_123
/// 
/// Response (200 OK):
/// {
///   "staffId": "staff_123",
///   "pendingCommissions": [
///     {
///       "commissionId": "comm_1001",
///       "saleId": "sale_5001",
///       "baseCommission": 187.46,
///       "bonus": 500.0,
///       "totalCommission": 687.46,
///       "status": "PENDING",
///       "createdAt": "2026-06-18T10:30:00Z"
///     },
///     {
///       "commissionId": "comm_1000",
///       "saleId": "sale_5000",
///       "baseCommission": 125.0,
///       "bonus": 0.0,
///       "totalCommission": 125.0,
///       "status": "PENDING",
///       "createdAt": "2026-06-17T14:15:00Z"
///     }
///   ],
///   "totalPending": 3,
///   "totalAmount": 3700.0
/// }

/// 4. Request Commission Payout
/// POST /api/staff/commissions/payout/request
/// 
/// Request:
/// {
///   "staffId": "staff_123",
///   "amount": 2000.0,
///   "bankAccount": "1234",
///   "paymentMethod": "UPI"
/// }
/// 
/// Response (200 OK):
/// {
///   "success": true,
///   "payoutId": "payout_501",
///   "staffId": "staff_123",
///   "amount": 2000.0,
///   "status": "INITIATED",
///   "requestedAt": "2026-06-18T10:45:00Z",
///   "estimatedCompletionTime": "2026-06-18T15:00:00Z"
/// }

/// 5. Mark Commission as Paid
/// PUT /api/staff/commissions/{commissionId}/mark-paid
/// 
/// Request:
/// {
///   "payoutId": "payout_501",
///   "transactionId": "txn_5001"
/// }
/// 
/// Response (200 OK):
/// {
///   "success": true,
///   "commissionId": "comm_1001",
///   "status": "PAID",
///   "paidAt": "2026-06-18T11:00:00Z"
/// }

// ============================================================================
// LOYALTY PROGRAM ENDPOINTS
// ============================================================================

/// 6. Get Customer Loyalty Details
/// GET /api/loyalty/customer/{customerId}
/// 
/// Response (200 OK):
/// {
///   "customerId": "cust_123",
///   "name": "Ramesh Patel",
///   "points": 4250,
///   "tier": "gold",
///   "redeemValue": 2125.0,
///   "tierBenefits": {
///     "pointsMultiplier": 1.5,
///     "discount": 12,
///     "freeDelivery": true,
///     "birthdayBonus": 100
///   },
///   "nextTier": "platinum",
///   "pointsToNextTier": 750,
///   "joinedAt": "2023-01-15T00:00:00Z",
///   "lastPurchaseAt": "2026-06-17T18:30:00Z"
/// }

/// 7. Add Loyalty Points on Purchase
/// POST /api/loyalty/points/add
/// 
/// Request:
/// {
///   "customerId": "cust_123",
///   "saleId": "sale_5001",
///   "purchaseAmount": 2499.50,
///   "isPremiumMember": false
/// }
/// 
/// Response (200 OK):
/// {
///   "success": true,
///   "pointsAdded": 2499,
///   "currentPoints": 4250,
///   "tierUpgrade": null,
///   "nextMilestone": {
///     "milestone": 5000,
///     "pointsRemaining": 750
///   }
/// }

/// 8. Redeem Loyalty Points
/// POST /api/loyalty/points/redeem
/// 
/// Request:
/// {
///   "customerId": "cust_123",
///   "pointsToRedeem": 500,
///   "redemptionType": "DISCOUNT"
/// }
/// 
/// Response (200 OK):
/// {
///   "success": true,
///   "redeemed": 500,
///   "discountValue": 250.0,
///   "remainingPoints": 3750,
///   "redeemCode": "REDEEM_5001"
/// }

/// 9. Get Loyalty Leaderboard
/// GET /api/loyalty/leaderboard?limit=10
/// 
/// Response (200 OK):
/// {
///   "leaderboard": [
///     {
///       "rank": 1,
///       "customerId": "cust_001",
///       "name": "Anjali Singh",
///       "points": 45000,
///       "tier": "platinum",
///       "purchases": 250
///     },
///     {
///       "rank": 2,
///       "customerId": "cust_002",
///       "name": "Priya Verma",
///       "points": 38500,
///       "tier": "platinum",
///       "purchases": 210
///     }
///   ]
/// }

// ============================================================================
// DELIVERY TRACKING ENDPOINTS
// ============================================================================

/// 10. Get Delivery Tracking Info
/// GET /api/delivery/track/{orderId}
/// 
/// Response (200 OK):
/// {
///   "orderId": "ORD-12345",
///   "status": "dispatched",
///   "createdAt": "2026-06-18T08:00:00Z",
///   "dispatchedAt": "2026-06-18T09:30:00Z",
///   "deliveredAt": null,
///   "estimatedDeliveryTime": "2026-06-18T14:00:00Z",
///   "customerAddress": "123 Main Street, City - 560001",
///   "customerPhone": "+91-98765-43210",
///   "orderAmount": 2499.50,
///   "partnerName": "DeliveryPro",
///   "partnerPhone": "+91-99999-88888",
///   "currentLocation": {
///     "latitude": 12.9716,
///     "longitude": 77.5946
///   }
/// }

/// 11. Update Delivery Location (Real-time)
/// POST /api/delivery/update-location
/// 
/// Request:
/// {
///   "orderId": "ORD-12345",
///   "latitude": 12.9716,
///   "longitude": 77.5946,
///   "timestamp": "2026-06-18T10:00:00Z",
///   "status": "dispatched"
/// }
/// 
/// Response (200 OK):
/// {
///   "success": true,
///   "orderId": "ORD-12345",
///   "status": "dispatched",
///   "eta": "2026-06-18T13:45:00Z"
/// }

/// 12. Mark Delivery Complete
/// PUT /api/delivery/{orderId}/complete
/// 
/// Request:
/// {
///   "signature": "base64_encoded_image",
///   "notes": "Delivered successfully"
/// }
/// 
/// Response (200 OK):
/// {
///   "success": true,
///   "orderId": "ORD-12345",
///   "status": "delivered",
///   "deliveredAt": "2026-06-18T13:50:00Z"
/// }

// ============================================================================
// SMART NOTIFICATIONS ENDPOINTS
// ============================================================================

/// 13. Schedule Daily Summary Notification
/// POST /api/notifications/schedule
/// 
/// Request:
/// {
///   "userId": "user_123",
///   "type": "DAILY_SUMMARY",
///   "scheduledTime": "21:00",
///   "timezone": "Asia/Kolkata",
///   "enabled": true
/// }
/// 
/// Response (200 OK):
/// {
///   "success": true,
///   "notificationId": "notif_1001",
///   "nextScheduledTime": "2026-06-18T21:00:00Z"
/// }

/// 14. Get Today's Daily Summary
/// GET /api/notifications/daily-summary?date=2026-06-18
/// 
/// Response (200 OK):
/// {
///   "date": "2026-06-18",
///   "totalSales": 15678.50,
///   "totalOrders": 24,
///   "topProduct": "Milk - 1L",
///   "bestHour": "19:00-20:00",
///   "topCustomer": "Rajesh Patel",
///   "lowStockItems": 5,
///   "summary": "📊 Today's Summary: Sales ₹15,678 | Orders 24 | Top: Milk"
/// }

/// 15. Send Stock Alert
/// POST /api/notifications/stock-alert
/// 
/// Request:
/// {
///   "userId": "user_123",
///   "items": [
///     {"productId": "prod_001", "name": "Milk", "current": 5, "threshold": 10},
///     {"productId": "prod_002", "name": "Bread", "current": 3, "threshold": 15}
///   ]
/// }
/// 
/// Response (200 OK):
/// {
///   "success": true,
///   "notificationsSent": 2,
///   "alertId": "alert_5001"
/// }

/// 16. Send Payment Reminder Notification
/// POST /api/notifications/payment-reminder
/// 
/// Request:
/// {
///   "customerId": "cust_123",
///   "khataAmount": 5000.0,
///   "daysOverdue": 7
/// }
/// 
/// Response (200 OK):
/// {
///   "success": true,
///   "notificationId": "notif_1002",
///   "sentAt": "2026-06-18T10:30:00Z"
/// }

// ============================================================================
// PAYMENT VERIFICATION ENDPOINTS (High-Value)
// ============================================================================

/// 17. Verify High-Value Payment
/// POST /api/payments/verify-high-value
/// 
/// Request:
/// {
///   "amount": 2500.0,
///   "utr": "415011U10221345",
///   "bankSender": "+919876543210",
///   "billMatchConfidence": 0.95,
///   "saleId": "sale_5001"
/// }
/// 
/// Response (200 OK):
/// {
///   "success": true,
///   "verified": true,
///   "status": "CONFIRMED",
///   "verificationMethod": "UTR_MATCHED",
///   "riskScore": 0.05
/// }

// ============================================================================
// ERROR RESPONSES
// ============================================================================

/// All endpoints follow standard error format:
/// 
/// 400 Bad Request:
/// {
///   "error": "INVALID_REQUEST",
///   "message": "Missing required field: staffId",
///   "code": "ERR_INVALID_REQUEST"
/// }
/// 
/// 401 Unauthorized:
/// {
///   "error": "UNAUTHORIZED",
///   "message": "Invalid or missing JWT token",
///   "code": "ERR_UNAUTHORIZED"
/// }
/// 
/// 404 Not Found:
/// {
///   "error": "NOT_FOUND",
///   "message": "Staff member not found",
///   "code": "ERR_NOT_FOUND"
/// }
/// 
/// 500 Internal Server Error:
/// {
///   "error": "INTERNAL_ERROR",
///   "message": "Database connection failed",
///   "code": "ERR_INTERNAL"
/// }

// ============================================================================
// RATE LIMITING
// ============================================================================

/// Standard rate limits per endpoint:
/// - Commission endpoints: 100 requests/minute
/// - Loyalty endpoints: 200 requests/minute
/// - Delivery endpoints: 150 requests/minute
/// - Notifications endpoints: 50 requests/minute
/// 
/// Rate limit headers in response:
/// X-RateLimit-Limit: 100
/// X-RateLimit-Remaining: 95
/// X-RateLimit-Reset: 1718699400

// ============================================================================
// WEBSOCKET ENDPOINTS (Real-time Tracking)
// ============================================================================

/// WebSocket Connection for Real-time Delivery Updates
/// wss://retail-mind-vkbp.onrender.com/ws/delivery/track
/// 
/// Connect:
/// {
///   "action": "connect",
///   "orderId": "ORD-12345",
///   "token": "JWT_TOKEN"
/// }
/// 
/// Subscribe to Order:
/// {
///   "action": "subscribe",
///   "orderId": "ORD-12345"
/// }
/// 
/// Server broadcasts every 30 seconds:
/// {
///   "action": "location_update",
///   "orderId": "ORD-12345",
///   "latitude": 12.9716,
///   "longitude": 77.5946,
///   "status": "dispatched",
///   "eta": "2026-06-18T13:45:00Z",
///   "timestamp": "2026-06-18T10:00:00Z"
/// }
/// 
/// Order Status Change:
/// {
///   "action": "status_change",
///   "orderId": "ORD-12345",
///   "status": "delivered",
///   "timestamp": "2026-06-18T13:50:00Z"
/// }
/// 
/// Disconnect:
/// {
///   "action": "disconnect",
///   "orderId": "ORD-12345"
/// }

// ============================================================================
// IMPLEMENTATION NOTES
// ============================================================================

/// 1. All timestamps are in ISO 8601 format (UTC timezone)
/// 2. All currency values are in Indian Rupees (₹)
/// 3. Phone numbers include +91 country code for India
/// 4. JWT token must be included in Authorization header: "Bearer {token}"
/// 5. All responses include a "timestamp" field for audit trails
/// 6. Idempotency keys recommended for POST requests
/// 7. Implement retry logic with exponential backoff (3x attempts)
/// 8. Use request IDs for debugging: "X-Request-ID" header
/// 9. All sensitive data (phone, bank account) partially masked in responses
/// 10. WebSocket connections support automatic reconnection with exponential backoff

void _apiSpecificationDocumentation() {
  // This file serves as both documentation and type hints for API integration
  // Use the endpoints listed above when implementing API client methods
  // Update this file when API contract changes
}
