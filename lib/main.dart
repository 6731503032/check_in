// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'screens/home_screen.dart';

// ── Firebase Web Config ──────────────────────────────────────────────────
// Replace these values with your own from:
// Firebase Console → Project Settings → Your apps → Web app → Config
const _firebaseWebOptions = FirebaseOptions(
  apiKey: 'YOUR_API_KEY',
  authDomain: 'YOUR_PROJECT_ID.firebaseapp.com',
  projectId: 'YOUR_PROJECT_ID',
  storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  messagingSenderId: 'YOUR_SENDER_ID',
  appId: 'YOUR_APP_ID',
);
// ────────────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (kIsWeb) {
      // Web requires explicit FirebaseOptions — cannot use google-services.json
      await Firebase.initializeApp(options: _firebaseWebOptions);
    } else {
      // Mobile reads from google-services.json / GoogleService-Info.plist
      await Firebase.initializeApp();
    }
  } catch (e) {
    // App still runs with local storage if Firebase isn't configured yet
    debugPrint('Firebase init skipped: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Class Check-in',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      builder: (context, child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: child!,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}