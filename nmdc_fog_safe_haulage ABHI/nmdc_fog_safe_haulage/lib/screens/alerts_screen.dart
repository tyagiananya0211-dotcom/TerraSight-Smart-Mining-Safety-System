import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../widgets/glass_card.dart';
import '../services/alert_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final AlertService _alertService = AlertService();

  @override
  void dispose() {
    _alertService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Safety Alerts', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        actions: [
          IconButton(
            onPressed: () => _alertService.acknowledgeAll(),
            icon: const Icon(Icons.done_all, color: AppColors.textPrimary),
          ),
        ],
      ),
      body: StreamBuilder<List<SafetyAlert>>(
        stream: _alertService.alertsStream,
        initialData: _alertService.currentAlerts,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final alerts = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              return _buildAlertCard(alerts[index]);
            },
          );
        }
      ),
    );
  }

  Widget _buildAlertCard(SafetyAlert alert) {
    Color cardColor;
    IconData icon;

    switch (alert.type) {
      case 'Critical':
        cardColor = AppColors.statusCritical;
        icon = Icons.warning_rounded;
        break;
      case 'Warning':
        cardColor = AppColors.statusWarning;
        icon = Icons.radar;
        break;
      default:
        cardColor = AppColors.statusInfo;
        icon = Icons.info_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: cardColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert.title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(alert.type.toUpperCase(), style: TextStyle(color: cardColor, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Text('${alert.timestamp.hour}:${alert.timestamp.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            Text(alert.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.textMuted, size: 16),
                const SizedBox(width: 4),
                Text(alert.location, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: alert.isAcknowledged ? null : () => _alertService.acknowledgeAlert(alert.id),
                style: OutlinedButton.styleFrom(
                  foregroundColor: alert.isAcknowledged ? AppColors.statusSafe : cardColor,
                  side: BorderSide(color: alert.isAcknowledged ? AppColors.statusSafe : cardColor),
                ),
                child: Text(alert.isAcknowledged ? 'ACKNOWLEDGED' : 'ACKNOWLEDGE ALERT'),
              ),
            )
          ],
        ),
      ),
    );
  }
}