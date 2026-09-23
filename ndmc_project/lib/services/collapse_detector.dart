import 'dart:collection';

/// Road-Edge Collapse Detection Service
///
/// This is our most fog-immune safety feature. It detects when the road
/// drops away (collapsed bench edge, trench, washout) by monitoring the
/// downward-facing ultrasonic sensor.
///
/// KEY ADVANTAGE: Works identically at 5m visibility and 500m visibility.
/// Fog doesn't affect downward ground distance measurement.
///
/// PRINCIPLE:
/// - Normal road undulation: ±10-20% variation
/// - Edge collapse: >60% sudden drop
///
/// SAFETY APPROACH:
/// - CAUTION: >30% deviation (might be steep ramp or pothole)
/// - HAZARD: >60% deviation for 3 CONSECUTIVE samples (edge collapse)
/// - Consecutive requirement suppresses single-spike false positives
class CollapseDetector {
  /// Rolling baseline buffer (last 20 samples)
  final _baselineBuffer = Queue<double>();
  static const int _baselineWindowSize = 20;

  /// Consecutive hazard sample counter
  int _consecutiveHazardCount = 0;
  static const int _hazardConsecutiveThreshold = 3;

  /// Current baseline (median of buffer)
  double _baseline = 100.0; // Initial safe default

  /// Thresholds for detection
  static const double cautionThreshold = 0.30; // 30% above baseline
  static const double hazardThreshold = 0.60;  // 60% above baseline

  /// Current detection state
  String _currentState = "OK"; // OK, CAUTION, HAZARD
  String get currentState => _currentState;

  /// Baseline value for display/debugging
  double get baseline => _baseline;

  /// Number of samples in baseline buffer
  int get sampleCount => _baselineBuffer.length;

  /// Process new ground distance sample
  ///
  /// Returns: Detection state ("OK", "CAUTION", "HAZARD")
  String processSample(double groundDistance) {
    // Validate input
    if (groundDistance <= 0 || groundDistance > 1000.0) {
      // Invalid reading - ignore
      return _currentState;
    }

    // Add to rolling buffer
    _baselineBuffer.addLast(groundDistance);
    if (_baselineBuffer.length > _baselineWindowSize) {
      _baselineBuffer.removeFirst();
    }

    // Update baseline (median of buffer)
    _updateBaseline();

    // Calculate deviation from baseline
    final deviation = groundDistance - _baseline;
    final deviationPercent = deviation / _baseline;

    // Determine state based on deviation
    if (deviationPercent > hazardThreshold) {
      // Potential HAZARD - increment consecutive counter
      _consecutiveHazardCount++;

      if (_consecutiveHazardCount >= _hazardConsecutiveThreshold) {
        _currentState = "HAZARD";
      } else {
        // Not yet consecutive threshold - still CAUTION
        _currentState = "CAUTION";
      }
    } else if (deviationPercent > cautionThreshold) {
      // CAUTION zone
      _currentState = "CAUTION";
      _consecutiveHazardCount = 0; // Reset consecutive counter
    } else {
      // Normal operation
      _currentState = "OK";
      _consecutiveHazardCount = 0; // Reset consecutive counter
    }

    return _currentState;
  }

  /// Update baseline using median of buffer
  void _updateBaseline() {
    if (_baselineBuffer.isEmpty) return;

    // Calculate median (more robust than mean for outlier rejection)
    final sorted = List<double>.from(_baselineBuffer)..sort();
    final mid = sorted.length ~/ 2;

    if (sorted.length.isEven) {
      _baseline = (sorted[mid - 1] + sorted[mid]) / 2;
    } else {
      _baseline = sorted[mid];
    }
  }

  /// Calibrate baseline on known flat ground
  ///
  /// Call this when the vehicle is stopped on flat, stable ground.
  /// Clears the buffer and sets the next 20 samples as the new baseline.
  ///
  /// Parameters:
  ///   [currentGroundDistance] - Current reading from downward ultrasonic
  void calibrate(double currentGroundDistance) {
    _baselineBuffer.clear();
    _consecutiveHazardCount = 0;
    _currentState = "OK";

    // Seed buffer with current reading
    for (int i = 0; i < _baselineWindowSize; i++) {
      _baselineBuffer.addLast(currentGroundDistance);
    }

    _updateBaseline();
  }

  /// Get diagnostic information for display
  Map<String, dynamic> getDiagnostics(double currentGroundDistance) {
    final deviation = currentGroundDistance - _baseline;
    final deviationPercent = (deviation / _baseline) * 100;

    return {
      'baseline': _baseline.toStringAsFixed(1),
      'current': currentGroundDistance.toStringAsFixed(1),
      'deviation': deviation.toStringAsFixed(1),
      'deviationPercent': deviationPercent.toStringAsFixed(1),
      'state': _currentState,
      'consecutiveHazardCount': _consecutiveHazardCount,
      'sampleCount': _baselineBuffer.length,
    };
  }

  /// Reset detector to initial state
  void reset() {
    _baselineBuffer.clear();
    _consecutiveHazardCount = 0;
    _currentState = "OK";
    _baseline = 100.0;
  }
}
