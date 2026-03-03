class Validators {
  
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    final passwordRegex = RegExp(
      r'^(?=.*[A-Z])(?=.*[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$'
    );

    if (!passwordRegex.hasMatch(value)) {
      // Detailed feedback helps the user (and the instructor) know why it failed
      if (value.length < 8) return 'Min. 8 characters required';
      if (!value.contains(RegExp(r'[A-Z]'))) return 'One uppercase letter required';
      if (!value.contains(RegExp(r'[a-z]'))) return 'One lowercase letter required';
      if (!value.contains(RegExp(r'[0-9]'))) return 'At least one number required';
      if (!value.contains(RegExp(r'[!@#\$&*~]'))) return 'One special character required';
      
      return 'Password does not meet security requirements';
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
    if (value.trim().split(' ').length < 2) {
      return 'Please enter your full name';
    }
    return null;
  }
}