import 'package:flutter_test/flutter_test.dart';
import 'package:nmdc_fog_safe_haulage/models/telemetry.dart';
import 'dart:convert';

void main() {
  group('Telemetry Model', () {
    group('JSON Serialization', () {
      test('toJson should use wire-format short keys', () {
        final telemetry = Telemetry(
          vehicleId: "DMP-01",
          timestampMs: 1234567890,
          frontDistance: 150.5,
          groundDistance: 95.2,
          groundBaseline: 100.0,
          tofSweep: [
            RadarPoint(angle: 45.0, dist: 120.0),
            RadarPoint(angle: 90.0, dist: 200.0),
          ],
          visibilityMeters: 25.5,
          visConfidence: "HIGH",
          temperature: 28.3,
          humidity: 75.8,
          dewPointSpread: 4.2,
          ambientLux: 450.0,
          pitch: 5.5,
          roll: -2.3,
          yawRate: 1.2,
          motorPwm: 180,
          speed: 25.7,
          safeSpeedLimit: 30.0,
          humanBaselineSpeed: 20.0,
          speedGainRatio: 1.5,
          ttc: 5.8,
          alertState: "CAUTION",
          isSimulated: false,
        );

        final json = telemetry.toJson();

        // Verify wire-format short keys
        expect(json['vid'], equals("DMP-01"));
        expect(json['ts'], equals(1234567890));
        expect(json['fd'], equals(150.5));
        expect(json['gd'], equals(95.2));
        expect(json['gb'], equals(100.0));
        expect(json['sweep'], isA<List>());
        expect(json['sweep'].length, equals(2));
        expect(json['vis'], equals(25.5));
        expect(json['vis_conf'], equals("HIGH"));
        expect(json['temp'], equals(28.3));
        expect(json['hum'], equals(75.8));
        expect(json['dps'], equals(4.2));
        expect(json['lux'], equals(450.0));
        expect(json['pitch'], equals(5.5));
        expect(json['roll'], equals(-2.3));
        expect(json['yaw'], equals(1.2));
        expect(json['pwm'], equals(180));
        expect(json['spd'], equals(25.7));
        expect(json['safe'], equals(30.0));
        expect(json['base'], equals(20.0));
        expect(json['gain'], equals(1.5));
        expect(json['ttc'], equals(5.8));
        expect(json['alert'], equals("CAUTION"));
        expect(json['sim'], equals(false));
      });

      test('fromJson should parse wire-format correctly', () {
        final json = {
          'vid': "DMP-02",
          'ts': 9876543210,
          'fd': 200.5,
          'gd': 105.0,
          'gb': 100.0,
          'sweep': [
            {'a': 30.0, 'd': 150.0},
            {'a': 60.0, 'd': 180.0},
          ],
          'vis': 15.2,
          'vis_conf': "LOW",
          'temp': 22.5,
          'hum': 85.0,
          'dps': 2.5,
          'lux': 300.0,
          'pitch': -3.2,
          'roll': 1.8,
          'yaw': 0.5,
          'pwm': 150,
          'spd': 18.5,
          'safe': 20.0,
          'ttc': 8.5,
          'alert': "OK",
          'sim': true,
        };

        final telemetry = Telemetry.fromJson(json);

        expect(telemetry.vehicleId, equals("DMP-02"));
        expect(telemetry.timestampMs, equals(9876543210));
        expect(telemetry.frontDistance, equals(200.5));
        expect(telemetry.groundDistance, equals(105.0));
        expect(telemetry.groundBaseline, equals(100.0));
        expect(telemetry.tofSweep.length, equals(2));
        expect(telemetry.tofSweep[0].angle, equals(30.0));
        expect(telemetry.tofSweep[0].dist, equals(150.0));
        expect(telemetry.visibilityMeters, equals(15.2));
        expect(telemetry.visConfidence, equals("LOW"));
        expect(telemetry.temperature, equals(22.5));
        expect(telemetry.humidity, equals(85.0));
        expect(telemetry.dewPointSpread, equals(2.5));
        expect(telemetry.ambientLux, equals(300.0));
        expect(telemetry.pitch, equals(-3.2));
        expect(telemetry.roll, equals(1.8));
        expect(telemetry.yawRate, equals(0.5));
        expect(telemetry.motorPwm, equals(150));
        expect(telemetry.speed, equals(18.5));
        expect(telemetry.safeSpeedLimit, equals(20.0));
        expect(telemetry.ttc, equals(8.5));
        expect(telemetry.alertState, equals("OK"));
        expect(telemetry.isSimulated, equals(true));
      });

      test('round-trip serialization should preserve all data', () {
        final original = Telemetry(
          vehicleId: "DMP-03",
          timestampMs: 1111111111,
          frontDistance: 175.3,
          groundDistance: 98.7,
          groundBaseline: 100.0,
          tofSweep: [
            RadarPoint(angle: 0.0, dist: 100.0),
            RadarPoint(angle: 180.0, dist: 250.0),
          ],
          visibilityMeters: 30.0,
          visConfidence: "HIGH",
          temperature: 25.0,
          humidity: 70.0,
          dewPointSpread: 5.0,
          ambientLux: 500.0,
          pitch: 0.0,
          roll: 0.0,
          yawRate: 0.0,
          motorPwm: 200,
          speed: 35.0,
          safeSpeedLimit: 40.0,
          humanBaselineSpeed: 30.0,
          speedGainRatio: 1.33,
          ttc: 10.0,
          alertState: "HAZARD",
          isSimulated: false,
        );

        // Serialize
        final json = original.toJson();

        // Deserialize
        final roundTrip = Telemetry.fromJson(json);

        // Verify all fields match
        expect(roundTrip.vehicleId, equals(original.vehicleId));
        expect(roundTrip.timestampMs, equals(original.timestampMs));
        expect(roundTrip.frontDistance, equals(original.frontDistance));
        expect(roundTrip.groundDistance, equals(original.groundDistance));
        expect(roundTrip.groundBaseline, equals(original.groundBaseline));
        expect(roundTrip.tofSweep.length, equals(original.tofSweep.length));
        expect(roundTrip.visibilityMeters, equals(original.visibilityMeters));
        expect(roundTrip.visConfidence, equals(original.visConfidence));
        expect(roundTrip.temperature, equals(original.temperature));
        expect(roundTrip.humidity, equals(original.humidity));
        expect(roundTrip.dewPointSpread, equals(original.dewPointSpread));
        expect(roundTrip.ambientLux, equals(original.ambientLux));
        expect(roundTrip.pitch, equals(original.pitch));
        expect(roundTrip.roll, equals(original.roll));
        expect(roundTrip.yawRate, equals(original.yawRate));
        expect(roundTrip.motorPwm, equals(original.motorPwm));
        expect(roundTrip.speed, equals(original.speed));
        expect(roundTrip.safeSpeedLimit, equals(original.safeSpeedLimit));
        expect(roundTrip.ttc, equals(original.ttc));
        expect(roundTrip.alertState, equals(original.alertState));
        expect(roundTrip.isSimulated, equals(original.isSimulated));
      });

      test('JSON encoding should be valid and parseable', () {
        final telemetry = Telemetry.empty();
        final json = telemetry.toJson();

        // Should be able to encode to JSON string without errors
        final jsonString = jsonEncode(json);
        expect(jsonString, isNotEmpty);

        // Should be able to decode back
        final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
        final parsed = Telemetry.fromJson(decoded);

        expect(parsed.vehicleId, equals(telemetry.vehicleId));
      });

      test('payload size should be under 500 bytes for 20Hz streaming', () {
        final telemetry = Telemetry(
          vehicleId: "DMP-01",
          timestampMs: DateTime.now().millisecondsSinceEpoch,
          frontDistance: 150.0,
          groundDistance: 100.0,
          groundBaseline: 100.0,
          tofSweep: List.generate(
            10,
            (i) => RadarPoint(angle: i * 18.0, dist: 100.0 + i * 10),
          ),
          visibilityMeters: 25.0,
          visConfidence: "HIGH",
          temperature: 25.0,
          humidity: 75.0,
          dewPointSpread: 5.0,
          ambientLux: 450.0,
          pitch: 5.0,
          roll: -2.0,
          yawRate: 1.0,
          motorPwm: 180,
          speed: 25.0,
          safeSpeedLimit: 30.0,
          humanBaselineSpeed: 20.0,
          speedGainRatio: 1.5,
          ttc: 6.0,
          alertState: "OK",
          isSimulated: false,
        );

        final jsonString = jsonEncode(telemetry.toJson());
        final bytes = utf8.encode(jsonString).length;

        // Should be well under 500 bytes
        expect(bytes, lessThan(500),
            reason: 'Payload size must be under 500 bytes for 20Hz streaming');

        // Print actual size for reference
        print('Telemetry payload size: $bytes bytes (limit: 500 bytes)');
      });
    });

    group('Default Values', () {
      test('fromJson should handle missing fields with defaults', () {
        final json = {
          'vid': "DMP-TEST",
          // Most fields missing
        };

        final telemetry = Telemetry.fromJson(json);

        expect(telemetry.vehicleId, equals("DMP-TEST"));
        expect(telemetry.frontDistance, equals(1000.0)); // Default
        expect(telemetry.visConfidence, equals("LOW")); // Default
        expect(telemetry.temperature, equals(25.0)); // Default
        expect(telemetry.isSimulated, equals(true)); // Default
      });

      test('Telemetry.empty() should create valid default instance', () {
        final telemetry = Telemetry.empty();

        expect(telemetry.vehicleId, equals("DMP-00"));
        expect(telemetry.frontDistance, greaterThan(0));
        expect(telemetry.groundDistance, greaterThan(0));
        expect(telemetry.visibilityMeters, greaterThan(0));
        expect(telemetry.isSimulated, equals(true));
        expect(telemetry.alertState, equals("OK"));
      });
    });

    group('RadarPoint', () {
      test('RadarPoint should serialize correctly', () {
        final point = RadarPoint(angle: 45.0, dist: 120.5);
        final json = point.toJson();

        expect(json['a'], equals(45.0));
        expect(json['d'], equals(120.5));
      });

      test('RadarPoint should deserialize correctly', () {
        final json = {'a': 90.0, 'd': 200.3};
        final point = RadarPoint.fromJson(json);

        expect(point.angle, equals(90.0));
        expect(point.dist, equals(200.3));
      });

      test('RadarPoint round-trip should preserve data', () {
        final original = RadarPoint(angle: 135.0, dist: 175.8);
        final json = original.toJson();
        final roundTrip = RadarPoint.fromJson(json);

        expect(roundTrip.angle, equals(original.angle));
        expect(roundTrip.dist, equals(original.dist));
      });
    });

    group('copyWith', () {
      test('copyWith should update specified fields only', () {
        final original = Telemetry.empty();
        final updated = original.copyWith(
          speed: 45.0,
          alertState: "HAZARD",
        );

        expect(updated.speed, equals(45.0));
        expect(updated.alertState, equals("HAZARD"));
        expect(updated.vehicleId, equals(original.vehicleId)); // Unchanged
        expect(updated.temperature, equals(original.temperature)); // Unchanged
      });

      test('copyWith with no parameters should return copy', () {
        final original = Telemetry.empty();
        final copy = original.copyWith();

        expect(copy.vehicleId, equals(original.vehicleId));
        expect(copy.speed, equals(original.speed));
        expect(copy.alertState, equals(original.alertState));
      });
    });

    group('Contract Compliance', () {
      test('JSON keys should match contract specification', () {
        final telemetry = Telemetry.empty();
        final json = telemetry.toJson();

        // Verify all contract-specified keys exist
        final expectedKeys = [
          'vid', 'ts', 'fd', 'gd', 'gb', 'sweep', 'vis', 'vis_conf',
          'temp', 'hum', 'dps', 'lux', 'pitch', 'roll', 'yaw', 'pwm',
          'spd', 'safe', 'base', 'gain', 'ttc', 'alert', 'sim'
        ];

        for (final key in expectedKeys) {
          expect(json.containsKey(key), isTrue,
              reason: 'Contract key "$key" missing from JSON');
        }
      });

      test('alertState should use string values (OK, CAUTION, HAZARD)', () {
        final ok = Telemetry.empty().copyWith(alertState: "OK");
        final caution = Telemetry.empty().copyWith(alertState: "CAUTION");
        final hazard = Telemetry.empty().copyWith(alertState: "HAZARD");

        expect(ok.toJson()['alert'], equals("OK"));
        expect(caution.toJson()['alert'], equals("CAUTION"));
        expect(hazard.toJson()['alert'], equals("HAZARD"));
      });

      test('visConfidence should use string values (HIGH, LOW)', () {
        final high = Telemetry.empty().copyWith(visConfidence: "HIGH");
        final low = Telemetry.empty().copyWith(visConfidence: "LOW");

        expect(high.toJson()['vis_conf'], equals("HIGH"));
        expect(low.toJson()['vis_conf'], equals("LOW"));
      });
    });
  });
}
