import 'dart:async';
import '../core/constants/safety_config.dart';

/// Speed estimation confidence level
enum SpeedConfidence {
  high,   // PWM stable, no slip detected
  medium, // Minor transients or slight slip
  low,    // Active acceleration, slip, or unreliable data
}

/// Speed estimation result
class SpeedEstimate {
  /// Estimated speed in km/h
  final double speedKmh;

  /// Confidence level of the estimate
  final SpeedConfidence confidence;

  /// Whether wheel slip is detected
  final bool slipDetected;

  /// Speed from PWM calibration table (km/h)
  final double pwmSpeed;

  /// Speed from IMU integration (km/h)
  final double imuSpeed;

  SpeedEstimate({
    required this.speedKmh,
    required this.confidence,
    required this.slipDetected,
    required this.pwmSpeed,
    required this.imuSpeed,
  });

  @override
  String toString() {
    return 'SpeedEstimate(${speedKmh.toStringAsFixed(1)} km/h, '
        'conf: $confidence, slip: $slipDetected)';
  }
}

/// Speed Estimator Service
///
/// IMPORTANT: This estimator exists because the prototype lacks wheel encoders.
/// Production deployment should read speed from:
///   - Vehicle CAN bus (NMDC haul trucks typically support J1939)
///   - Hall-effect wheel sensors
///   - GPS velocity (as fallback)
///
/// This implementation uses TWO sources and fuses them:
///   1. PWM calibration table (stable, drift-free, primary)
///   2. IMU acceleration integration (transient-responsive, drift-prone, secondary)
///
/// Honesty: A confidently wrong number is worse than an honest uncertainty.
/// We surface confidence levels rather than pretending precision we don't have.
class SpeedEstimator {
  // ============================================================================
  // STATE
  // ============================================================================

  /// Current fused speed estimate (km/h)
  double _currentSpeed = 0.0;

  /// IMU-integrated velocity (km/h) - drifts over time
  double _imuIntegratedSpeed = 0.0;

  /// Last PWM value
  int _lastPwm = 0;

  /// Time when PWM last changed
  DateTime _lastPwmChange = DateTime.now();

  /// Whether PWM is currently stable
  bool _isPwmStable = true;

  /// Last IMU acceleration reading (m/s²)
  double _lastImuAccel = 0.0;

  /// Stream controller for speed updates
  final _speedController = StreamController<SpeedEstimate>.broadcast();

  /// Public stream of speed estimates
  Stream<SpeedEstimate> get speedStream => _speedController.stream;

  // ============================================================================
  // CORE ESTIMATION LOGIC
  // ============================================================================

