import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../widgets/glass_card.dart';
import '../services/analytics_service.dart';
import '../services/telemetry_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  FleetAnalytics? _analytics;
  bool _isLoading = true;
  StreamSubscription? _telemetrySub;
  double _dynamicAverageSpeed = 18.5;
  int _incidentsPrevented = 14;

  @override
  void initState() {
    super.initState();
    _loadData();
    _telemetrySub = TelemetryService().telemetryStream.listen((data) {
      if (mounted) {
        setState(() {
          // Average speed across the fleet (simulated by taking individual telemetry + a small random offset)
          _dynamicAverageSpeed = data.speed > 0 ? data.speed - 2.5 : 0.0;
          if (_dynamicAverageSpeed < 0) _dynamicAverageSpeed = 0;
          
          if (data.isEmergency) {
            _incidentsPrevented = 15; // Dynamically increment incident on emergency
          }
        });
      }
    });
  }

  Future<void> _loadData() async {
    final data = await _analyticsService.getDailyAnalytics();
    if (mounted) {
      setState(() {
        _analytics = data;
        _isLoading = false;
        _dynamicAverageSpeed = data.averageSpeed;
        _incidentsPrevented = data.totalIncidentsPrevented;
      });
    }
  }

  @override
  void dispose() {
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
        title: const Text('AI Safety Analytics', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.calendar_month_outlined, color: AppColors.textPrimary)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSafetyScore(),
                  const SizedBox(height: 24),
                  
                  const Text('Operational Overview', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(child: _metricCard('Incidents Prevented', '$_incidentsPrevented', Icons.shield, AppColors.statusSafe)),
                      const SizedBox(width: 16),
                      Expanded(child: _metricCard('Active Vehicles', '${_analytics!.activeVehicles}', Icons.local_shipping, AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _metricCard('Avg Speed', '${_dynamicAverageSpeed.toStringAsFixed(1)} km/h', Icons.speed, AppColors.statusWarning)),
                      const SizedBox(width: 16),
                      Expanded(child: _metricCard('Network Uptime', '${_analytics!.networkUptime}%', Icons.wifi, AppColors.statusInfo)),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  const Text('Visibility Trend (Last 24h)', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                  const SizedBox(height: 12),
                  _buildTrendCard(),
                  
                  const SizedBox(height: 32),
                  
                  const Text('AI Recommendations', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                  const SizedBox(height: 12),
                  
                  _recommendation(Icons.speed, 'Reduce dumper speed to below 15 km/h in Hill Top Road.'),
                  const SizedBox(height: 12),
                  _recommendation(Icons.alt_route, 'Redirect vehicles from Sector-2A to the alternate route.'),
                ],
              ),
            ),
    );
  }

  Widget _buildSafetyScore() {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      hasGlow: true,
      child: Column(
        children: [
          const Text('SYSTEM SAFETY SCORE', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 24),
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: 0.88,
                    strokeWidth: 12,
                    backgroundColor: AppColors.border,
                    color: AppColors.statusSafe,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('88', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.statusSafe, height: 1.0)),
                    Text('/ 100', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('GOOD', style: TextStyle(color: AppColors.statusSafe, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          const Text('System operating safely. Minor fog risks detected.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTrendCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: CustomPaint(
          painter: TrendPainter(),
        ),
      ),
    );
  }

  Widget _recommendation(IconData icon, String text) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12))),
        ],
      ),
    );
  }
}

class TrendPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.border.withOpacity(0.4)
      ..strokeWidth = 1;

    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (double i = 0; i <= size.height; i += 35) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    final path = Path();
    path.moveTo(0, size.height * 0.2);
    path.cubicTo(size.width * 0.3, size.height * 0.4, size.width * 0.6, size.height * 0.8, size.width, size.height * 0.7);

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}