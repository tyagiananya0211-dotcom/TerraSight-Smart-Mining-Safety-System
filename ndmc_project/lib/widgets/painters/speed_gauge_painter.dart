import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Custom painter for the speed gauge with colored arc envelope
class SpeedGaugePainter extends CustomPainter {
  /// Current vehicle speed (km/h)
  final double currentSpeed;

  /// Safe speed limit from envelope calculation (km/h)
  final double safeSpeedLimit;

  /// Maximum speed to display on gauge (km/h)
  final double maxSpeed;

  /// Whether to flash the gauge (when over limit)
  final bool shouldFlash;

  SpeedGaugePainter({
    required this.currentSpeed,
    required this.safeSpeedLimit,
    this.maxSpeed = 50.0,
    this.shouldFlash = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;

    // Draw gauge background arc
    _drawBackgroundArc(canvas, center, radius);

    // Draw safe speed envelope arc
    _drawEnvelopeArc(canvas, center, radius);

    // Draw current speed needle
    _drawSpeedNeedle(canvas, center, radius);

    // Draw center circle
    _drawCenterCircle(canvas, center);

    // Draw speed labels
    _drawSpeedLabels(canvas, center, radius);
  }

  /// Draw the background arc (full gauge range)
  void _drawBackgroundArc(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = AppColors.border.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 25
      ..strokeCap = StrokeCap.round;

    const startAngle = math.pi * 0.75; // 135 degrees
    const sweepAngle = math.pi * 1.5; // 270 degrees

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  /// Draw the colored envelope arc showing safe/warning/danger zones
  void _drawEnvelopeArc(Canvas canvas, Offset center, double radius) {
    const startAngle = math.pi * 0.75; // 135 degrees
    const sweepAngle = math.pi * 1.5; // 270 degrees

    // Calculate angles for different zones
    final safeRatio = safeSpeedLimit / maxSpeed;
    final currentRatio = currentSpeed / maxSpeed;
    final warningThreshold = 0.90; // 90% of safe limit

    // Draw safe zone (green) - from 0 to safe limit
    if (safeSpeedLimit > 0) {
      final safeSweep = sweepAngle * safeRatio;
      final safePaint = Paint()
        ..color = AppColors.statusSafe
        ..style = PaintingStyle.stroke
        ..strokeWidth = 25
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        safeSweep,
        false,
        safePaint,
      );
    }

    // Draw warning indicator if speed is near limit
    if (currentSpeed > safeSpeedLimit * warningThreshold &&
        currentSpeed <= safeSpeedLimit) {
      final warningSweep = sweepAngle * currentRatio;
      final warningPaint = Paint()
        ..color = AppColors.statusWarning
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        warningSweep,
        false,
        warningPaint,
      );
    }

    // Draw danger zone (red) if over limit
    if (currentSpeed > safeSpeedLimit) {
      final dangerStart = startAngle + (sweepAngle * safeRatio);
      final dangerSweep = sweepAngle * (currentRatio - safeRatio);

      final dangerPaint = Paint()
        ..color = shouldFlash ? AppColors.statusCritical : AppColors.statusHigh
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        dangerStart,
        dangerSweep,
        false,
        dangerPaint,
      );
    }
  }

  /// Draw the speed needle pointing to current speed
  void _drawSpeedNeedle(Canvas canvas, Offset center, double radius) {
    final speedRatio = (currentSpeed / maxSpeed).clamp(0.0, 1.0);
    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;
    final needleAngle = startAngle + (sweepAngle * speedRatio);

    // Calculate needle end point
    final needleLength = radius - 15;
    final needleEnd = Offset(
      center.dx + needleLength * math.cos(needleAngle),
      center.dy + needleLength * math.sin(needleAngle),
    );

    // Determine needle color based on speed status
    Color needleColor;
    if (currentSpeed > safeSpeedLimit) {
      needleColor = shouldFlash ? Colors.red : AppColors.statusCritical;
    } else if (currentSpeed > safeSpeedLimit * 0.90) {
      needleColor = AppColors.statusWarning;
    } else {
      needleColor = Colors.white;
    }

    // Draw needle
    final needlePaint = Paint()
      ..color = needleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, needleEnd, needlePaint);

    // Draw needle tip circle
    final tipPaint = Paint()
      ..color = needleColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(needleEnd, 6, tipPaint);
  }

  /// Draw the center circle
  void _drawCenterCircle(Canvas canvas, Offset center) {
    // Outer ring
    final outerPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 20, outerPaint);

    // Inner circle
    final innerPaint = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 12, innerPaint);
  }

  /// Draw speed labels around the gauge
  void _drawSpeedLabels(Canvas canvas, Offset center, double radius) {
    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;
    final labelRadius = radius + 35;

    // Draw labels at 0, 10, 20, 30, 40, 50 km/h
    final labels = [0, 10, 20, 30, 40, 50];
    for (final speed in labels) {
      if (speed > maxSpeed) continue;

      final ratio = speed / maxSpeed;
      final angle = startAngle + (sweepAngle * ratio);

      final labelPos = Offset(
        center.dx + labelRadius * math.cos(angle),
        center.dy + labelRadius * math.sin(angle),
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: '$speed',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          labelPos.dx - textPainter.width / 2,
          labelPos.dy - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(SpeedGaugePainter oldDelegate) {
    return oldDelegate.currentSpeed != currentSpeed ||
        oldDelegate.safeSpeedLimit != safeSpeedLimit ||
        oldDelegate.shouldFlash != shouldFlash ||
        oldDelegate.maxSpeed != maxSpeed;
  }
}
