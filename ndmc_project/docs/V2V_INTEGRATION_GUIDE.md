# V2V Conflict Warning Integration Guide

## Overview

This guide shows how to integrate the GPS-free vehicle-to-vehicle (V2V) conflict warning system into the Driver HUD.

## Integration Steps

### 1. Add V2V Services to HUD Screen

Add to `lib/screens/driver_hud_screen.dart`:

```dart
import '../services/v2v_service.dart';
import '../services/conflict_predictor.dart';
import '../widgets/conflict_warning_widget.dart';

class _DriverHudScreenState extends State<DriverHudScreen> {
  // ... existing fields ...

  // ADD THESE:
  final V2VService _v2vService = V2VService();
  final ConflictPredictor _conflictPredictor = ConflictPredictor();
  List<ConflictDetection> _conflicts = [];
  Timer? _conflictCheckTimer;
```

### 2. Initialize V2V in `_initSensors()`

```dart
void _initSensors() {
  _roverService = RoverIngestService();
  _telemetrySource = TelemetrySource(_roverService);

  _telemetrySub = _telemetrySource.stream.listen((telemetry) {
    if (!mounted) return;

    // Existing collapse detector logic...
    final collapseState = _collapseDetector.processSample(telemetry.groundDistance);

    // ADD V2V PEER PARSING (if ESP32 includes peer data):
    // Parse peer data from telemetry JSON and update V2VService
    // Example: if telemetry has 'peers' field
    // _updateV2VPeers(telemetry);

    // Existing logic...
    String finalAlertState = telemetry.alertState;
    if (collapseState == "HAZARD") {
      finalAlertState = "HAZARD";
    }

    final updatedTelemetry = telemetry.copyWith(alertState: finalAlertState);

    setState(() {
      _telemetry = updatedTelemetry;
      _collapseState = collapseState;
    });

    // ... rest of existing logic
  });

  // ADD: Start periodic conflict checking (10Hz)
  _conflictCheckTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
    _checkConflicts();
  });
}
```

### 3. Add V2V Peer Update Method

```dart
/// Update V2V service with peer data from ESP32
void _updateV2VPeers(dynamic telemetryJson) {
  // Parse peer data from telemetry
  // Format: { "peers": [{"vid": "DMP-02", "rssi": -45, "heading": 180, ...}] }

  if (telemetryJson is Map && telemetryJson.containsKey('peers')) {
    final peers = telemetryJson['peers'] as List;

    for (final peerData in peers) {
      _v2vService.updatePeer(
        vehicleId: peerData['vid'] as String,
        rssi: peerData['rssi'] as int,
        heading: (peerData['heading'] ?? 0.0).toDouble(),
        speed: (peerData['speed'] ?? 0.0).toDouble(),
        alert: peerData['alert'] as int? ?? 0,
        seq: peerData['seq'] as int,
        timestampMs: peerData['ts'] as int,
      );
    }
  }
}

/// Check for conflicts periodically
void _checkConflicts() {
  if (!mounted) return;

  final activePeers = _v2vService.activePeers;

  if (activePeers.isEmpty) {
    if (_conflicts.isNotEmpty) {
      setState(() {
        _conflicts = [];
      });
    }
    return;
  }

  // Run conflict predictor
  final newConflicts = _conflictPredictor.evaluateConflicts(
    peers: activePeers,
    ownHeading: _telemetry.yawRate, // Or use compass heading if available
    tofSweep: _telemetry.tofSweep,
  );

  // Update state if conflicts changed
  if (newConflicts.length != _conflicts.length ||
      newConflicts.any((c) => !_conflicts.any((old) => old.peerId == c.peerId))) {
    setState(() {
      _conflicts = newConflicts;
    });

    // POST conflict events to PHP
    for (final conflict in newConflicts) {
      if (conflict.severity == "CONFLICT") {
        _postConflictAlert(conflict);
      }
    }
  }
}

/// POST conflict alert to PHP backend
void _postConflictAlert(ConflictDetection conflict) {
  _phpBridge?.postAlert(
    alertType: "PROXIMITY",
    severity: conflict.severity,
    message: "V2V conflict with ${conflict.peerId} at ${conflict.distanceBand} range",
    metadata: {
      'peerId': conflict.peerId,
      'distanceBand': conflict.distanceBand,
      'closingRate': conflict.closingRate,
      'tofAcquired': conflict.tofAcquired,
      if (conflict.tofAcquired) 'tofBearing': conflict.tofBearing,
      if (conflict.tofAcquired) 'tofDistance': conflict.tofDistance,
    },
  );
}
```

### 4. Add Conflict Warning to UI

In the `build()` method, add the conflict warning widget after the collapse banner:

```dart
return Scaffold(
  backgroundColor: AppColors.background,
  body: SafeArea(
    child: Column(
      children: [
        // Existing collapse HAZARD banner
        if (_collapseState == "HAZARD")
          Container(
            // ... collapse banner code ...
          ),

        // ADD: V2V CONFLICT WARNING
        if (_conflicts.isNotEmpty)
          ConflictWarningWidget(
            conflicts: _conflicts,
            onTap: () {
              // Show conflict details dialog
              showDialog(
                context: context,
                builder: (_) => ConflictDetailDialog(conflicts: _conflicts),
              );
            },
          ),

        // Rest of UI...
        Expanded(
          child: Row(
            children: [
              // Left panel...
              // Right grid...
            ],
          ),
        ),
      ],
    ),
  ),
);
```

### 5. Add V2V Status to Left Panel

Add V2V peer count indicator in the connectivity section:

```dart
// In the connectivity Container, add after PHP and Clients:
const SizedBox(height: 4),
Row(
  children: [
    Icon(
      _v2vService.peerCount > 0 ? Icons.groups : Icons.person,
      size: 12,
      color: _v2vService.peerCount > 0
          ? AppColors.statusSafe
          : AppColors.textMuted,
    ),
    const SizedBox(width: 6),
    Expanded(
      child: Text(
        'V2V Peers',
        style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
      ),
    ),
    Text(
      '${_v2vService.peerCount}',
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.bold,
        color: _v2vService.peerCount > 0
            ? AppColors.statusSafe
            : AppColors.textMuted,
      ),
    ),
  ],
),
```

### 6. Cleanup in `dispose()`

```dart
@override
void dispose() {
  // Existing cleanup...
  _conflictCheckTimer?.cancel();
  _v2vService.clear();
  _conflictPredictor.reset();
  // ... rest of cleanup
  super.dispose();
}
```

## Testing Without Hardware

### Simulated Peer Data

For testing without ESP32, add simulated peers in `_initSensors()`:

```dart
// TESTING ONLY: Simulate peer vehicles
Timer.periodic(const Duration(milliseconds: 250), (_) {
  if (!mounted || !_isServerRunning) return;

  // Simulate peer DMP-02 approaching
  final now = DateTime.now().millisecondsSinceEpoch;
  final elapsed = (now - _startTime) / 1000.0; // seconds

  // Simulate RSSI increasing (approaching)
  final rssi = (-70 + (elapsed * 2)).toInt().clamp(-90, -30);

  _v2vService.updatePeer(
    vehicleId: "DMP-02",
    rssi: rssi,
    heading: 180.0, // Opposite heading
    speed: 25.0,
    alert: 0,
    seq: (elapsed * 4).toInt(),
    timestampMs: now,
  );
});
```

## Production Deployment

### ESP32 Integration

When ESP32 firmware implements V2V (per `ESP32_V2V_SPECIFICATION.md`):

1. ESP32 broadcasts V2V packets at 4Hz
2. ESP32 captures RSSI from received packets
3. ESP32 forwards peer data to phone in telemetry JSON
4. Phone parses peer data and updates `V2VService`
5. `ConflictPredictor` runs continuously
6. Conflicts displayed in HUD
7. Conflict events POSTed to PHP backend

### GPS Upgrade Path

When GPS/DGPS is added:

1. Set `ConflictPredictor.hasAbsolutePositioning = true`
2. Replace RSSI-based logic with geometric predictor
3. Interface remains the same
4. More accurate conflict detection
5. Works beyond ESP-NOW range

## Demonstration Points for Judges

1. **GPS-Free Operation**: "Works at blind curves where GPS would fail"
2. **Closing Rate Detection**: "RSSI linear regression more reliable than distance"
3. **Sensor Fusion**: "Hand off from V2V to ToF when peer enters radar range"
4. **Honest Engineering**: "No false bearing claims until ToF acquires target"
5. **Production Upgrade**: "Designed for GPS upgrade without interface changes"

## Troubleshooting

### No Peers Detected
- Check ESP32 V2V firmware is broadcasting
- Verify RSSI is being captured
- Check peer data forwarding to phone
- Confirm V2V service is receiving updates

### False Positives
- Increase `consecutiveThreshold` (default: 3)
- Adjust `closingRateThreshold` (default: 0.5 dBm/s)
- Check RSSI variance in environment

### ToF Handoff Not Working
- Verify peer estimated distance < 3m
- Check ToF sweep has valid points
- Increase tolerance in `_checkTofHandoff()`

## Performance Notes

- **V2V Service**: O(n) per peer update
- **Conflict Predictor**: O(n) per evaluation, n = peer count
- **10Hz check rate**: Acceptable for up to 10 peers
- **RSSI regression**: 20 samples = 5 seconds of history

---

**Document Version**: 1.0
**Last Updated**: 2026-09-14