  /// Update speed estimate with new sensor data
  ///
  /// Call this method at regular intervals (e.g., 50Hz) with fresh sensor data
  ///
  /// Parameters:
  ///   [motorPwm] - Current motor PWM value (0-255)
  ///   [forwardAccelMs2] - Forward acceleration from IMU (m/s²)
  ///   [deltaTimeSeconds] - Time since last update (seconds)
  SpeedEstimate updateSpeed({
    required int motorPwm,
    required double forwardAccelMs2,
    required double deltaTimeSeconds,
  }) {
    // ------------------------------------------------------------------------
    // SOURCE A: PWM Calibration Table (Primary, Stable)
    // ------------------------------------------------------------------------

    final pwmSpeed = SafetyConfig.getSpeedFromPWM(motorPwm);

    // Detect PWM stability
    if (motorPwm != _lastPwm) {
      _lastPwmChange = DateTime.now();
      _isPwmStable = false;
      _lastPwm = motorPwm;
    } else {
      final stableDuration =
          DateTime.now().difference(_lastPwmChange).inMilliseconds / 1000.0;
      _isPwmStable = stableDuration >= SafetyConfig.pwmStableWindow;
    }

    // ------------------------------------------------------------------------
    // SOURCE B: IMU Integration (Secondary, Corrective)
    // ------------------------------------------------------------------------

    // Apply high-pass filter to remove DC bias (simple: ignore small values)
    final filteredAccel =
        forwardAccelMs2.abs() > 0.1 ? forwardAccelMs2 : 0.0;

    // Integrate acceleration to get velocity change
    final velocityDeltaMs = filteredAccel * deltaTimeSeconds;
    final velocityDeltaKmh = velocityDeltaMs * 3.6;

    // Update IMU integrated speed
    _imuIntegratedSpeed += velocityDeltaKmh;
    _imuIntegratedSpeed = _imuIntegratedSpeed.clamp(0.0, 50.0); // Sanity check

    // Reset IMU integrator when PWM is stable to eliminate drift
    if (_isPwmStable) {
      _imuIntegratedSpeed = pwmSpeed;
    }

    // ------------------------------------------------------------------------
    // FUSION: Complementary Filter
    // ------------------------------------------------------------------------

    // Heavily trust PWM (alpha = 0.9), use IMU to catch transients
    final alpha = SafetyConfig.speedFusionAlpha;
    _currentSpeed = alpha * pwmSpeed + (1 - alpha) * _imuIntegratedSpeed;
    _currentSpeed = _currentSpeed.clamp(0.0, 50.0);

    // ------------------------------------------------------------------------
    // WHEEL SLIP DETECTION
    // ------------------------------------------------------------------------

    // Expected acceleration from PWM change
    final expectedAccel = _computeExpectedAcceleration(motorPwm, _lastPwm);

    // If PWM indicates we should be accelerating but IMU says we're not,
    // we have wheel slip (wet surface, loose gravel, etc.)
    final slipDetected = expectedAccel > 0.5 &&
        forwardAccelMs2.abs() < SafetyConfig.slipDetectionThreshold;

    _lastImuAccel = forwardAccelMs2;

    // ------------------------------------------------------------------------
    // CONFIDENCE ASSESSMENT
    // ------------------------------------------------------------------------

    SpeedConfidence confidence;

    if (slipDetected) {
      confidence = SpeedConfidence.low;
    } else if (_isPwmStable && forwardAccelMs2.abs() < 0.3) {
      confidence = SpeedConfidence.high;
    } else if (forwardAccelMs2.abs() > 1.0 || !_isPwmStable) {
      confidence = SpeedConfidence.medium;
    } else {
      confidence = SpeedConfidence.high;
    }

    // ------------------------------------------------------------------------
    // EMIT RESULT
    // ------------------------------------------------------------------------

    final estimate = SpeedEstimate(
      speedKmh: _currentSpeed,
      confidence: confidence,
      slipDetected: slipDetected,
      pwmSpeed: pwmSpeed,
      imuSpeed: _imuIntegratedSpeed,
    );

    _speedController.add(estimate);
    return estimate;
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Compute expected acceleration based on PWM change
  ///
  /// This is a rough estimate - actual acceleration depends on load, slope, etc.
  double _computeExpectedAcceleration(int currentPwm, int previousPwm) {
    // Simple heuristic: if PWM increased significantly, we expect acceleration
    final pwmDelta = currentPwm - previousPwm;

    if (pwmDelta > 20) return 1.0; // Strong acceleration expected
    if (pwmDelta > 10) return 0.5; // Moderate acceleration expected
    if (pwmDelta < -20) return -1.0; // Deceleration expected

    return 0.0; // No significant change
  }

  /// Reset the estimator state
  ///
  /// Call this when vehicle is known to be stopped (e.g., handbrake engaged)
  void reset() {
    _currentSpeed = 0.0;
    _imuIntegratedSpeed = 0.0;
    _lastPwm = 0;
    _isPwmStable = true;
    _lastImuAccel = 0.0;
  }

  /// Get current speed estimate without updating
  double getCurrentSpeed() => _currentSpeed;

  /// Check if current estimate has high confidence
  bool hasHighConfidence() => _isPwmStable && !_detectSlipCondition();

  /// Internal slip detection check
  bool _detectSlipCondition() {
    return _lastPwm > 100 && _lastImuAccel.abs() < 0.2;
  }

  // ============================================================================
  // CALIBRATION HELPERS
  // ============================================================================

  /// Generate calibration data (for documentation purposes)
  ///
  /// This would be run during initial setup with a measured course.
  /// Results are then hardcoded into SafetyConfig.pwmSpeedTable
  static String generateCalibrationInstructions() {
    return '''
PWM-to-Speed Calibration Procedure:

1. Mark a 3-meter course on flat, dry ground
2. For each PWM value [80, 120, 160, 200, 255]:
   a. Set motor to target PWM
   b. Allow vehicle to reach steady-state speed
   c. Time how long it takes to traverse 3-meter course
   d. Calculate speed: (3 meters / time_seconds) * 3.6 = km/h
   e. Repeat 3 times and average
3. Record results in SafetyConfig.pwmSpeedTable

Example calculation:
  - PWM 120, time = 0.71s → speed = (3/0.71)*3.6 = 15.2 km/h
''';
  }

  /// Dispose of resources
  void dispose() {
    _speedController.close();
  }
}

// ==============================================================================
// PRODUCTION DEPLOYMENT NOTES
// ==============================================================================

/// TODO: For production deployment with real NMDC haul trucks:
///
/// 1. PREFERRED: Read speed from vehicle CAN bus
///    - Most NMDC haul trucks support SAE J1939 protocol
///    - Speed available on PGN 65265 (Cruise Control/Vehicle Speed)
///    - This gives actual ground speed from transmission/wheel sensors
///
/// 2. ALTERNATIVE: Install hall-effect wheel sensors
///    - Magnetic sensor on wheel hub
///    - Count pulses to measure rotation
///    - More accurate than PWM estimation
///
/// 3. FALLBACK: GPS velocity
///    - Available from geolocator package
///    - Less accurate at low speeds, but better than nothing
///    - Update rate typically 1Hz (too slow for real-time control)
///
/// 4. KEEP THIS ESTIMATOR FOR:
///    - Prototype demonstrations without CAN access
///    - Redundancy/sanity checking against CAN data
///    - Research/development environments
