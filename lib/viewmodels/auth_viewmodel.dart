import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../views/profile_view.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final BiometricService _biometricService = BiometricService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // --- OTP STATE (ONLY FOR GOOGLE) ---
  final TextEditingController otpController = TextEditingController();
  String? _generatedOTP;
  bool _isWaitingForOTP = false;
  bool get isWaitingForOTP => _isWaitingForOTP;

  int _resendCountdown = 30;
  int get resendCountdown => _resendCountdown;
  bool get canResend => _resendCountdown == 0;
  Timer? _resendTimer;

  // --- UI STATE ---
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool obscurePassword = true;

  void togglePasswordVisibility() {
    obscurePassword = !obscurePassword;
    notifyListeners();
  }

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 12)),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF0DA6F2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  

  Future<void> verifyOTPAndAccess(BuildContext context) async {
    if (otpController.text.trim() == _generatedOTP) {
      _isLoading = true;
      notifyListeners();

      if (_auth.currentUser != null) {
        await _db.collection('users').doc(_auth.currentUser!.uid).update({'otpVerified': true});
      }

      _isWaitingForOTP = false;
      _generatedOTP = null;
      otpController.clear();

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ProfileView()),
          (route) => false,
        );
      }
    } else {
      _showSnackBar(context, "Invalid Access Code.", isError: true);
    }
    _isLoading = false;
    notifyListeners();
  }

  void cancelOTP() {
    _isWaitingForOTP = false;
    _generatedOTP = null;
    otpController.clear();
    _resendTimer?.cancel();
    notifyListeners();
  }

  void _startResendTimer() {
    _resendCountdown = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        _resendCountdown--;
        notifyListeners();
      } else {
        timer.cancel();
      }
    });
  }

  // --- UNTOUCHED ORIGINAL FUNCTIONS ---

  Future<void> handleLogin(BuildContext context) async {
    bool success = await validateAndLogin(emailController.text.trim(), passwordController.text.trim());
    if (success) {
      _showSnackBar(context, "Identity Verified. Welcome Agent.");
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ProfileView()));
    } else {
      _showSnackBar(context, _errorMessage ?? "Auth Failure", isError: true);
    }
  }

  Future<void> handleBiometricLogin(BuildContext context) async {
    bool success = await loginWithBiometrics();
    if (success) {
      _showSnackBar(context, "Biometric Confirmed. Access Granted.");
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ProfileView()));
    } else {
      _showSnackBar(context, _errorMessage ?? "Biometric Denied", isError: true);
    }
  }
 
 String _extractEmail(User? user) {
  if (user == null) return "no-email-provided";
  if (user.email != null && user.email!.isNotEmpty) return user.email!;
  
  // Deep search in providerData
  for (UserInfo profile in user.providerData) {
    if (profile.email != null && profile.email!.isNotEmpty) {
      return profile.email!;
    }
  }
  return "no-email-provided";
}

