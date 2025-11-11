import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/auth_wrapper.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
        apiKey: "AIzaSyCGYfJQAB44vqNv4iSQjRlp8RKdsgXhnLw",
        authDomain: "nampol-app.firebaseapp.com",
        projectId: "nampol-app",
        storageBucket: "nampol-app.firebasestorage.app",
        messagingSenderId: "590118171741",
        appId: "1:590118171741:web:0dab1e4c39f3735a6309b4",
        measurementId: "G-R61ZLXNG9V"
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
      home: const AuthWrapper(), // This handles the auth flow
      debugShowCheckedModeBanner: false,
    );
  }
}