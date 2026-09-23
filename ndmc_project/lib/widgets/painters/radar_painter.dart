import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:collection';
import '../../models/telemetry.dart';
import '../../core/constants/app_colors.dart';

/// Real Polar Radar Display with Persistence
///
/// DESIGN PRINCIPLES:
/// 1. Show actual ToF sensor data, not decorative animations
/// 2. Freeze and show "NO SIGNAL" if telemetry stops
/// 3. Fade old points (persistence) so sweep is readable
/// 4. Highlight hazardous points under safety threshold
/// 5. Color by distance: far = dim cyan, near = bright red
class RadarPainter extends CustomPainter {
  /// Current telemetry sweep points
  final List<RadarPoint> currentSweep;

  /// Persistence ring buffer (historica points with timestamps)
  final Queue<RadarPointWithTime> persistenceBuffer;

  /// Current servo angle (degrees, 0-360)
  final double currentServoAngle;

  /// Maximum range for display (meters)
  final double maxRangeMeters;

  /// Safety threshold distance (meters) - points closer get highlighted
  final double safetyThresholdMeters;

  /// Time since last telemetry update (ms)
  final int timeSinceLastUpdate;

  /// Freeze threshold (ms) - show NO SIGNAL if exceeded
  static const int freezeThresholdMs = 500;

  /// Persistence duration (ms) - points fade from full to gone
  static const int persistenceDurationMs = 2000;

  RadarPainter({
    required this.currentSweep,
    required this.persistenceBuffer,
    required this.currentServoAngle,
    this.maxRangeMeters = 3.0,
    this.safetyThresholdMeters = 1.0,
    this.timeSinceLastUpdate = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;

    // Check if radar is frozen (no recent telemetry)
    final isFrozen = timeSinceLastUpdate > freezeThresholdMs;

    // Draw background
    _drawBackground(canvas, size);

    // Draw range rings with labels
    _drawRangeRings(canvas, center, radius);

    if (isFrozen) {
      // Show NO SIGNAL warning
      _drawNoSignalWarning(canvas, size, center);
    } else {
      // Draw persistence points (faded by age)
      _drawPersistencePoints(canvas, center, radius);

      // Draw current sweep points
      _drawCurrentSweep(canvas, center, radius);

      // Draw sweep line at current servo angle
      _drawSweepLine(canvas, center, radius);
    }

    // Draw center vehicle marker
    _drawVehicleMarker(canvas, center);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = AppColors.background
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
  }

  void _drawRangeRings(Canvas canvas, Offset center, double radius) {
    final ringPaint = Paint()
      ..color = AppColors.border.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final labelStyle = TextStyle(
      color: AppColors.textMuted,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    // Draw 4 range rings at 25%, 50%, 75%, 100%
    for (int i = 1; i <= 4; i++) {
      final ringRadius = radius * (i / 4);
      canvas.drawCircle(center, ringRadius, ringPaint);

      // Label at top of ring
      final distanceMeters = maxRangeMeters * (i / 4);
      final label = '${distanceMeters.toStringAsFixed(1)}m';

      final textPainter = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      textPainter.paint(
        canvas,
        Offset(
          center.dx - textPainter.width / 2,
          center.dy - ringRadius - textPainter.height - 4,
        ),
      );
    }

    // Draw cardinal direction lines (faint)
    final dirPaint = Paint()
      ..color = AppColors.border.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // North (up), East, South, West
    for (double angle = 0; angle < 360; angle += 90) {
      final rad = angle * math.pi / 180;
      final endX = center.dx + radius * math.sin(rad);
      final endY = center.dy - radius * math.cos(rad);
      canvas.drawLine(center, Offset(endX, endY), dirPaint);
    }
  }

  void _drawPersistencePoints(Canvas canvas, Offset center, double radius) {
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final pointWithTime in persistenceBuffer) {
      final age = now - pointWithTime.timestampMs;
      if (age > persistenceDurationMs) continue; // Too old, skip

      // Fade factor: 1.0 at age 0, 0.0 at persistenceDurationMs
      final fadeFactor = 1.0 - (age / persistenceDurationMs);

      // Draw the point with fading
      _drawRadarPoint(
        canvas,
        center,
        radius,
        pointWithTime.point,
        opacity: fadeFactor * 0.5, // Max 0.5 for persistence points
        isPersistence: true,
      );
    }
  }

  void _drawCurrentSweep(Canvas canvas, Offset center, double radius) {
    for (final point in currentSweep) {
      final isHazard = (point.dist / 100.0) < safetyThresholdMeters;

      _drawRadarPoint(
        canvas,
        center,
        radius,
        point,
        opacity: 1.0,
        isHazard: isHazard,
        isPersistence: false,
      );
    }
  }

  void _drawRadarPoint(
    Canvas canvas,
    Offset center,
    double radius,
    RadarPoint point,
    {
      required double opacity,
      bool isHazard = false,
      bool isPersistence = false,
    }
  ) {
    // Convert polar to cartesian
    // angle: 0° = right, 90° = up, 180° = left, 270° = down
    // We want 0° = up (north), so rotate by -90°
    final angleRad = (point.angle - 90) * math.pi / 180;

    // Distance in cm -> meters -> normalized to radius
    final distanceMeters = point.dist / 100.0;
    final normalizedDistance = (distanceMeters / maxRangeMeters).clamp(0.0, 1.0);
    final pointRadius = radius * normalizedDistance;

    final x = center.dx + pointRadius * math.cos(angleRad);
    final y = center.dy + pointRadius * math.sin(angleRad);

    // Color by distance: far = dim cyan, near = bright red
    Color pointColor;
    if (normalizedDistance < 0.25) {
      pointColor = Colors.red; // Very close - critical
    } else if (normalizedDistance < 0.5) {
      pointColor = Colors.orange; // Close - warning
    } else if (normalizedDistance < 0.75) {
      pointColor = Colors.yellow; // Medium
    } else {
      pointColor = Colors.cyan; // Far - safe
    }

    final paint = Paint()
      ..color = pointColor.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    // Point size: larger for hazards, smaller for persistence
    final dotSize = isHazard ? 5.0 : (isPersistence ? 2.0 : 3.5);
    canvas.drawCircle(Offset(x, y), dotSize, paint);

    // Highlight hazardous points with ring
    if (isHazard && !isPersistence) {
      final ringPaint = Paint()
        ..color = Colors.red.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(Offset(x, y), 8.0, ringPaint);
    }
  }

  void _drawSweepLine(Canvas canvas, Offset center, double radius) {
    // Convert servo angle to radians (0° = up/north)
    final angleRad = (currentServoAngle - 90) * math.pi / 180;

    final endX = center.dx + radius * math.cos(angleRad);
    final endY = center.dy + radius * math.sin(angleRad);

    final sweepPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawLine(center, Offset(endX, endY), sweepPaint);

    // Add a gradient effect at the sweep line (fading trail)
    final gradientPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.primary.withOpacity(0.3),
          AppColors.primary.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(endX, endY), radius: 30));

