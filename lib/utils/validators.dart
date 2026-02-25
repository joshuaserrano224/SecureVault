class Validators {
  /// Validates password strength (M2 Requirement)
  /// Min 8 chars, 1 Uppercase, 1 Special Char
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    
    // Length check
    if (value.length < 8) {
      return 'Min. 8 characters required';
    }

    // Uppercase check
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'At least one uppercase letter required';
    }

    // Special character check
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'At least one special character required';
    }

    return null; // Valid
  }

  /// Basic Email Validation
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Full Name Validation
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    return null;
  }
}