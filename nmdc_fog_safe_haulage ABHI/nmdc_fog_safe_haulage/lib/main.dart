import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/role_router.dart';
import 'screens/role_selection_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MineSafetyApp());
}

class MineSafetyApp extends StatelessWidget {
  const MineSafetyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NMDC Fog Safe Haulage',
      theme: ThemeData(
        useMaterial3: true,
      ),

      // App always starts with Splash Screen
      home: const SplashScreen(),
    );
  }
}

// Firebase login state check
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF07111F),
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // User already logged in, route based on role
        if (snapshot.hasData && snapshot.data != null) {
          return RoleRouter(user: snapshot.data!);
        }

        // User not logged in
        return const RoleSelectionScreen(isSsoDemo: false);
      },
    );
  }
}