import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import '../utils/bmp_converter.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:io' show HttpServer;
import 'package:audioplayers/audioplayers.dart';
import '../widgets/hud_4grid_widget.dart';
import '../core/constants/app_colors.dart';
import '../services/mjpeg_server_service.dart';
import '../services/php_bridge_service.dart';
import '../services/collapse_detector.dart';
import '../models/telemetry.dart';
import '../services/rover_ingest_service.dart';
import '../services/telemetry_source.dart';
import '../services/v2v_service.dart';
import '../services/conflict_predictor.dart';
import '../widgets/conflict_warning_widget.dart';

class DriverHudScreen extends StatefulWidget {
  const DriverHudScreen({Key? key}) : super(key: key);

  @override
  State<DriverHudScreen> createState() => _DriverHudScreenState();
}

class _DriverHudScreenState extends State<DriverHudScreen> {
  String _localIp = 'Fetching...';
  bool _isServerRunning = false;
  HttpServer? _server;
  final MjpegServerService _mjpegService = MjpegServerService();
  final List<WebSocketChannel> _clients = [];
  CameraController? _cameraController;
  late final RoverIngestService _roverService;
  late final TelemetrySource _telemetrySource;
  PhpBridgeService? _phpBridge;
  final CollapseDetector _collapseDetector = CollapseDetector();
  StreamSubscription? _telemetrySub;

  Telemetry _telemetry = Telemetry.empty();
  bool _isProcessingFrame = false;

  // DEBUG: hidden developer panel that pushes hand-crafted telemetry
  // straight to connected WebSocket clients (the web control room), so the
  // dashboard/3D twin/alerts/production engine can be exercised end-to-end
  // without ESP32 hardware wired up yet.
  final TextEditingController _debugVehicleIdController = TextEditingController(text: 'DMP-01');
  double _debugPitch = 0.0; // -45..45 deg
  double _debugRoll = 0.0; // -45..45 deg
  double _debugSpeed = 0.0; // 0..50 km/h
  double _debugSafeSpeed = 15.0; // 0..50 km/h
  double _debugTofDistance = 3000.0; // 0..5000 cm
  double _debugCliffDistance = 30.0; // 30..200 cm
  bool _debugAutoSend = false;
  Timer? _debugSendTimer;
  DateTime? _lastDebugSendAt;
  int _lastDebugSendCount = 0;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;
  String _collapseState = "OK";
  DateTime? _lastCollapseAlertTime;

  // V2V Conflict Warning
  final V2VService _v2vService = V2VService();
  final ConflictPredictor _conflictPredictor = ConflictPredictor();
  List<ConflictDetection> _conflicts = [];
  Timer? _conflictCheckTimer;
  Timer? _v2vSimTimer; // For testing without hardware

  @override
  void initState() {
    super.initState();
    // Force landscape mode for Driver HUD
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    // Full-screen tactical display: hide the status/nav bars so the HUD
    // gets that vertical space back instead of squeezing under them.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _fetchLocalIp();
    _initCamera();
    _initSensors();
  }

