import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import 'dashboard_screen.dart';
import 'admin_home_screen.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  final bool isSsoDemo;
  const RoleSelectionScreen({super.key, this.isSsoDemo = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        title: const Text('Select Your Role', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.precision_manufacturing, size: 60, color: AppColors.primary),
                  const SizedBox(height: 24),
                  const Text(
                    'TERASIGHT',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please select your role to continue',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                  const SizedBox(height: 48),
                  _buildRoleCard(
                    context: context,
                    title: 'Driver',
                    icon: Icons.local_shipping,
                    color: Colors.blueAccent,
                    onTap: () {
                      if (isSsoDemo) {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen(simulatedRole: 'Driver')));
                      } else {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen(selectedRole: 'Driver')));
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildRoleCard(
                    context: context,
                    title: 'Operator',
                    icon: Icons.engineering,
                    color: Colors.orangeAccent,
                    onTap: () {
                      if (isSsoDemo) {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen(simulatedRole: 'Operator')));
                      } else {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen(selectedRole: 'Operator')));
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildRoleCard(
                    context: context,
                    title: 'Safety Officer',
                    icon: Icons.health_and_safety,
                    color: Colors.greenAccent,
                    onTap: () {
                      if (isSsoDemo) {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminHomeScreen(simulatedRole: 'Safety Officer')));
                      } else {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen(selectedRole: 'Safety Officer')));
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildRoleCard(
                    context: context,
                    title: 'Admin',
                    icon: Icons.admin_panel_settings,
                    color: Colors.redAccent,
                    onTap: () {
                      if (isSsoDemo) {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminHomeScreen(simulatedRole: 'Admin')));
                      } else {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen(selectedRole: 'Admin')));
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: AppColors.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }
}
