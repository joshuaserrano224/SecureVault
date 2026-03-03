import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 1. Add this import
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/profile_viewmodel.dart';
import 'views/login_view.dart';
import 'views/register_view.dart';
import 'views/profile_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Load the .env file before anything else
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: .env file not found. Ensure it exists in the root folder.");
  }

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase Init Error: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => ProfileViewModel()),
      ],
      child: const MyApp(),
    ),
  );
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secure Vault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF020408),
        primaryColor: const Color(0xFF0DA6F2),
      ),
      // 1. Remove the 'home:' property entirely
      // 2. Add these two properties:
      initialRoute: '/login', 
      routes: {
        '/login': (context) => const LoginView(),
        // Only add these below once the files actually exist!
        '/register': (context) => const RegisterView(),
         '/profile': (context) => const ProfileView(),
      },
    );
  }
}