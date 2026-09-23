/// Safety Configuration Constants
///
/// This file contains all tunable safety parameters for the Visibility-Indexed
/// Safe Speed Envelope system. These values are based on engineering standards
/// for loaded haul trucks operating in mining conditions.
///
/// References:
/// - Deceleration: Conservative value for fully loaded 85-ton haul truck
///   on wet haul road with applied brakes (1.5 m/s²)
/// - Reaction time: MSHA standard driver reaction time (1.5 seconds)
/// - Max safe speed: Site-specific speed limit for NMDC operations

class SafetyConfig {
  // ============================================================================
  // SPEED ENVELOPE PARAMETERS
  // ============================================================================

  /// Conservative deceleration rate for a loaded haul truck (m/s²)
  ///
  /// This accounts for:
  /// - Loaded vehicle weight (85+ tons)
  /// - Wet/slippery mine haul road conditions
  /// - Brake system response time
  /// - Safety margin for emergency stops
  static const double decelerationRate = 1.5; // m/s²

  /// Standard driver reaction time (seconds)
  ///
  /// Based on MSHA (Mine Safety and Health Administration) standards
  /// for heavy vehicle operators in adverse conditions.
  static const double reactionTime = 1.5; // seconds

  /// Maximum safe speed limit for site operations (km/h)
  ///
  /// Site-specific limit based on NMDC operating procedures
  static const double maxSafeSpeed = 40.0; // km/h

  /// Minimum safe speed (km/h)
  ///
  /// Below this speed, vehicle should be stopped
  static const double minSafeSpeed = 0.0; // km/h

  // ============================================================================
  // SPEED ESTIMATOR PARAMETERS
  // ============================================================================

  /// Complementary filter weight for PWM-based speed estimation
  ///
  /// Higher alpha = more trust in PWM table (stable, drift-free)
  /// Lower alpha = more trust in IMU integration (captures transients)
  static const double speedFusionAlpha = 0.9;

  /// Time window for PWM stability detection (seconds)
  ///
  /// PWM must remain constant for this duration before we reset
  /// IMU integrator to eliminate drift
  static const double pwmStableWindow = 1.0; // seconds

  /// Wheel slip detection threshold
  ///
  /// If IMU acceleration is below this threshold while PWM indicates
  /// acceleration, we flag wheel slip
  static const double slipDetectionThreshold = 0.2; // m/s²

  // ============================================================================
  // PWM CALIBRATION TABLE
  // ============================================================================

  /// PWM to Speed calibration table
  ///
  /// Generated from controlled 3-meter course runs at various PWM values.
  /// Each value repeated 3 times and averaged for accuracy.
  ///
  /// Format: [PWM_value, Speed_in_km/h]
  ///
  /// NOTE: Production deployment should read speed from vehicle CAN bus
  /// or hall-effect wheel sensor. This calibration exists because the
  /// prototype lacks wheel encoders.
  static const List<List<double>> pwmSpeedTable = [
    [0, 0.0],       // Stopped
    [80, 8.5],      // Low crawl
    [120, 15.2],    // Moderate
    [160, 22.8],    // Medium
    [200, 31.5],    // High
    [255, 38.0],    // Maximum
  ];

  // ============================================================================
  // SENSOR PARAMETERS
  // ============================================================================

  /// Maximum effective range of visibility sensors (meters)
  ///
  /// Beyond this range, sensor data becomes unreliable
  static const double sensorMaxRange = 100.0; // meters

  /// Minimum confidence threshold for sensor data (0-100)
  ///
  /// Below this confidence, speed envelope calculations should
  /// fall back to conservative estimates
  static const double minSensorConfidence = 70.0;

  // ============================================================================
  // ToF FOG DEGRADATION CALIBRATION
  // ============================================================================

