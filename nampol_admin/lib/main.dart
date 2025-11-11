import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/auth_wrapper.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: FirebaseOptions(
        apiKey:dotenv.env['FIREBASE_API_KEY'] ?? '',
        authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? '',
        projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? '',
        storageBucket:dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '',
        messagingSenderId:dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '',
        appId:dotenv.env['FIREBASE_APP_ID'] ?? '',
        measurementId:dotenv.env['MEASUREMENT_ID'] ?? ''
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Police Admin',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AuthWrapper(), 
      debugShowCheckedModeBanner: false,
    );
  }
}
