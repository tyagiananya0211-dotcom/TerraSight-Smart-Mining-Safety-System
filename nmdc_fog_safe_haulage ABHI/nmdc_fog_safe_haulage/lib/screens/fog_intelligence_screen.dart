import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../widgets/glass_card.dart';
import '../services/sensor_simulation_service.dart';

class FogIntelligenceScreen extends StatefulWidget {
  const FogIntelligenceScreen({super.key});

  @override
  State<FogIntelligenceScreen> createState() => _FogIntelligenceScreenState();
}

class _FogIntelligenceScreenState extends State<FogIntelligenceScreen> {
  double _visibility = 100.0;
  StreamSubscription? _sensorSub;

  @override
  void initState() {
    super.initState();
    _sensorSub = SensorSimulationService().getSensorData().listen((data) {
      if (mounted) setState(() => _visibility = data.visibility);
    });
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isFoggy = _visibility < 40;
    final now = DateTime.now();
    String currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Fog Intelligence', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Fog Detected Critical Alert
            if (isFoggy)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.statusCritical.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.statusCritical, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.statusCritical.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    )
                  ]
                ),
                child: Column(
                  children: [
                    const Icon(Icons.warning_rounded, color: AppColors.statusCritical, size: 48),
                    const SizedBox(height: 12),
                    const Text('FOG DETECTED', style: TextStyle(color: AppColors.statusCritical, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    const SizedBox(height: 16),
                    _buildAlertDetailRow('By', 'NMDC-101'),
                    _buildAlertDetailRow('Visibility', '${_visibility.toStringAsFixed(0)} m'),
                    _buildAlertDetailRow('Location', 'Route B (Simulated)'),
                    _buildAlertDetailRow('Time', currentTime),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.statusSafe.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.statusSafe, width: 1.5),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.statusSafe, size: 48),
                    const SizedBox(height: 12),
                    const Text('ALL CLEAR', style: TextStyle(color: AppColors.statusSafe, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    const SizedBox(height: 16),
                    _buildAlertDetailRow('Visibility', '${_visibility.toStringAsFixed(0)} m (Good)'),
                    _buildAlertDetailRow('Network', 'Cooperative Link Active'),
                  ],
                ),
              ),
            
            const SizedBox(height: 32),
            
            const Text('Alert Sent To Nearby Vehicles', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 12),
            
            // Nearby Vehicles List
            _buildNearbyVehicleRow('NMDC-102', '320 m', AppColors.statusSafe, 'Alerted'),
            _buildNearbyVehicleRow('NMDC-103', '450 m', AppColors.statusSafe, 'Alerted'),
            _buildNearbyVehicleRow('NMDC-104', '610 m', AppColors.statusWarning, 'Pending'),
            _buildNearbyVehicleRow('NMDC-105', '780 m', AppColors.textMuted, 'Offline'),

            const SizedBox(height: 32),
            
            // Cooperative Network Status
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.hub, color: AppColors.primary, size: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Cooperative Network', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        SizedBox(height: 4),
                        Text('12', style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
                        Text('Vehicles Connected', style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.statusSafe.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.statusSafe),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.wifi, color: AppColors.statusSafe, size: 14),
                        SizedBox(width: 6),
                        Text('Online', style: TextStyle(color: AppColors.statusSafe, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAlertDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$label: ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildNearbyVehicleRow(String id, String distance, Color statusColor, String statusText) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Text(id, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
          const Spacer(),
          Text(distance, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(width: 16),
          Row(
            children: [
              Icon(Icons.circle, color: statusColor, size: 8),
              const SizedBox(width: 6),
              SizedBox(
                width: 50,
                child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 12)),
              )
            ],
          )
        ],
      ),
    );
  }
}
