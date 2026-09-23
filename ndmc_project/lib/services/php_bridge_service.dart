import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/telemetry.dart';

/// Bridge service for PHP backend communication
///
/// CRITICAL: All operations are fire-and-forget with timeouts.
/// Network failures NEVER affect the HUD display.
class PhpBridgeService {
  String baseUrl;
  final String vehicleId;
  final String localIp;
  final int wsPort;
  final int mjpegPort;

  // Connectivity state
  bool _isPhpConnected = false;
  bool get isPhpConnected => _isPhpConnected;

  // Telemetry batching for 2Hz history logging
  final List<Telemetry> _telemetryBuffer = [];
  Timer? _telemetryTimer;

  // Failed telemetry queue (bounded to 200 frames)
  final List<Map<String, dynamic>> _failedQueue = [];
  static const int maxQueueSize = 200;

  // Registration heartbeat
  Timer? _registrationTimer;

  // Alert state tracking
  String _lastAlertState = "OK";

  // Timeout for all HTTP requests
  static const Duration requestTimeout = Duration(seconds: 2);

  PhpBridgeService({
    this.baseUrl = 'http://192.168.43.100/terasight/api',
    required this.vehicleId,
    required this.localIp,
    this.wsPort = 8080,
    this.mjpegPort = 8081,
  });

  /// Start all background tasks
  void start() {
    _startRegistrationHeartbeat();
    _startTelemetryBatching();
  }

  /// Stop all background tasks
  void stop() {
    _registrationTimer?.cancel();
    _telemetryTimer?.cancel();
  }

  /// Update base URL (for in-app settings)
  void updateBaseUrl(String newUrl) {
    baseUrl = newUrl;
    _isPhpConnected = false; // Force re-check
  }

  // ============================================================================
  // REGISTRATION HEARTBEAT (every 30 seconds)
  // ============================================================================

  void _startRegistrationHeartbeat() {
    // Register immediately
    _register();

    // Then every 30 seconds
    _registrationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _register();
    });
  }

  Future<void> _register() async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/register.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'vid': vehicleId,
              'ip': localIp,
              'ws_port': wsPort,
              'mjpeg_port': mjpegPort,
              'ts': DateTime.now().millisecondsSinceEpoch,
            }),
          )
          .timeout(requestTimeout);

      _isPhpConnected = response.statusCode == 200;

      // Retry failed telemetry on reconnect
      if (_isPhpConnected && _failedQueue.isNotEmpty) {
        _retryFailedTelemetry();
      }
    } catch (e) {
      _isPhpConnected = false;
      // Silent failure - HUD continues working
    }
  }

  // ============================================================================
  // TELEMETRY HISTORY (2Hz batched logging)
  // ============================================================================

  void _startTelemetryBatching() {
    // Post batches every 500ms (2Hz)
    _telemetryTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _postTelemetryBatch();
    });
  }

  /// Add telemetry frame to buffer (called at 20Hz from HUD)
  void addTelemetry(Telemetry telemetry) {
    _telemetryBuffer.add(telemetry);

    // Batch up to 10 frames (20Hz / 2Hz = 10 frames per batch)
    if (_telemetryBuffer.length >= 10) {
      _postTelemetryBatch();
    }
  }

  Future<void> _postTelemetryBatch() async {
    if (_telemetryBuffer.isEmpty) return;

    // Take up to 10 frames
    final batch = _telemetryBuffer.take(10).toList();
    _telemetryBuffer.removeRange(0, batch.length);

    final payload = {
      'vid': vehicleId,
      'frames': batch.map((t) => t.toJson()).toList(),
    };

    try {
      await http
          .post(
            Uri.parse('$baseUrl/telemetry.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(requestTimeout);
    } catch (e) {
      // Queue failed batches (bounded to 200 frames total)
      _queueFailedTelemetry(payload);
    }
  }

  void _queueFailedTelemetry(Map<String, dynamic> payload) {
    _failedQueue.add(payload);

    // Drop oldest if over limit
    while (_failedQueue.length > maxQueueSize) {
      _failedQueue.removeAt(0);
    }
  }

  Future<void> _retryFailedTelemetry() async {
    while (_failedQueue.isNotEmpty) {
      final payload = _failedQueue.first;

      try {
        await http
            .post(
              Uri.parse('$baseUrl/telemetry.php'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(requestTimeout);

        _failedQueue.removeAt(0); // Success, remove from queue
      } catch (e) {
        // Still failing, stop retrying for now
        break;
      }
    }
  }

  // ============================================================================
  // ALERTS (immediate posting on state transitions)
  // ============================================================================

  /// Check and post alert if alertState changed
  void checkAndPostAlert(Telemetry telemetry) {
    final currentState = telemetry.alertState;

    if (currentState != _lastAlertState) {
      _postAlert(telemetry, currentState, _lastAlertState);
      _lastAlertState = currentState;
    }
  }

  /// Post custom alert (for V2V conflicts, manual triggers, etc.)
  Future<void> postAlert({
    required String alertType,
    required String severity,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    final payload = {
      'vid': vehicleId,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'type': alertType,
      'severity': severity,
      'detail': message,
      if (metadata != null) 'metadata': metadata,
    };

    try {
      await http
          .post(
            Uri.parse('$baseUrl/alert.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(requestTimeout);
    } catch (e) {
      // Silent failure - alerts are non-critical for HUD operation
    }
  }

  Future<void> _postAlert(Telemetry telemetry, String newState, String oldState) async {
    // Determine alert type based on telemetry conditions
    String alertType = _inferAlertType(telemetry);

    final payload = {
      'vid': vehicleId,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'type': alertType,
      'severity': newState,
      'detail': _generateAlertDetail(telemetry, alertType, newState, oldState),
      'telemetry': telemetry.toJson(),
    };

    try {
      await http
          .post(
            Uri.parse('$baseUrl/alert.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(requestTimeout);
    } catch (e) {
      // Silent failure - alerts are non-critical for HUD operation
    }
  }

  String _inferAlertType(Telemetry telemetry) {
    // Infer alert type from telemetry conditions
    if (telemetry.speed > telemetry.safeSpeedLimit) {
      return 'OVERSPEED';
    }
    if (telemetry.frontDistance < 200.0) {
      return 'PROXIMITY';
    }
    if (telemetry.yawRate.abs() > 5.0) {
      return 'SLIP';
    }
    if (telemetry.groundDistance < telemetry.groundBaseline - 20) {
      return 'COLLAPSE';
    }
    return 'PROXIMITY'; // Default
  }

  String _generateAlertDetail(Telemetry telemetry, String type, String newState, String oldState) {
    switch (type) {
      case 'OVERSPEED':
        return 'Speed ${telemetry.speed.toStringAsFixed(1)} km/h exceeds safe limit ${telemetry.safeSpeedLimit.toStringAsFixed(1)} km/h';
      case 'PROXIMITY':
        return 'Obstacle detected at ${telemetry.frontDistance.toStringAsFixed(0)} cm';
      case 'SLIP':
        return 'Wheel slip detected, yaw rate ${telemetry.yawRate.toStringAsFixed(1)} deg/s';
      case 'COLLAPSE':
        final delta = telemetry.groundBaseline - telemetry.groundDistance;
        return 'Ground drop detected: ${delta.toStringAsFixed(0)} cm below baseline';
      default:
        return 'Alert state changed from $oldState to $newState';
    }
  }

  /// Get count of queued failed telemetry frames
  int get queuedFrameCount => _failedQueue.fold(
      0, (sum, batch) => sum + (batch['frames'] as List).length);

  void dispose() {
    stop();
  }
}
