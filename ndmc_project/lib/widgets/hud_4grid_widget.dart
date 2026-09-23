import 'package:flutter/material.dart';
import '../utils/contrast_enhance_filter.dart';
import 'painters/lane_painter.dart';
import 'radar_widget.dart';
import '../core/constants/app_colors.dart';
import 'speed_gauge_widget.dart';

import '../models/telemetry.dart';

class Hud4GridWidget extends StatelessWidget {
  final Widget opticalFeedWidget;
  final Telemetry telemetry;

  const Hud4GridWidget({
    super.key,
    required this.opticalFeedWidget,
    required this.telemetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // PROMINENT SPEED GAUGE AT TOP
        //
        // Bounded via Expanded + FittedBox so the gauge always scales to
        // fill the space it's given rather than overflowing on short
        // landscape-phone screens. showDetails:false keeps the widget's
        // natural footprint a plain square (just the dial), so FittedBox
        // isn't shrinking the dial to make room for extra text rows below.
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SpeedGaugeWidget(
                  currentSpeed: telemetry.speed,
                  safeSpeedLimit: telemetry.safeSpeedLimit,
                  visibility: telemetry.visibilityMeters,
                  showDetails: false,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 4-GRID TACTICAL DISPLAY
        Expanded(
          flex: 4,
          child: Row(
            children: [
              Expanded(
                child: _buildQuadrant(
                  child: opticalFeedWidget,
                  title: 'OPTICAL FEED',
                  color: AppColors.statusInfo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuadrant(
                  child: ContrastEnhanceFilter.apply(opticalFeedWidget),
                  title: 'CONTRAST ENHANCE (CLAHE)',
                  color: AppColors.statusWarning,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          flex: 5,
          child: Row(
            children: [
              Expanded(
                child: _buildQuadrant(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      opticalFeedWidget,
                      CustomPaint(
                        painter: LanePainter(
                          isDrifting: telemetry.alertState == "HAZARD" || telemetry.alertState == "CAUTION",
                          driftAngle: telemetry.roll,
                          tiltRoll: telemetry.pitch,
                        ),
                        child: Container(),
                      ),
                    ],
                  ),
                  title: 'PATHWAY CORRIDOR',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuadrant(
                  child: Container(
                    color: AppColors.background,
                    child: RadarWidget(
                      telemetry: telemetry,
                      maxRangeMeters: 3.0,
                      safetyThresholdMeters: 1.0,
                    ),
                  ),
                  title: 'ToF RADAR (3m)',
                  color: AppColors.statusSafe,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuadrant({required Widget child, required String title, required Color color}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
