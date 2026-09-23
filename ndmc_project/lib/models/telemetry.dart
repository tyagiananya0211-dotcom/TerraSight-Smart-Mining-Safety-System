/// Alert states for vehicle safety
enum AlertState { ok, caution, hazard }

/// Radar sweep point from ToF sensor
class RadarPoint {
  final double angle;
  final double dist;

  const RadarPoint({required this.angle, required this.dist});

  Map<String, dynamic> toJson() => {'a': angle, 'd': dist};

  factory RadarPoint.fromJson(Map<String, dynamic> json) => RadarPoint(
        angle: (json['a'] ?? 0.0).toDouble(),
        dist: (json['d'] ?? 0.0).toDouble(),
      );
}

/// Telemetry data model - CONTRACT with PHP dashboard and Python service
///
/// IMPORTANT: This is a shared schema. Changing field names or JSON keys
/// is a BREAKING CHANGE that requires coordination with:
/// - PHP dashboard
/// - Python visibility service
/// - ESP32 firmware
///
/// Wire format uses short keys to keep payload under 500 bytes.
class Telemetry {
  final String vehicleId;        // Wire: "vid"
  final int timestampMs;         // Wire: "ts"
  final double frontDistance;    // Wire: "fd"  cm, forward ultrasonic
  final double groundDistance;   // Wire: "gd"  cm, downward ultrasonic
  final double groundBaseline;   // Wire: "gb"  cm, calibrated flat-ground reference
  final List<RadarPoint> tofSweep; // Wire: "sweep" [{a: angle, d: dist}]
  final double visibilityMeters; // Wire: "vis"  from Python service
  final String visConfidence;    // Wire: "vis_conf"  HIGH | LOW
  final double temperature;      // Wire: "temp"
  final double humidity;         // Wire: "hum"
  final double dewPointSpread;   // Wire: "dps"  temp - dewPoint; small = fog risk
  final double ambientLux;       // Wire: "lux"
  final double pitch;            // Wire: "pitch"
  final double roll;             // Wire: "roll"
  final double yawRate;          // Wire: "yaw"
  final int motorPwm;            // Wire: "pwm"  0-255
  final double speed;            // Wire: "spd"  km/h, estimated
  final double safeSpeedLimit;   // Wire: "safe" km/h, computed (sensor-enabled)
  final double humanBaselineSpeed; // Wire: "base" km/h, what driver could do with eyes alone
  final double speedGainRatio;   // Wire: "gain" safeSpeedLimit / humanBaselineSpeed (KEY METRIC)
  final double ttc;              // Wire: "ttc"  seconds
  final String alertState;       // Wire: "alert" OK | CAUTION | HAZARD
  final bool isSimulated;        // Wire: "sim"  true if running on phone fallback

  const Telemetry({
    required this.vehicleId,
    required this.timestampMs,
    required this.frontDistance,
    required this.groundDistance,
    required this.groundBaseline,
    required this.tofSweep,
    required this.visibilityMeters,
    required this.visConfidence,
    required this.temperature,
    required this.humidity,
    required this.dewPointSpread,
    required this.ambientLux,
    required this.pitch,
    required this.roll,
    required this.yawRate,
    required this.motorPwm,
    required this.speed,
    required this.safeSpeedLimit,
    required this.humanBaselineSpeed,
    required this.speedGainRatio,
    required this.ttc,
    required this.alertState,
    required this.isSimulated,
  });

  /// Create empty/default telemetry for initialization
  factory Telemetry.empty() {
    return Telemetry(
      vehicleId: "DMP-00",
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      frontDistance: 1000.0,
      groundDistance: 100.0,
      groundBaseline: 100.0,
      tofSweep: [],
      visibilityMeters: 10.0,
      visConfidence: "LOW",
      temperature: 25.0,
      humidity: 50.0,
      dewPointSpread: 5.0,
      ambientLux: 500.0,
      pitch: 0.0,
      roll: 0.0,
      yawRate: 0.0,
      motorPwm: 0,
      speed: 0.0,
      safeSpeedLimit: 15.0,
      humanBaselineSpeed: 15.0,
      speedGainRatio: 1.0,
      ttc: 99.0,
      alertState: "OK",
      isSimulated: true,
    );
  }

