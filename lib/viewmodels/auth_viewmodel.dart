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

  String? _tempUID;

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
  // CRITICAL FIX: Only proceed if the widget still exists in the tree
  if (!context.mounted) return; 

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message, 
        style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 12)
      ),
      backgroundColor: isError ? Colors.redAccent : const Color(0xFF0DA6F2),
      behavior: SnackBarBehavior.floating,
    ),
  );
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
    
    // --- CLEAR SENSITIVE INPUTS ---
    emailController.clear();
    passwordController.clear();
    
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
    // 1. Get the Fresh Firebase User
    User? firebaseUser = await _authService.loginWithGoogle();
    
    if (firebaseUser == null) {
      _isLoading = false;
      notifyListeners();
      return; 
    }

    final String uid = firebaseUser.uid;
    // Extract the actual email used in this specific login session
    final String actualEmail = _extractEmail(firebaseUser); 
    
    DocumentSnapshot userDoc = await _db.collection('users').doc(uid).get();

    if (!userDoc.exists) {
      // NEW USER: Trigger OTP using the actual email from the Google session
      await _triggerOTPProtocol(context, actualEmail, uid, firebaseUser.displayName, provider: 'google');
    } else {
      final userData = userDoc.data() as Map<String, dynamic>;
      
      // Verification Check
      if (userData['otpVerified'] == true) {
        await _secureStorage.write(key: "login_provider", value: "google");
        
        // Use the email from the DB to ensure consistency
        _currentUser = UserModel(
          id: uid, 
          fullName: userData['fullName'] ?? firebaseUser.displayName ?? "Agent", 
          email: userData['email'] ?? actualEmail
        );
        
        if (context.mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ProfileView()));
        }
      } else {
        // Exists but not verified: Trigger OTP
        await _triggerOTPProtocol(context, actualEmail, uid, firebaseUser.displayName, provider: 'google');
      }
    }
  } catch (e) {
    // If something goes wrong, sign out to prevent session hanging
    await _authService.signOut();
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

  Future<bool> loginWithBiometrics() async {
  _isLoading = true;
  _errorMessage = null;
  notifyListeners();

  try {
    // 1. Identify who this phone belongs to via the Hardware Registry
    String deviceId = await _biometricService.getDeviceId();
    DocumentSnapshot registryDoc = await _db.collection('biometric_registry').doc(deviceId).get();
    
    if (!registryDoc.exists) {
      _errorMessage = "Device not registered.";
      return false;
    }

    // 2. Fetch the actual account data from the 'users' collection
    String ownerId = registryDoc.get('userId');
    DocumentSnapshot userDoc = await _db.collection('users').doc(ownerId).get();
    
    if (!userDoc.exists) {
      _errorMessage = "Account data not found.";
      return false;
    }

    // 3. Check the biometric toggle
    if (!(userDoc.get('biometricEnabled') ?? false)) {
      _errorMessage = "Biometrics is turned off for this device.";
      return false;
    }

    // 4. Perform the hardware scan
    String? authError = await _biometricService.authenticate();
    if (authError != null) {
      _errorMessage = authError;
      return false;
    }

    // 5. THE FIX: Fetch EVERYTHING from the database doc
    // This forces the email to be the one from the DB, not the Google ghost.
    _currentUser = UserModel(
      id: ownerId, 
      fullName: userDoc.get('fullName') ?? "Authorized Agent", 
      email: userDoc.get('email') ?? "No Email Linked" // Directly from DB
    );

    // Update the last login time in the background
    await _db.collection('users').doc(ownerId).update({
      'lastLogin': FieldValue.serverTimestamp(),
    });

    return true; 

  } catch (e) {
    _errorMessage = "Access Denied: Identity Protocol Breach.";
    return false;
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

Future<void> _triggerOTPProtocol(BuildContext context, String email, String uid, String? name, {String provider = 'google'}) async {
  try {
    // 1. CLEAR LOADING IMMEDIATELY
    _isLoading = false;
    _errorMessage = null;
    notifyListeners(); // Force UI to remove any loading overlays

    // 2. Set OTP State
    _isWaitingForOTP = true;
    _startResendTimer();
    _tempName = name; 
    _tempProvider = provider;
    notifyListeners(); 

    if (email != "no-email-provided") {
      _generatedOTP = await _authService.sendEmailOTP(email);
      if (_isWaitingForOTP) {
        _showSnackBar(context, "Verification Code Transmitted to $email");
      }
    } else {
      _generatedOTP = "123456"; 
      _showSnackBar(context, "Manual Override Required (Dev Mode)", isError: true);
    }
  } catch (e) {
    _isLoading = false;
    _isWaitingForOTP = false;
    notifyListeners();
    _showSnackBar(context, "Protocol Transmission Failed.", isError: true);
  }
}

// 2. Add a safeguard to the cancelOTP method
Future<void> cancelOTP(BuildContext context) async {
  // Prevent double-triggering
  if (!_isWaitingForOTP) return;

  _isLoading = true;
  _isWaitingForOTP = false; // Set this to false IMMEDIATELY
  _generatedOTP = null; 
  notifyListeners();

  try {
    if (_auth.currentUser != null) {
      await _auth.currentUser!.delete(); 
    }
    await _authService.signOut(); 
    
    await _secureStorage.delete(key: "temp_password");
    await _secureStorage.delete(key: "temp_email");
    
    _showSnackBar(context, "Identity Registration Aborted.", isError: true);
  } catch (e) {
    debugPrint("Rollback Error: $e");
  } finally {
    _isLoading = false;
    otpController.clear();
    notifyListeners();
  }
}
// 3. UPDATED VERIFY: Save to Database ONLY when OTP is correct
String? _tempName;
String? _tempProvider;

Future<void> verifyOTPAndAccess(BuildContext context) async {
  // 1. Check if the controller actually has text and if we have a code to check against
  String enteredCode = otpController.text.trim();
  
  if (enteredCode.isEmpty) {
    _showSnackBar(context, "Please enter the verification code.", isError: true);
    return;
  }

  if (enteredCode == _generatedOTP) {
    _isLoading = true;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user != null) {
        // SAVE TO FIRESTORE
        await _db.collection('users').doc(user.uid).set({
          'fullName': _tempName ?? "Agent",
          'email': user.email,
          'otpVerified': true,
          'lastLogin': FieldValue.serverTimestamp(),
          'provider': _tempProvider ?? 'email',
          'biometricEnabled': false, // Initialize this to avoid null errors later
        }, SetOptions(merge: true));

        // LOCK IN PROVIDER
        await _secureStorage.write(key: "login_provider", value: _tempProvider);
        
        if (_tempProvider == 'email') {
          String? tPass = await _secureStorage.read(key: "temp_password");
          if (tPass != null) await _secureStorage.write(key: "biometric_password", value: tPass);
          await _secureStorage.write(key: "biometric_email", value: user.email);
        }

        _currentUser = UserModel(
          id: user.uid, 
          fullName: _tempName ?? "Agent", 
          email: user.email ?? ""
        );

        // Success cleanup
        _isWaitingForOTP = false;
        _generatedOTP = null;
        otpController.clear();
        
        _showSnackBar(context, "Identity Secured. Profile Established.");

        if (context.mounted) {
          // Use pushAndRemoveUntil to clear the stack so they can't go back to the register page
          Navigator.pushAndRemoveUntil(
            context, 
            MaterialPageRoute(builder: (context) => const ProfileView()), 
            (route) => false
          );
        }
      } else {
        _showSnackBar(context, "Session Expired. Please retry registration.", isError: true);
      }
    } catch (e) {
      _showSnackBar(context, "Database Protocol Failure.", isError: true);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  } else {
    _showSnackBar(context, "Invalid Access Code. Verification Failed.", isError: true);
  }
}

Future<bool> register(BuildContext context, String name, String email, String password) async {
  _isLoading = true;
  _errorMessage = null;
  notifyListeners();

  try {
    // 1. THE SECURITY CHECK: Look for ANY existing verified account with this email
    // This catches Google, Facebook, and previous Manual registrations
    final existing = await _db.collection('users')
        .where('email', isEqualTo: email)
        .where('otpVerified', isEqualTo: true)
        .get();
    
    if (existing.docs.isNotEmpty) {
      final userData = existing.docs.first.data();
      final provider = userData['provider'] ?? 'another method';
      
      // Inform the user specifically how they previously registered
      _errorMessage = "Identity already active via $provider. Please Login.";
      _isLoading = false;
      notifyListeners();
      return false; // STOPS HERE: No OTP is sent
    }

    // 2. FIREBASE LAYER: Register or Login if they exist but aren't verified yet
    User? firebaseUser;
    try {
      firebaseUser = await _authService.registerWithEmail(name, email, password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // User exists in Firebase but failed the 'otpVerified' check in step 1
        firebaseUser = await _authService.loginWithEmail(email, password);
      } else { rethrow; }
    }
    
    if (firebaseUser != null) {
      _tempUID = firebaseUser.uid; 
      
      // 3. SECURE STAGING: Prepare for Biometric Key migration later
      await _secureStorage.write(key: "temp_email", value: email);
      await _secureStorage.write(key: "temp_password", value: password);
      await _secureStorage.write(key: "temp_provider", value: "email");

      // 4. TRIGGER OTP: Only happens if no verified account was found in step 1
      await _triggerOTPProtocol(context, email, firebaseUser.uid, name, provider: 'email');
      return true;
    }
    return false;
  } catch (e) {
    _errorMessage = "Registration Protocol Failed.";
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
  
  // ADD THIS: Clear the provider tracking so biometrics doesn't "remember" Facebook
  await _secureStorage.delete(key: "login_provider");
  await _secureStorage.delete(key: "biometric_email");
  await _secureStorage.delete(key: "biometric_password");

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

//By Jeslito Geverola 