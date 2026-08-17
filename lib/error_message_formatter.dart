import 'package:flutter/material.dart';

/// 🎯 User-friendly error message formatter
/// Converts technical errors to shop owner-friendly messages
class ErrorMessageFormatter {
  static String format(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    // Authentication Errors
    if (errorStr.contains('username already registered') || 
        errorStr.contains('already exists')) {
      return 'This user is already registered. Please login instead.';
    }
    if (errorStr.contains('invalid credentials') || 
        errorStr.contains('wrong password')) {
      return 'Wrong username or password. Please try again.';
    }
    if (errorStr.contains('user not found') || 
        errorStr.contains('does not exist')) {
      return 'User account not found. Please register first.';
    }

    // Network Errors
    if (errorStr.contains('socket') || 
        errorStr.contains('connection refused')) {
      return 'Server not responding. Please check your internet connection and try again.';
    }
    if (errorStr.contains('timeout')) {
      return 'Request took too long. Please check your internet and try again.';
    }
    if (errorStr.contains('no internet') || 
        errorStr.contains('network unreachable')) {
      return 'No internet connection. Please connect to WiFi or mobile data and try again.';
    }

    // Validation Errors
    if (errorStr.contains('email') && 
        (errorStr.contains('invalid') || errorStr.contains('format'))) {
      return 'Please enter a valid email address.';
    }
    if (errorStr.contains('password') && 
        (errorStr.contains('too short') || errorStr.contains('weak'))) {
      return 'Password must be at least 8 characters with uppercase, lowercase, and numbers.';
    }
    if (errorStr.contains('phone') && errorStr.contains('invalid')) {
      return 'Please enter a valid 10-digit phone number.';
    }

    // Business Logic Errors
    if (errorStr.contains('insufficient inventory') || 
        errorStr.contains('out of stock')) {
      return 'Insufficient stock. Please check inventory.';
    }
    if (errorStr.contains('duplicate invoice') || 
        errorStr.contains('already exists')) {
      return 'This invoice/transaction already exists.';
    }
    if (errorStr.contains('customer not found')) {
      return 'Customer record not found. Please create a new customer.';
    }
    if (errorStr.contains('payment failed')) {
      return 'Payment could not be processed. Please try again or use a different payment method.';
    }
    if (errorStr.contains('khata limit exceeded')) {
      return 'Customer has exceeded credit limit. Please collect payment first.';
    }

    // Permission Errors
    if (errorStr.contains('403') || 
        errorStr.contains('forbidden') || 
        errorStr.contains('not authorized')) {
      return 'You do not have permission for this action. Please contact administrator.';
    }
    if (errorStr.contains('401') || 
        errorStr.contains('unauthorized') || 
        errorStr.contains('token')) {
      return 'Your session has expired. Please login again.';
    }

    // Server Errors
    if (errorStr.contains('500') || 
        errorStr.contains('internal server error')) {
      return 'Server error. Please try again in a moment.';
    }
    if (errorStr.contains('503') || 
        errorStr.contains('service unavailable')) {
      return 'Server is temporarily down. Please try again later.';
    }

    // OTP Errors
    if (errorStr.contains('otp') && errorStr.contains('expired')) {
      return 'OTP has expired. Please request a new one.';
    }
    if (errorStr.contains('otp') && errorStr.contains('invalid')) {
      return 'OTP is incorrect. Please try again.';
    }

    // Generic Fallback
    return 'Something went wrong. Please try again or contact support.';
  }

  /// Show user-friendly error dialog
  static void showErrorDialog(
    BuildContext context,
    dynamic error, {
    String title = 'Error',
    VoidCallback? onRetry,
  }) {
    final message = format(error);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
          if (onRetry != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                onRetry();
              },
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  /// Show error snackbar
  static void showErrorSnackbar(
    BuildContext context,
    dynamic error, {
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(format(error)),
        backgroundColor: Colors.red,
        duration: duration,
      ),
    );
  }
}
