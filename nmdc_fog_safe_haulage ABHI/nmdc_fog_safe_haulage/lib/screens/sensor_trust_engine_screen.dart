import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../widgets/glass_card.dart';
import '../services/sensor_simulation_service.dart';
import '../services/telemetry_service.dart';
import '../models/sensor_data.dart';

class SensorTrustEngineScreen extends StatefulWidget {
  const SensorTrustEngineScreen({super.key});

  @override
  State<SensorTrustEngineScreen> createState() => _SensorTrustEngineScreenState();
}

class _SensorTrustEngineScreenState extends State<SensorTrustEngineScreen> {
  final SensorSimulationService _sensorService = SensorSimulationService();
  StreamSubscription? _sensorSub;
  StreamSubscription? _telemetrySub;

  double _cameraConfidence = 85.0;
  double _radarConfidence = 95.0;
  double _lidarConfidence = 90.0;
  double _safeSpeed = 30.0;
  double _stopDistance = 15.0;

  @override
  void initState() {
    super.initState();
    _sensorSub = _sensorService.getSensorData().listen((data) {
      if (mounted) {
        setState(() {
          // Camera fails in fog/rain
          _cameraConfidence = (data.visibility > 50) ? 95.0 : (data.visibility > 20 ? 60.0 : 35.0);
          if (data.rainfall > 30) _cameraConfidence -= 20;

          // LiDAR is okay in rain but bad in dense fog
          _lidarConfidence = (data.visibility > 30) ? 90.0 : 45.0;

          // Radar is mostly immune to weather
          _radarConfidence = 92.0;

          _cameraConfidence = _cameraConfidence.clamp(0.0, 100.0);
          _lidarConfidence = _lidarConfidence.clamp(0.0, 100.0);
        });
      }
    });

    _telemetrySub = TelemetryService().telemetryStream.listen((data) {
      if (mounted) {
        setState(() {
          _safeSpeed = data.speed > 0 ? data.speed : 0.0;
          _stopDistance = (data.speed / 10) * (data.speed / 10) + (data.speed * 0.278 * 1.5); // Mock stopping distance
        });
      }
    });
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    _telemetrySub?.cancel();
    super.dispose();
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
        title: const Text('Sensor Trust Engine', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Sensor Array Status', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 12),
            
            _buildSensorCard(
              name: 'Radar (mmWave)',
              status: _radarConfidence > 80 ? 'OK' : 'Degraded',
              confidence: _radarConfidence.toInt(),
              statusColor: _radarConfidence > 80 ? AppColors.statusSafe : AppColors.statusWarning,
              note: 'Penetrating fog successfully.',
              icon: Icons.radar,
            ),
            const SizedBox(height: 12),
            
            _buildSensorCard(
              name: 'LiDAR',
              status: _lidarConfidence > 80 ? 'OK' : 'Degraded',
              confidence: _lidarConfidence.toInt(),
              statusColor: _lidarConfidence > 80 ? AppColors.statusSafe : AppColors.statusWarning,
              note: _lidarConfidence < 50 ? 'Heavy fog interference detected.' : 'Clear path.',
              icon: Icons.lightbulb_outline,
            ),
            const SizedBox(height: 12),
            
            _buildSensorCard(
              name: 'Thermal Camera',
              status: _cameraConfidence > 80 ? 'Active' : 'Degraded',
              confidence: _cameraConfidence.toInt(),
              statusColor: _cameraConfidence > 80 ? AppColors.statusSafe : (_cameraConfidence > 50 ? AppColors.statusWarning : AppColors.statusCritical),
              note: _cameraConfidence < 40 ? 'Severe visibility loss.' : 'Clear heat signatures.',
              icon: Icons.thermostat,
            ),
            
            const SizedBox(height: 32),
            
            const Text('Dynamic Safety Profile', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('Safe Speed', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        const SizedBox(height: 8),
                        Text('${_safeSpeed.toStringAsFixed(0)} km/h', style: const TextStyle(color: AppColors.statusSafe, fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text('Stop Distance', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        SizedBox(height: 8),
                        Text('${_stopDistance.toStringAsFixed(0)} m', style: TextStyle(color: AppColors.statusWarning, fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorCard({
    required String name,
    required String status,
    required int confidence,
    required Color statusColor,
    required String note,
    required IconData icon,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.textSecondary, size: 24),
              const SizedBox(width: 12),
              Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor),
                ),
                child: Text(status, style: TextStyle(color: statusColor, fontSize: 12)),
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Confidence Level', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              Text('$confidence%', style: TextStyle(color: statusColor, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: confidence / 100,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 12),
          Text(note, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}
