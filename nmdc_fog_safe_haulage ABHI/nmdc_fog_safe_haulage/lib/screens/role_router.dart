import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';
import 'dashboard_screen.dart';
import 'account_under_review_screen.dart';
import 'login_screen.dart';
import 'admin_home_screen.dart';

class RoleRouter extends StatelessWidget {
  final User user;
  const RoleRouter({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: FirestoreService().streamUserProfile(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF040A10), // AppColors.background
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFF040A10),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error loading profile: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const DashboardScreen()),
                      );
                    },
                    child: const Text('Bypass to Dashboard'),
                  )
                ],
              ),
            ),
          );
        }

        final profile = snapshot.data;

        if (profile == null) {
           return const Scaffold(
            backgroundColor: Color(0xFF040A10),
            body: Center(
              child: Text(
                'Profile not found. Please contact support.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        // Bypass approval check as requested by user
        // if (!profile.approved || profile.status == 'pending') {
        //   return const AccountUnderReviewScreen();
        // }

        if (profile.status == 'rejected') {
          return Scaffold(
            backgroundColor: const Color(0xFF040A10),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Account Rejected', style: TextStyle(color: Colors.red, fontSize: 24)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    child: const Text('Logout'),
                  )
                ],
              ),
            ),
          );
        }

        // Route based on role
        if (profile.role == 'Driver') {
          return const DashboardScreen();
        } else if (profile.role == 'Admin' || profile.role == 'Safety Officer') {
          return const AdminHomeScreen();
        } else {
           return const DashboardScreen(); // Default Fallback
        }
      },
    );
  }
}
