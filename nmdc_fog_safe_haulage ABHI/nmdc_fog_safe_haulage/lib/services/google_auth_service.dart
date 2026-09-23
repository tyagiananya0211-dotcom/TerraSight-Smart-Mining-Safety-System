import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_profile.dart';
import 'firestore_service.dart';

class GoogleAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserCredential?> signInWithGoogle([String? selectedRole]) async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        // Web: Use Firebase built-in OAuth popup
        final provider = GoogleAuthProvider();
        provider.setCustomParameters({
          'prompt': 'select_account',
        });
        userCredential = await _auth.signInWithPopup(provider);
      } else {
        // Android / iOS: Use google_sign_in package
        final GoogleSignIn googleSignIn = GoogleSignIn();
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        
        if (googleUser == null) return null; // Cancelled

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await _auth.signInWithCredential(credential);
      }

      // Check if user exists in Firestore
      if (userCredential.user != null) {
        final profile = await FirestoreService().getUserProfile(userCredential.user!.uid);
        
        if (profile == null) {
          // New user from Google Sign-In, create profile
          final newProfile = UserProfile(
            uid: userCredential.user!.uid,
            fullName: userCredential.user!.displayName ?? 'Google User',
            email: userCredential.user!.email ?? '',
            employeeId: '', 
            role: selectedRole ?? 'Driver', // Use selected role or fallback to Driver
            status: 'pending',
            approved: false,
            createdAt: DateTime.now(),
          );
          await FirestoreService().createUserProfile(newProfile);
        }
      }

      return userCredential;
    } catch (e) {
      print('Google Sign-In failed: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
    }
    await _auth.signOut();
  }
}
