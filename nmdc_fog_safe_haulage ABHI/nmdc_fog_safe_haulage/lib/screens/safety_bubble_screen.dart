import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../widgets/glass_card.dart';
import 'dart:math' as math;
import '../services/telemetry_service.dart';
import '../services/sensor_simulation_service.dart';
import '../services/safety_risk_engine.dart';

class SafetyBubbleScreen extends StatefulWidget {
  const SafetyBubbleScreen({super.key});

  @override
  State<SafetyBubbleScreen> createState() => _SafetyBubbleScreenState();
}

class _SafetyBubbleScreenState extends State<SafetyBubbleScreen> {
  double _speed = 0.0;
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
      if (mounted) setState(() => _visibility = data.visibility);
    });
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    _sensorSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic calculations based on speed and visibility
    final risk = SafetyRiskEngine.calculateRisk(
      visibility: _visibility,
      speed: _speed,
      roadFriction: 0.6,
      obstacleDistance: 100,
      rainfall: 0,
      vehicleLoad: 50,
      slope: 0,
      sensorConfidence: 90,
    );

    double stopDist = risk.stoppingDistance;
    double cautionDist = risk.requiredSafeDistance;
    double safeDist = cautionDist * 1.5;

    // Visual scaling constraints
    double maxVisualSize = 300.0;
    double stopVisual = (stopDist / safeDist) * maxVisualSize;
    double cautionVisual = (cautionDist / safeDist) * maxVisualSize;
    
    stopVisual = stopVisual.clamp(80.0, 200.0);
    cautionVisual = cautionVisual.clamp(140.0, 250.0);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('360° Safety Bubble', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Dynamic Proximity Zones',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 40),
            
            // Bubble Visualization
            SizedBox(
              height: 350,
              width: 350,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Safe Zone (Green)
                  _buildZoneCircle(maxVisualSize, AppColors.statusSafe.withOpacity(0.1), AppColors.statusSafe.withOpacity(0.3)),
                  
                  // Warning Zone (Yellow)
                  _buildZoneCircle(cautionVisual, AppColors.statusWarning.withOpacity(0.15), AppColors.statusWarning.withOpacity(0.5)),
                  
                  // Stop Zone (Red)
                  _buildZoneCircle(stopVisual, AppColors.statusCritical.withOpacity(0.2), AppColors.statusCritical),
                  
                  // Vehicle in center
                  Transform.rotate(
                    angle: -math.pi / 2, // point up
                    child: const Icon(Icons.local_shipping, size: 48, color: AppColors.textPrimary),
                  ),

                  // Labels
                  const Positioned(
                    top: 20,
                    child: Text('Safe Zone', style: TextStyle(color: AppColors.statusSafe, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  Positioned(
                    top: (350 - cautionVisual) / 2 + 10,
                    child: Text('Caution (${cautionDist.toStringAsFixed(0)}m)', style: const TextStyle(color: AppColors.statusWarning, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  Positioned(
                    top: (350 - stopVisual) / 2 + 10,
                    child: Text('Stop Distance (${stopDist.toStringAsFixed(0)}m)', style: const TextStyle(color: AppColors.statusCritical, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Dynamic Status
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.statusInfo, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Dynamic Bubble Active', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Zones calculating dynamically based on speed (${_speed.toStringAsFixed(0)} km/h) and visibility (${_visibility.toStringAsFixed(0)}m).', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Metrics
            Row(
              children: [
                Expanded(child: _buildMetricCard('Front', '${stopDist.toStringAsFixed(1)}m', AppColors.statusCritical)),
                const SizedBox(width: 12),
                Expanded(child: _buildMetricCard('Sides', '4.0m', AppColors.statusWarning)),
                const SizedBox(width: 12),
                Expanded(child: _buildMetricCard('Rear', '12.0m', AppColors.statusWarning)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildZoneCircle(double size, Color fillColor, Color borderColor) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fillColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
