import 'package:flutter/material.dart';
import 'screens/driver_hud_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      // App goes directly to Driver HUD
      home: const DriverHudScreen(),
    );
  }
}
