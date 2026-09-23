import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../services/telemetry_service.dart';
import '../services/sensor_simulation_service.dart';
import '../services/safety_risk_engine.dart';
import '../models/hazard_report.dart';
import '../models/shift_log.dart';
import '../core/constants/app_colors.dart';
import '../widgets/glass_card.dart';
import 'mine_map_screen.dart';
import 'alerts_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String? simulatedRole;
  const DashboardScreen({super.key, this.simulatedRole});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  // Telemetry state
  double _mySpeed = 0.0;
  double _visibility = 30.0;
  double _recommendedSpeed = 30.0;
  bool _isCriticalFog = false;
  bool _hasShownCriticalAlert = false;

  final TelemetryService _telemetryService = TelemetryService();
  final SensorSimulationService _sensorService = SensorSimulationService();
  StreamSubscription? _telemetrySub;
  StreamSubscription? _sensorSub;

  bool _isSafeMode = false;
  bool _isEmergencyStop = false;

  // Shift state
  bool _isShiftActive = false;
  String? _activeShiftId;
  DateTime? _shiftStartTime;

  @override
  void initState() {
    super.initState();
    _telemetrySub = _telemetryService.telemetryStream.listen((data) {
      if (mounted) {
        setState(() {
          _mySpeed = data.speed;
          _updateSafetyEngine();
        });
      }
    });

    _sensorSub = _sensorService.getSensorData().listen((data) {
      if (mounted) {
        setState(() {
          _visibility = data.visibility;
          _updateSafetyEngine();
        });
      }
    });
  }

  void _updateSafetyEngine() {
    final risk = SafetyRiskEngine.calculateRisk(
      visibility: _visibility,
      speed: _mySpeed,
      roadFriction: 0.6,
      obstacleDistance: 100,
      rainfall: 0,
      vehicleLoad: 50,
      slope: 0,
      sensorConfidence: 90,
    );

    _recommendedSpeed = risk.recommendedSpeed;
    
    bool previouslyCritical = _isCriticalFog;
    _isCriticalFog = risk.riskLevel == 'CRITICAL' || risk.riskLevel == 'HIGH';

    if (_isCriticalFog && !_hasShownCriticalAlert) {
      _hasShownCriticalAlert = true;
      _showCriticalFogAlert();
    } else if (!_isCriticalFog && previouslyCritical) {
      _hasShownCriticalAlert = false;
    }
  }

  void _showCriticalFogAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.statusCritical, width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.statusCritical, size: 32),
            SizedBox(width: 8),
            Text('SEVERE FOG WARNING', style: TextStyle(color: AppColors.statusCritical, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Visibility has dropped to ${_visibility.toStringAsFixed(1)}m.', style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 12),
            const Text('Action Required:', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            const Text('• Reduce speed to below 15 km/h immediately.\n• Engage fog lights and hazard flashers.\n• Maintain 3x following distance.', style: TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.statusCritical),
            onPressed: () {
              Navigator.pop(context);
              _reduceSpeed(); // Automatically engage speed reduction
            },
            child: const Text('ENGAGE SAFE MODE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('DISMISS', style: TextStyle(color: AppColors.textSecondary)),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    _sensorSub?.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _reduceSpeed() {
    _telemetryService.setTargetSpeed(10.0);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Speed reduced to safe limit.')),
    );
  }

  void _toggleSafeMode() {
    setState(() {
      _isSafeMode = !_isSafeMode;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isSafeMode ? 'Safe Mode Activated' : 'Safe Mode Deactivated')),
    );
  }

  void _triggerEmergencyStop() {
    _telemetryService.triggerEmergencyStop();
    setState(() {
      _isEmergencyStop = true;
    });
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('EMERGENCY STOP INITIATED', style: TextStyle(color: AppColors.statusCritical)),
        content: const Text('Vehicle is stopping immediately.', style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _telemetryService.releaseEmergencyStop();
              _telemetryService.setTargetSpeed(30.0);
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

  Future<void> _toggleShift() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_isShiftActive && _activeShiftId != null) {
      // End Shift
      await FirestoreService().endShift(_activeShiftId!, {
        'endTime': DateTime.now(),
        'distanceCovered': 12050, // mock data
        'averageSpeed': 24.5, // mock data
      });
      setState(() {
        _isShiftActive = false;
        _activeShiftId = null;
        _shiftStartTime = null;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shift Ended Successfully')));
    } else {
      // Start Shift
      final shift = ShiftLog(
        id: '',
        driverId: user.uid,
        startTime: DateTime.now(),
      );
      final id = await FirestoreService().startShift(shift);
      setState(() {
        _isShiftActive = true;
        _activeShiftId = id;
        _shiftStartTime = DateTime.now();
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shift Started. Drive Safely!')));
    }
  }

  Future<void> _reportHazard() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Show dialog to select hazard type
    String? selectedType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Report Hazard', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.landslide, color: AppColors.statusCritical),
              title: const Text('Fallen Rocks', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'Fallen Rocks'),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off, color: AppColors.statusWarning),
              title: const Text('Zero Visibility Zone', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'Zero Visibility Zone'),
            ),
            ListTile(
              leading: const Icon(Icons.car_crash, color: AppColors.statusCritical),
              title: const Text('Vehicle Breakdown', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'Vehicle Breakdown'),
            ),
          ],
        ),
      ),
    );

    if (selectedType != null) {
      final hazard = HazardReport(
        id: '',
        reporterId: user.uid,
        type: selectedType,
        latitude: 18.0, // Mock coordinates
        longitude: 80.0,
        timestamp: DateTime.now(),
        isActive: true,
      );
      await FirestoreService().reportHazard(hazard);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$selectedType reported successfully!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _buildDriverDashboard(),
      const MineMapScreen(), // Map
      const AlertsScreen(),  // Alerts
      ProfileScreen(simulatedRole: widget.simulatedRole),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              backgroundImage: FirebaseAuth.instance.currentUser?.photoURL != null 
                  ? NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!) 
                  : null,
              child: FirebaseAuth.instance.currentUser?.photoURL == null 
                  ? const Icon(Icons.person, size: 16, color: Colors.white) 
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Driver Dashboard', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16)),
                Text(FirebaseAuth.instance.currentUser?.displayName ?? widget.simulatedRole ?? 'Operator', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {}, 
          )
        ],
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.surface,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.warning_amber_rounded), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildDriverDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Metrics
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  hasGlow: _isCriticalFog,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Visibility', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${_visibility.toInt()}', style: TextStyle(color: _isCriticalFog ? AppColors.statusCritical : AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          Text('m', style: TextStyle(color: _isCriticalFog ? AppColors.statusCritical : AppColors.textSecondary, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(_isCriticalFog ? 'CRITICAL' : 'SAFE', style: TextStyle(color: _isCriticalFog ? AppColors.statusCritical : AppColors.statusSafe, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Recommended\nSpeed', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.1)),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${_recommendedSpeed.toInt()}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          const Text('km/h', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('My Speed', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${_mySpeed.toInt()}', style: TextStyle(color: _mySpeed > _recommendedSpeed ? AppColors.statusCritical : AppColors.statusSafe, fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          const Text('km/h', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),

          // Shift Control Banner
          GestureDetector(
            onTap: _toggleShift,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isShiftActive 
                    ? [AppColors.statusSafe.withOpacity(0.8), AppColors.statusSafe.withOpacity(0.4)]
                    : [AppColors.primary.withOpacity(0.8), AppColors.primary.withOpacity(0.4)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _isShiftActive ? AppColors.statusSafe : AppColors.primary),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_isShiftActive ? 'SHIFT ACTIVE' : 'START SHIFT', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      if (_isShiftActive)
                        const Text('Logging telemetry data to cloud', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  Icon(_isShiftActive ? Icons.stop_circle_outlined : Icons.play_circle_fill, color: Colors.white, size: 32),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),

          // Critical Alert Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.statusCritical.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.statusCritical.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_rounded, color: AppColors.statusCritical, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('CRITICAL FOG DETECTED', style: TextStyle(color: AppColors.statusCritical, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text('Reduce speed and maintain safe distance.', style: TextStyle(color: AppColors.statusCritical, fontSize: 12)),
                    ],
                  ),
                )
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Vehicle Card
          const Text('My Vehicle', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('NMDC-101', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                    Container(
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
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Image.asset('lib/screens/assets/images/mine_truck.png', width: 120, height: 80, fit: BoxFit.cover, errorBuilder: (_,__,___) => const SizedBox(width: 120, height: 80)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildVehicleDetail(Icons.local_shipping, 'Dumper Type', 'HD785'),
                          const SizedBox(height: 8),
                          _buildVehicleDetail(Icons.scale, 'Load', '85%'),
                          const SizedBox(height: 8),
                          _buildVehicleDetail(Icons.local_gas_station, 'Fuel', '62%'),
                        ],
                      ),
                    )
                  ],
                )
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Quick Actions
          const Text('Quick Actions', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.speed,
                  label: 'Reduce Speed',
                  color: AppColors.statusWarning,
                  onTap: _reduceSpeed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.shield,
                  label: 'Safe Mode',
                  color: _isSafeMode ? AppColors.statusSafe : AppColors.textSecondary,
                  onTap: _toggleSafeMode,
                  isActive: _isSafeMode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.warning_amber_rounded,
                  label: 'Report Hazard',
                  color: AppColors.statusWarning,
                  onTap: _reportHazard,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.stop_circle,
                  label: 'Emergency',
                  color: AppColors.statusCritical,
                  onTap: _triggerEmergencyStop,
                  isActive: _isEmergencyStop,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleDetail(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textMuted, size: 16),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const Spacer(),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap, bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.2) : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? color : AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: isActive ? color : AppColors.textPrimary, fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}