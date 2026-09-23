import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../widgets/glass_card.dart';

class DriverSafetyScoreScreen extends StatelessWidget {
  const DriverSafetyScoreScreen({super.key});

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
        title: const Text('Driver Safety Score', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Big Score Circle
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: CircularProgressIndicator(
                      value: 0.92,
                      strokeWidth: 16,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.statusSafe),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    children: const [
                      Text('92', style: TextStyle(color: AppColors.textPrimary, fontSize: 64, fontWeight: FontWeight.bold, height: 1.0)),
                      Text('/ 100', style: TextStyle(color: AppColors.textSecondary, fontSize: 20, height: 1.0)),
                      SizedBox(height: 8),
                      Text('Excellent', style: TextStyle(color: AppColors.statusSafe, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Metrics List
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Current Shift Metrics', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            ),
            const SizedBox(height: 12),
            
            _buildMetricItem(
              title: 'Over-speeding Events',
              value: '0',
              statusText: 'Perfect',
              color: AppColors.statusSafe,
              icon: Icons.speed,
            ),
            const SizedBox(height: 12),
            _buildMetricItem(
              title: 'Harsh Braking',
              value: '1',
              statusText: 'Minor',
              color: AppColors.statusWarning,
              icon: Icons.front_hand,
            ),
            const SizedBox(height: 12),
            _buildMetricItem(
              title: 'Safe Distance Maintained',
              value: '98%',
              statusText: 'Excellent',
              color: AppColors.statusSafe,
              icon: Icons.social_distance,
            ),
            
            const SizedBox(height: 32),
            
            // Rewards/Insights
            GlassCard(
              padding: const EdgeInsets.all(16),
              hasGlow: true,
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium, color: AppColors.statusWarning, size: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Safety Bonus Tracked', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Maintain this score for the rest of the shift to earn the daily safety bonus.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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

  Widget _buildMetricItem({
    required String title,
    required String value,
    required String statusText,
    required Color color,
    required IconData icon,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                const SizedBox(height: 4),
                Text(statusText, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
