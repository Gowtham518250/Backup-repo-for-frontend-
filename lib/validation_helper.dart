import 'package:flutter/foundation.dart';

/// Input validation helper with XSS/injection prevention
class InputValidator {
  /// Sanitize user input - remove suspicious characters
  static String sanitizeInput(String? value, {int maxLength = 255}) {
    if (value == null || value.isEmpty) return '';
    
    // Remove potentially dangerous characters (& is allowed for product names like "Salt & Pepper")
    final cleaned = value
        .replaceAll(RegExp(r'[<>\";%+]'), '') // & removed - legitimate in Indian product names
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
    
    // FIX: Use cleaned.length instead of value.length to avoid RangeError
    // when dangerous characters are removed and string becomes shorter
    return cleaned.substring(0, _min(cleaned.length, maxLength));
  }

  /// Validate price - must be positive number
  static String? validatePrice(String? value) {
    if (value == null || value.isEmpty) {
      return 'Price is required';
    }
    
    // Remove non-numeric characters
    final sanitized = value.replaceAll(RegExp(r'[^\d.]'), '');
    
    try {
      final price = double.parse(sanitized);
      if (price <= 0) {
        return 'Price must be greater than 0';
      }
      if (price > 10000000) {
        return 'Price too large (max ₹1,00,00,000)';
      }
      if (price.isInfinite || price.isNaN) {
        return 'Invalid price value';
      }
      return null;
    } catch (e) {
      return 'Invalid price format';
    }
  }

  /// Validate quantity - must be positive number
  static String? validateQuantity(String? value) {
    if (value == null || value.isEmpty) {
      return 'Quantity is required';
    }
    
    final sanitized = value.replaceAll(RegExp(r'[^\d.]'), '');
    
    try {
      final qty = double.parse(sanitized);
      if (qty <= 0) {
        return 'Quantity must be greater than 0';
      }
      if (qty > 1000000) {
        return 'Quantity too large';
      }
      if (qty.isInfinite || qty.isNaN) {
        return 'Invalid quantity value';
      }
      return null;
    } catch (e) {
      return 'Invalid quantity format';
    }
  }

  /// Validate amount - must be positive
  static String? validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Amount is required';
    }
    
    final sanitized = value.replaceAll(RegExp(r'[^\d.]'), '');
    
    try {
      final amount = double.parse(sanitized);
      if (amount < 0) {
        return 'Amount cannot be negative';
      }
      if (amount.isInfinite || amount.isNaN) {
        return 'Invalid amount value';
      }
      return null;
    } catch (e) {
      return 'Invalid amount format';
    }
  }

  /// Validate customer name with XSS prevention
  static String? validateCustomerName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Customer name is required';
    }
    
    final sanitized = sanitizeInput(value, maxLength: 100);
    
    if (sanitized.length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (sanitized.length > 100) {
      return 'Name too long (max 100 characters)';
    }
    
    // Allow only letters, numbers, spaces, and basic punctuation
    if (!RegExp(r"^[a-zA-Z0-9\s.,\-']+$").hasMatch(sanitized)) {
      return 'Name contains invalid characters';
    }
    return null;
  }

  /// Validate phone number
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }
    
    final sanitized = value.replaceAll(RegExp(r'[^\d+\-\(\)\s]'), '');
    final digitsOnly = sanitized.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.length < 10) {
      return 'Phone must be at least 10 digits';
    }
    if (digitsOnly.length > 15) {
      return 'Phone number too long';
    }
    if (!RegExp(r'^[0-9]{10,15}$').hasMatch(digitsOnly)) {
      return 'Phone must contain only digits';
    }
    return null;
  }

  /// Validate UPI ID
  static String? validateUpiId(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }
    
    final sanitized = sanitizeInput(value, maxLength: 255);
    
    // UPI ID format: username@bankname
    if (!RegExp(r'^[a-zA-Z0-9._-]+@[a-zA-Z]+$').hasMatch(sanitized)) {
      return 'Invalid UPI ID format (e.g., user@bank)';
    }
    return null;
  }

  /// Validate email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }
    
    final sanitized = sanitizeInput(value, maxLength: 255);
    
    // Basic email validation
    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(sanitized)) {
      return 'Invalid email address';
    }
    return null;
  }

  /// Validate GST number
  static String? validateGST(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }
    
    final sanitized = sanitizeInput(value, maxLength: 15);
    
    if (!RegExp(r'^[0-9A-Z]{15}$').hasMatch(sanitized)) {
      return 'Invalid GST format (15 alphanumeric characters)';
    }
    return null;
  }

  /// Validate barcode
  static String? validateBarcode(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }
    
    final sanitized = value.replaceAll(RegExp(r'[^\d]'), '');
    
    if (sanitized.length < 8 || sanitized.length > 15) {
      return 'Barcode must be 8-15 digits';
    }
    return null;
  }

  /// Import minimum helper
  static int _min(int a, int b) => a < b ? a : b;

  /// Safely parse double with validation
  static double toDouble(dynamic value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    if (value is double) return value > 0 ? value : defaultValue;
    if (value is int) return value > 0 ? value.toDouble() : defaultValue;
    if (value is String) {
      try {
        final parsed = double.parse(value);
        return parsed > 0 ? parsed : defaultValue;
      } catch (e) {
        return defaultValue;
      }
    }
    return defaultValue;
  }

  /// Safely parse int with validation
  static int toInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value > 0 ? value : defaultValue;
    if (value is double) return value > 0 ? value.toInt() : defaultValue;
    if (value is String) {
      try {
        final parsed = int.parse(value);
        return parsed > 0 ? parsed : defaultValue;
      } catch (e) {
        return defaultValue;
      }
    }
    return defaultValue;
  }
}

/// DateTime validation helper
class DateTimeValidator {
  /// Safely parse DateTime from string
  static DateTime? safeParse(String? dateString, [DateTime? defaultValue]) {
    if (dateString == null || dateString.isEmpty) return defaultValue;
    
    try {
      final parsed = DateTime.tryParse(dateString);
      if (parsed == null) return defaultValue;
      
      // Check if date is reasonable (not in far future/past)
      if (parsed.year < 1900 || parsed.year > 2100) {
        return defaultValue;
      }
      
      return parsed;
    } catch (e) {
    if (kDebugMode) debugPrint('⚠️ DateTime parse error for "$dateString": $e');
      return defaultValue;
    }
  }

  /// Get safe DateTime from dynamic value
  static DateTime? toDateTime(dynamic value, [DateTime? defaultValue]) {
    if (value == null) return defaultValue;
    if (value is DateTime) return value;
    if (value is String) return safeParse(value, defaultValue);
    return defaultValue;
  }

  /// Check if date is today
  static bool isToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year &&
           date.month == now.month &&
           date.day == now.day;
  }

  /// Format date for display
  static String formatDate(DateTime? date) {
    if (date == null) return 'No date';
    return '${date.day}/${date.month}/${date.year}';
  }
}



