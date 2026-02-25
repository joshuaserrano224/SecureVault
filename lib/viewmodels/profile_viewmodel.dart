import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/biometric_service.dart';

enum UpdateNameResult { success, failed, requiresReauth }

class ProfileViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final BiometricService _biometricService = BiometricService();

  // Controllers live here now
  final TextEditingController nameController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _currentUserName;
  bool _isDarkMode = true;
  bool _biometricEnabled = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isDarkMode => _isDarkMode;
  bool get biometricEnabled => _biometricEnabled;
  User? get currentUser => _auth.currentUser;
  String get displayName => _currentUserName ?? _auth.currentUser?.displayName ?? "USER";

  ProfileViewModel() {
    _currentUserName = _auth.currentUser?.displayName;
    nameController.text = displayName;
  }

  // --- Inside ProfileViewModel class ---

// Add this getter to handle the "N/A" or missing email issue
String get email {
  User? user = _auth.currentUser;
  if (user == null) return "N/A";

  // 1. Try the primary email field
  if (user.email != null && user.email!.isNotEmpty) {
    return user.email!;
  }

  // 2. If primary is null, search through social providers (Google/Facebook)
  for (UserInfo profile in user.providerData) {
    if (profile.email != null && profile.email!.isNotEmpty) {
      return profile.email!;
    }
  }

  return "N/A";
}

  // --- CLEAN LOGIC: The "Smart" Sync Trigger moved here ---
  void syncProfileState(String? activeId) {
    if (activeId != null && !_isLoading) {
      fetchBiometricStatus(passedUid: activeId);
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> fetchBiometricStatus({String? passedUid}) async {
    final String? uid = passedUid ?? _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      var doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        _biometricEnabled = data['biometricEnabled'] ?? false;
        if (data['fullName'] != null && _currentUserName != data['fullName']) {
          _currentUserName = data['fullName'];
          nameController.text = _currentUserName!;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Status fetch failed: $e");
    }
  }

  Future<void> toggleBiometricSupport(bool enabled, String? activeUserId) async {
    final String? uid = activeUserId ?? _auth.currentUser?.uid;
    if (uid == null) {
      _errorMessage = "Authentication session required";
      notifyListeners();
      return;
    }

    _setLoading(true);
    _errorMessage = null;

    if (enabled) {
      String? authError = await _biometricService.authenticate();
      if (authError == null) {
        try {
          String deviceId = await _biometricService.getDeviceId();
          var registryDoc = await _db.collection('biometric_registry').doc(deviceId).get();

          if (registryDoc.exists && (registryDoc.data() as Map)['userId'] != uid) {
            _errorMessage = "Hardware already linked to another account.";
            _biometricEnabled = false;
          } else {
            WriteBatch batch = _db.batch();
            batch.set(_db.collection('biometric_registry').doc(deviceId), {
              'userId': uid,
              'timestamp': FieldValue.serverTimestamp(),
            });
            batch.update(_db.collection('users').doc(uid), {'biometricEnabled': true});
            await batch.commit();
            _biometricEnabled = true;
          }
        } catch (e) {
          _errorMessage = "Database update failed.";
        }
      } else {
        _errorMessage = authError;
      }
    } else {
      try {
        await _db.collection('users').doc(uid).update({'biometricEnabled': false});
        _biometricEnabled = false;
      } catch (e) {
        _errorMessage = "Failed to disable biometrics.";
      }
    }
    _setLoading(false);
  }

  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  Future<UpdateNameResult> handleUpdateName() async {
    final newName = nameController.text.trim();
    if (newName.isEmpty) {
      _errorMessage = "Codename cannot be empty";
      notifyListeners();
      return UpdateNameResult.failed;
    }

    _setLoading(true);
    _errorMessage = null;

    try {
      User? user = _auth.currentUser;
      if (user == null) throw Exception("No User");

      try {
        await user.updateDisplayName(newName);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          _setLoading(false);
          return UpdateNameResult.requiresReauth;
        }
        rethrow;
      }

      await _db.collection('users').doc(user.uid).update({
        'fullName': newName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _currentUserName = newName;
      _setLoading(false);
      return UpdateNameResult.success;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return UpdateNameResult.failed;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _biometricEnabled = false;
    _currentUserName = null;
    nameController.clear();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String getInitials() {
    String name = displayName;
    if (name.isEmpty || name == "USER") return "ID";
    List<String> names = name.trim().split(" ");
    return names.length > 1 
        ? (names[0][0] + names[1][0]).toUpperCase() 
        : names[0][0].toUpperCase();
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }
}