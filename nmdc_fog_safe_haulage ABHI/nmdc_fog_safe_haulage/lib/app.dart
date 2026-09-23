import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/login_screen.dart';

class NmdcApp extends StatelessWidget {
  const NmdcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NMDC Fog Safe Haulage',

      debugShowCheckedModeBanner: false,

      theme: AppTheme.darkTheme,

      home: const LoginScreen(),
    );
  }
}