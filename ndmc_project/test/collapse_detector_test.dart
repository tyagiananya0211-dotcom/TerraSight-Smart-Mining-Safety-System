import 'package:flutter_test/flutter_test.dart';
import 'package:nmdc_fog_safe_haulage/services/collapse_detector.dart';

void main() {
  group('CollapseDetector', () {
    late CollapseDetector detector;

    setUp(() {
      detector = CollapseDetector();
    });

    group('Baseline Calculation', () {
      test('should initialize with default baseline of 100.0', () {
        expect(detector.baseline, equals(100.0));
        expect(detector.currentState, equals("OK"));
        expect(detector.sampleCount, equals(0));
      });

      test('should build baseline from samples (median)', () {
        // Feed 20 samples to build baseline
        for (int i = 0; i < 20; i++) {
          detector.processSample(100.0);
        }

        expect(detector.sampleCount, equals(20));
        expect(detector.baseline, equals(100.0));
      });

      test('should use median for baseline (robust against outliers)', () {
        // Feed mostly 100.0 with some outliers
        for (int i = 0; i < 18; i++) {
          detector.processSample(100.0);
        }
        detector.processSample(200.0); // Outlier
        detector.processSample(300.0); // Outlier

        // Baseline should be close to 100.0 (median), not affected by outliers
        expect(detector.baseline, closeTo(100.0, 5.0));
      });

      test('should update baseline with rolling window', () {
        // Build initial baseline at 100 cm
        for (int i = 0; i < 20; i++) {
          detector.processSample(100.0);
        }
        expect(detector.baseline, equals(100.0));

        // Feed new samples at 120 cm - baseline should slowly shift
        for (int i = 0; i < 20; i++) {
          detector.processSample(120.0);
        }

        // After 20 new samples, baseline should have moved to 120 cm
        expect(detector.baseline, equals(120.0));
      });
    });

    group('CAUTION Detection (>30% deviation)', () {
      test('should trigger CAUTION when deviation exceeds 30%', () {
        // Build baseline at 100 cm
        for (int i = 0; i < 20; i++) {
          detector.processSample(100.0);
        }

        // Feed sample with >30% deviation (140 cm = 40% deviation)
        final state = detector.processSample(140.0);

        expect(state, equals("CAUTION"));
        expect(detector.currentState, equals("CAUTION"));
      });

      test('should stay OK when deviation is under 30%', () {
        // Build baseline at 100 cm
        for (int i = 0; i < 20; i++) {
          detector.processSample(100.0);
        }

        // Feed sample with <30% deviation (125 cm = 25% deviation)
        final state = detector.processSample(125.0);

        expect(state, equals("OK"));
      });

      test('should return to OK when deviation drops below 30%', () {
        // Build baseline at 100 cm
        for (int i = 0; i < 20; i++) {
          detector.processSample(100.0);
        }

        // Trigger CAUTION
        detector.processSample(140.0);
        expect(detector.currentState, equals("CAUTION"));

        // Return to normal
        final state = detector.processSample(110.0);
        expect(state, equals("OK"));
      });
    });

    group('HAZARD Detection (>60% for 3 consecutive)', () {
      test('should require 3 consecutive samples above 60% for HAZARD', () {
        // Build baseline at 100 cm
        for (int i = 0; i < 20; i++) {
          detector.processSample(100.0);
        }

        // First >60% sample - should be CAUTION, not HAZARD
        String state = detector.processSample(170.0); // 70% deviation
        expect(state, equals("CAUTION"));

        // Second >60% sample - still CAUTION
        state = detector.processSample(170.0);
        expect(state, equals("CAUTION"));

        // Third >60% sample - now HAZARD
        state = detector.processSample(170.0);
        expect(state, equals("HAZARD"));
      });

      test('should reset consecutive counter if deviation drops below 60%', () {
        // Build baseline at 100 cm
        for (int i = 0; i < 20; i++) {
          detector.processSample(100.0);
        }

        // Two HAZARD samples
        detector.processSample(170.0);
        detector.processSample(170.0);
        expect(detector.currentState, equals("CAUTION"));

        // Drop below 60% (but still above 30%)
        detector.processSample(140.0); // 40% deviation
        expect(detector.currentState, equals("CAUTION"));

        // Back to >60% - counter should have reset, so still CAUTION
        detector.processSample(170.0);
        expect(detector.currentState, equals("CAUTION"));
      });

      test('should maintain HAZARD state once triggered', () {
        // Build baseline at 100 cm
        for (int i = 0; i < 20; i++) {
          detector.processSample(100.0);
        }

        // Trigger HAZARD (3 consecutive >60%)
        detector.processSample(170.0);
        detector.processSample(170.0);
        detector.processSample(170.0);
        expect(detector.currentState, equals("HAZARD"));

        // Continue with >60% samples - should stay HAZARD
        final state = detector.processSample(180.0);
        expect(state, equals("HAZARD"));
      });

      test('should clear HAZARD only when deviation drops below 60%', () {
        // Build baseline at 100 cm
        for (int i = 0; i < 20; i++) {
          detector.processSample(100.0);
        }

        // Trigger HAZARD
        detector.processSample(170.0);
        detector.processSample(170.0);
        detector.processSample(170.0);
        expect(detector.currentState, equals("HAZARD"));

        // Drop to CAUTION zone (30-60%)
        final state = detector.processSample(140.0); // 40% deviation
        expect(state, equals("CAUTION"));

        // Drop to OK
        final okState = detector.processSample(110.0); // 10% deviation
        expect(okState, equals("OK"));
      });
    });

    group('Invalid Input Handling', () {
      test('should ignore zero or negative readings', () {
        // Build baseline
        for (int i = 0; i < 20; i++) {
          detector.processSample(100.0);
        }

        final initialState = detector.currentState;

        // Send invalid readings
        detector.processSample(0.0);
        detector.processSample(-10.0);

        // State should not change
        expect(detector.currentState, equals(initialState));
        expect(detector.sampleCount, equals(20)); // No new samples added
      });

      test('should ignore readings above 1000 cm', () {
        // Build baseline
        for (int i = 0; i < 20; i++) {
          detector.processSample(100.0);
        }

        // Send invalid reading
        detector.processSample(1500.0);

        // Should not be added to buffer
        expect(detector.sampleCount, equals(20));
      });
    });

    group('Calibration', () {
      test('calibrate() should reset baseline to current reading', () {
        // Build baseline at 100 cm
        for (int i = 0; i < 20; i++) {
          detector.processSample(100.0);
        }
        expect(detector.baseline, equals(100.0));

        // Trigger HAZARD
        detector.processSample(170.0);
        detector.processSample(170.0);
        detector.processSample(170.0);
        expect(detector.currentState, equals("HAZARD"));

        // Calibrate at 150 cm (new flat ground)
        detector.calibrate(150.0);

        // Should reset state and baseline
        expect(detector.currentState, equals("OK"));
        expect(detector.baseline, equals(150.0));
        expect(detector.sampleCount, equals(20));
      });

      test('calibrate() should seed buffer with current reading', () {
        detector.calibrate(120.0);

        // All samples should be 120.0
        expect(detector.baseline, equals(120.0));
        expect(detector.sampleCount, equals(20));

        // Next sample at 120.0 should be OK
        final state = detector.processSample(120.0);
        expect(state, equals("OK"));
      });
    });

    group('Reset', () {
      test('reset() should return to initial state', () {
        // Build baseline and trigger HAZARD
        for (int i = 0; i < 20; i++) {
          detector.processSample(100.0);
        }
        detector.processSample(170.0);
        detector.processSample(170.0);
        detector.processSample(170.0);

        // Reset
        detector.reset();

        // Should be back to initial state
        expect(detector.currentState, equals("OK"));
        expect(detector.baseline, equals(100.0));
        expect(detector.sampleCount, equals(0));
      });
    });

    group('Diagnostics', () {
      test('getDiagnostics() should return correct information', () {
        // Build baseline at 100 cm
        for (int i = 0; i < 20; i++) {
          detector.processSample(100.0);
        }

        // Sample at 140 cm (40% deviation)
        detector.processSample(140.0);

        final diag = detector.getDiagnostics(140.0);

        expect(diag['baseline'], equals('100.0'));
        expect(diag['current'], equals('140.0'));
        expect(diag['deviation'], equals('40.0'));
        expect(diag['deviationPercent'], equals('40.0'));
        expect(diag['state'], equals('CAUTION'));
        expect(diag['sampleCount'], equals(20));
      });

      test('getDiagnostics() should show consecutive count during hazard buildup', () {
        // Build baseline
        for (int i = 0; i < 20; i++) {
          detector.processSample(100.0);
        }

        // First hazard sample
        detector.processSample(170.0);
        var diag = detector.getDiagnostics(170.0);
        expect(diag['consecutiveHazardCount'], equals(1));

        // Second hazard sample
        detector.processSample(170.0);
        diag = detector.getDiagnostics(170.0);
        expect(diag['consecutiveHazardCount'], equals(2));

        // Third hazard sample
        detector.processSample(170.0);
        diag = detector.getDiagnostics(170.0);
        expect(diag['consecutiveHazardCount'], equals(3));
        expect(diag['state'], equals('HAZARD'));
      });
    });

    group('Real-World Scenarios', () {
      test('should detect sudden edge collapse (100 cm -> 180 cm)', () {
        // Normal driving on flat road (100 cm ground clearance)
        for (int i = 0; i < 20; i++) {
          detector.processSample(100.0);
        }

        // Vehicle approaches collapsed edge - ground distance suddenly increases
        // Consecutive readings showing drop-off
        detector.processSample(180.0); // CAUTION
        expect(detector.currentState, equals("CAUTION"));

        detector.processSample(185.0); // Still CAUTION
        expect(detector.currentState, equals("CAUTION"));

        detector.processSample(190.0); // HAZARD triggered
        expect(detector.currentState, equals("HAZARD"));
      });

      test('should tolerate normal road undulation (±15%)', () {
        // Build baseline at 100 cm
        for (int i = 0; i < 20; i++) {
          detector.processSample(100.0);
        }

        // Simulate normal bumpy road (±15% variation)
        detector.processSample(110.0); // +10%
        expect(detector.currentState, equals("OK"));

        detector.processSample(95.0); // -5%
        expect(detector.currentState, equals("OK"));

        detector.processSample(115.0); // +15%
        expect(detector.currentState, equals("OK"));

        detector.processSample(90.0); // -10%
        expect(detector.currentState, equals("OK"));
      });

      test('should handle gradual slope change (not collapse)', () {
        // Build baseline at 100 cm
        for (int i = 0; i < 20; i++) {
          detector.processSample(100.0);
        }

        // Gradual uphill - ground clearance increases slowly
        detector.processSample(105.0);
        detector.processSample(110.0);
        detector.processSample(115.0);
        detector.processSample(120.0);

        // Should stay OK because deviation is gradual and <30%
        expect(detector.currentState, equals("OK"));
      });

      test('should suppress single-spike false positive', () {
        // Build baseline
        for (int i = 0; i < 20; i++) {
          detector.processSample(100.0);
        }

        // Single spike (sensor glitch or small rock)
        detector.processSample(180.0); // Would be HAZARD if sustained
        expect(detector.currentState, equals("CAUTION"));

        // Back to normal
        detector.processSample(100.0);
        expect(detector.currentState, equals("OK"));

        // HAZARD should NOT have been triggered (only 1 sample, not 3)
      });
    });
  });
}
