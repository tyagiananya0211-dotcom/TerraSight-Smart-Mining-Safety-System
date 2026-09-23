import '../models/sensor_data.dart';

class SafetyResult {
  final int safetyScore;
  final String riskLevel;
  final String decision;
  final double recommendedSpeed;
  final String message;

  SafetyResult({
    required this.safetyScore,
    required this.riskLevel,
    required this.decision,
    required this.recommendedSpeed,
    required this.message,
  });
}

class SafetyEngine {
  static SafetyResult analyze(SensorData data) {
    int score = 100;

    // Visibility analysis
    if (data.visibility < 5) {
      score -= 50;
    } else if (data.visibility < 10) {
      score -= 35;
    } else if (data.visibility < 20) {
      score -= 20;
    }

    // Road friction analysis
    if (data.roadFriction < 0.3) {
      score -= 25;
    } else if (data.roadFriction < 0.5) {
      score -= 15;
    }

    // Obstacle distance analysis
    if (data.obstacleDistance < 10) {
      score -= 30;
    } else if (data.obstacleDistance < 20) {
      score -= 15;
    }

    // Wind speed analysis
    if (data.windSpeed > 40) {
      score -= 10;
    }

    // Rainfall analysis
    if (data.rainfall > 50) {
      score -= 10;
    }

    if (score < 0) score = 0;

    String riskLevel;
    String decision;
    double recommendedSpeed;
    String message;

    if (score <= 30) {
      riskLevel = 'CRITICAL';
      decision = 'STOP';
      recommendedSpeed = 0;

      message =
          'Unsafe conditions detected. Stop dumper movement immediately.';
    } else if (score <= 60) {
      riskLevel = 'HIGH';
      decision = 'CAUTION';
      recommendedSpeed = 10;

      message =
          'Severe weather conditions detected. Reduce speed and maintain safe distance.';
    } else if (score <= 80) {
      riskLevel = 'MODERATE';
      decision = 'CAUTION';
      recommendedSpeed = 20;

      message =
          'Moderate risk detected. Continue with controlled speed.';
    } else {
      riskLevel = 'LOW';
      decision = 'PROCEED';
      recommendedSpeed = 35;

      message =
          'Conditions are safe for normal dumper operations.';
    }

    return SafetyResult(
      safetyScore: score,
      riskLevel: riskLevel,
      decision: decision,
      recommendedSpeed: recommendedSpeed,
      message: message,
    );
  }
}