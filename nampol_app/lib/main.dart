import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:nampol_app/screens/home_screen.dart';
import 'package:nampol_app/splash_screen.dart';
import 'auth/forget_password_screen.dart';
import 'auth/login_screen.dart';
import 'auth/signup_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Police Incident Reporter',
      theme: ThemeData(
        // Color Scheme
        primaryColor: const Color(0xFF0A4D8C), // Police navy blue
        primaryColorDark: const Color(0xFF08345E),
        primaryColorLight: const Color(0xFF4D7CAC),
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF0A4D8C),
          secondary: const Color(0xFFD32F2F), // Emergency red
          surface: Colors.white,
          background: const Color(0xFFF5F7FA), // Light gray-blue
        ),

        // App Bar Theme
        appBarTheme: const AppBarTheme(
          elevation: 2,
          centerTitle: true,
          color: Color(0xFF0A4D8C),
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),

        // Input Fields
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 12,
          ),
          labelStyle: const TextStyle(color: Colors.grey),
        ),

        // Buttons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFF0A4D8C),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),

        // Text Theme (Updated for Flutter 3.x+)
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 72, fontWeight: FontWeight.bold),
          displayMedium: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
          displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
          headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), // Replaces headline6
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontSize: 16), // Replaces bodyText1
          bodyMedium: TextStyle(fontSize: 14), // Replaces bodyText2
          bodySmall: TextStyle(fontSize: 12),
          labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Used for buttons
          labelMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),

        // Card Theme
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(8),
        ),

        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SplashScreen(),
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}