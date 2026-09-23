import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_colors.dart';
import '../widgets/glass_card.dart';
import '../services/sensor_simulation_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final TextEditingController _ipController = TextEditingController();

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _showHardwareConnectDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Connect ESP32 Hardware', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter ESP32 IP Address:', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              TextField(
                controller: _ipController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. 192.168.1.5',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                final ip = _ipController.text.trim();
                if (ip.isNotEmpty) {
                  SensorSimulationService().connectToHardware(ip);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Connecting to Hardware at $ip...')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('CONNECT'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showGlobalSettingsDialog() async {
    double tempSpeedLimit = 15.0; // Default or fetch from firestore

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.card,
              title: const Text('Global Safety Parameters', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Convoy Speed Limit (km/h)', style: TextStyle(color: AppColors.textSecondary)),
                  Slider(
                    value: tempSpeedLimit,
                    min: 5,
                    max: 40,
                    divisions: 35,
                    label: tempSpeedLimit.round().toString(),
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setStateDialog(() {
                        tempSpeedLimit = val;
                      });
                    },
                  ),
                  Center(child: Text('${tempSpeedLimit.round()} km/h', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL', style: TextStyle(color: AppColors.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Update global settings in Firestore (mock global settings document)
                    await FirebaseFirestore.instance.collection('settings').doc('global').set({
                      'convoySpeedLimit': tempSpeedLimit,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Global Safety Parameters Updated!')));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('APPLY FLEET-WIDE'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Admin & Configuration', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('System Management', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            const SizedBox(height: 12),
            
            _buildAdminMenu(Icons.people, 'User Management', 'Approve/Reject pending accounts'),
            const SizedBox(height: 12),
            _buildAdminMenu(
              Icons.settings, 
              'Global Safety Parameters', 
              'Configure max speeds & buffer distances',
              onTap: _showGlobalSettingsDialog,
            ),
            const SizedBox(height: 12),
            _buildAdminMenu(
              Icons.api, 
              'Sensor API Configuration', 
              'Manage external sensor connections',
              onTap: _showHardwareConnectDialog,
            ),
            const SizedBox(height: 12),
            _buildAdminMenu(Icons.shield, 'Security & Audit Logs', 'View access logs and critical overrides'),
            
            const SizedBox(height: 32),
            
            const Text('Quick Actions', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      SensorSimulationService().triggerFog();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Simulating Dense Fog globally...')));
                    },
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: const [
                          Icon(Icons.cloud, color: AppColors.statusWarning, size: 28),
                          SizedBox(height: 8),
                          Text('Simulate Fog', style: TextStyle(color: AppColors.statusWarning, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      SensorSimulationService().clearFog();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clearing Weather globally...')));
                    },
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: const [
                          Icon(Icons.wb_sunny, color: AppColors.statusSafe, size: 28),
                          SizedBox(height: 8),
                          Text('Clear Weather', style: TextStyle(color: AppColors.statusSafe, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAdminMenu(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

