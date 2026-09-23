import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/constants/app_colors.dart';
import '../services/firestore_service.dart';
import '../models/user_profile.dart';
import 'role_selection_screen.dart';

// Screens
import 'analytics_screen.dart';
import 'fleet_screen.dart';
import 'fog_intelligence_screen.dart';
import 'predictive_ai_screen.dart';
import 'safety_bubble_screen.dart';
import 'stopping_distance_screen.dart';
import 'sensor_trust_engine_screen.dart';
import 'vehicle_control_center_screen.dart';
import 'admin_panel_screen.dart';
import 'profile_screen.dart';
import 'server_control_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  final String? simulatedRole;
  const AdminHomeScreen({super.key, this.simulatedRole});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;

  late final List<Map<String, dynamic>> _menuItems;

  @override
  void initState() {
    super.initState();
    _menuItems = [
      {'title': 'Terasight AI Engine', 'icon': Icons.developer_board, 'screen': const ServerControlScreen()},
      {'title': 'Analytics Overview', 'icon': Icons.analytics, 'screen': const AnalyticsScreen()},
      {'title': 'Live Fleet Map', 'icon': Icons.map, 'screen': const FleetScreen()},
      {'title': 'Fog Intelligence', 'icon': Icons.cloud, 'screen': const FogIntelligenceScreen()},
      {'title': 'Predictive AI', 'icon': Icons.psychology, 'screen': const PredictiveAIScreen()},
      {'title': 'Safety Bubble', 'icon': Icons.shield, 'screen': const SafetyBubbleScreen()},
      {'title': 'Stopping Distance', 'icon': Icons.linear_scale, 'screen': const StoppingDistanceScreen()},
      {'title': 'Sensor Trust Engine', 'icon': Icons.sensors, 'screen': const SensorTrustEngineScreen()},
      {'title': 'Vehicle Control Center', 'icon': Icons.local_shipping, 'screen': const VehicleControlCenterScreen(vehicleId: 'NMDC-101')},
      {'title': 'Admin & Config', 'icon': Icons.admin_panel_settings, 'screen': const AdminPanelScreen()},
      {'title': 'My Profile', 'icon': Icons.person, 'screen': ProfileScreen(simulatedRole: widget.simulatedRole)},
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 850;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isDesktop
          ? null // No app bar on desktop, we use a sleek sidebar
          : AppBar(
              backgroundColor: AppColors.surface,
              title: const Text('NMDC Terasight', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
      drawer: isDesktop ? null : _buildSidebar(),
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(),
          Expanded(
            child: _menuItems[_selectedIndex]['screen'] as Widget,
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo Area
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.precision_manufacturing, color: AppColors.primary, size: 32),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('TERASIGHT', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    Text('NMDC FOG SAFE', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, letterSpacing: 1.2)),
                  ],
                ),
              ],
            ),
          ),

          // Menu Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                final item = _menuItems[index];
                final isSelected = _selectedIndex == index;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedIndex = index;
                      });
                      if (MediaQuery.of(context).size.width < 850) {
                        Navigator.pop(context); // Close drawer on mobile
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSelected ? AppColors.primary.withOpacity(0.5) : Colors.transparent),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item['icon'] as IconData,
                            color: isSelected ? AppColors.primary : AppColors.textMuted,
                            size: 20,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            item['title'] as String,
                            style: TextStyle(
                              color: isSelected ? AppColors.primary : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // User brief
          StreamBuilder<UserProfile?>(
            stream: FirebaseAuth.instance.currentUser != null 
                ? FirestoreService().streamUserProfile(FirebaseAuth.instance.currentUser!.uid)
                : const Stream.empty(),
            builder: (context, snapshot) {
              final profile = snapshot.data;
              final user = FirebaseAuth.instance.currentUser;
              final photoUrl = user?.photoURL;
              
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary,
                      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                      child: photoUrl == null ? const Icon(Icons.person, size: 20, color: Colors.white) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile?.fullName ?? user?.displayName ?? widget.simulatedRole ?? 'Loading...', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          Text(profile?.role ?? widget.simulatedRole ?? 'Role', style: const TextStyle(color: AppColors.statusSafe, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: AppColors.textSecondary, size: 20),
                      onPressed: () async {
                        if (!kIsWeb) {
                          try {
                            await GoogleSignIn().signOut();
                          } catch (_) {}
                        }
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                            (Route<dynamic> route) => false,
                          );
                        }
                      },
                    ),
                  ],
                ),
              );
            }
          ),
        ],
      ),
    );
  }
}
