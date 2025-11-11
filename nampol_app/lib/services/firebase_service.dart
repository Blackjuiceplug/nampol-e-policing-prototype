import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Email & Password Sign In
  static Future<User?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Email & Password Sign Up with Officer Details
  static Future<User?> signUpWithOfficerDetails({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String badgeNumber,
    required String phoneNumber,
    required String department,
    required String rank,
  }) async {
    try {
      // Create user in Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Save additional officer details to Firestore
      await _firestore
          .collection('officers')
          .doc(userCredential.user!.uid)
          .set({
        'email': email.trim(),
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'badgeNumber': badgeNumber.trim(),
        'phoneNumber': phoneNumber.trim(),
        'department': department.trim(),
        'rank': rank.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'isApproved': false, // Admin can approve later
        'role': 'officer', // Default role
        'status': 'pending', // Account status
      });

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Registration failed: $e';
    }
  }

  // Update officer profile
  static Future<void> updateOfficerProfile({
    required String uid,
    String? firstName,
    String? lastName,
    String? badgeNumber,
    String? phoneNumber,
    String? department,
    String? rank,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};

      if (firstName != null) updateData['firstName'] = firstName.trim();
      if (lastName != null) updateData['lastName'] = lastName.trim();
      if (badgeNumber != null) updateData['badgeNumber'] = badgeNumber.trim();
      if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber.trim();
      if (department != null) updateData['department'] = department.trim();
      if (rank != null) updateData['rank'] = rank.trim();

      await _firestore.collection('officers').doc(uid).update(updateData);
    } catch (e) {
      throw 'Failed to update profile: $e';
    }
  }

  // Password Reset
  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Change Password
  static Future<void> changePassword(
      String currentPassword, String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'No authenticated user';

      // Reauthenticate user
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);

      // Change password
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign Out
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get Officer Data
  static Future<Map<String, dynamic>?> getOfficerData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('officers').doc(uid).get();
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      throw 'Failed to fetch officer data: $e';
    }
  }

  // Stream officer data
  static Stream<DocumentSnapshot> getOfficerDataStream(String uid) {
    return _firestore.collection('officers').doc(uid).snapshots();
  }

  // Handle Firebase Auth Exceptions
  static String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This user has been disabled.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'The email address is already in use.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'weak-password':
        return 'The password is too weak (min 6 characters).';
      case 'requires-recent-login':
        return 'Please log in again to perform this action.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'An error occurred: ${e.message}';
    }
  }

  // Report Submission
  static Future<void> submitReport(Map<String, dynamic> reportData) async {
    try {
      final position = await getCurrentLocation();
      final user = _auth.currentUser;
      final officerData = user != null ? await getOfficerData(user.uid) : null;

      reportData.addAll({
        'timestamp': FieldValue.serverTimestamp(),
        'geoLocation': GeoPoint(position.latitude, position.longitude),
        'officerId': user?.uid,
        'officerName': officerData != null
            ? '${officerData['firstName']} ${officerData['lastName']}'
            : null,
        'badgeNumber': officerData?['badgeNumber'],
        'status': 'Submitted',
      });

      await _firestore.collection('reports').add(reportData);
    } catch (e) {
      throw 'Failed to submit report: $e';
    }
  }

  // Get current location
  static Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Location services are disabled';
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permissions are denied';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Location permissions are permanently denied';
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
  }

  // Stream of reports
  static Stream<QuerySnapshot> getReportsStream({String? officerId}) {
    Query query = _firestore
        .collection('reports')
        .orderBy('timestamp', descending: true);

    if (officerId != null) {
      query = query.where('officerId', isEqualTo: officerId);
    }

    return query.snapshots();
  }

  // Update officer location
  static Future<void> updateOfficerLocation(Position position) async {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      await _firestore.collection('officer_locations').doc(userId).set({
        'position': GeoPoint(position.latitude, position.longitude),
        'timestamp': FieldValue.serverTimestamp(),
        'officerId': userId,
      }, SetOptions(merge: true));
    }
  }

  // Get nearby officers
  static Stream<QuerySnapshot> getNearbyOfficers(
      GeoPoint center, double radiusInKm) {
    // Approximate 1 degree = 111 km
    final degree = radiusInKm / 111;
    final lowerLat = center.latitude - degree;
    final upperLat = center.latitude + degree;
    final lowerLng = center.longitude - degree;
    final upperLng = center.longitude + degree;

    return _firestore
        .collection('officer_locations')
        .where('position.latitude', isGreaterThan: lowerLat)
        .where('position.latitude', isLessThan: upperLat)
        .where('position.longitude', isGreaterThan: lowerLng)
        .where('position.longitude', isLessThan: upperLng)
        .snapshots();
  }
}