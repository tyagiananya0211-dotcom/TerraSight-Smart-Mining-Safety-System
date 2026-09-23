import 'dart:math' as math;
import 'dart:collection';

/// Peer Vehicle Information
///
/// Tracks a peer vehicle detected via ESP-NOW V2V communication.
/// Uses RSSI-based proximity estimation (GPS-free).
class PeerVehicle {
  /// Vehicle ID (e.g., "DMP-02")
  final String id;

  /// Current RSSI (Received Signal Strength Indicator) in dBm
  int rssi;

  /// RSSI history (last 20 samples) for closing rate detection
  final Queue<RssiSample> rssiHistory;

  /// Heading in degrees (0-360)
  double heading;

  /// Speed in km/h
  double speed;

  /// Alert state (0=OK, 1=CAUTION, 2=HAZARD)
  int alert;

  /// Sequence number (to detect packet loss)
  int seq;

  /// Last seen timestamp (milliseconds since epoch)
  int lastSeenMs;

  /// Estimated distance band (NEAR, MID, FAR)
  String distanceBand;

  /// Estimated distance in meters (crude, ±40% accuracy)
  double estimatedDistance;

  PeerVehicle({
    required this.id,
    required this.rssi,
    required this.heading,
    required this.speed,
    required this.alert,
    required this.seq,
    required this.lastSeenMs,
    this.distanceBand = "FAR",
    this.estimatedDistance = 100.0,
  }) : rssiHistory = Queue<RssiSample>() {
    // Add initial RSSI to history
    rssiHistory.addLast(RssiSample(rssi: rssi, timestampMs: lastSeenMs));
    // Calculate initial distance estimate
    _updateDistanceEstimate();
  }

  /// Update peer with new packet data
  void update({
    required int rssi,
    required double heading,
    required double speed,
    required int alert,
    required int seq,
    required int timestampMs,
  }) {
    this.rssi = rssi;
    this.heading = heading;
    this.speed = speed;
    this.alert = alert;
    this.seq = seq;
    this.lastSeenMs = timestampMs;

    // Add to RSSI history
    rssiHistory.addLast(RssiSample(rssi: rssi, timestampMs: timestampMs));

    // Keep last 20 samples
    while (rssiHistory.length > 20) {
      rssiHistory.removeFirst();
    }

    // Estimate distance and band
    _updateDistanceEstimate();
  }

  /// Update distance estimate using log-distance path loss model
  void _updateDistanceEstimate() {
    // Log-distance path loss model:
    // RSSI = TxPower - 10 * n * log10(d)
    // Solving for d: d = 10 ^ ((TxPower - RSSI) / (10 * n))
    //
    // Assumptions:
    // - TxPower at 1m: -30 dBm (typical ESP32)
    // - Path loss exponent n: 2.0 (free space)
    //
    // This is CRUDE: ±40% accuracy due to multipath, fading, etc.

    const double txPowerAt1m = -30.0; // dBm
    const double pathLossExponent = 2.0;

    final double distance = math.pow(
      10,
      (txPowerAt1m - rssi) / (10 * pathLossExponent),
    ).toDouble();

    estimatedDistance = distance;

    // Classify into bands (rover scale)
    if (distance < 3.0) {
      distanceBand = "NEAR";
    } else if (distance < 10.0) {
      distanceBand = "MID";
    } else {
      distanceBand = "FAR";
    }
  }

  /// Get closing rate (dBm/s) via linear regression on RSSI history
  ///
  /// Positive = approaching (RSSI increasing)
  /// Negative = receding (RSSI decreasing)
  /// Near zero = stationary relative distance
  double getClosingRate() {
    if (rssiHistory.length < 3) return 0.0;

    // Linear regression: y = mx + b
    // where y = RSSI, x = time (seconds)
    // m (slope) = closing rate in dBm/s

    final samples = rssiHistory.toList();
    final n = samples.length;

    // Use first timestamp as t=0 reference
    final t0 = samples.first.timestampMs;

    double sumX = 0.0;
    double sumY = 0.0;
    double sumXY = 0.0;
    double sumX2 = 0.0;

    for (final sample in samples) {
      final x = (sample.timestampMs - t0) / 1000.0; // Time in seconds
      final y = sample.rssi.toDouble();

      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
    }

    // Slope: m = (n*sumXY - sumX*sumY) / (n*sumX2 - sumX^2)
    final denominator = n * sumX2 - sumX * sumX;
    if (denominator.abs() < 0.0001) return 0.0;

    final slope = (n * sumXY - sumX * sumY) / denominator;

    return slope; // dBm/s
  }

  /// Check if peer is stale (not heard in last 3 seconds)
  bool isStale(int currentTimeMs) {
    return (currentTimeMs - lastSeenMs) > 3000;
  }
}

/// RSSI Sample with timestamp
class RssiSample {
  final int rssi;
  final int timestampMs;

  RssiSample({
    required this.rssi,
    required this.timestampMs,
  });
}

/// Vehicle-to-Vehicle (V2V) Service
///
/// Manages peer vehicles detected via ESP-NOW V2V communication.
/// Uses RSSI-based proximity estimation (GPS-free).
///
/// KEY DESIGN:
/// - NO GPS DEPENDENCY
/// - RSSI-based ranging (crude but sufficient)
/// - Closing rate detection via linear regression
/// - 3-second peer timeout
class V2VService {
  /// Map of peer vehicles (keyed by vehicle ID)
  final Map<String, PeerVehicle> _peers = {};

  /// Get all active peers (heard in last 3 seconds)
  Map<String, PeerVehicle> get activePeers {
    final now = DateTime.now().millisecondsSinceEpoch;
    _cleanupStalePeers(now);
    return Map.from(_peers);
  }

  /// Get peer count
  int get peerCount => activePeers.length;

  /// Update or add peer from V2V packet
  void updatePeer({
    required String vehicleId,
    required int rssi,
    required double heading,
    required double speed,
    required int alert,
    required int seq,
    required int timestampMs,
  }) {
    if (_peers.containsKey(vehicleId)) {
      // Update existing peer
      _peers[vehicleId]!.update(
        rssi: rssi,
        heading: heading,
        speed: speed,
        alert: alert,
        seq: seq,
        timestampMs: timestampMs,
      );
    } else {
      // Add new peer
      _peers[vehicleId] = PeerVehicle(
        id: vehicleId,
        rssi: rssi,
        heading: heading,
        speed: speed,
        alert: alert,
        seq: seq,
        lastSeenMs: timestampMs,
      );
    }
  }

  /// Remove stale peers (not heard in last 3 seconds)
  void _cleanupStalePeers(int currentTimeMs) {
    _peers.removeWhere((id, peer) => peer.isStale(currentTimeMs));
  }

  /// Get peer by ID
  PeerVehicle? getPeer(String vehicleId) {
    return _peers[vehicleId];
  }

  /// Clear all peers
  void clear() {
    _peers.clear();
  }

  /// Get diagnostic information
  Map<String, dynamic> getDiagnostics() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _cleanupStalePeers(now);

    return {
      'peerCount': _peers.length,
      'peers': _peers.values.map((peer) => {
        'id': peer.id,
        'rssi': peer.rssi,
        'distanceBand': peer.distanceBand,
        'estimatedDistance': peer.estimatedDistance.toStringAsFixed(1),
        'heading': peer.heading.toStringAsFixed(0),
        'speed': peer.speed.toStringAsFixed(1),
        'closingRate': peer.getClosingRate().toStringAsFixed(2),
        'sampleCount': peer.rssiHistory.length,
      }).toList(),
    };
  }
}
