import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../widgets/glass_card.dart';
import 'vehicle_control_center_screen.dart';
import '../services/telemetry_service.dart';
import 'mine_map_screen.dart';

class FleetScreen extends StatefulWidget {
  const FleetScreen({super.key});

  @override
  State<FleetScreen> createState() => _FleetScreenState();
}

class _FleetScreenState extends State<FleetScreen> {
  double _currentSpeed = 0.0;

  @override
  void initState() {
    super.initState();
    TelemetryService().telemetryStream.listen((data) {
      if (mounted) {
        setState(() {
          _currentSpeed = data.speed;
        });
      }
    });
  }

  List<Map<String, dynamic>> get recentVehicles => [
    {
      'id': 'NMDC-101',
      'distance': '3 m',
      'speed': '${_currentSpeed.toStringAsFixed(0)} km/h',
      'status': _currentSpeed > 25 ? 'Critical' : 'Normal',
      'color': _currentSpeed > 25 ? AppColors.statusCritical : AppColors.statusSafe,
    },
    {
      'id': 'NMDC-102',
      'distance': '15 m',
      'speed': '18 km/h',
      'status': 'Caution',
      'color': AppColors.statusWarning,
    },
    {
      'id': 'NMDC-103',
      'distance': '35 m',
      'speed': '25 km/h',
      'status': 'Normal',
      'color': AppColors.statusSafe,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Fleet Overview',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert, color: AppColors.textPrimary), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Summary Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 3.5, // Reduced height for top cards
              children: [
                _buildSummaryCard('Active Dumpers', '24', AppColors.statusInfo, Icons.local_shipping),
                _buildSummaryCard('Critical Alerts', '07', AppColors.statusCritical, Icons.warning_rounded, isHighPriority: true),
                _buildSummaryCard('Normal Ops', '17', AppColors.statusSafe, Icons.check_circle_outline),
                _buildSummaryCard('Under Maintenance', '04', AppColors.textMuted, Icons.build_circle_outlined),
              ],
            ),
            
            const SizedBox(height: 24),

            // Embedded Map
            const Text('Live Fleet Locations', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              height: 400,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: const MineMapScreen(isEmbedded: true),
            ),

            const SizedBox(height: 24),

            // Fleet Status Section
            const Text('Fleet Status', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Placeholder for a pie chart, using a simple circle for now
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border, width: 8),
                    ),
                    child: Center(
                      child: Text('24\nTotal', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                    ),
                  ),
                  
                  // Status Legend
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusLegendRow('Critical', '7', AppColors.statusCritical),
                      const SizedBox(height: 8),
                      _buildStatusLegendRow('Caution', '6', AppColors.statusWarning),
                      const SizedBox(height: 8),
                      _buildStatusLegendRow('Normal', '17', AppColors.statusSafe),
                      const SizedBox(height: 8),
                      _buildStatusLegendRow('Maintenance', '4', AppColors.textMuted),
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Recent Vehicles
            const Text('Recent Vehicles', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 8),
            
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentVehicles.length,
              itemBuilder: (context, index) {
                final vehicle = recentVehicles[index];
                return GestureDetector(
                  onTap: () {
                     Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => VehicleControlCenterScreen(vehicleId: vehicle['id'])),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(vehicle['id'], style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(vehicle['distance'], style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        Text(vehicle['speed'], style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: vehicle['color'].withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: vehicle['color']),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.circle, color: vehicle['color'], size: 8),
                              const SizedBox(width: 4),
                              Text(vehicle['status'], style: TextStyle(color: vehicle['color'], fontSize: 10)),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color, IconData icon, {bool isHighPriority = false}) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
              if (isHighPriority)
                const Text('High Priority', style: TextStyle(color: AppColors.statusCritical, fontSize: 8)),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
              const Spacer(),
              Icon(icon, color: color.withOpacity(0.5), size: 20),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatusLegendRow(String label, String value, Color color) {
    return Row(
      children: [
        Icon(Icons.circle, color: color, size: 8),
        const SizedBox(width: 8),
        SizedBox(width: 80, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}