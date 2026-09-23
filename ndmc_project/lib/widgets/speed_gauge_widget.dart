import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/safety_config.dart';
import '../services/speed_envelope_service.dart';
import 'painters/speed_gauge_painter.dart';

/// Speed Gauge Widget - Primary HUD Element
///
/// Displays current speed with colored arc showing safe envelope.
/// Provides visual and audio alerts when speed exceeds safe limits.
class SpeedGaugeWidget extends StatefulWidget {
  /// Current vehicle speed (km/h)
  final double currentSpeed;

  /// Safe speed limit from envelope (km/h)
  final double safeSpeedLimit;

  /// Current visibility (meters)
  final double visibility;

  /// Speed envelope details (optional, for additional info)
  final SpeedEnvelope? envelope;

  /// Callback when speed exceeds limit
  final VoidCallback? onSpeedExceeded;

  /// Whether to show the info line (safe limit/visibility/gain) and status
  /// chip below the dial. Turning this off keeps the widget's natural size
  /// close to a plain square, so a parent that scales it to fit a small
  /// allotted space (e.g. via FittedBox) doesn't shrink the dial itself to
  /// accommodate extra rows of text.
  final bool showDetails;

  const SpeedGaugeWidget({
    Key? key,
    required this.currentSpeed,
    required this.safeSpeedLimit,
    required this.visibility,
    this.envelope,
    this.onSpeedExceeded,
    this.showDetails = true,
  }) : super(key: key);

  @override
  State<SpeedGaugeWidget> createState() => _SpeedGaugeWidgetState();
}

