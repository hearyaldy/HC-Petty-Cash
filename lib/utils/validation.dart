class ValidationUtils {
  // Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    
    // Basic email format validation
    final emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    
    // Sanitize the email by trimming whitespace
    return null;
  }

  // Password validation
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }

    return null;
  }

  // Name validation
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    
    if (value.length < 2) {
      return 'Name must be at least 2 characters long';
    }
    
    if (value.length > 100) {
      return 'Name must be less than 100 characters';
    }
    
    // Sanitize by removing leading/trailing whitespace
    return null;
  }

  // Phone number validation
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    
    // Remove any non-digit characters for validation
    final cleanValue = value.replaceAll(RegExp(r'[^0-9+]'), '');
    
    if (cleanValue.length < 10) {
      return 'Phone number must be at least 10 digits';
    }
    
    if (cleanValue.length > 15) {
      return 'Phone number is too long';
    }
    
    return null;
  }

  // Amount validation
  static String? validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Amount is required';
    }
    
    try {
      final amount = double.tryParse(value);
      if (amount == null || amount <= 0) {
        return 'Amount must be a positive number';
      }
      
      if (amount > 1000000) { // Set a reasonable maximum
        return 'Amount is too large';
      }
    } catch (e) {
      return 'Please enter a valid number';
    }
    
    return null;
  }

  // Text field validation with length limits
  static String? validateTextField(String? value, {int minLength = 1, int maxLength = 255, String fieldName = 'Field'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    
    if (value.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    
    if (value.length > maxLength) {
      return '$fieldName must be less than $maxLength characters';
    }
    
    // Sanitize by removing leading/trailing whitespace
    return null;
  }

  // Sanitize string input by removing potentially harmful characters
  static String sanitizeString(String input) {
    // Remove leading and trailing whitespace
    var sanitized = input.trim();
    
    // Remove potentially harmful characters (customize as needed)
    // This is a basic example - you might want to be more specific based on your use case
    sanitized = sanitized.replaceAll(RegExp(r'[<>]'), '');
    
    return sanitized;
  }
}