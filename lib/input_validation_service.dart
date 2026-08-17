import 'dart:io';

/// Comprehensive Input Validation Service
/// Provides validation for all user inputs across the application
/// Prevents invalid data, security issues, and improves data quality
class InputValidationService {
  static InputValidationService? _instance;
  
  InputValidationService._();
  
  static InputValidationService get instance {
    _instance ??= InputValidationService._();
    return _instance!;
  }
  
  /// Validate email address
  ValidationResult validateEmail(String email) {
    if (email.isEmpty) {
      return ValidationResult(false, 'Email is required');
    }
    
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      return ValidationResult(false, 'Please enter a valid email address');
    }
    
    if (email.length > 254) {
      return ValidationResult(false, 'Email is too long (max 254 characters)');
    }
    
    return ValidationResult(true, 'Valid email');
  }
  
  /// Validate phone number (Indian format)
  ValidationResult validatePhone(String phone) {
    if (phone.isEmpty) {
      return ValidationResult(false, 'Phone number is required');
    }
    
    // Remove spaces and special characters
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    if (cleanPhone.length != 10) {
      return ValidationResult(false, 'Phone number must be 10 digits');
    }
    
    if (!cleanPhone.startsWith('6') && !cleanPhone.startsWith('7') && 
        !cleanPhone.startsWith('8') && !cleanPhone.startsWith('9')) {
      return ValidationResult(false, 'Invalid phone number format');
    }
    
    return ValidationResult(true, 'Valid phone number');
  }
  
  /// Validate password strength
  ValidationResult validatePassword(String password) {
    if (password.isEmpty) {
      return ValidationResult(false, 'Password is required');
    }
    
    if (password.length < 8) {
      return ValidationResult(false, 'Password must be at least 8 characters');
    }
    
    if (password.length > 128) {
      return ValidationResult(false, 'Password is too long (max 128 characters)');
    }
    
    bool hasUppercase = false;
    bool hasLowercase = false;
    bool hasDigit = false;
    bool hasSpecial = false;
    
    for (int i = 0; i < password.length; i++) {
      final char = password[i];
      if (char.toUpperCase() != char && char.toLowerCase() == char) {
        hasUppercase = true;
      } else if (char.toLowerCase() != char && char.toUpperCase() == char) {
        hasLowercase = true;
      } else if (int.tryParse(char) != null) {
        hasDigit = true;
      } else if (_isSpecialChar(char)) {
        hasSpecial = true;
      }
    }
    
    final issues = <String>[];
    if (!hasUppercase) issues.add('uppercase letter');
    if (!hasLowercase) issues.add('lowercase letter');
    if (!hasDigit) issues.add('number');
    if (!hasSpecial) issues.add('special character');
    
    if (issues.isNotEmpty) {
      return ValidationResult(false, 'Password must contain: ${issues.join(', ')}');
    }
    
    return ValidationResult(true, 'Valid password');
  }
  
  /// Validate username
  ValidationResult validateUsername(String username) {
    if (username.isEmpty) {
      return ValidationResult(false, 'Username is required');
    }
    
    if (username.length < 3) {
      return ValidationResult(false, 'Username must be at least 3 characters');
    }
    
    if (username.length > 50) {
      return ValidationResult(false, 'Username is too long (max 50 characters)');
    }
    
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(username)) {
      return ValidationResult(false, 'Username can only contain letters, numbers, and underscores');
    }
    
    return ValidationResult(true, 'Valid username');
  }
  
  /// Validate shop name
  ValidationResult validateShopName(String shopName) {
    if (shopName.isEmpty) {
      return ValidationResult(false, 'Shop name is required');
    }
    
    if (shopName.length < 3) {
      return ValidationResult(false, 'Shop name must be at least 3 characters');
    }
    
    if (shopName.length > 100) {
      return ValidationResult(false, 'Shop name is too long (max 100 characters)');
    }
    
    // Allow alphanumeric, spaces, and common special characters
    final shopNameRegex = RegExp(r'^[a-zA-Z0-9\s\-_,.&]+$');
    if (!shopNameRegex.hasMatch(shopName)) {
      return ValidationResult(false, 'Shop name contains invalid characters');
    }
    
    return ValidationResult(true, 'Valid shop name');
  }
  
  /// Validate product name
  ValidationResult validateProductName(String productName) {
    if (productName.isEmpty) {
      return ValidationResult(false, 'Product name is required');
    }
    
    if (productName.length < 2) {
      return ValidationResult(false, 'Product name must be at least 2 characters');
    }
    
    if (productName.length > 200) {
      return ValidationResult(false, 'Product name is too long (max 200 characters)');
    }
    
    return ValidationResult(true, 'Valid product name');
  }
  
  /// Validate price
  ValidationResult validatePrice(String priceStr) {
    if (priceStr.isEmpty) {
      return ValidationResult(false, 'Price is required');
    }
    
    final price = double.tryParse(priceStr);
    if (price == null) {
      return ValidationResult(false, 'Price must be a valid number');
    }
    
    if (price < 0) {
      return ValidationResult(false, 'Price cannot be negative');
    }
    
    if (price > 99999999) {
      return ValidationResult(false, 'Price is too high (max ₹9,99,99,999)');
    }
    
    return ValidationResult(true, 'Valid price');
  }
  
  /// Validate quantity
  ValidationResult validateQuantity(String quantityStr) {
    if (quantityStr.isEmpty) {
      return ValidationResult(false, 'Quantity is required');
    }
    
    final quantity = int.tryParse(quantityStr);
    if (quantity == null) {
      return ValidationResult(false, 'Quantity must be a whole number');
    }
    
    if (quantity < 0) {
      return ValidationResult(false, 'Quantity cannot be negative');
    }
    
    if (quantity > 10000) {
      return ValidationResult(false, 'Quantity is too high (max 10,000)');
    }
    
    return ValidationResult(true, 'Valid quantity');
  }
  
  /// Validate GST number (Indian format)
  ValidationResult validateGSTNumber(String gstNumber) {
    if (gstNumber.isEmpty) {
      return ValidationResult(true, 'GST number is optional'); // Allow empty
    }
    
    // Indian GST format: 22AAAAA0000A1Z5
    final gstRegex = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[0-9]{1}[A-Z]{1}[0-9A-Z]{1}$');
    if (!gstRegex.hasMatch(gstNumber)) {
      return ValidationResult(false, 'Invalid GST number format (e.g., 22AAAAA0000A1Z5)');
    }
    
    return ValidationResult(true, 'Valid GST number');
  }
  
  /// Validate PIN code (Indian format)
  ValidationResult validatePINCode(String pinCode) {
    if (pinCode.isEmpty) {
      return ValidationResult(true, 'PIN code is optional'); // Allow empty
    }
    
    if (pinCode.length != 6) {
      return ValidationResult(false, 'PIN code must be 6 digits');
    }
    
    final pinRegex = RegExp(r'^[0-9]{6}$');
    if (!pinRegex.hasMatch(pinCode)) {
      return ValidationResult(false, 'PIN code must be 6 digits');
    }
    
    return ValidationResult(true, 'Valid PIN code');
  }
  
  /// Validate address
  ValidationResult validateAddress(String address) {
    if (address.isEmpty) {
      return ValidationResult(true, 'Address is optional'); // Allow empty
    }
    
    if (address.length < 10) {
      return ValidationResult(false, 'Address is too short (min 10 characters)');
    }
    
    if (address.length > 500) {
      return ValidationResult(false, 'Address is too long (max 500 characters)');
    }
    
    return ValidationResult(true, 'Valid address');
  }
  
  /// Validate discount percentage
  ValidationResult validateDiscount(String discountStr) {
    if (discountStr.isEmpty) {
      return ValidationResult(false, 'Discount is required');
    }
    
    final discount = double.tryParse(discountStr);
    if (discount == null) {
      return ValidationResult(false, 'Discount must be a valid number');
    }
    
    if (discount < 0) {
      return ValidationResult(false, 'Discount cannot be negative');
    }
    
    if (discount > 100) {
      return ValidationResult(false, 'Discount cannot exceed 100%');
    }
    
    return ValidationResult(true, 'Valid discount');
  }
  
  /// Validate text input (generic)
  ValidationResult validateText(String text, {String fieldName = 'Text', int minLength = 1, int maxLength = 100}) {
    if (text.isEmpty) {
      return ValidationResult(false, '$fieldName is required');
    }
    
    if (text.length < minLength) {
      return ValidationResult(false, '$fieldName must be at least $minLength characters');
    }
    
    if (text.length > maxLength) {
      return ValidationResult(false, '$fieldName is too long (max $maxLength characters)');
    }
    
    return ValidationResult(true, 'Valid $fieldName');
  }
  
  /// Sanitize text input to prevent XSS
  String sanitizeText(String text) {
    // Remove potentially dangerous characters
    final dangerousChars = RegExp('[<>"\'&]');
    return text.replaceAll(dangerousChars, '');
  }
  
  /// Validate file upload
  ValidationResult validateFile(File file, {int maxSizeMB = 10, List<String>? allowedExtensions}) {
    if (!file.existsSync()) {
      return ValidationResult(false, 'File does not exist');
    }
    
    // Check file size
    final fileSize = file.lengthSync() / (1024 * 1024); // Convert to MB
    if (fileSize > maxSizeMB) {
      return ValidationResult(false, 'File size exceeds ${maxSizeMB}MB limit');
    }
    
    // Check file extension
    if (allowedExtensions != null) {
      final extension = file.path.split('.').last.toLowerCase();
      if (!allowedExtensions.contains(extension)) {
        return ValidationResult(false, 'File type not allowed. Allowed: ${allowedExtensions.join(', ')}');
      }
    }
    
    return ValidationResult(true, 'Valid file');
  }
  
  /// Validate URL
  ValidationResult validateURL(String url) {
    if (url.isEmpty) {
      return ValidationResult(false, 'URL is required');
    }
    
    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
        return ValidationResult(false, 'URL must start with http:// or https://');
      }
      
      if (!uri.hasAuthority) {
        return ValidationResult(false, 'Invalid URL format');
      }
      
      return ValidationResult(true, 'Valid URL');
    } catch (e) {
      return ValidationResult(false, 'Invalid URL format');
    }
  }
  
  /// Validate numeric input
  ValidationResult validateNumeric(String value, {String fieldName = 'Value', double? min, double? max}) {
    if (value.isEmpty) {
      return ValidationResult(false, '$fieldName is required');
    }
    
    final numericValue = double.tryParse(value);
    if (numericValue == null) {
      return ValidationResult(false, '$fieldName must be a valid number');
    }
    
    if (min != null && numericValue < min) {
      return ValidationResult(false, '$fieldName must be at least $min');
    }
    
    if (max != null && numericValue > max) {
      return ValidationResult(false, '$fieldName must be at most $max');
    }
    
    return ValidationResult(true, 'Valid $fieldName');
  }
  
  /// Check if character is special character
  bool _isSpecialChar(String char) {
    const specialChars = r'!@#$%^&*()_+-=[]{}|;:,.<>?';
    return specialChars.contains(char);
  }
  
  /// Validate batch of inputs
  Map<String, ValidationResult> validateBatch(Map<String, dynamic> inputs) {
    final results = <String, ValidationResult>{};
    
    inputs.forEach((key, value) {
      switch (key.toLowerCase()) {
        case 'email':
          results[key] = validateEmail(value.toString());
          break;
        case 'phone':
        case 'mobile':
        case 'phone_number':
          results[key] = validatePhone(value.toString());
          break;
        case 'password':
          results[key] = validatePassword(value.toString());
          break;
        case 'username':
          results[key] = validateUsername(value.toString());
          break;
        case 'shop_name':
          results[key] = validateShopName(value.toString());
          break;
        case 'price':
          results[key] = validatePrice(value.toString());
          break;
        case 'quantity':
        case 'qty':
          results[key] = validateQuantity(value.toString());
          break;
        case 'discount':
          results[key] = validateDiscount(value.toString());
          break;
        case 'gst':
        case 'gst_number':
          results[key] = validateGSTNumber(value.toString());
          break;
        case 'pincode':
        case 'pin_code':
          results[key] = validatePINCode(value.toString());
          break;
        default:
          results[key] = validateText(value.toString(), fieldName: key);
      }
    });
    
    return results;
  }
}

/// Validation result
class ValidationResult {
  final bool isValid;
  final String message;
  
  ValidationResult(this.isValid, this.message);
  
  bool get isInvalid => !isValid;
  
  @override
  String toString() => isValid ? 'Valid' : 'Invalid: $message';
}