  /// ToF Sensor Fog Degradation Calibration Curve
  ///
  /// PHYSICS: Infrared ToF sensors (850-940nm) suffer from backscatter in fog.
  /// Water droplets scatter IR light, causing false short readings.
  /// Effective range degrades exponentially as fog density increases.
  ///
  /// METHODOLOGY: Characterization test procedure (performed on prototype):
  /// - Fixed target at known distance (3.0m)
  /// - Introduce fog with humidifier at varying densities
  /// - Record ToF readings vs estimated visibility
  /// - 20+ data points across visibility range 5m-100m
  ///
  /// RESULTS: Empirical curve showing ToF effective range vs visibility
  ///
  /// Format: [visibility_meters, tof_effective_range_meters]
  ///
  /// SAFETY NOTE: This curve is CONSERVATIVE. In production, perform
  /// site-specific calibration with actual fog conditions.
  static const List<List<double>> tofFogDegradationCurve = [
    // Dense fog - severe degradation
    [5.0, 0.5],    // At 5m visibility, ToF only reliable to 0.5m
    [7.5, 0.8],    // Moderate improvement
    [10.0, 1.2],   // Still heavily degraded

    // Moderate fog - significant degradation
    [15.0, 1.8],   // ToF range improving
    [20.0, 2.2],   // Usable but degraded
    [30.0, 2.6],   // Approaching nominal performance

    // Light fog - minimal degradation
    [40.0, 2.8],   // Near-nominal performance
    [50.0, 2.9],   // Minimal degradation

    // Clear conditions - full performance
    [75.0, 3.0],   // Full ToF range (3m nominal)
    [100.0, 3.0],  // Full ToF range
  ];

  /// Nominal ToF sensor range (meters) in clear conditions
  static const double tofNominalRange = 3.0;

  /// Get effective ToF range based on current visibility
  ///
  /// Uses linear interpolation between calibration points.
  /// Extrapolates conservatively outside calibration range.
  static double getTofEffectiveRange(double visibilityMeters) {
    // Clamp visibility to reasonable range
    final vis = visibilityMeters.clamp(0.0, 200.0);

    // Handle edge cases
    if (vis <= tofFogDegradationCurve.first[0]) {
      // Below minimum calibration point - use minimum effective range
      return tofFogDegradationCurve.first[1];
    }

    if (vis >= tofFogDegradationCurve.last[0]) {
      // Above maximum calibration point - use nominal range
      return tofFogDegradationCurve.last[1];
    }

    // Find interpolation points
    for (int i = 0; i < tofFogDegradationCurve.length - 1; i++) {
      final lower = tofFogDegradationCurve[i];
      final upper = tofFogDegradationCurve[i + 1];

      if (vis >= lower[0] && vis <= upper[0]) {
        // Linear interpolation
        final t = (vis - lower[0]) / (upper[0] - lower[0]);
        return lower[1] + t * (upper[1] - lower[1]);
      }
    }

    // Fallback (should never reach here)
    return tofFogDegradationCurve.first[1];
  }

  // ============================================================================
  // UI ALERT THRESHOLDS
  // ============================================================================

  /// Speed limit warning threshold (percentage)
  ///
  /// Warning (amber) shown when speed exceeds this percentage of safe limit
  static const double warningThreshold = 0.90; // 90%

  /// Audio alert debounce time (seconds)
  ///
  /// Minimum time between consecutive audio alerts to prevent alert fatigue
  static const double audioDebounceTime = 3.0; // seconds

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Get interpolated speed from PWM value
  static double getSpeedFromPWM(int pwm) {
    // Clamp PWM to valid range
    final clampedPwm = pwm.clamp(0, 255).toDouble();

    // Find the two points to interpolate between
    for (int i = 0; i < pwmSpeedTable.length - 1; i++) {
      final lower = pwmSpeedTable[i];
      final upper = pwmSpeedTable[i + 1];

      if (clampedPwm >= lower[0] && clampedPwm <= upper[0]) {
        // Linear interpolation
        final t = (clampedPwm - lower[0]) / (upper[0] - lower[0]);
        return lower[1] + t * (upper[1] - lower[1]);
      }
    }

    // If PWM is at or beyond the maximum, return max speed
    return pwmSpeedTable.last[1];
  }
}
