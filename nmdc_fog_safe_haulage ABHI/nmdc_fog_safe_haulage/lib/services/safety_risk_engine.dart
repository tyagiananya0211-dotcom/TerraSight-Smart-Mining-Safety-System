class RiskOutput {
  final String riskLevel; // SAFE, MODERATE, HIGH, CRITICAL
  final int riskScore; // 0-100
  final double recommendedSpeed; // km/h
  final double requiredSafeDistance; // m
  final double stoppingDistance; // m

  RiskOutput({
    required this.riskLevel,
    required this.riskScore,
    required this.recommendedSpeed,
    required this.requiredSafeDistance,
    required this.stoppingDistance,
  });
}

class SafetyRiskEngine {
  static RiskOutput calculateRisk({
    required double visibility,
    required double speed, // km/h
    required double roadFriction, // 0.0 to 1.0
    required double obstacleDistance,
    required double rainfall,
    required double vehicleLoad, // percentage 0-100
    required double slope, // degrees
    required double sensorConfidence, // percentage 0-100
  }) {
    // 1. Calculate Stopping Distance
    // Simplified physics model for simulation
    double speedMs = speed * (1000 / 3600); // convert km/h to m/s
    double reactionTime = 2.0; // seconds
    double reactionDistance = speedMs * reactionTime;
    
    // Adjust friction based on rainfall and slope
    double effectiveFriction = roadFriction;
    if (rainfall > 0) {
      effectiveFriction -= (rainfall / 100) * 0.2; 
    }
    // Downhill slope increases stopping distance (decreases effective friction representation)
    if (slope < 0) {
      effectiveFriction -= (slope.abs() / 15) * 0.1;
    }
    
    // Adjust for load (heavier vehicle needs more stopping distance)
    double loadFactor = 1.0 + (vehicleLoad / 100) * 0.3;
    
    // Braking distance = v^2 / (2 * u * g)
    double brakingDistance = (speedMs * speedMs) / (2 * effectiveFriction * 9.81) * loadFactor;
    
    double totalStoppingDistance = reactionDistance + brakingDistance;

    // 2. Required Safe Distance
    // Should be stopping distance + buffer based on visibility and sensor confidence
    double buffer = 10.0; // base buffer 10m
    if (visibility < 20) buffer += (20 - visibility);
    if (sensorConfidence < 80) buffer += (80 - sensorConfidence) * 0.5;
    
    double requiredSafeDistance = totalStoppingDistance + buffer;

    // 3. Recommended Speed
    // Reduce speed if visibility is low or required safe distance exceeds obstacle distance
    double recommendedSpeed = 40.0; // max safe speed
    if (visibility < 50) {
      recommendedSpeed = (visibility / 50) * 40;
    }
    if (recommendedSpeed < 10) recommendedSpeed = 10; // min crawl speed
    
    // 4. Calculate Risk Score
    double score = 0;
    
    // Speed risk
    if (speed > recommendedSpeed) {
      score += (speed - recommendedSpeed) * 2;
    }
    
    // Distance risk
    if (obstacleDistance < requiredSafeDistance) {
      score += (requiredSafeDistance - obstacleDistance) * 3;
    }
    
    // Visibility risk
    if (visibility < 15) score += 30;
    else if (visibility < 30) score += 15;
    
    // Sensor risk
    if (sensorConfidence < 70) score += 20;

    score = score.clamp(0, 100);

    // 5. Determine Risk Level
    String riskLevel = 'SAFE';
    if (score > 75) {
      riskLevel = 'CRITICAL';
    } else if (score > 50) {
      riskLevel = 'HIGH';
    } else if (score > 25) {
      riskLevel = 'MODERATE';
    }

    return RiskOutput(
      riskLevel: riskLevel,
      riskScore: score.toInt(),
      recommendedSpeed: recommendedSpeed,
      requiredSafeDistance: requiredSafeDistance,
      stoppingDistance: totalStoppingDistance,
    );
  }
}
