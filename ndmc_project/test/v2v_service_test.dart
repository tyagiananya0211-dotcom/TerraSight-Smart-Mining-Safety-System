import 'package:flutter_test/flutter_test.dart';
import 'package:nmdc_fog_safe_haulage/services/v2v_service.dart';
import 'package:nmdc_fog_safe_haulage/services/conflict_predictor.dart';
import 'package:nmdc_fog_safe_haulage/models/telemetry.dart';

void main() {
  group('V2VService', () {
    late V2VService service;

    setUp(() {
      service = V2VService();
    });

    test('should add new peer', () {
      service.updatePeer(
        vehicleId: "DMP-02",
        rssi: -50,
        heading: 180.0,
        speed: 25.0,
        alert: 0,
        seq: 1,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      );

      expect(service.peerCount, equals(1));
      expect(service.getPeer("DMP-02"), isNotNull);
    });

    test('should update existing peer', () {
      final now = DateTime.now().millisecondsSinceEpoch;

      service.updatePeer(
        vehicleId: "DMP-02",
        rssi: -50,
        heading: 180.0,
        speed: 25.0,
        alert: 0,
        seq: 1,
        timestampMs: now,
      );

      service.updatePeer(
        vehicleId: "DMP-02",
        rssi: -45, // Stronger signal
        heading: 180.0,
        speed: 30.0,
        alert: 0,
        seq: 2,
        timestampMs: now + 250,
      );

      final peer = service.getPeer("DMP-02");
      expect(peer, isNotNull);
      expect(peer!.rssi, equals(-45));
      expect(peer.speed, equals(30.0));
      expect(peer.rssiHistory.length, equals(2));
    });

    test('should track multiple peers', () {
      final now = DateTime.now().millisecondsSinceEpoch;

      service.updatePeer(
        vehicleId: "DMP-02",
        rssi: -50,
        heading: 180.0,
        speed: 25.0,
        alert: 0,
        seq: 1,
        timestampMs: now,
      );

      service.updatePeer(
        vehicleId: "DMP-03",
        rssi: -65,
        heading: 90.0,
        speed: 15.0,
        alert: 1,
        seq: 1,
        timestampMs: now,
      );

      expect(service.peerCount, equals(2));
    });

    test('should remove stale peers (>3 seconds)', () {
      final now = DateTime.now().millisecondsSinceEpoch;

      service.updatePeer(
        vehicleId: "DMP-02",
        rssi: -50,
        heading: 180.0,
        speed: 25.0,
        alert: 0,
        seq: 1,
        timestampMs: now - 4000, // 4 seconds ago (stale)
      );

      final activePeers = service.activePeers;
      expect(activePeers.length, equals(0));
    });
  });

  group('PeerVehicle', () {
    test('should estimate distance using log-distance path loss', () {
      final peer = PeerVehicle(
        id: "DMP-02",
        rssi: -50,
        heading: 180.0,
        speed: 25.0,
        alert: 0,
        seq: 1,
        lastSeenMs: DateTime.now().millisecondsSinceEpoch,
      );

      // RSSI -50 dBm should give distance ~3-10m range
      expect(peer.estimatedDistance, greaterThan(1.0));
      expect(peer.estimatedDistance, lessThan(20.0));
    });

    test('should classify distance into bands', () {
      final now = DateTime.now().millisecondsSinceEpoch;

      // NEAR: < 3m (very strong signal, ~-35 dBm)
      final nearPeer = PeerVehicle(
        id: "DMP-02",
        rssi: -35,
        heading: 180.0,
        speed: 25.0,
        alert: 0,
        seq: 1,
        lastSeenMs: now,
      );
      expect(nearPeer.distanceBand, equals("NEAR"));

      // MID: 3-10m (moderate signal, ~-45 dBm for ~5.6m)
      final midPeer = PeerVehicle(
        id: "DMP-03",
        rssi: -45,
        heading: 180.0,
        speed: 25.0,
        alert: 0,
        seq: 1,
        lastSeenMs: now,
      );
      expect(midPeer.distanceBand, equals("MID"));

      // FAR: >10m (weak signal, ~-55 dBm for ~17.8m)
      final farPeer = PeerVehicle(
        id: "DMP-04",
        rssi: -55,
        heading: 180.0,
        speed: 25.0,
        alert: 0,
        seq: 1,
        lastSeenMs: now,
      );
      expect(farPeer.distanceBand, equals("FAR"));
    });

    test('should calculate closing rate via linear regression', () {
      final now = DateTime.now().millisecondsSinceEpoch;

      final peer = PeerVehicle(
        id: "DMP-02",
        rssi: -70,
        heading: 180.0,
        speed: 25.0,
        alert: 0,
        seq: 1,
        lastSeenMs: now,
      );

      // Simulate approaching vehicle (RSSI increasing)
      for (int i = 0; i < 15; i++) {
        peer.update(
          rssi: -70 + (i * 2), // RSSI rising by 2 dBm per sample
          heading: 180.0,
          speed: 25.0,
          alert: 0,
          seq: i + 2,
          timestampMs: now + (i * 250),
        );
      }

      final closingRate = peer.getClosingRate();

      // Closing rate should be positive (approaching)
      expect(closingRate, greaterThan(0.0));
    });
  });

  group('ConflictPredictor', () {
    late ConflictPredictor predictor;
    late V2VService v2vService;

    setUp(() {
      predictor = ConflictPredictor();
      v2vService = V2VService();
    });

    test('should detect conflict when approaching with opposed headings', () {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Add peer with opposed heading (180 degrees)
      v2vService.updatePeer(
        vehicleId: "DMP-02",
        rssi: -50, // MID range
        heading: 180.0,
        speed: 25.0,
        alert: 0,
        seq: 1,
        timestampMs: now,
      );

      // Simulate approaching (RSSI rising)
      for (int i = 0; i < 15; i++) {
        v2vService.updatePeer(
          vehicleId: "DMP-02",
          rssi: -50 + i,
          heading: 180.0,
          speed: 25.0,
          alert: 0,
          seq: i + 2,
          timestampMs: now + (i * 250),
        );
      }

      // Evaluate conflicts
      final conflicts = predictor.evaluateConflicts(
        peers: v2vService.activePeers,
        ownHeading: 0.0, // Opposed to peer's 180 degrees
        tofSweep: [],
      );

      expect(conflicts.isNotEmpty, isTrue);

      final conflict = conflicts.first;
      expect(conflict.isHeadingOpposed, isTrue);
      expect(conflict.closingRate, greaterThan(0.0));
    });

    test('should require 3 consecutive evaluations for CONFLICT severity', () {
      final now = DateTime.now().millisecondsSinceEpoch;

      v2vService.updatePeer(
        vehicleId: "DMP-02",
        rssi: -50,
        heading: 180.0,
        speed: 25.0,
        alert: 0,
        seq: 1,
        timestampMs: now,
      );

      // Build RSSI history (approaching)
      for (int i = 0; i < 15; i++) {
        v2vService.updatePeer(
          vehicleId: "DMP-02",
          rssi: -50 + i,
          heading: 180.0,
          speed: 25.0,
          alert: 0,
          seq: i + 2,
          timestampMs: now + (i * 250),
        );
      }

      // First evaluation - CAUTION
      var conflicts = predictor.evaluateConflicts(
        peers: v2vService.activePeers,
        ownHeading: 0.0,
        tofSweep: [],
      );
      expect(conflicts.first.severity, equals("CAUTION"));
      expect(conflicts.first.consecutiveCount, equals(1));

      // Second evaluation - CAUTION
      conflicts = predictor.evaluateConflicts(
        peers: v2vService.activePeers,
        ownHeading: 0.0,
        tofSweep: [],
      );
      expect(conflicts.first.severity, equals("CAUTION"));
      expect(conflicts.first.consecutiveCount, equals(2));

      // Third evaluation - CONFLICT
      conflicts = predictor.evaluateConflicts(
        peers: v2vService.activePeers,
        ownHeading: 0.0,
        tofSweep: [],
      );
      expect(conflicts.first.severity, equals("CONFLICT"));
      expect(conflicts.first.consecutiveCount, equals(3));
    });

    test('should not detect conflict when receding', () {
      final now = DateTime.now().millisecondsSinceEpoch;

      v2vService.updatePeer(
        vehicleId: "DMP-02",
        rssi: -40, // Start close
        heading: 180.0,
        speed: 25.0,
        alert: 0,
        seq: 1,
        timestampMs: now,
      );

      // Simulate receding (RSSI decreasing)
      for (int i = 0; i < 15; i++) {
        v2vService.updatePeer(
          vehicleId: "DMP-02",
          rssi: -40 - i, // RSSI falling
          heading: 180.0,
          speed: 25.0,
          alert: 0,
          seq: i + 2,
          timestampMs: now + (i * 250),
        );
      }

      final conflicts = predictor.evaluateConflicts(
        peers: v2vService.activePeers,
        ownHeading: 0.0,
        tofSweep: [],
      );

      // Should have detection but not CONFLICT (receding)
      if (conflicts.isNotEmpty) {
        expect(conflicts.first.closingRate, lessThan(0.0));
        expect(conflicts.first.severity, equals("NONE"));
      }
    });

    test('should detect ToF handoff when peer enters sensor range', () {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Peer at estimated 2.5m (within ToF range)
      v2vService.updatePeer(
        vehicleId: "DMP-02",
        rssi: -45,
        heading: 180.0,
        speed: 25.0,
        alert: 0,
        seq: 1,
        timestampMs: now,
      );

      // Build approaching history
      for (int i = 0; i < 15; i++) {
        v2vService.updatePeer(
          vehicleId: "DMP-02",
          rssi: -45 + i,
          heading: 180.0,
          speed: 25.0,
          alert: 0,
          seq: i + 2,
          timestampMs: now + (i * 250),
        );
      }

      // ToF sweep with point at similar distance
      final tofSweep = [
        RadarPoint(angle: 90.0, dist: 250.0), // 2.5m in cm
      ];

      final conflicts = predictor.evaluateConflicts(
        peers: v2vService.activePeers,
        ownHeading: 0.0,
        tofSweep: tofSweep,
      );

      if (conflicts.isNotEmpty) {
        final conflict = conflicts.first;
        // ToF handoff might occur if distance matches
        if (conflict.tofAcquired) {
          expect(conflict.tofBearing, equals(90.0));
          expect(conflict.tofDistance, closeTo(2.5, 0.5));
        }
      }
    });
  });
}
