import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../widgets/glass_card.dart';

class ConvoyModeScreen extends StatefulWidget {
  const ConvoyModeScreen({super.key});

  @override
  State<ConvoyModeScreen> createState() => _ConvoyModeScreenState();
}

class _ConvoyModeScreenState extends State<ConvoyModeScreen> {
  bool _isConvoyActive = true;

  void _toggleConvoy() {
    setState(() {
      _isConvoyActive = !_isConvoyActive;
    });
    
    if (!_isConvoyActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Convoy mode disengaged. Manual control active.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Syncing with convoy...')),
      );
    }
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
        title: const Text('Automated Convoy', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isConvoyActive ? AppColors.statusInfo.withOpacity(0.1) : AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _isConvoyActive ? AppColors.statusInfo : AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.link, color: _isConvoyActive ? AppColors.statusInfo : AppColors.textSecondary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_isConvoyActive ? 'Convoy Active' : 'Convoy Disengaged', style: TextStyle(color: _isConvoyActive ? AppColors.statusInfo : AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 2),
                        const Text('Lead: NMDC-101 • You: Follower 2', style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Convoy Visualizer
            const Text('Convoy Formation', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 16),
            
            SizedBox(
              height: 250,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildConvoyTruck('NMDC-105', false, _isConvoyActive),
                  Container(width: 40, height: 2, color: _isConvoyActive ? AppColors.statusSafe : AppColors.border),
                  _buildConvoyTruck('NMDC-103', true, _isConvoyActive), // YOU
                  Container(width: 40, height: 2, color: _isConvoyActive ? AppColors.statusSafe : AppColors.border),
                  _buildConvoyTruck('NMDC-101', false, _isConvoyActive, isLead: true),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Metrics
            Row(
              children: [
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('Convoy Speed', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        const SizedBox(height: 8),
                        Text(_isConvoyActive ? '12 km/h' : '--', style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
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
                        const Text('Gap to Lead', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        const SizedBox(height: 8),
                        Text(_isConvoyActive ? '30 m' : '--', style: const TextStyle(color: AppColors.statusSafe, fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 40),
            
            // Action Button
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _toggleConvoy,
                icon: Icon(_isConvoyActive ? Icons.link_off : Icons.link, color: Colors.white),
                label: Text(
                  _isConvoyActive ? 'DISENGAGE CONVOY' : 'REJOIN CONVOY',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isConvoyActive ? AppColors.statusCritical : AppColors.statusSafe,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildConvoyTruck(String id, bool isYou, bool isConvoyActive, {bool isLead = false}) {
    Color color = isYou ? AppColors.primary : (isLead ? AppColors.statusWarning : AppColors.textSecondary);
    if (!isConvoyActive && !isYou) color = AppColors.border;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLead) const Text('LEAD', style: TextStyle(color: AppColors.statusWarning, fontSize: 10, fontWeight: FontWeight.bold)),
        if (isYou) const Text('YOU', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: isYou ? 2 : 1),
          ),
          child: Icon(Icons.local_shipping, color: color, size: 32),
        ),
        const SizedBox(height: 8),
        Text(id, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
