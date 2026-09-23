import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user_profile.dart';
import 'firestore_service.dart';

class SSOAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserCredential?> signInWithSSO() async {
    try {
      UserCredential userCredential;
      final provider = MicrosoftAuthProvider();

      if (kIsWeb) {
        // For web, we use signInWithPopup
        userCredential = await _auth.signInWithPopup(provider);
      } else {
        // For native, use signInWithProvider
        userCredential = await _auth.signInWithProvider(provider);
      }
      
      // Check if user exists in Firestore
      if (userCredential.user != null) {
        final profile = await FirestoreService().getUserProfile(userCredential.user!.uid);
        
        if (profile == null) {
          // New SSO user, create profile
          final newProfile = UserProfile(
            uid: userCredential.user!.uid,
            fullName: userCredential.user!.displayName ?? 'SSO User',
            email: userCredential.user!.email ?? '',
            employeeId: '',
            role: 'Driver', // Default role; admin should not be auto-assigned
            status: 'pending',
            approved: false, 
            createdAt: DateTime.now(),
          );
          await FirestoreService().createUserProfile(newProfile);
        }
      }
      
      return userCredential;
    } catch (e) {
      print('SSO Sign-In failed: $e');
      rethrow;
    }
  }
}
