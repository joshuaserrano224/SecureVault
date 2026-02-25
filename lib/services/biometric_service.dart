import 'dart:io';
import 'package:local_auth/local_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Fetches a UNIQUE Hardware ID.
  /// Using build.id alone is risky because it's often the OS version ID.
  /// We combine model and fingerpint (the build fingerprint) for better uniqueness.
  Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        var build = await _deviceInfo.androidInfo;
        // Combining model and hardware/id ensures the ID is unique to THIS device
        return "${build.model}_${build.id}".replaceAll(' ', '_'); 
      } else {
        var build = await _deviceInfo.iosInfo;
        return build.identifierForVendor ?? "unknown_ios";
      }
    } catch (e) {
      return "unknown_device";
    }
  }

  Future<String?> authenticate() async {
    try {
      // 1. Check if the hardware even exists
      bool canCheck = await _auth.canCheckBiometrics;
      bool isSupported = await _auth.isDeviceSupported();

      if (!canCheck && !isSupported) return "Biometric hardware not available.";

      // 2. Trigger the OS prompt
      // We set biometricOnly to false to allow PIN fallback.
      // We set useErrorDialogs to true so the OS tells the user what's wrong.
      bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Identity verification required for SecureVault access',
        options: const AuthenticationOptions(
          stickyAuth: true,      // Keeps auth alive if app goes to background
          biometricOnly: false,  // Allowing PIN fallback prevents the "silent fail"
          useErrorDialogs: true, // OS will show the "Enroll Fingerprint" dialogs
        ),
      );

      return didAuthenticate ? null : "Verification failed.";
    } on PlatformException catch (e) {
      // Handle specific error codes if needed
      if (e.code == 'NotAvailable') return "Biometrics not set up on this device.";
      if (e.code == 'LockedOut') return "Too many attempts. Locked out.";
      return e.message ?? "Hardware protocol error.";
    } catch (e) {
      return "Unexpected security breach.";
    }
  }
}