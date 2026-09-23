import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../widgets/glass_card.dart';

class BeyondVisibilityScreen extends StatelessWidget {
  const BeyondVisibilityScreen({super.key});

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
        title: const Text('Beyond-Visibility View', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Visibility Header
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.statusCritical.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.statusCritical),
                ),
                child: const Text('Actual Visibility: 8 m', style: TextStyle(color: AppColors.statusCritical, fontWeight: FontWeight.bold)),
              ),
            ),
            
            const SizedBox(height: 16),

            // Road Simulation Image Area
            Container(
              height: 350,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                image: const DecorationImage(
                  image: AssetImage('lib/screens/assets/images/mine_truck.png'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken), // Simulate fog/darkness
                ),
              ),
              child: Stack(
                children: [
                  // Overlays
                  Positioned(
                    top: 100,
                    right: 40,
                    child: _buildImageOverlayLabel('Vehicle Ahead\n75 m', AppColors.statusWarning),
                  ),
                  Positioned(
                    top: 180,
                    left: 60,
                    child: _buildImageOverlayLabel('Sharp Turn\n110 m', AppColors.statusHigh),
                  ),
                  Positioned(
                    bottom: 60,
                    right: 80,
                    child: _buildImageOverlayLabel('Restricted Zone\n150 m', AppColors.statusCritical),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Road Insight
            const Text('Road Insight', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 12),
            
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInsightRow(Icons.visibility_off, 'Blind Zone Ahead', '42 m', AppColors.statusCritical),
                  const Divider(color: AppColors.border, height: 24),
                  _buildInsightRow(Icons.alt_route, 'Intersection', '80 m', AppColors.statusWarning),
                  const Divider(color: AppColors.border, height: 24),
                  _buildInsightRow(Icons.speed, 'Speed Recommended', '10 km/h', AppColors.statusSafe),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildImageOverlayLabel(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInsightRow(IconData icon, String label, String value, Color iconColor) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        const Spacer(),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
