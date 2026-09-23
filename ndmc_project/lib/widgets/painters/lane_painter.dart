import 'package:flutter/material.dart';

class LanePainter extends CustomPainter {
  final bool isDrifting;
  final double driftAngle;
  final double tiltRoll;

  LanePainter({
    required this.isDrifting,
    this.driftAngle = 0.0,
    this.tiltRoll = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Deadzone: Ignore tiny movements (noise) less than 0.5 rad/s
    double effectiveDrift = driftAngle.abs() > 0.5 ? driftAngle : 0.0;
    
    // Dynamic vanishing point based on drift and tilt
    // Heavily scaled down so the pathway stays locked onto the screen
    double shiftX = effectiveDrift * 3.0; // Reduced from 20.0
    double shiftY = tiltRoll * 3.0; // Reduced from 10.0
    
    // Constrain shifts tightly so it doesn't leave the screen entirely
    shiftX = shiftX.clamp(-size.width * 0.25, size.width * 0.25);
    shiftY = shiftY.clamp(-size.height * 0.15, size.height * 0.15);

    final paint = Paint()
      ..color = isDrifting ? Colors.red.withOpacity(0.9) : const Color(0xFF00FFCC).withOpacity(0.7) // Neon Emerald
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDrifting ? 6.0 : 3.0;

    // Draw Dynamic Trapezoidal Pathway
    final path = Path();
    
    // Base anchors
    final double bottomY = size.height * 0.95;
    final double topY = size.height * 0.45 + shiftY;
    
    final double bottomLeftX = size.width * 0.1;
    final double bottomRightX = size.width * 0.9;
    
    final double topLeftX = size.width * 0.35 + shiftX;
    final double topRightX = size.width * 0.65 + shiftX;

    path.moveTo(bottomLeftX, bottomY);
    path.lineTo(topLeftX, topY);
    path.moveTo(bottomRightX, bottomY);
    path.lineTo(topRightX, topY);
    canvas.drawPath(path, paint);

    // Draw glowing dashed centerline
    final centerPaint = Paint()
      ..color = isDrifting ? Colors.red.withOpacity(0.6) : Colors.yellow.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    double currentY = bottomY;
    double currentX = size.width * 0.5;
    final double topCenterX = (topLeftX + topRightX) / 2;
    
    // Simple interpolation for dashed line
    const int segments = 8;
    for (int i = 0; i < segments; i++) {
      double t1 = i / segments;
      double t2 = (i + 0.5) / segments;
      
      double y1 = bottomY + (topY - bottomY) * t1;
      double x1 = currentX + (topCenterX - currentX) * t1;
      
      double y2 = bottomY + (topY - bottomY) * t2;
      double x2 = currentX + (topCenterX - currentX) * t2;
      
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), centerPaint);
      
      // Perspective distance tick marks
      if (i % 2 == 0 && i > 0) {
        double widthAtT = (bottomRightX - bottomLeftX) * (1 - t1) + (topRightX - topLeftX) * t1;
        double tickWidth = widthAtT * 0.1;
        canvas.drawLine(Offset(x1 - tickWidth, y1), Offset(x1 + tickWidth, y1), centerPaint);
      }
    }

    if (isDrifting) {
      // Draw pulsating warning overlay
      final textPainter = TextPainter(
        text: const TextSpan(
          text: '[ CRITICAL: BERM BREACH DEVIATION ]',
          style: TextStyle(
            color: Colors.white, 
            fontSize: 16, 
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            backgroundColor: Colors.red,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, size.height * 0.2));
    }
  }

  @override
  bool shouldRepaint(covariant LanePainter oldDelegate) {
    return oldDelegate.isDrifting != isDrifting || 
           oldDelegate.driftAngle != driftAngle || 
           oldDelegate.tiltRoll != tiltRoll;
  }
}
