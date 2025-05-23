// ignore_for_file: depend_on_referenced_packages

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
// ignore: unused_import
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
//import 'package:myapp/services/firestore_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  //final FirestoreService _firestoreService = FirestoreService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign up with email, password, and username
  Future<String?> registerWithEmail(String email, String password, String username) async {
    try {
      // Create user with email and password
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User user = result.user!;

      // Generate a random token
      const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
      final random = Random();
      final token = String.fromCharCodes(
        Iterable.generate(32, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
      );

      // Call Firebase Function to send verification email
      final callable = 'sendVerificationEmail'; // Name of the Cloud Function
      final response = await http.post(
        Uri.parse('https://us-central1-your-firebase-project-id.cloudfunctions.net/$callable'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'data': {
            'email': email,
            'token': token,
            'uid': user.uid,
          },
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to send verification email');
      }

      // Save user data to Firestore (unverified)
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'username': username,
        'createdAt': FieldValue.serverTimestamp(),
        'isVerified': false, // Track verification status
      });

      // Add default habits
      await _initializeUserData(user);

      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Unknown error occurred: $e';
    }
  }

  // Verify email token
  Future<String?> verifyEmailToken(String uid, String token) async {
    try {
      final tokenDoc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('verification_tokens')
          .doc(token)
          .get();

      if (!tokenDoc.exists) {
        return 'Invalid or expired token';
      }

      final data = tokenDoc.data()!;
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      final now = DateTime.now();

      if (now.isAfter(expiresAt)) {
        return 'Token has expired';
      }

      // Mark user as verified
      await _firestore.collection('users').doc(uid).update({
        'isVerified': true,
      });

      // Delete token to prevent reuse
      await tokenDoc.reference.delete();

      // Refresh user to update emailVerified status
      final user = _auth.currentUser!;
      await user.reload();
      return null; // Success
    } catch (e) {
      return 'Verification failed: $e';
    }
  }

  // Sign in with email and password
  Future<String?> loginWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = result.user!;
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final isVerified = userDoc.exists && (userDoc.data()!['isVerified'] == true);

      if (!isVerified) {
        return 'Please verify your email before signing in.';
      }

      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Unknown error occurred';
    }
  }

  // Try silent sign-in first (for returning users)
  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (e) {
      return null;
    }
  }

  // Process Google Sign-In account after authentication
  Future<String?> processGoogleUser(GoogleSignInAccount googleUser) async {
    try {
      // Verify email domain
      if (!_isGoogleEmail(googleUser.email)) {
        await _googleSignIn.signOut();
        return 'Only Google emails (@gmail.com or Google Workspace) are allowed.';
      }

      // Get Google authentication credentials
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with Google credentials
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User user = userCredential.user!;

      // Initialize user data in Firestore
      await _initializeUserData(user);

      return null; // Success
    } catch (e) {
      return 'Google Sign-In failed: $e';
    }
  }

  // Sign in with Google - Legacy method for non-web platforms
  Future<String?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // For web, this should not be called directly
        // Instead, use the renderButton in the UI and processGoogleUser
        return 'For web platforms, use the Google Sign-In button instead';
      } else {
        // For mobile platforms, we can still use the traditional flow
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return 'Sign-in canceled';
        
        return processGoogleUser(googleUser);
      }
    } catch (e) {
      return 'Google Sign-In failed: $e';
    }
  }

  // Check if email is a Google email
  bool _isGoogleEmail(String email) {
    final domain = email.split('@').last.toLowerCase();
    return domain == 'gmail.com' || _isGoogleWorkspaceDomain(domain);
  }

  // Placeholder for Google Workspace domain check
  bool _isGoogleWorkspaceDomain(String domain) {
    // Add specific Workspace domains if needed
    return false; // Extend for Workspace support
  }

  // Initialize user data in Firestore
  Future<void> _initializeUserData(User user) async {
    final userDoc = _firestore.collection('users').doc(user.uid);
    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      await userDoc.set({
        'uid': user.uid,
        'email': user.email,
        'username': user.displayName ?? 'User',
        'createdAt': FieldValue.serverTimestamp(),
        'isVerified': true, // Google users are auto-verified
      });

      // Add default habits (consistent with ProfilePage)
     // await _firestoreService.addHabit(user.uid, 'Exercise', 'Daily');
      // await _firestoreService.addHabit(user.uid, 'Read', 'Daily');
     // await _firestoreService.addHabit(user.uid, 'Meditate', 'Daily');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Check if user is verified
  bool isUserVerified() {
    final user = _auth.currentUser;
    if (user == null) return false;

    // For Google users, assume verified; for email users, check Firestore
    if (user.providerData.any((info) => info.providerId == 'google.com')) {
      return true;
    }

    return user.emailVerified;
  }
}
