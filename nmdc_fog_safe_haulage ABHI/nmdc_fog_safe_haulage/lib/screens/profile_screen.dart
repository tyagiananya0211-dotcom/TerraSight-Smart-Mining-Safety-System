import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/constants/app_colors.dart';
import '../widgets/glass_card.dart';
import '../services/firestore_service.dart';
import '../models/user_profile.dart';
import 'role_selection_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';

class ProfileScreen extends StatefulWidget {
  final String? simulatedRole;
  const ProfileScreen({super.key, this.simulatedRole});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
    });
    try {
      if (!kIsWeb) {
        try {
          await GoogleSignIn().signOut();
        } catch (_) {}
      }
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        // AuthGate will automatically redirect, but in case it's nested deep:
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _updateRole(String newRole) async {
    if (currentUser == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      await FirestoreService().updateUserProfile(currentUser!.uid, {'role': newRole});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Role updated to $newRole! UI will refresh.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update role: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null && widget.simulatedRole == null) {
      return const Center(child: Text('Not logged in', style: TextStyle(color: Colors.white)));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ),
      body: StreamBuilder<UserProfile?>(
        stream: currentUser != null ? FirestoreService().streamUserProfile(currentUser!.uid) : Stream.value(null),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasError && currentUser != null) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          UserProfile? profile = snapshot.data;
          
          // If Firestore fails (timeout or missing doc), or it's a simulated user, provide a fallback
          if (profile == null) {
            profile = UserProfile(
              uid: currentUser?.uid ?? 'simulated',
              fullName: currentUser?.displayName ?? (widget.simulatedRole != null ? 'Simulated ${widget.simulatedRole}' : 'Offline User'),
              email: currentUser?.email ?? 'user@example.com',
              role: widget.simulatedRole ?? 'Driver',
              employeeId: 'SIM-001',
              status: 'approved',
              approved: true,
              createdAt: DateTime.now(),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Avatar and Basic Info
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primary,
                        backgroundImage: currentUser?.photoURL != null ? NetworkImage(currentUser!.photoURL!) : null,
                        child: currentUser?.photoURL == null ? const Icon(Icons.person, size: 40, color: Colors.white) : null,
                      ),
                      const SizedBox(height: 16),
                      Text(profile!.fullName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(profile!.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: Text(profile!.role.toUpperCase(), style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Details List
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildDetailRow(Icons.badge, 'Employee ID', profile!.employeeId),
                      const Divider(color: AppColors.card, height: 24),
                      _buildDetailRow(Icons.verified_user, 'Status', profile!.status.toUpperCase()),
                      const Divider(color: AppColors.card, height: 24),
                      _buildDetailRow(Icons.calendar_today, 'Joined', profile!.createdAt != null ? '${profile!.createdAt!.day}/${profile!.createdAt!.month}/${profile!.createdAt!.year}' : 'N/A'),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Demo Role Switcher
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  hasGlow: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.developer_mode, color: AppColors.statusWarning, size: 20),
                          SizedBox(width: 8),
                          Text('Demo Options', style: TextStyle(color: AppColors.statusWarning, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Simulate switching accounts by changing your role below. The app will instantly re-route you.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: profile!.role,
                            isExpanded: true,
                            dropdownColor: AppColors.background,
                            iconEnabledColor: Colors.white,
                            style: const TextStyle(color: Colors.white),
                            items: const [
                              DropdownMenuItem(value: 'Driver', child: Text('Driver Dashboard')),
                              DropdownMenuItem(value: 'Operator', child: Text('Operator Dashboard')),
                              DropdownMenuItem(value: 'Admin', child: Text('Admin Dashboard')),
                              DropdownMenuItem(value: 'Safety Officer', child: Text('Safety Officer Dashboard')),
                            ],
                            onChanged: _isLoading ? null : (value) {
                              if (value != null && value != profile!.role) {
                                _updateRole(value);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Logout Button
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _logout,
                  icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.logout, color: Colors.white),
                  label: const Text('LOGOUT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.statusCritical,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                
                const SizedBox(height: 24),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textMuted, size: 20),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        const Spacer(),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