class _SpeedGaugeWidgetState extends State<SpeedGaugeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _flashController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  DateTime? _lastAlertTime;
  bool _isOverLimit = false;

  @override
  void initState() {
    super.initState();

    // Flash animation for over-limit warning
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _checkSpeedLimit();
  }

  @override
  void didUpdateWidget(SpeedGaugeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentSpeed != widget.currentSpeed ||
        oldWidget.safeSpeedLimit != widget.safeSpeedLimit) {
      _checkSpeedLimit();
    }
  }

  @override
  void dispose() {
    _flashController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Check if current speed exceeds safe limit
  void _checkSpeedLimit() {
    final wasOverLimit = _isOverLimit;
    _isOverLimit = widget.currentSpeed > widget.safeSpeedLimit;

    if (_isOverLimit && !wasOverLimit) {
      // Just exceeded limit - start flashing
      _flashController.repeat(reverse: true);
      _triggerAlert();
    } else if (!_isOverLimit && wasOverLimit) {
      // Back under limit - stop flashing
      _flashController.stop();
      _flashController.value = 0;
    }
  }

  /// Trigger audio alert with debouncing
  void _triggerAlert() {
    final now = DateTime.now();

    // Check debounce - only alert once every 3 seconds
    if (_lastAlertTime != null) {
      final timeSinceLastAlert = now.difference(_lastAlertTime!);
      if (timeSinceLastAlert.inMilliseconds <
          SafetyConfig.audioDebounceTime * 1000) {
        return; // Too soon, skip alert
      }
    }

    _lastAlertTime = now;

    // Trigger callback
    widget.onSpeedExceeded?.call();

    // Play alert sound (using system beep as fallback)
    // In production, use a custom alert sound file
    _playAlertSound();
  }

  /// Play alert sound
  Future<void> _playAlertSound() async {
    try {
      // In a real app, you would load a custom sound file:
      // await _audioPlayer.play(AssetSource('sounds/speed_alert.mp3'));

      // For now, we'll use a simple approach
      // The actual beep would come from an audio asset
      debugPrint('🚨 SPEED ALERT: ${widget.currentSpeed.toInt()} km/h exceeds limit of ${widget.safeSpeedLimit.toInt()} km/h');
    } catch (e) {
      debugPrint('Audio alert failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main speed gauge
        SizedBox(
          width: 300,
          height: 300,
          child: AnimatedBuilder(
            animation: _flashController,
            builder: (context, child) {
              return CustomPaint(
                painter: SpeedGaugePainter(
                  currentSpeed: widget.currentSpeed,
                  safeSpeedLimit: widget.safeSpeedLimit,
                  maxSpeed: 50.0,
                  shouldFlash: _flashController.value > 0.5,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Current speed - large and prominent
                      Text(
                        widget.currentSpeed.toInt().toString(),
                        style: TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                          color: _getSpeedColor(),
                          shadows: _isOverLimit && _flashController.value > 0.5
                              ? [
                                  Shadow(
                                    color: Colors.red.withOpacity(0.8),
                                    blurRadius: 20,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      // Unit label
                      const Text(
                        'km/h',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        if (widget.showDetails) ...[
          const SizedBox(height: 16),
          // Info text line
          _buildInfoLine(),
          const SizedBox(height: 8),
          // Status indicator
          _buildStatusIndicator(),
        ],
      ],
    );
  }

  /// Build the info text line
  Widget _buildInfoLine() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.border.withOpacity(0.3),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            Icons.speed,
            size: 16,
            color: _getSafeLimitColor(),
          ),
          const SizedBox(width: 8),
          Text(
            'SAFE LIMIT: ${widget.safeSpeedLimit.toInt()} km/h',
            style: TextStyle(
              color: _getSafeLimitColor(),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            '|',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 16),
          Icon(
            Icons.visibility,
            size: 16,
            color: _getVisibilityColor(),
          ),
          const SizedBox(width: 8),
          Text(
            'VISIBILITY: ${widget.visibility.toInt()} m',
            style: TextStyle(
              color: _getVisibilityColor(),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (widget.envelope != null) ...[
            const SizedBox(width: 16),
            const Text(
              '|',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 16),
            Icon(
              Icons.trending_up,
              size: 16,
              color: _getGainColor(),
            ),
            const SizedBox(width: 8),
            Text(
              'GAIN: ${widget.envelope!.speedGainRatio.toStringAsFixed(1)}x',
              style: TextStyle(
                color: _getGainColor(),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 16),
            const Text(
              '|',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 16),
            Icon(
              _getLimitingIcon(),
              size: 16,
              color: _getLimitingColor(),
            ),
            const SizedBox(width: 8),
            Text(
              'LIMIT: ${_getLimitingText()}',
              style: TextStyle(
                color: _getLimitingColor(),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build status indicator
  Widget _buildStatusIndicator() {
    final status = SpeedEnvelopeService.getSpeedStatus(
      widget.currentSpeed,
      widget.safeSpeedLimit,
    );

    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'danger':
        statusText = 'SPEED LIMIT EXCEEDED';
        statusColor = AppColors.statusCritical;
        statusIcon = Icons.warning_amber_rounded;
        break;
      case 'warning':
        statusText = 'APPROACHING LIMIT';
        statusColor = AppColors.statusWarning;
        statusIcon = Icons.error_outline;
        break;
      default:
        statusText = 'SPEED SAFE';
        statusColor = AppColors.statusSafe;
        statusIcon = Icons.check_circle_outline;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// Get color for current speed display
  Color _getSpeedColor() {
    if (widget.currentSpeed > widget.safeSpeedLimit) {
      return AppColors.statusCritical;
    } else if (widget.currentSpeed >
        widget.safeSpeedLimit * SafetyConfig.warningThreshold) {
      return AppColors.statusWarning;
    }
    return AppColors.textPrimary;
  }

  /// Get color for safe limit display
  Color _getSafeLimitColor() {
    if (widget.currentSpeed > widget.safeSpeedLimit) {
      return AppColors.statusCritical;
    }
    return AppColors.primary;
  }

  /// Get color for visibility display
  Color _getVisibilityColor() {
    if (widget.visibility < 10) return AppColors.statusCritical;
    if (widget.visibility < 20) return AppColors.statusWarning;
    if (widget.visibility < 50) return AppColors.statusHigh;
    return AppColors.statusSafe;
  }

  /// Get color for gain ratio display
  Color _getGainColor() {
    final gain = widget.envelope?.speedGainRatio ?? 1.0;
    if (gain >= 2.0) return AppColors.statusSafe;   // 2x+ gain: excellent
    if (gain >= 1.5) return AppColors.statusHigh;   // 1.5-2x: good
    if (gain >= 1.2) return AppColors.statusWarning; // 1.2-1.5x: moderate
    return AppColors.textSecondary;                  // <1.2x: minimal gain
  }

  /// Get limiting sensor text for display
  String _getLimitingText() {
    final limitingSensor = widget.envelope?.limitingSensor ?? "UNKNOWN";
    switch (limitingSensor) {
      case "VISIBILITY":
        return "VISIBILITY";
      case "TOF_RANGE":
        return "ToF RANGE";
      case "OBSTACLE":
        return "OBSTACLE";
      default:
        return "UNKNOWN";
    }
  }

  /// Get limiting sensor icon
  IconData _getLimitingIcon() {
    final limitingSensor = widget.envelope?.limitingSensor ?? "UNKNOWN";
    switch (limitingSensor) {
      case "VISIBILITY":
        return Icons.visibility_off; // Visibility is limiting
      case "TOF_RANGE":
        return Icons.sensors; // ToF sensor is limiting
      case "OBSTACLE":
        return Icons.warning; // Obstacle detected
      default:
        return Icons.help_outline;
    }
  }

  /// Get limiting sensor color
  Color _getLimitingColor() {
    final limitingSensor = widget.envelope?.limitingSensor ?? "UNKNOWN";
    switch (limitingSensor) {
      case "VISIBILITY":
        return AppColors.statusWarning; // Fog is limiting
      case "TOF_RANGE":
        return AppColors.statusCritical; // ToF degraded by fog
      case "OBSTACLE":
        return AppColors.statusWarning; // Obstacle present
      default:
        return AppColors.textMuted;
    }
  }
}