    canvas.drawCircle(Offset(endX, endY), 30, gradientPaint);
  }

  void _drawVehicleMarker(Canvas canvas, Offset center) {
    // Draw vehicle as a triangle pointing up (forward)
    final vehiclePaint = Paint()
      ..color = AppColors.statusSafe
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(center.dx, center.dy - 8); // Top point (front)
    path.lineTo(center.dx - 6, center.dy + 6); // Bottom left
    path.lineTo(center.dx + 6, center.dy + 6); // Bottom right
    path.close();

    canvas.drawPath(path, vehiclePaint);

    // Outline
    final outlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, outlinePaint);
  }

  void _drawNoSignalWarning(Canvas canvas, Size size, Offset center) {
    // Draw frozen sweep visualization (grayscale)
    final frozenPaint = Paint()
      ..color = AppColors.textMuted.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final radius = math.min(size.width, size.height) / 2 - 20;
    canvas.drawCircle(center, radius, frozenPaint);

    // Draw "NO SIGNAL" text
    final textStyle = TextStyle(
      color: AppColors.statusCritical,
      fontSize: 24,
      fontWeight: FontWeight.bold,
      letterSpacing: 2.0,
    );

    final textPainter = TextPainter(
      text: TextSpan(text: 'NO SIGNAL', style: textStyle),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );

    // Draw warning icon
    final iconPainter = TextPainter(
      text: TextSpan(
        text: '⚠',
        style: TextStyle(
          fontSize: 48,
          color: AppColors.statusCritical.withOpacity(0.8),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(
        center.dx - iconPainter.width / 2,
        center.dy - textPainter.height / 2 - 60,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) {
    // Repaint if any data has changed
    return oldDelegate.currentSweep != currentSweep ||
           oldDelegate.persistenceBuffer != persistenceBuffer ||
           oldDelegate.currentServoAngle != currentServoAngle ||
           oldDelegate.timeSinceLastUpdate != timeSinceLastUpdate;
  }
}

/// Radar point with timestamp for persistence tracking
class RadarPointWithTime {
  final RadarPoint point;
  final int timestampMs;

  RadarPointWithTime({
    required this.point,
    required this.timestampMs,
  });
}