Future<void> handleGoogleLogin(BuildContext context) async {
  _isLoading = true;
  notifyListeners();
  try {
    User? firebaseUser = await _authService.loginWithGoogle();
    if (firebaseUser == null) {
      _isLoading = false;
      notifyListeners();
      return; 
    }

    // FIX: Save provider IMMEDIATELY so biometrics knows this is a Google user
    await _secureStorage.write(key: "login_provider", value: "google");

    final String uid = firebaseUser.uid;
    final String email = _extractEmail(firebaseUser);
    DocumentSnapshot userDoc = await _db.collection('users').doc(uid).get();

    if (!userDoc.exists) {
      await _triggerOTPProtocol(context, email, uid, firebaseUser.displayName);
    } else {
      final userData = userDoc.data() as Map<String, dynamic>;
      if (userData['otpVerified'] == true) {
        // TRACK PROVIDER FOR BIOMETRICS
        await _secureStorage.write(key: "login_provider", value: "google");
        
        _currentUser = UserModel(id: uid, fullName: userData['fullName'] ?? "Agent", email: email);
        if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ProfileView()));
      } else {
        await _triggerOTPProtocol(context, email, uid, firebaseUser.displayName);
      }
    }
  } catch (e) {
    _showSnackBar(context, "Auth Protocol Failure.", isError: true);
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

Future<void> handleFacebookLogin(BuildContext context) async {
  _isLoading = true;
  notifyListeners();
  try {
    User? firebaseUser = await _authService.loginWithFacebook();
    if (firebaseUser != null) {
      final String email = _extractEmail(firebaseUser);

      // TRACK PROVIDER FOR BIOMETRICS
      await _secureStorage.write(key: "login_provider", value: "facebook");

      await _db.collection('users').doc(firebaseUser.uid).set({
        'fullName': firebaseUser.displayName ?? "Agent",
        'email': email,
        'otpVerified': true, 
        'lastLogin': FieldValue.serverTimestamp(),
        'provider': 'facebook',
      }, SetOptions(merge: true));

      _currentUser = UserModel(id: firebaseUser.uid, fullName: firebaseUser.displayName ?? "Agent", email: email);
      if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ProfileView()));
    }
  } catch (e) {
    _showSnackBar(context, "Facebook Auth Error", isError: true);
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

Future<void> _triggerOTPProtocol(BuildContext context, String email, String uid, String? name) async {
  try {
    // 1. Save to DB first (This is fast)
    await _db.collection('users').doc(uid).set({
      'fullName': name ?? "Agent",
      'email': email,
      'otpVerified': false, 
      'lastLogin': FieldValue.serverTimestamp(),
      'provider': 'google',
    }, SetOptions(merge: true));

    // 2. Prepare UI for OTP input IMMEDIATELY
    _isWaitingForOTP = true;
    _startResendTimer();
    notifyListeners(); // This shows the OTP UI so the app doesn't look frozen

    // 3. Trigger Email in the background
    if (email != "no-email-provided") {
      try {
        _generatedOTP = await _authService.sendEmailOTP(email);
        _showSnackBar(context, "Security Code sent to $email");
      } catch (e) {
        print("MAILER ERROR: $e");
        // Fallback for development if the SMTP server fails
        _generatedOTP = "123456";
        _showSnackBar(context, "Email failed. Using Debug Code: 123456", isError: true);
      }
    } else {
      _generatedOTP = "123456"; 
      _showSnackBar(context, "Manual Verification Required (Code: 123456)", isError: true);
    }
    
    notifyListeners(); 
  } catch (e) {
    print("DATABASE SAVE ERROR: $e");
    _showSnackBar(context, "Database write failed.", isError: true);
  }
}
  
 

  // --- MANUAL REGISTER ---
  Future<bool> register(String name, String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      // 1. Check if email exists in Firestore AT ALL
      final existing = await _db.collection('users').where('email', isEqualTo: email).get();
      if (existing.docs.isNotEmpty) {
        _errorMessage = "Conflict: Email already registered.";
        notifyListeners();
        return false;
      }

      User? firebaseUser = await _authService.registerWithEmail(name, email, password);
      if (firebaseUser != null) {
        // Unified Save Format
        await _db.collection('users').doc(firebaseUser.uid).set({
          'fullName': name,
          'email': email,
          'otpVerified': true, 
          'lastLogin': FieldValue.serverTimestamp(),
          'provider': 'email',
        });

        _currentUser = UserModel(id: firebaseUser.uid, fullName: name, email: email);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = "Registration Failed.";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
 
 // REPLACE THE ENTIRE loginWithBiometrics
Future<bool> loginWithBiometrics() async {
  _isLoading = true;
  _errorMessage = null;
  notifyListeners();
  try {
    // 1. Check Registry
    String deviceId = await _biometricService.getDeviceId();
    DocumentSnapshot registryDoc = await _db.collection('biometric_registry').doc(deviceId).get();
    
    if (!registryDoc.exists) {
      _errorMessage = "Device not registered.";
      return false;
    }

    String ownerId = registryDoc.get('userId');
    DocumentSnapshot userDoc = await _db.collection('users').doc(ownerId).get();
    
    if (!userDoc.exists || !(userDoc.get('biometricEnabled') ?? false)) {
      _errorMessage = "Biometric login disabled.";
      return false;
    }

    // 2. Hardware Auth
    String? authError = await _biometricService.authenticate();
    if (authError != null) {
      _errorMessage = authError;
      return false;
    }

    // 3. Provider Check
    String? provider = await _secureStorage.read(key: "login_provider");

    if (provider == "email") {
      final email = await _secureStorage.read(key: "biometric_email");
      final password = await _secureStorage.read(key: "biometric_password");
      if (email == null || password == null) throw "Manual credentials missing.";
      
      UserCredential credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      _currentUser = UserModel(id: credential.user!.uid, fullName: userDoc.get('fullName'), email: email);
      
    } else if (provider == "google") {
      // Try silent first
      User? user = await _authService.silentLoginWithGoogle();
      
      // If silent fails, force manual Google login
      user ??= await _authService.loginWithGoogle();
      
      if (user == null) throw "Google authentication failed.";
      _currentUser = UserModel(id: user.uid, fullName: user.displayName ?? "Agent", email: user.email ?? "");
      
    } else if (provider == "facebook") {
      User? user = await _authService.loginWithFacebook();
      if (user == null) throw "Facebook authentication failed.";
      _currentUser = UserModel(id: user.uid, fullName: user.displayName ?? "Agent", email: user.email ?? "");
    } else {
      // If code reaches here, provider was likely cleared or never set
      _errorMessage = "Manual login required to re-sync biometrics.";
      return false;
    }

    return true; 
  } catch (e) {
    _errorMessage = "Access Denied: Protocol Breach.";
    return false;
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

  Future<bool> validateAndLogin(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      _errorMessage = "Access Denied: Missing Credentials";
      notifyListeners();
      return false;
    }
    return await login(email, password);
  }


 Future<bool> login(String email, String password) async {
  return await _performAuthAction(() async {
    User? firebaseUser = await _authService.loginWithEmail(email, password);
    if (firebaseUser != null) {
      String? token = await firebaseUser.getIdToken();
      if (token != null) await _authService.saveToken(token);
      
      // TRACK PROVIDER FOR BIOMETRICS
      await _secureStorage.write(key: "login_provider", value: "email");
      await _secureStorage.write(key: "biometric_email", value: email);
      await _secureStorage.write(key: "biometric_password", value: password);
      
      _currentUser = UserModel(id: firebaseUser.uid, fullName: firebaseUser.displayName ?? "Vault User", email: email);
      return true;
    }
    return false;
  });
}

  Future<bool> loginWithFacebook() async {
    return await _performAuthAction(() async {
      User? firebaseUser = await _authService.loginWithFacebook();
      if (firebaseUser != null) {
        await _db.collection('users').doc(firebaseUser.uid).set({
          'fullName': firebaseUser.displayName ?? "Agent",
          'email': firebaseUser.email ?? "Private",
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        _currentUser = UserModel(id: firebaseUser.uid, fullName: firebaseUser.displayName ?? "Agent", email: firebaseUser.email ?? "Private");
        return true;
      }
      return false;
    });
  }

  Future<void> logout() async {
    await _authService.signOut();
    await _authService.clearSession();
    _currentUser = null;
    notifyListeners();
  }

  Future<bool> _performAuthAction(Future<bool> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      bool success = await action();
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = "Protocol Breach.";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    emailController.dispose();
    passwordController.dispose();
    otpController.dispose();
    super.dispose();
  }
}

//By Jeslito geverola 