  /// Serialize to JSON with wire-format short keys
  ///
  /// Payload must be under 500 bytes for 20Hz streaming
  Map<String, dynamic> toJson() {
    return {
      'vid': vehicleId,
      'ts': timestampMs,
      'fd': frontDistance,
      'gd': groundDistance,
      'gb': groundBaseline,
      'sweep': tofSweep.map((e) => e.toJson()).toList(),
      'vis': visibilityMeters,
      'vis_conf': visConfidence,
      'temp': temperature,
      'hum': humidity,
      'dps': dewPointSpread,
      'lux': ambientLux,
      'pitch': pitch,
      'roll': roll,
      'yaw': yawRate,
      'pwm': motorPwm,
      'spd': speed,
      'safe': safeSpeedLimit,
      'base': humanBaselineSpeed,
      'gain': speedGainRatio,
      'ttc': ttc,
      'alert': alertState,
      'sim': isSimulated,
    };
  }

  /// Deserialize from JSON wire format
  factory Telemetry.fromJson(Map<String, dynamic> json) {
    return Telemetry(
      vehicleId: json['vid'] as String? ?? "DMP-00",
      timestampMs: json['ts'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      frontDistance: (json['fd'] ?? 1000.0).toDouble(),
      groundDistance: (json['gd'] ?? 100.0).toDouble(),
      groundBaseline: (json['gb'] ?? 100.0).toDouble(),
      tofSweep: (json['sweep'] as List<dynamic>?)
              ?.map((e) => RadarPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      visibilityMeters: (json['vis'] ?? 10.0).toDouble(),
      visConfidence: json['vis_conf'] as String? ?? "LOW",
      temperature: (json['temp'] ?? 25.0).toDouble(),
      humidity: (json['hum'] ?? 50.0).toDouble(),
      dewPointSpread: (json['dps'] ?? 5.0).toDouble(),
      ambientLux: (json['lux'] ?? 500.0).toDouble(),
      pitch: (json['pitch'] ?? 0.0).toDouble(),
      roll: (json['roll'] ?? 0.0).toDouble(),
      yawRate: (json['yaw'] ?? 0.0).toDouble(),
      motorPwm: json['pwm'] as int? ?? 0,
      speed: (json['spd'] ?? 0.0).toDouble(),
      safeSpeedLimit: (json['safe'] ?? 15.0).toDouble(),
      humanBaselineSpeed: (json['base'] ?? 15.0).toDouble(),
      speedGainRatio: (json['gain'] ?? 1.0).toDouble(),
      ttc: (json['ttc'] ?? 99.0).toDouble(),
      alertState: json['alert'] as String? ?? "OK",
      isSimulated: json['sim'] as bool? ?? true,
    );
  }

  /// Create a copy with updated fields
  Telemetry copyWith({
    String? vehicleId,
    int? timestampMs,
    double? frontDistance,
    double? groundDistance,
    double? groundBaseline,
    List<RadarPoint>? tofSweep,
    double? visibilityMeters,
    String? visConfidence,
    double? temperature,
    double? humidity,
    double? dewPointSpread,
    double? ambientLux,
    double? pitch,
    double? roll,
    double? yawRate,
    int? motorPwm,
    double? speed,
    double? safeSpeedLimit,
    double? humanBaselineSpeed,
    double? speedGainRatio,
    double? ttc,
    String? alertState,
    bool? isSimulated,
  }) {
    return Telemetry(
      vehicleId: vehicleId ?? this.vehicleId,
      timestampMs: timestampMs ?? this.timestampMs,
      frontDistance: frontDistance ?? this.frontDistance,
      groundDistance: groundDistance ?? this.groundDistance,
      groundBaseline: groundBaseline ?? this.groundBaseline,
      tofSweep: tofSweep ?? this.tofSweep,
      visibilityMeters: visibilityMeters ?? this.visibilityMeters,
      visConfidence: visConfidence ?? this.visConfidence,
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      dewPointSpread: dewPointSpread ?? this.dewPointSpread,
      ambientLux: ambientLux ?? this.ambientLux,
      pitch: pitch ?? this.pitch,
      roll: roll ?? this.roll,
      yawRate: yawRate ?? this.yawRate,
      motorPwm: motorPwm ?? this.motorPwm,
      speed: speed ?? this.speed,
      safeSpeedLimit: safeSpeedLimit ?? this.safeSpeedLimit,
      humanBaselineSpeed: humanBaselineSpeed ?? this.humanBaselineSpeed,
      speedGainRatio: speedGainRatio ?? this.speedGainRatio,
      ttc: ttc ?? this.ttc,
      alertState: alertState ?? this.alertState,
      isSimulated: isSimulated ?? this.isSimulated,
    );
  }
}
