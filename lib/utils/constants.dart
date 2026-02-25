import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // Firebase
  static final String firebaseApiKey = dotenv.env['FIREBASE_API_KEY'] ?? '';
  static final String firebaseAppId = dotenv.env['FIREBASE_APP_ID'] ?? '';
  static final String firebaseMessagingSenderId = dotenv.env['FIREBASE_SENDER_ID'] ?? '';
  static final String firebaseProjectId = dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
  static final String firebaseStorageBucket = dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '';

  // SMTP
  static final String smtpEmail = dotenv.env['SMTP_EMAIL'] ?? '';
  static final String smtpPassword = dotenv.env['SMTP_PASSWORD'] ?? '';

  // Facebook
  static final String facebookAppId = dotenv.env['FB_APP_ID'] ?? '';
  static final String facebookClientToken = dotenv.env['FB_CLIENT_TOKEN'] ?? '';

  // UI Styling (These can stay const)
  static const int cyanPrimary = 0xFF0DA6F2;
  static const int pinkAccent = 0xFFFF00FF;
  static const int darkBg = 0xFF020408;
}