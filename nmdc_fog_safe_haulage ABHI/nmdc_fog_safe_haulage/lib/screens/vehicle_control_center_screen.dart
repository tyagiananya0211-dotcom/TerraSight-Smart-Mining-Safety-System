import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../widgets/glass_card.dart';
import '../services/telemetry_service.dart';
import '../services/sensor_simulation_service.dart';

class VehicleControlCenterScreen extends StatefulWidget {
  final String vehicleId;
  const VehicleControlCenterScreen({super.key, required this.vehicleId});

  @override
  State<VehicleControlCenterScreen> createState() => _VehicleControlCenterScreenState();
}

class _VehicleControlCenterScreenState extends State<VehicleControlCenterScreen> {
  double _speed = 0.0;
  bool _isSafeMode = false;
  bool _isEmergencyStop = false;
  double _visibility = 100.0;

  @override
  void initState() {
    super.initState();
    // Listen to global telemetry to sync speed
    TelemetryService().telemetryStream.listen((data) {
      if (mounted) {
        setState(() {
          _speed = data.speed;
        });
      }
    });
    // Listen to global visibility
    SensorSimulationService().getSensorData().listen((data) {
      if (mounted) {
        setState(() {
          _visibility = data.visibility;
        });
      }
    });
  }

  void _reduceSpeed() {
    TelemetryService().setTargetSpeed(10.0);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Target speed reduced to 10 km/h globally.')),
    );
  }

  void _toggleSafeMode() {
    setState(() {
      _isSafeMode = !_isSafeMode;
    });
    if (_isSafeMode) {
      TelemetryService().setTargetSpeed(15.0);
    } else {
      TelemetryService().setTargetSpeed(30.0);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isSafeMode ? 'Safe Mode Activated (Max 15 km/h)' : 'Safe Mode Deactivated')),
    );
  }

  void _triggerEmergencyStop() {
    TelemetryService().triggerEmergencyStop();
    setState(() {
      _isEmergencyStop = true;
    });
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('EMERGENCY STOP', style: TextStyle(color: AppColors.statusCritical)),
        content: Text('${widget.vehicleId} is stopping immediately.', style: const TextStyle(color: AppColors.textPrimary)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              TelemetryService().releaseEmergencyStop();
              setState(() {
                _isEmergencyStop = false;
              });
            },
            child: const Text('DISMISS'),
          )
        ],
      ),
    );
  }

  void _voiceCommand() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Voice command listening (Simulation)')),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.vehicleId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary)),
            const Text('HD785', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.statusSafe.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.statusSafe),
              ),
              child: Row(
                children: const [
                  Icon(Icons.check_circle, color: AppColors.statusSafe, size: 12),
                  SizedBox(width: 4),
                  Text('Active', style: TextStyle(color: AppColors.statusSafe, fontSize: 12)),
                ],
              ),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Vehicle Image Placeholder
            Container(
              height: 180,
              decoration: BoxDecoration(
                image: const DecorationImage(
                  image: AssetImage('lib/screens/assets/images/mine_truck.png'),
                  fit: BoxFit.cover,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Metrics Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMetric('Speed', '${_speed.toStringAsFixed(0)}', 'km/h', color: _speed > 25 ? AppColors.statusCritical : AppColors.textPrimary),
                _buildMetric('Visibility', '${_visibility.toStringAsFixed(0)}', 'm', color: _visibility < 15 ? AppColors.statusCritical : AppColors.statusWarning),
                _buildMetric('Load', '85', '%'),
                _buildMetric('Fuel', '62', '%'),
              ],
            ),
            
            const SizedBox(height: 32),
            
            const Text('Control Actions', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 12),
            
            // Action Buttons
            _buildLargeActionCard(
              title: 'Reduce Speed',
              subtitle: 'Set recommended speed',
              icon: Icons.speed,
              color: AppColors.statusWarning,
              onTap: _reduceSpeed,
            ),
            const SizedBox(height: 12),
            _buildLargeActionCard(
              title: 'Safe Mode',
              subtitle: 'Limit speed & optimize safety',
              icon: Icons.shield,
              color: _isSafeMode ? AppColors.statusSafe : AppColors.textPrimary,
              onTap: _toggleSafeMode,
              isActive: _isSafeMode,
            ),
            const SizedBox(height: 12),
            _buildLargeActionCard(
              title: 'Emergency Stop',
              subtitle: 'Immediately stop vehicle',
              icon: Icons.stop_circle,
              color: AppColors.statusCritical,
              onTap: _triggerEmergencyStop,
              isActive: _isEmergencyStop,
            ),
            
            const SizedBox(height: 16),
            
            // Voice Command Button
            GestureDetector(
              onTap: _voiceCommand,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.mic, color: AppColors.textPrimary),
                    SizedBox(width: 8),
                    Text('Send Voice Command', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, String unit, {Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: TextStyle(color: color ?? AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(width: 2),
            Text(unit, style: TextStyle(color: color ?? AppColors.textSecondary, fontSize: 12)),
          ],
        )
      ],
    );
  }

  Widget _buildLargeActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.15) : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? color : AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: isActive ? color : AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            )
          ],
        ),
      ),
    );
  }
}