  Future<void> _fetchLocalIp() async {
    try {
      final info = NetworkInfo();
      final ip = await info.getWifiIP();
      setState(() {
        _localIp = ip ?? 'Unknown IP';
      });
    } catch(e) {
      setState(() { _localIp = 'Unsupported Platform'; });
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(
          cameras.first,
          ResolutionPreset.low,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );
        await _cameraController!.initialize();
        if (mounted) setState(() {});
      }
    } catch(e) {
      print('Camera init error: $e');
    }
  }


  void _initSensors() {
    _roverService = RoverIngestService();
    _telemetrySource = TelemetrySource(_roverService);

    _telemetrySub = _telemetrySource.stream.listen((telemetry) {
      if (!mounted) return;

      // Process ground distance through collapse detector
      final collapseState = _collapseDetector.processSample(telemetry.groundDistance);

      // Determine final alert state (worst of speed/collapse)
      String finalAlertState = telemetry.alertState;
      if (collapseState == "HAZARD") {
        finalAlertState = "HAZARD";
      } else if (collapseState == "CAUTION" && finalAlertState == "OK") {
        finalAlertState = "CAUTION";
      }

      // Update telemetry with collapse-aware alert state
      final updatedTelemetry = telemetry.copyWith(alertState: finalAlertState);

      setState(() {
        _telemetry = updatedTelemetry;
        _collapseState = collapseState;
      });

      // Collapse HAZARD audio alert (distinct from speed alert)
      if (collapseState == "HAZARD") {
        _triggerCollapseAlert();
      }

      // Speed alert (original logic)
      if (telemetry.alertState == "HAZARD" && !_isPlayingAudio) {
        _isPlayingAudio = true;
        // In a real app we'd play a beep asset here
      } else if (telemetry.alertState != "HAZARD") {
        _isPlayingAudio = false;
      }

      // Send to WebSocket clients.
      // Payload is additive: the on-device short wire keys (fd/gd/spd/...)
      // stay for any consumer built against the Telemetry contract, plus the
      // long-key fields the web control room's admin dashboard expects
      // (tofDistance/speed/safeSpeed/cliffDistance/vehicleId/...).
      if (_clients.isNotEmpty) {
        final wirePayload = {
          ...updatedTelemetry.toJson(),
          'vehicleId': updatedTelemetry.vehicleId,
          'speed': updatedTelemetry.speed,
          'safeSpeed': updatedTelemetry.safeSpeedLimit,
          'tofDistance': updatedTelemetry.frontDistance,
          'cliffDistance': updatedTelemetry.groundDistance - updatedTelemetry.groundBaseline,
          'pitch': updatedTelemetry.pitch,
          'roll': updatedTelemetry.roll,
          'isDrifting': updatedTelemetry.alertState == 'HAZARD' || updatedTelemetry.alertState == 'CAUTION',
          'timestamp': updatedTelemetry.timestampMs,
        };
        final telemetryData = jsonEncode(wirePayload);
        for (var client in _clients) {
          client.sink.add(telemetryData);
        }
      }

      // Send to PHP backend
      _phpBridge?.addTelemetry(updatedTelemetry);
      _phpBridge?.checkAndPostAlert(updatedTelemetry);
    });

    // V2V CONFLICT CHECKING (10Hz)
    _conflictCheckTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _checkConflicts();
    });

    // TESTING ONLY: Simulate approaching peer vehicle
    // This will be replaced by real ESP32 V2V data
    final simStartTime = DateTime.now().millisecondsSinceEpoch;
    _v2vSimTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || !_isServerRunning) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = (now - simStartTime) / 1000.0; // seconds

      // Simulate RSSI increasing (approaching) for first 10 seconds
      // Then plateau to show conflict stabilization
      final rssi = elapsed < 10
          ? (-70 + (elapsed * 2)).toInt().clamp(-90, -30)
          : -50; // Plateau at MID range

      _v2vService.updatePeer(
        vehicleId: "DMP-02",
        rssi: rssi,
        heading: 180.0, // Opposite heading (conflict condition)
        speed: 25.0,
        alert: 0,
        seq: (elapsed * 4).toInt(),
        timestampMs: now,
      );
    });
  }

  Timer? _frameTimer;

  /// Trigger distinct collapse alert audio (different from speed alert)
  void _triggerCollapseAlert() {
    final now = DateTime.now();

    // Debounce - only alert once every 2 seconds
    if (_lastCollapseAlertTime != null) {
      final timeSinceLastAlert = now.difference(_lastCollapseAlertTime!);
      if (timeSinceLastAlert.inMilliseconds < 2000) {
        return; // Too soon, skip alert
      }
    }

    _lastCollapseAlertTime = now;

    // Play distinct collapse alert sound
    // In production, use a different sound file than speed alert
    try {
      // In a real app: await _audioPlayer.play(AssetSource('sounds/collapse_alert.mp3'));
      debugPrint('🚨 COLLAPSE ALERT: Road edge detected! Ground distance: ${_telemetry.groundDistance.toStringAsFixed(1)} cm, Baseline: ${_collapseDetector.baseline.toStringAsFixed(1)} cm');
    } catch (e) {
      debugPrint('Collapse audio alert failed: $e');
    }
  }

  /// Calibrate collapse detector baseline
  void _calibrateCollapseDetector() {
    _collapseDetector.calibrate(_telemetry.groundDistance);
    setState(() {
      _collapseState = "OK";
    });

    // Show feedback to driver
    debugPrint('✅ Collapse detector calibrated at ${_telemetry.groundDistance.toStringAsFixed(1)} cm');
  }

  // =====================================================================
  // DEBUG PANEL — hand-crafted telemetry pushed straight to the web
  // control room over the existing WS 8080 broadcast, independent of the
  // real rover/phone-sensor pipeline. Lets a tester drive the dashboard's
  // 3D twin, braking envelope, bench-drop alarm and production engine
  // without ESP32 hardware wired up yet.
  // =====================================================================

  void _sendDebugTelemetry() {
    _lastDebugSendAt = DateTime.now();
    if (_clients.isEmpty) {
      _lastDebugSendCount = 0;
      return;
    }
    final payload = {
      'vehicleId': _debugVehicleIdController.text.trim().isEmpty
          ? 'DMP-01'
          : _debugVehicleIdController.text.trim(),
      'speed': _debugSpeed,
      'safeSpeed': _debugSafeSpeed,
      'pitch': _debugPitch,
      'roll': _debugRoll,
      'tofDistance': _debugTofDistance,
      'cliffDistance': _debugCliffDistance,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };
    final data = jsonEncode(payload);
    // A stale/broken socket throwing here must not stop the payload from
    // reaching the other connected clients, and must not silently make
    // the whole "Send Once" tap look like a no-op.
    final deadClients = <WebSocketChannel>[];
    var sentCount = 0;
    for (var client in _clients) {
      try {
        client.sink.add(data);
        sentCount++;
      } catch (e) {
        debugPrint('⚠️ Debug telemetry send failed for a client, dropping it: $e');
        deadClients.add(client);
      }
    }
    if (deadClients.isNotEmpty) {
      _clients.removeWhere((c) => deadClients.contains(c));
    }
    _lastDebugSendCount = sentCount;
  }

  void _setDebugAutoSend(bool enabled) {
    _debugAutoSend = enabled;
    _debugSendTimer?.cancel();
    if (enabled) {
      _sendDebugTelemetry();
      _debugSendTimer = Timer.periodic(
        const Duration(milliseconds: 500), // 2 Hz
        (_) => _sendDebugTelemetry(),
      );
    }
  }

  /// Compact sidebar trigger for the hidden developer panel.
  Widget _buildDebugPanelTrigger() {
    return OutlinedButton.icon(
      onPressed: _showDebugPanel,
      icon: Icon(Icons.bug_report_outlined, size: 14, color: _debugAutoSend ? AppColors.statusWarning : AppColors.textMuted),
      label: Text(
        _debugAutoSend ? 'DEBUG: LIVE @ 2Hz' : 'DEBUG PANEL',
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: _debugAutoSend ? AppColors.statusWarning : AppColors.textMuted),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8),
        side: BorderSide(color: _debugAutoSend ? AppColors.statusWarning : AppColors.border),
      ),
    );
  }

  void _showDebugPanel() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget slider({
              required String label,
              required double value,
              required double min,
              required double max,
              required String suffix,
              required ValueChanged<double> onChanged,
            }) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$label: ${value.toStringAsFixed(1)}$suffix',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: value,
                    min: min,
                    max: max,
                    activeColor: AppColors.statusWarning,
                    onChanged: (v) {
                      onChanged(v);
                      setDialogState(() {});
                    },
                  ),
                ],
              );
            }

            void applyScenario({
              required double speed,
              required double safeSpeed,
              required double tofDistance,
              required double cliffDistance,
              required double pitch,
              required double roll,
            }) {
              _debugSpeed = speed;
              _debugSafeSpeed = safeSpeed;
              _debugTofDistance = tofDistance;
              _debugCliffDistance = cliffDistance;
              _debugPitch = pitch;
              _debugRoll = roll;
              setDialogState(() {});
              if (_debugAutoSend) _sendDebugTelemetry();
            }

            Widget scenarioButton(String label, IconData icon, Color color, VoidCallback onTap) {
              return OutlinedButton.icon(
                onPressed: onTap,
                icon: Icon(icon, size: 14, color: color),
                label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10.5)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  side: BorderSide(color: color.withValues(alpha: 0.6)),
                  backgroundColor: color.withValues(alpha: 0.08),
                ),
              );
            }

            return Dialog(
              backgroundColor: AppColors.surface,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.bug_report_outlined, color: AppColors.statusWarning, size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'DEVELOPER TELEMETRY PANEL',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.0),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: AppColors.textMuted),
                              onPressed: () => Navigator.of(dialogContext).pop(),
                            ),
                          ],
                        ),
                        const Text(
                          'Pushes hand-crafted telemetry straight to the web control room over WS 8080, bypassing real sensors.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 14),

                        const Text('SCENARIOS', style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 0.6)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            scenarioButton('NORMAL SAFE', Icons.check_circle_outline, AppColors.statusSafe, () {
                              applyScenario(speed: 25, safeSpeed: 30, tofDistance: 4000, cliffDistance: 30, pitch: 0, roll: 0);
                            }),
                            scenarioButton('THICK FOG', Icons.foggy, AppColors.statusInfo, () {
                              applyScenario(speed: 15, safeSpeed: 15, tofDistance: 1200, cliffDistance: 30, pitch: 0, roll: 0);
                            }),
                            scenarioButton('OVERSPEED', Icons.speed, AppColors.statusWarning, () {
                              applyScenario(speed: 35, safeSpeed: 15, tofDistance: 1200, cliffDistance: 30, pitch: 0, roll: 0);
                            }),
                            scenarioButton('CRITICAL BENCH DROP', Icons.dangerous_outlined, AppColors.statusCritical, () {
                              applyScenario(speed: 5, safeSpeed: 10, tofDistance: 4000, cliffDistance: 150, pitch: 5, roll: 5);
                            }),
                            scenarioButton('3D ATTITUDE TEST', Icons.view_in_ar_outlined, AppColors.primary, () {
                              applyScenario(speed: 10, safeSpeed: 20, tofDistance: 4000, cliffDistance: 30, pitch: 20, roll: 15);
                            }),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: AppColors.border, height: 1),
                        const SizedBox(height: 16),

                        const Text('MANUAL CONTROL', style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 0.6)),
                        const SizedBox(height: 10),

                        const Text('VEHICLE ID', style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 0.6)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _debugVehicleIdController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: AppColors.background,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
                          ),
                        ),
                        const SizedBox(height: 8),

                        slider(
                          label: 'Pitch',
                          value: _debugPitch,
                          min: -45,
                          max: 45,
                          suffix: '°',
                          onChanged: (v) => _debugPitch = v,
                        ),
                        slider(
                          label: 'Roll',
                          value: _debugRoll,
                          min: -45,
                          max: 45,
                          suffix: '°',
                          onChanged: (v) => _debugRoll = v,
                        ),
                        slider(
                          label: 'Speed',
                          value: _debugSpeed,
                          min: 0,
                          max: 50,
                          suffix: ' km/h',
                          onChanged: (v) => _debugSpeed = v,
                        ),
                        slider(
                          label: 'Safe Speed',
                          value: _debugSafeSpeed,
                          min: 0,
                          max: 50,
                          suffix: ' km/h',
                          onChanged: (v) => _debugSafeSpeed = v,
                        ),
                        slider(
                          label: 'ToF Distance (usable horizon)',
                          value: _debugTofDistance,
                          min: 0,
                          max: 5000,
                          suffix: ' cm',
                          onChanged: (v) => _debugTofDistance = v,
                        ),
                        slider(
                          label: 'Cliff Distance (ground sensor)',
                          value: _debugCliffDistance,
                          min: 30,
                          max: 200,
                          suffix: ' cm',
                          onChanged: (v) => _debugCliffDistance = v,
                        ),

                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _debugAutoSend ? AppColors.statusWarning : AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text('AUTO-SEND @ 2 Hz', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              Switch(
                                value: _debugAutoSend,
                                activeThumbColor: AppColors.statusWarning,
                                onChanged: (v) {
                                  _setDebugAutoSend(v);
                                  setDialogState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            _sendDebugTelemetry();
                            setDialogState(() {});
                          },
                          icon: const Icon(Icons.send, size: 16, color: Colors.white),
                          label: const Text('SEND ONCE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                        if (!_isServerRunning) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Server is OFF — go back and tap START first, otherwise there is nothing to send over.',
                            style: TextStyle(color: AppColors.statusCritical, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ] else if (_clients.isEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'No dashboard connected yet — open the PHP dashboard in Chrome and connect it to this phone\'s IP first.',
                            style: TextStyle(color: AppColors.statusWarning, fontSize: 11),
                          ),
                        ],
                        if (_lastDebugSendAt != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _lastDebugSendCount > 0
                                ? '✓ Sent to $_lastDebugSendCount client(s) at ${_lastDebugSendAt!.hour.toString().padLeft(2, '0')}:${_lastDebugSendAt!.minute.toString().padLeft(2, '0')}:${_lastDebugSendAt!.second.toString().padLeft(2, '0')}'
                                : '✗ Last tap sent to 0 clients at ${_lastDebugSendAt!.hour.toString().padLeft(2, '0')}:${_lastDebugSendAt!.minute.toString().padLeft(2, '0')}:${_lastDebugSendAt!.second.toString().padLeft(2, '0')} — nobody is connected',
                            style: TextStyle(
                              color: _lastDebugSendCount > 0 ? AppColors.statusSafe : AppColors.statusWarning,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Check for V2V conflicts (called at 10Hz)
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

  void _startMission() async {
    if (_isServerRunning) return;

    // Start HTTP Server on 8080 for WebSocket Telemetry with CORS
    try {
      // CORS middleware
      Middleware corsMiddleware = (Handler handler) {
        return (Request request) async {
          if (request.method == 'OPTIONS') {
            return Response.ok('', headers: {
              'Access-Control-Allow-Origin': '*',
              'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
              'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
            });
          }

          final response = await handler(request);
          return response.change(headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
          });
        };
      };

      var wsHandler = webSocketHandler((webSocket, protocol) {
        final channel = webSocket as WebSocketChannel;
        _clients.add(channel);
        channel.sink.done.then((_) {
          _clients.remove(channel);
        });
      });

      var handler = const Pipeline()
          .addMiddleware(corsMiddleware)
          .addHandler(wsHandler);

      _server = await shelf_io.serve(handler, '0.0.0.0', 8080);
      
      // Start MJPEG Server natively for Video Streaming
      await _mjpegService.start(port: 8081);

      setState(() {
        _isServerRunning = true;
      });

      // Initialize PHP Bridge
      _phpBridge = PhpBridgeService(
        vehicleId: "DMP-01",
        localIp: _localIp,
        wsPort: 8080,
        mjpegPort: 8081,
      );
      _phpBridge!.start();

      // Start sending frames from camera directly to MJPEG HTTP clients
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        if (_cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
        }
        
        await _cameraController!.startImageStream((CameraImage image) {
          if (_isProcessingFrame) return;
          _isProcessingFrame = true;
          
          try {
            if (image.format.group == ImageFormatGroup.jpeg) {
              _mjpegService.pushFrame(image.planes[0].bytes);
            } else {
              final bmpBytes = BmpConverter.convertGrayscaleToBmp(image);
              _mjpegService.pushFrame(bmpBytes, isBmp: true);
            }
          } catch(e) {
            print("Frame push error: $e");
          } finally {
            _isProcessingFrame = false;
          }
        });
      }


    } catch (e) {
      print('Error starting server: $e');
    }
  }

  void _stopMission() {
    _frameTimer?.cancel();
    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      _cameraController!.stopImageStream();
    }
    _mjpegService.stop();
    _phpBridge?.stop();
    _server?.close(force: true);
    for(var client in _clients) {
      client.sink.close();
    }
    _clients.clear();
    if (mounted) {
      setState(() {
        _isServerRunning = false;
      });
    }
  }

  @override
  void dispose() {
    // Revert to normal orientations and system UI when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _stopMission();
    _telemetrySub?.cancel();
    _conflictCheckTimer?.cancel();
    _v2vSimTimer?.cancel();
    _v2vService.clear();
    _conflictPredictor.reset();
    _telemetrySource.dispose();
    _roverService.dispose();
    _phpBridge?.dispose();
    _cameraController?.dispose();
    _audioPlayer.dispose();
    _debugSendTimer?.cancel();
    _debugVehicleIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget opticalFeed = Container(
      color: AppColors.background,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, color: AppColors.textMuted, size: 48),
            SizedBox(height: 8),
            Text('NO CAMERA DETECTED', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ],
        ),
      ),
    );
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      // Wrap CameraPreview in FittedBox to cover the box without squishing
      opticalFeed = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _cameraController!.value.previewSize?.height ?? 1,
            height: _cameraController!.value.previewSize?.width ?? 1,
            child: CameraPreview(_cameraController!),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      // Removed AppBar for maximum screen real-estate in Landscape
      body: SafeArea(
        child: Column(
          children: [
            // FULL-WIDTH HAZARD BANNER (shows only on collapse detection)
            if (_collapseState == "HAZARD")
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                decoration: BoxDecoration(
                  color: AppColors.statusCritical,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.statusCritical.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'EDGE DETECTED — STOP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ],
                ),
              ),

            // V2V CONFLICT WARNING
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

            // MAIN CONTENT (LEFT PANEL + RIGHT GRID)
            Expanded(
              child: Row(
                children: [
                  // LEFT CONTROL PANEL (25% width)
                  Container(
              width: 200,
              padding: const EdgeInsets.all(12),
              color: AppColors.surface,
              child: SingleChildScrollView(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('DRIVER HUD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: _telemetry.isSimulated ? AppColors.statusWarning.withValues(alpha: 0.2) : AppColors.statusSafe.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _telemetry.isSimulated ? AppColors.statusWarning : AppColors.statusSafe),
                    ),
                    child: Center(
                      child: Text(
                        _telemetry.isSimulated ? 'PHONE FALLBACK' : 'ROVER LIVE',
                        style: TextStyle(
                          color: _telemetry.isSimulated ? AppColors.statusWarning : AppColors.statusSafe,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isServerRunning ? AppColors.statusSafe.withValues(alpha: 0.12) : AppColors.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isServerRunning ? AppColors.statusSafe : AppColors.border,
                        width: _isServerRunning ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _isServerRunning ? Icons.wifi_tethering : Icons.wifi,
                          color: AppColors.statusSafe,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        if (_isServerRunning) ...[
                          const Text(
                            'SERVER ACTIVE AT',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.statusSafe, fontSize: 9, letterSpacing: 1.0),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _localIp,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.statusSafe, fontSize: 15),
                          ),
                          const Text('PORT: 8080 · 8081', style: TextStyle(color: AppColors.textMuted, fontSize: 9)),
                        ] else ...[
                          Text('IP: $_localIp', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.statusSafe, fontSize: 12)),
                          const Text('PORT: 8080', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Connectivity Indicator
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              _telemetry.isSimulated ? Icons.phone_android : Icons.precision_manufacturing,
                              size: 12,
                              color: _telemetry.isSimulated ? AppColors.statusWarning : AppColors.statusSafe,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Rover',
                                style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                              ),
                            ),
                            Text(
                              _telemetry.isSimulated ? 'SIM' : 'LIVE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: _telemetry.isSimulated ? AppColors.statusWarning : AppColors.statusSafe,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              _phpBridge?.isPhpConnected ?? false ? Icons.cloud_done : Icons.cloud_off,
                              size: 12,
                              color: _phpBridge?.isPhpConnected ?? false ? AppColors.statusSafe : AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'PHP',
                                style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                              ),
                            ),
                            Text(
                              _phpBridge?.isPhpConnected ?? false ? 'OK' : 'OFF',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: _phpBridge?.isPhpConnected ?? false ? AppColors.statusSafe : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              _clients.isNotEmpty ? Icons.devices : Icons.devices_other,
                              size: 12,
                              color: _clients.isNotEmpty ? AppColors.statusSafe : AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Clients',
                                style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                              ),
                            ),
                            Text(
                              '${_clients.length}',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: _clients.isNotEmpty ? AppColors.statusSafe : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
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
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // COLLAPSE DETECTOR CALIBRATION
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _collapseState == "HAZARD"
                            ? AppColors.statusCritical
                            : _collapseState == "CAUTION"
                                ? AppColors.statusWarning
                                : AppColors.border,
                        width: _collapseState != "OK" ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.vertical_align_bottom,
                              size: 12,
                              color: _collapseState == "HAZARD"
                                  ? AppColors.statusCritical
                                  : _collapseState == "CAUTION"
                                      ? AppColors.statusWarning
                                      : AppColors.statusSafe,
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Ground',
                                style: TextStyle(fontSize: 9, color: AppColors.textMuted),
                              ),
                            ),
                            Text(
                              _collapseState,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: _collapseState == "HAZARD"
                                    ? AppColors.statusCritical
                                    : _collapseState == "CAUTION"
                                        ? AppColors.statusWarning
                                        : AppColors.statusSafe,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Baseline: ${_collapseDetector.baseline.toStringAsFixed(0)} cm',
                          style: const TextStyle(fontSize: 8, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 6),
                        ElevatedButton(
                          onPressed: _calibrateCollapseDetector,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          child: const Text(
                            'CALIBRATE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  _buildDebugPanelTrigger(),

                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: _isServerRunning ? null : _startMission,
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    label: const Text('START', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusSafe,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isServerRunning ? _stopMission : null,
                    icon: const Icon(Icons.stop, color: Colors.white),
                    label: const Text('STOP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusCritical,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              ),
            ),

                    // RIGHT TACTICAL GRID (75% width)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Hud4GridWidget(
                          opticalFeedWidget: opticalFeed,
                          telemetry: _telemetry,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
