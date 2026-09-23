import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import '../models/telemetry.dart';
import 'rover_ingest_service.dart';
import 'speed_envelope_service.dart';

class TelemetrySource {
  final RoverIngestService _roverService;
  
  final _telemetryController = StreamController<Telemetry>.broadcast();
  Stream<Telemetry> get stream => _telemetryController.stream;

  StreamSubscription? _roverSub;
  StreamSubscription? _gyroSub;
  StreamSubscription? _accelSub;
  StreamSubscription? _geoSub;
  Timer? _fallbackTimer;

  // Phone Sensor state
  bool _isDrifting = false;
  double _driftAngle = 0.0;
  double _slope = 0.0;
  double _speed = 0.0;
  
  // Fake sweep state
  double _radarAngle = 90.0;
  int _radarDirection = 1;

  TelemetrySource(this._roverService) {
    _roverService.isRoverConnected.addListener(_onConnectionChanged);
    _onConnectionChanged();
  }

  void _onConnectionChanged() {
    if (_roverService.isRoverConnected.value) {
      _stopFallbackSensors();
      _startRoverPiping();
    } else {
      _stopRoverPiping();
      _startFallbackSensors();
    }
  }

  void _startRoverPiping() {
    _roverSub?.cancel();
    _roverSub = _roverService.telemetryStream.listen((telemetry) {
      _telemetryController.add(telemetry);
    });
  }

  void _stopRoverPiping() {
    _roverSub?.cancel();
  }

  void _startFallbackSensors() {
    // Start local sensors
    _gyroSub = gyroscopeEventStream().listen((GyroscopeEvent event) {
      _isDrifting = event.y.abs() > 2.0;
      _driftAngle = event.y * 10;
      _slope = event.x * 10;
    });
    
    _accelSub = userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
      // reserved for sudden braking
    });
    
    _geoSub = Geolocator.getPositionStream().listen((Position position) {
      _speed = position.speed * 3.6;
    }, onError: (_) {});

    // Polling loop (20Hz)
    _fallbackTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      // Fake radar sweep for UI
      _radarAngle += 5 * _radarDirection;
      if (_radarAngle >= 180) { _radarAngle = 180; _radarDirection = -1; }
      if (_radarAngle <= 0) { _radarAngle = 0; _radarDirection = 1; }

      // Compute speed envelope for fallback mode
      final visibilityMeters = 5.0; // Monsoon default
      final obstacleDistanceMeters = 100.0; // Fixed safe distance for fallback
      final envelope = SpeedEnvelopeService.calculateEnvelope(
        visibilityMeters: visibilityMeters,
        nearestObstacleDistanceMeters: obstacleDistanceMeters,
        sensorConfidence: 50.0, // Low confidence for phone fallback
      );

      final fallbackTelemetry = Telemetry(
        vehicleId: "DMP-01",
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        frontDistance: obstacleDistanceMeters, // Fixed safe distance for fallback
        groundDistance: 100.0,
        groundBaseline: 100.0,
        tofSweep: [RadarPoint(angle: _radarAngle, dist: obstacleDistanceMeters)],
        visibilityMeters: visibilityMeters,
        visConfidence: "LOW", // Phone sensors can't measure visibility
        temperature: 25.0,
        humidity: 80.0,
        dewPointSpread: 3.0, // Approx for high humidity
        ambientLux: 200.0, // Estimated low light
        pitch: _slope,
        roll: _driftAngle,
        yawRate: _isDrifting ? 10.0 : 0.0,
        motorPwm: 0, // Unknown in phone fallback
        speed: _speed,
        safeSpeedLimit: envelope.safeSpeedLimit,
        humanBaselineSpeed: envelope.humanBaselineSpeed,
        speedGainRatio: envelope.speedGainRatio,
        ttc: 99.0,
        alertState: _isDrifting ? "CAUTION" : "OK",
        isSimulated: true, // IMPORTANT FLAG
      );

      _telemetryController.add(fallbackTelemetry);
    });
  }

  void _stopFallbackSensors() {
    _gyroSub?.cancel();
    _accelSub?.cancel();
    _geoSub?.cancel();
    _fallbackTimer?.cancel();
  }

  void dispose() {
    _roverService.isRoverConnected.removeListener(_onConnectionChanged);
    _stopRoverPiping();
    _stopFallbackSensors();
    _telemetryController.close();
  }
}
