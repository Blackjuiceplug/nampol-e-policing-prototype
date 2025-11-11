import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/admin_dashboard.dart';

class EmergencyAdminPage extends StatefulWidget {
  const EmergencyAdminPage({super.key});

  @override
  State<EmergencyAdminPage> createState() => _EmergencyAdminPageState();
}

class _EmergencyAdminPageState extends State<EmergencyAdminPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create First Admin')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Admin Email'),
                validator: (value) => value!.contains('@') ? null : 'Invalid email',
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Temporary Password'),
                obscureText: true,
                validator: (value) => value!.length >= 8 ? null : 'Minimum 8 characters',
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _createFirstAdmin,
                child: const Text('Create Super Admin'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createFirstAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // 1. Create Firebase user
      UserCredential user = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Add to admins collection
      await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.user!.uid)
          .set({
        'email': _emailController.text.trim(),
        'role': 'super-admin',
        'createdAt': FieldValue.serverTimestamp(),
        'isInitialAdmin': true, // Mark for later audit
      });

      // 3. Navigate to dashboard
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminDashboard()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}