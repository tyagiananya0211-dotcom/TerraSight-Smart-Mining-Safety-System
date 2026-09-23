import 'dart:async';
import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class TelemetryData {
  final double speed; // km/h
  final double heading; // degrees 0-360
  final double latitude; // Real GPS Latitude
  final double longitude; // Real GPS Longitude
  final DateTime timestamp;
  final bool isEmergency;
  final String activeRouteName;

  TelemetryData({
    required this.speed,
    required this.heading,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.isEmergency = false,
    this.activeRouteName = 'Route B',
  });
}

class TelemetryService {
  // Singleton pattern
  static final TelemetryService _instance = TelemetryService._internal();
  factory TelemetryService() => _instance;
  TelemetryService._internal() {
    _startSimulation();
  }

  final _controller = StreamController<TelemetryData>.broadcast();
  Stream<TelemetryData> get telemetryStream => _controller.stream;

  // The predefined routes
  final List<LatLng> _demoRouteB = const [
    LatLng(18.7380, 81.2210),
    LatLng(18.7420, 81.2280),
    LatLng(18.7470, 81.2360),
    LatLng(18.7520, 81.2450),
    LatLng(18.7600, 81.2540),
  ];

  final List<LatLng> _demoRouteC = const [
    LatLng(18.7380, 81.2210),
    LatLng(18.7390, 81.2230),
    LatLng(18.7450, 81.2250),
    LatLng(18.7580, 81.2600),
  ];

  late List<LatLng> _activeRoute = _demoRouteB;
  String _activeRouteName = 'Route B';

  int _currentRouteSegmentIndex = 0;
  double _segmentProgress = 0.0; // 0.0 to 1.0 along the current segment

  TelemetryData _currentData = TelemetryData(
    speed: 0,
    heading: 0,
    latitude: 18.7380,
    longitude: 81.2210,
    timestamp: DateTime.now(),
    isEmergency: false,
    activeRouteName: 'Route B',
  );

  TelemetryData get currentData => _currentData;
  Timer? _timer;
  final Random _random = Random();

  bool _isEmergencyStop = false;
  double _targetSpeed = 30.0; // km/h
  bool _useRealLocation = false;

  List<LatLng> get currentRoute => _activeRoute;
  String get currentRouteName => _activeRouteName;

  void changeRoute() {
    if (_activeRouteName == 'Route B') {
      _activeRoute = _demoRouteC;
      _activeRouteName = 'Route C';
    } else {
      _activeRoute = _demoRouteB;
      _activeRouteName = 'Route B';
    }
    _currentRouteSegmentIndex = 0;
    _segmentProgress = 0.0;
  }

  void _startSimulation() async {
    // Check location permissions safely without crashing
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          _useRealLocation = true;
        }
      }
    } catch (e) {
      // Permission issues on web/devices, silently fallback to simulation
      _useRealLocation = false;
    }

    _timer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      _updateTelemetry();
    });
  }

  void _updateTelemetry() async {
    // 1. Calculate new speed
    double speedChange = (_random.nextDouble() * 2) - 1.0; // -1 to +1 km/h per tick
    
    if (_isEmergencyStop) {
      _currentData = TelemetryData(
        speed: max(0, _currentData.speed - 10.0), // Fast deceleration
        heading: _currentData.heading,
        latitude: _currentData.latitude,
        longitude: _currentData.longitude,
        timestamp: DateTime.now(),
        isEmergency: true,
        activeRouteName: _activeRouteName,
      );
      _controller.add(_currentData);
      return;
    } 

    // Approach target speed
    double newSpeed = _currentData.speed;
    if (newSpeed < _targetSpeed - 1) {
      newSpeed += 1.0 + (_random.nextDouble() * 0.5); // Accelerate
    } else if (newSpeed > _targetSpeed + 1) {
      newSpeed -= 1.0 + (_random.nextDouble() * 0.5); // Decelerate
    } else {
      newSpeed += speedChange; // Cruise fluctuation
    }
    
    newSpeed = max(0, min(newSpeed, 60)); // Cap between 0 and 60 km/h

    double currentLat = _currentData.latitude;
    double currentLng = _currentData.longitude;
    double newHeading = _currentData.heading;

    if (_useRealLocation) {
      try {
        Position position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 2)));
        currentLat = position.latitude;
        currentLng = position.longitude;
        if (position.heading > 0) {
          newHeading = position.heading;
        } else if (position.speed > 0) {
          newHeading = _currentData.heading;
        }
        if (position.speed >= 0) {
           newSpeed = position.speed * 3.6;
        }
      } catch (e) {
        // Fallback to demo mode if location fetch times out or fails
        _simulateMovement(newSpeed);
        return;
      }
    } else {
      _simulateMovement(newSpeed);
      return;
    }

    _currentData = TelemetryData(
      speed: newSpeed,
      heading: newHeading,
      latitude: currentLat,
      longitude: currentLng,
      timestamp: DateTime.now(),
      isEmergency: false,
      activeRouteName: _activeRouteName,
    );
    _controller.add(_currentData);
  }

  void _simulateMovement(double newSpeed) {
    // 2. Simulate movement along the active route
    LatLng start = _activeRoute[_currentRouteSegmentIndex];
    LatLng end = _activeRoute[(_currentRouteSegmentIndex + 1) % _activeRoute.length];

    double dLat = end.latitude - start.latitude;
    double dLng = end.longitude - start.longitude;
    double segmentLengthApprox = sqrt((dLat * dLat) + (dLng * dLng)); 
    
    // Speed is km/h. distance in degrees approx (1 deg ~ 111km)
    double speedInDegPerSec = (newSpeed / 3600) / 111; 
    
    if (segmentLengthApprox > 0) {
      _segmentProgress += speedInDegPerSec / segmentLengthApprox;
    } else {
      _segmentProgress = 1.0;
    }

    if (_segmentProgress >= 1.0) {
      _segmentProgress = 0.0;
      _currentRouteSegmentIndex = (_currentRouteSegmentIndex + 1) % (_activeRoute.length - 1);
      start = _activeRoute[_currentRouteSegmentIndex];
      end = _activeRoute[_currentRouteSegmentIndex + 1];
    }

    double currentLat = start.latitude + (end.latitude - start.latitude) * _segmentProgress;
    double currentLng = start.longitude + (end.longitude - start.longitude) * _segmentProgress;

    double newHeading = atan2(end.longitude - start.longitude, end.latitude - start.latitude) * (180 / pi);
    if (newHeading < 0) {
      newHeading += 360;
    }

    _currentData = TelemetryData(
      speed: newSpeed,
      heading: newHeading,
      latitude: currentLat,
      longitude: currentLng,
      timestamp: DateTime.now(),
      isEmergency: false,
      activeRouteName: _activeRouteName,
    );
    _controller.add(_currentData);
  }

  void triggerEmergencyStop() {
    _isEmergencyStop = true;
    _targetSpeed = 0.0;
  }

  void releaseEmergencyStop() {
    _isEmergencyStop = false;
  }

  void setTargetSpeed(double speed) {
    if (!_isEmergencyStop) {
      _targetSpeed = speed;
    }
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
