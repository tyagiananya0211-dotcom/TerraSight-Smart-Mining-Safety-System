import 'package:flutter/material.dart';
import 'dart:async';
import '../core/constants/app_colors.dart';
import '../widgets/glass_card.dart';

class EmergencySOSScreen extends StatefulWidget {
  const EmergencySOSScreen({super.key});

  @override
  State<EmergencySOSScreen> createState() => _EmergencySOSScreenState();
}

class _EmergencySOSScreenState extends State<EmergencySOSScreen> with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  bool _isActivated = false;
  double _progress = 0.0;
  Timer? _timer;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(_pulseController);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerEvent details) {
    if (_isActivated) return;
    
    setState(() {
      _isPressed = true;
    });
    
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      setState(() {
        _progress += 0.01;
        if (_progress >= 1.0) {
          _progress = 1.0;
          _isActivated = true;
          _isPressed = false;
          timer.cancel();
          _triggerEmergency();
        }
      });
    });
  }

  void _onPointerUp(PointerEvent details) {
    if (_isActivated) return;
    
    _timer?.cancel();
    setState(() {
      _isPressed = false;
      _progress = 0.0;
    });
  }

  void _triggerEmergency() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('EMERGENCY SIGNAL SENT TO CONTROL ROOM'),
        backgroundColor: AppColors.statusCritical,
        duration: Duration(seconds: 5),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isActivated ? AppColors.statusCritical.withOpacity(0.2) : AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('EMERGENCY SOS', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.statusCritical)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text(
              'Select emergency type (Optional)',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 24),
            
            // Grid of options
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.5,
              children: [
                _buildEmergencyType(Icons.medical_services, 'Medical'),
                _buildEmergencyType(Icons.build, 'Breakdown'),
                _buildEmergencyType(Icons.local_fire_department, 'Fire'),
                _buildEmergencyType(Icons.car_crash, 'Collision'),
              ],
            ),
            
            const SizedBox(height: 60),
            
            // SOS Button
            Listener(
              onPointerDown: _onPointerDown,
              onPointerUp: _onPointerUp,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isActivated ? 1.0 : (_isPressed ? 0.95 : _pulseAnimation.value),
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isActivated ? AppColors.statusCritical : AppColors.background,
                        border: Border.all(
                          color: AppColors.statusCritical,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.statusCritical.withOpacity(_isActivated ? 0.8 : 0.3),
                            blurRadius: 30,
                            spreadRadius: 10,
                          )
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_isPressed && !_isActivated)
                            CircularProgressIndicator(
                              value: _progress,
                              color: AppColors.statusCritical,
                              strokeWidth: 8,
                            ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.warning_rounded,
                                color: _isActivated ? Colors.white : AppColors.statusCritical,
                                size: 48,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isActivated ? 'ACTIVATED' : 'SOS',
                                style: TextStyle(
                                  color: _isActivated ? Colors.white : AppColors.statusCritical,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 40),
            
            Text(
              _isActivated ? 'Help is on the way. Remain calm.' : 'Hold for 3 seconds to activate.',
              style: TextStyle(
                color: _isActivated ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 16,
                fontWeight: _isActivated ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            
            const SizedBox(height: 40),
            
            if (_isActivated)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isActivated = false;
                      _progress = 0.0;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.textSecondary),
                  ),
                  child: const Text('CANCEL FALSE ALARM'),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyType(IconData icon, String label) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        ],
      ),
    );
  }
}
