import 'package:flutter_test/flutter_test.dart';
import 'package:nmdc_fog_safe_haulage/services/speed_envelope_service.dart';
import 'package:nmdc_fog_safe_haulage/core/constants/safety_config.dart';
import 'dart:math';

void main() {
  group('SpeedEnvelopeService - computeSafeSpeed', () {
    test('5 meter range should yield low safe speed', () {
      final speed = SpeedEnvelopeService.computeSafeSpeed(
        usableRangeMeters: 5.0,
      );

      // With 5m range, reaction time 1.5s, decel 1.5 m/s²:
      // d = v*t + v²/(2*a)
      // 5 = v*1.5 + v²/(2*1.5)
      // Solving: v ≈ 2.23 m/s ≈ 8.0 km/h
      expect(speed, greaterThan(0));
      expect(speed, lessThan(10)); // Should be quite low
      expect(speed, closeTo(8.0, 1.5)); // Within 1.5 km/h tolerance
    });

    test('10 meter range should yield moderate safe speed', () {
      final speed = SpeedEnvelopeService.computeSafeSpeed(
        usableRangeMeters: 10.0,
      );

      // With 10m range:
      // Expected ≈ 12 km/h
      expect(speed, greaterThan(10));
      expect(speed, lessThan(15));
      expect(speed, closeTo(12.0, 2.0));
    });

    test('20 meter range should yield higher safe speed', () {
      final speed = SpeedEnvelopeService.computeSafeSpeed(
        usableRangeMeters: 20.0,
      );

      // With 20m range:
      // Expected ≈ 19 km/h
      expect(speed, greaterThan(17));
      expect(speed, lessThan(22));
      expect(speed, closeTo(19.0, 2.0));
    });

    test('50 meter range should yield high safe speed', () {
      final speed = SpeedEnvelopeService.computeSafeSpeed(
        usableRangeMeters: 50.0,
      );

      // With 50m range:
      // Expected ≈ 36 km/h
      expect(speed, greaterThan(30));
      expect(speed, lessThan(40)); // Should be capped at maxSafeSpeed
      expect(speed, closeTo(36.0, 3.0));
    });

    test('100 meter range should be capped at maxSafeSpeed', () {
      final speed = SpeedEnvelopeService.computeSafeSpeed(
        usableRangeMeters: 100.0,
      );

      // Should be clamped to max safe speed (40 km/h)
      expect(speed, equals(SafetyConfig.maxSafeSpeed));
    });

    test('zero range should return zero speed', () {
      final speed = SpeedEnvelopeService.computeSafeSpeed(
        usableRangeMeters: 0.0,
      );

      expect(speed, equals(0.0));
    });

    test('negative range should return zero speed', () {
      final speed = SpeedEnvelopeService.computeSafeSpeed(
        usableRangeMeters: -10.0,
      );

      expect(speed, equals(0.0));
    });

    test('invalid deceleration should return zero speed', () {
      final speed = SpeedEnvelopeService.computeSafeSpeed(
        usableRangeMeters: 20.0,
        decelMs2: -1.0, // Invalid negative deceleration
      );

      expect(speed, equals(0.0));
    });

    test('invalid reaction time should return zero speed', () {
      final speed = SpeedEnvelopeService.computeSafeSpeed(
        usableRangeMeters: 20.0,
        reactionSeconds: -1.0, // Invalid negative reaction time
      );

      expect(speed, equals(0.0));
    });

    test('custom deceleration rate should affect result', () {
      final normalSpeed = SpeedEnvelopeService.computeSafeSpeed(
        usableRangeMeters: 20.0,
        decelMs2: 1.5,
      );

      final betterSpeed = SpeedEnvelopeService.computeSafeSpeed(
        usableRangeMeters: 20.0,
        decelMs2: 2.0, // Better brakes
      );

      // Better brakes should allow higher safe speed
      expect(betterSpeed, greaterThan(normalSpeed));
    });

    test('custom reaction time should affect result', () {
      final normalSpeed = SpeedEnvelopeService.computeSafeSpeed(
        usableRangeMeters: 20.0,
        reactionSeconds: 1.5,
      );

      final fasterSpeed = SpeedEnvelopeService.computeSafeSpeed(
        usableRangeMeters: 20.0,
        reactionSeconds: 1.0, // Faster reaction
      );

      // Faster reaction should allow higher safe speed
      expect(fasterSpeed, greaterThan(normalSpeed));
    });
  });

  group('SpeedEnvelopeService - calculateEnvelope', () {
    test('should calculate complete envelope with all metrics', () {
      // Use clear visibility (100m) where ToF works at full range
      final envelope = SpeedEnvelopeService.calculateEnvelope(
        visibilityMeters: 100.0,
        nearestObstacleDistanceMeters: 50.0,
        sensorConfidence: 95.0,
      );

      // Usable range should be limited by ToF nominal range (3m) since obstacle is at 50m
      expect(envelope.tofEffectiveRange, equals(3.0));
      expect(envelope.usableRange, equals(3.0));
      expect(envelope.visibility, equals(100.0));
      expect(envelope.obstacleDistance, equals(50.0));
      expect(envelope.confidence, equals(95.0));
      expect(envelope.limitingSensor, equals("TOF_RANGE"));

      // Safe speed should be based on 3m ToF range
      expect(envelope.safeSpeedLimit, greaterThan(5));
      expect(envelope.safeSpeedLimit, lessThan(10));

      // Human baseline should be much higher (100m visibility)
      expect(envelope.humanBaselineSpeed, equals(SafetyConfig.maxSafeSpeed));

      // Gain ratio should be poor in clear conditions (ToF limiting)
      expect(envelope.speedGainRatio, lessThan(0.3));
    });

    test('sensor-detected obstacle closer than visibility should improve safety', () {
      // Clear conditions with close obstacle
      final envelope = SpeedEnvelopeService.calculateEnvelope(
        visibilityMeters: 100.0,
        nearestObstacleDistanceMeters: 2.0, // Obstacle at 2m (within ToF range)
        sensorConfidence: 95.0,
      );

      // Usable range should be limited by obstacle (2m)
      expect(envelope.usableRange, equals(2.0));
      expect(envelope.limitingSensor, equals("OBSTACLE"));

      // Safe speed should be conservative (based on 2m)
      expect(envelope.safeSpeedLimit, lessThan(7));

      // Human baseline should be much higher (100m visibility)
      expect(envelope.humanBaselineSpeed, equals(SafetyConfig.maxSafeSpeed));

      // NO gain in this case - sensors make us SLOWER for safety
      expect(envelope.speedGainRatio, lessThan(0.2));
    });

    test('ToF degradation in fog should limit usable range', () {
      // Moderate fog (10m visibility) - ToF severely degraded
      final envelope = SpeedEnvelopeService.calculateEnvelope(
        visibilityMeters: 10.0,
        nearestObstacleDistanceMeters: 50.0,
        sensorConfidence: 95.0,
      );

      // ToF effective range at 10m visibility is 1.2m (from calibration curve)
      expect(envelope.tofEffectiveRange, closeTo(1.2, 0.1));

      // Usable range limited by ToF (1.2m), not visibility (10m)
      expect(envelope.usableRange, closeTo(1.2, 0.1));
      expect(envelope.limitingSensor, equals("TOF_RANGE"));

      // Safe speed based on degraded ToF range (~1.2m)
      expect(envelope.safeSpeedLimit, lessThan(5));

      // Human baseline based on 10m visibility
      expect(envelope.humanBaselineSpeed, closeTo(12.0, 2.0));

      // Gain ratio poor due to ToF degradation
      expect(envelope.speedGainRatio, lessThan(0.5));
    });

    test('sensor confidence should be included in envelope', () {
      final highConf = SpeedEnvelopeService.calculateEnvelope(
        visibilityMeters: 30.0,
        nearestObstacleDistanceMeters: 50.0,
        sensorConfidence: 95.0,
      );

      final lowConf = SpeedEnvelopeService.calculateEnvelope(
        visibilityMeters: 30.0,
        nearestObstacleDistanceMeters: 50.0,
        sensorConfidence: 50.0,
      );

      expect(highConf.confidence, equals(95.0));
      expect(lowConf.confidence, equals(50.0));
    });

    test('confidence over 100 should be clamped', () {
      final envelope = SpeedEnvelopeService.calculateEnvelope(
        visibilityMeters: 30.0,
        nearestObstacleDistanceMeters: 50.0,
        sensorConfidence: 150.0, // Invalid
      );

      expect(envelope.confidence, equals(100.0));
    });

    test('negative confidence should be clamped to 0', () {
      final envelope = SpeedEnvelopeService.calculateEnvelope(
        visibilityMeters: 30.0,
        nearestObstacleDistanceMeters: 50.0,
        sensorConfidence: -10.0, // Invalid
      );

      expect(envelope.confidence, equals(0.0));
    });
  });

  group('SpeedEnvelope - status methods', () {
    late SpeedEnvelope envelope;

    setUp(() {
      envelope = SpeedEnvelopeService.calculateEnvelope(
        visibilityMeters: 100.0, // Clear conditions
        nearestObstacleDistanceMeters: 50.0,
      );
    });

    test('isSafe should return true when below limit', () {
      expect(envelope.isSafe(envelope.safeSpeedLimit - 5), isTrue);
      expect(envelope.isSafe(envelope.safeSpeedLimit), isTrue);
    });

    test('isSafe should return false when above limit', () {
      expect(envelope.isSafe(envelope.safeSpeedLimit + 1), isFalse);
    });

    test('isWarning should detect speeds near limit', () {
      final warningSpeed = envelope.safeSpeedLimit * 0.95; // 95% of limit
      expect(envelope.isWarning(warningSpeed), isTrue);
    });

    test('isWarning should be false when well below limit', () {
      final safeSpeed = envelope.safeSpeedLimit * 0.80;
      expect(envelope.isWarning(safeSpeed), isFalse);
    });

    test('isDanger should detect speeds over limit', () {
      expect(envelope.isDanger(envelope.safeSpeedLimit + 1), isTrue);
    });

    test('isDanger should be false when at or below limit', () {
      expect(envelope.isDanger(envelope.safeSpeedLimit), isFalse);
      expect(envelope.isDanger(envelope.safeSpeedLimit - 1), isFalse);
    });
  });

  group('SpeedEnvelopeService - calculateStoppingDistance', () {
    test('should calculate correct stopping distance', () {
      // 30 km/h = 8.33 m/s
      // d = v*t + v²/(2*a) = 8.33*1.5 + 8.33²/(2*1.5)
      // d = 12.5 + 23.15 = 35.65m
      final distance = SpeedEnvelopeService.calculateStoppingDistance(
        speedKmh: 30.0,
      );

      expect(distance, closeTo(35.65, 1.0));
    });

    test('zero speed should give zero stopping distance', () {
      final distance = SpeedEnvelopeService.calculateStoppingDistance(
        speedKmh: 0.0,
      );

      expect(distance, equals(0.0));
    });

    test('higher speed should give longer stopping distance', () {
      final dist20 = SpeedEnvelopeService.calculateStoppingDistance(
        speedKmh: 20.0,
      );

      final dist40 = SpeedEnvelopeService.calculateStoppingDistance(
        speedKmh: 40.0,
      );

      // Stopping distance increases quadratically with speed
      expect(dist40, greaterThan(dist20 * 2));
    });
  });

  group('SpeedEnvelopeService - getSpeedStatus', () {
    test('should return safe when well below limit', () {
      final status = SpeedEnvelopeService.getSpeedStatus(20.0, 30.0);
      expect(status, equals('safe'));
    });

    test('should return warning when near limit', () {
      final status = SpeedEnvelopeService.getSpeedStatus(28.0, 30.0);
      expect(status, equals('warning'));
    });

    test('should return danger when over limit', () {
      final status = SpeedEnvelopeService.getSpeedStatus(31.0, 30.0);
      expect(status, equals('danger'));
    });
  });

  group('Physics Validation', () {
    test('physics formula should be mathematically correct', () {
      // Verify the physics math: d = v*t + v²/(2*a)
      // Rearranged: v = -at + sqrt((at)² + 2ad)

      const a = 1.5; // deceleration
      const t = 1.5; // reaction time
      const d = 20.0; // range

      // Expected velocity in m/s
      final at = a * t;
      final vMs = -at + sqrt(pow(at, 2) + 2 * a * d);
      final vKmh = vMs * 3.6;

      final calculatedSpeed = SpeedEnvelopeService.computeSafeSpeed(
        usableRangeMeters: d,
        decelMs2: a,
        reactionSeconds: t,
      );

      // Verify physics match
      expect(calculatedSpeed, closeTo(vKmh, 0.01));

      // Verify stopping distance matches
      final stoppingDist = SpeedEnvelopeService.calculateStoppingDistance(
        speedKmh: calculatedSpeed,
        decelMs2: a,
        reactionSeconds: t,
      );

      expect(stoppingDist, closeTo(d, 0.1));
    });
  });

  group('Edge Cases', () {
    test('very small range should give very small speed', () {
      final speed = SpeedEnvelopeService.computeSafeSpeed(
        usableRangeMeters: 0.1,
      );

      expect(speed, greaterThanOrEqualTo(0));
      expect(speed, lessThan(1.0));
    });

    test('very large range should be capped', () {
      final speed = SpeedEnvelopeService.computeSafeSpeed(
        usableRangeMeters: 1000.0,
      );

      expect(speed, equals(SafetyConfig.maxSafeSpeed));
    });

    test('calculateEnvelopeWithFallback should use conservative estimate on low confidence', () {
      final envelope = SpeedEnvelopeService.calculateEnvelopeWithFallback(
        visibilityMeters: 100.0, // Clear conditions to test fallback logic
        nearestObstacleDistanceMeters: 50.0,
        sensorConfidence: 50.0, // Below threshold
      );

      // Should fall back to visibility-only (conservative)
      // At 100m visibility, ToF effective range is 3m (ToF always limits in clear)
      // With low confidence, obstacle is ignored (treated as visibility)
      // Usable range = min(100m visibility, 3m ToF, 100m obstacle-ignored) = 3m
      expect(envelope.tofEffectiveRange, equals(3.0));
      expect(envelope.usableRange, closeTo(3.0, 0.1));

      // Gain ratio will be low because ToF limits speed in clear conditions
      // (This is realistic - ToF is not useful in clear conditions)
      expect(envelope.speedGainRatio, lessThan(0.2));
    });

    test('calculateEnvelopeWithFallback should use sensors on high confidence', () {
      final envelope = SpeedEnvelopeService.calculateEnvelopeWithFallback(
        visibilityMeters: 20.0,
        nearestObstacleDistanceMeters: 50.0,
        sensorConfidence: 85.0, // Above threshold
      );

      // Should use sensor data
      expect(envelope.confidence, equals(85.0));
    });
  });
}
