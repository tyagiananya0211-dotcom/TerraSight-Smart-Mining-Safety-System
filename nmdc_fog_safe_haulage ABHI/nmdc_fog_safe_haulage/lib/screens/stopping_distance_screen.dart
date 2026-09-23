import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../widgets/glass_card.dart';
import '../services/safety_risk_engine.dart';
import '../services/telemetry_service.dart';
import '../services/sensor_simulation_service.dart';

class StoppingDistanceScreen extends StatefulWidget {
  const StoppingDistanceScreen({super.key});

  @override
  State<StoppingDistanceScreen> createState() => _StoppingDistanceScreenState();
}

class _StoppingDistanceScreenState extends State<StoppingDistanceScreen> {
  double _speed = 0.0;
  double _load = 85.0; // Simulated constant
  double _friction = 0.6;
  double _visibility = 100.0;
  
  StreamSubscription? _telemetrySub;
  StreamSubscription? _sensorSub;

  @override
  void initState() {
    super.initState();
    _telemetrySub = TelemetryService().telemetryStream.listen((data) {
      if (mounted) setState(() => _speed = data.speed);
    });
    _sensorSub = SensorSimulationService().getSensorData().listen((data) {
      if (mounted) {
        setState(() {
          _visibility = data.visibility;
          _friction = data.roadFriction;
        });
      }
    });
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    _sensorSub?.cancel();
    super.dispose();
  }

  RiskOutput _calculateDistance() {
    return SafetyRiskEngine.calculateRisk(
      visibility: _visibility,
      speed: _speed,
      roadFriction: _friction,
      obstacleDistance: 50.0,
      rainfall: 0.0,
      vehicleLoad: _load,
      slope: 0.0,
      sensorConfidence: 90.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _calculateDistance();
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Dynamic Stopping Distance', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Calculated Results
            Row(
              children: [
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('Calculated Stop Dist', style: TextStyle(color: AppColors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text('${result.stoppingDistance.toStringAsFixed(1)} m', style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
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
                        const Text('Required Safe Dist', style: TextStyle(color: AppColors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text('${result.requiredSafeDistance.toStringAsFixed(1)} m', style: const TextStyle(color: AppColors.statusCritical, fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            const Text('Live Variables', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            const SizedBox(height: 12),
            
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildMetricRow('Speed', '${_speed.toStringAsFixed(0)} km/h'),
                  _buildMetricRow('Road Friction', '${(_friction * 100).toStringAsFixed(0)}%'),
                  _buildMetricRow('Load', '${_load.toStringAsFixed(0)}%'),
                  _buildMetricRow('Visibility', '${_visibility.toStringAsFixed(0)} m'),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Visualization
            const Text('Distance Visualization', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Road
                  Container(
                    width: double.infinity,
                    height: 4,
                    color: AppColors.border,
                  ),
                  // Vehicle
                  const Icon(Icons.local_shipping, color: AppColors.textPrimary, size: 24),
                  
                  // Stopping distance indicator
                  Positioned(
                    left: 24,
                    child: Container(
                      width: result.stoppingDistance * 2.5, // visual scaling
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.statusWarning,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  
                  // Required Safe distance indicator
                  Positioned(
                    left: 24,
                    child: Container(
                      width: result.requiredSafeDistance * 2.5,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.statusCritical.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
