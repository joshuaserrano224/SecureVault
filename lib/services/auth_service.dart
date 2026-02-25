import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../utils/constants.dart'; 

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  

  // --- M3 REQUIREMENT: SECURE STORAGE ---

  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: 'auth_token', value: token);
  }

 Future<void> clearSession() async {
  // Only delete the auth_token. 
  // DO NOT delete login_provider, otherwise biometrics won't know which service to call.
  await _secureStorage.delete(key: 'auth_token');
}
  // Inside AuthService class
Future<void> saveProvider(String provider) async {
  await _secureStorage.write(key: 'login_provider', value: provider);
}

Future<String?> getProvider() async {
  return await _secureStorage.read(key: 'login_provider');


}

Future<User?> silentLoginWithGoogle() async {
  try {
    // try to sign in silently (no popup)
    final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
    
    // If silent fails, we have to fall back to the popup once
    if (googleUser == null) {
      return await loginWithGoogle(); 
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    UserCredential userCredential = await _auth.signInWithCredential(credential);
    return userCredential.user;
  } catch (e) {
    print("Silent Google Auth Failed: $e");
    return null;
  }
}

  // --- FIREBASE AUTH METHODS ---

  Future<User?> registerWithEmail(String name, String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      User? user = result.user;

      if (user != null) {
        await user.updateDisplayName(name);
        await _db.collection('users').doc(user.uid).set({
          'fullName': name,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        });

        String? token = await user.getIdToken();
        if (token != null) await saveToken(token);
      }
      return user;
    } catch (e) {
      rethrow; 
    }
  }

  Future<User?> loginWithGoogle() async {
  try {
    // ONLY signOut(), DO NOT use disconnect()
    // Disconnect revokes the app's permission, making biometrics fail.
    await _googleSignIn.signOut();

    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    UserCredential userCredential = await _auth.signInWithCredential(credential);
    
    String? token = await userCredential.user?.getIdToken();
    if (token != null) await saveToken(token);

    return userCredential.user;
  } catch (e) {
    rethrow;
  }
}
  // --- OTP TRANSMISSION ---
  Future<String> sendEmailOTP(String recipientEmail) async {
    String otp = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString().substring(0, 6);

    // Using AppConstants as defined in your file
    final smtpServer = gmail(AppConstants.smtpEmail, AppConstants.smtpPassword);

    final message = Message()
      ..from = Address(AppConstants.smtpEmail, 'SECURE VAULT')
      ..recipients.add(recipientEmail)
      ..subject = 'ACCESS CODE: $otp'
      ..html = """
        <div style="font-family: monospace; background-color: #020408; color: #0DA6F2; padding: 20px; border: 1px solid #0DA6F2;">
          <h2 style="color: white;">SECURITY PROTOCOL</h2>
          <p>Your authentication code is:</p>
          <h1 style="color: #FF00FF; letter-spacing: 5px;">$otp</h1>
          <p style="font-size: 10px; color: grey;">If you did not request this, ignore this transmission.</p>
        </div>
      """;

    try {
      await send(message, smtpServer);
      return otp;
    } catch (e) {
      throw "Mailer Error: Protocol failed to transmit.";
    }
  }

 Future<User?> loginWithFacebook() async {
    try {
      // Trigger the sign-in flow
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status == LoginStatus.success) {
        // Create a credential from the access token
        final AuthCredential credential = FacebookAuthProvider.credential(
          result.accessToken!.tokenString,
        );

        // Sign in to Firebase with the Facebook credential
        UserCredential userCredential = await _auth.signInWithCredential(credential);
        
        // Save session token locally
        String? token = await userCredential.user?.getIdToken();
        if (token != null) await saveToken(token);

        return userCredential.user;
      } else if (result.status == LoginStatus.cancelled) {
        return null;
      } else {
        throw result.message ?? "Facebook login failed.";
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> loginWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );

      User? user = result.user;
      if (user != null) {
        String? token = await user.getIdToken();
        if (token != null) {
          await saveToken(token);
        }
      }
      return user;
    } catch (e) {
      rethrow;
    }
  }

 Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    await FacebookAuth.instance.logOut(); // Added Facebook logout
    await clearSession();
  }
}