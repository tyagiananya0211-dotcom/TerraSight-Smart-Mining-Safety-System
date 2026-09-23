import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../services/conflict_predictor.dart';

/// Conflict Warning Widget
///
/// Displays vehicle-to-vehicle conflict warnings based on GPS-free
/// RSSI proximity detection.
///
/// HONEST DESIGN:
/// - NO false bearing claims (until ToF acquires peer)
/// - Shows closing rate and proximity band
/// - Upgrades to true bearing when ToF takes over
class ConflictWarningWidget extends StatelessWidget {
  /// Conflict detections to display
  final List<ConflictDetection> conflicts;

  /// Callback when warning is tapped (for details/dismiss)
  final VoidCallback? onTap;

  const ConflictWarningWidget({
    Key? key,
    required this.conflicts,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Filter to only show CONFLICT severity (stable conflicts)
    final activeConflicts = conflicts.where((c) => c.severity == "CONFLICT").toList();

    if (activeConflicts.isEmpty) {
      return const SizedBox.shrink();
    }

    // Show top conflict (closest/most severe)
    final topConflict = activeConflicts.first;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.statusCritical,
          boxShadow: [
            BoxShadow(
              color: AppColors.statusCritical.withOpacity(0.5),
              blurRadius: 15,
              spreadRadius: 3,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main warning text
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.car_crash,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getWarningText(topConflict),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getDetailText(topConflict),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ],
            ),

            // Additional conflicts indicator
            if (activeConflicts.length > 1) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+${activeConflicts.length - 1} more vehicle${activeConflicts.length > 2 ? 's' : ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Get main warning text based on conflict state
  String _getWarningText(ConflictDetection conflict) {
    if (conflict.tofAcquired) {
      // ToF has acquired peer - show bearing
      return 'VEHICLE APPROACHING — ${conflict.tofBearing!.toStringAsFixed(0)}°';
    } else {
      // GPS-free mode - NO false bearing claims
      return 'VEHICLE APPROACHING — CLOSING — ${conflict.distanceBand}';
    }
  }

  /// Get detail text
  String _getDetailText(ConflictDetection conflict) {
    if (conflict.tofAcquired) {
      // ToF acquired - show true distance and bearing
      return 'ToF ACQUIRED: ${conflict.tofDistance!.toStringAsFixed(1)}m at ${conflict.tofBearing!.toStringAsFixed(0)}° — SLOW DOWN';
    } else {
      // RSSI-based proximity - show closing rate and band
      final closingRateText = conflict.closingRate > 0 ? 'APPROACHING' : 'RECEDING';
      return 'V2V PROXIMITY: ${conflict.peerId} — $closingRateText (${conflict.closingRate.toStringAsFixed(1)} dBm/s) — SLOW DOWN';
    }
  }
}

/// Conflict Detail Dialog
///
/// Shows detailed information about all detected conflicts
class ConflictDetailDialog extends StatelessWidget {
  final List<ConflictDetection> conflicts;

  const ConflictDetailDialog({
    Key? key,
    required this.conflicts,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Row(
        children: [
          Icon(Icons.car_crash, color: AppColors.statusCritical),
          SizedBox(width: 12),
          Text(
            'V2V Conflicts',
            style: TextStyle(color: AppColors.textPrimary),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: conflicts.length,
          separatorBuilder: (_, __) => const Divider(color: AppColors.border),
          itemBuilder: (context, index) {
            final conflict = conflicts[index];
            return _buildConflictTile(conflict);
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CLOSE'),
        ),
      ],
    );
  }

  Widget _buildConflictTile(ConflictDetection conflict) {
    return ListTile(
      leading: Icon(
        conflict.tofAcquired ? Icons.radar : Icons.wifi_tethering,
        color: _getSeverityColor(conflict.severity),
      ),
      title: Text(
        conflict.peerId,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Severity: ${conflict.severity} | Band: ${conflict.distanceBand}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          Text(
            'Closing Rate: ${conflict.closingRate.toStringAsFixed(2)} dBm/s',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          Text(
            'Heading Opposition: ${conflict.headingOpposition.toStringAsFixed(0)}°',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (conflict.tofAcquired)
            Text(
              '🎯 ToF: ${conflict.tofDistance!.toStringAsFixed(1)}m @ ${conflict.tofBearing!.toStringAsFixed(0)}°',
              style: const TextStyle(
                color: AppColors.statusSafe,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getSeverityColor(conflict.severity).withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _getSeverityColor(conflict.severity)),
        ),
        child: Text(
          conflict.consecutiveCount.toString(),
          style: TextStyle(
            color: _getSeverityColor(conflict.severity),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'CONFLICT':
        return AppColors.statusCritical;
      case 'CAUTION':
        return AppColors.statusWarning;
      default:
        return AppColors.statusSafe;
    }
  }
}
