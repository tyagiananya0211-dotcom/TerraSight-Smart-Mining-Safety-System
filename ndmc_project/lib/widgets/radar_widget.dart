import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:collection';
import '../models/telemetry.dart';
import 'painters/radar_painter.dart';

/// Real Polar Radar Widget with Persistence and Throttling
///
/// PERFORMANCE OPTIMIZATIONS:
/// 1. RepaintBoundary to isolate radar repaints
/// 2. ValueNotifier to avoid rebuilding entire widget tree
/// 3. Throttle repaints to 20 FPS (50ms interval)
/// 4. Ring buffer for persistence (auto-cleanup old points)
///
/// SAFETY FEATURES:
/// 1. Freezes and shows "NO SIGNAL" if telemetry stops
/// 2. Only updates when actual data changes
/// 3. Tracks time since last update
class RadarWidget extends StatefulWidget {
  /// Telemetry stream providing radar data
  final Telemetry telemetry;

  /// Maximum range for display (meters)
  final double maxRangeMeters;

  /// Safety threshold distance (meters)
  final double safetyThresholdMeters;

  const RadarWidget({
    Key? key,
    required this.telemetry,
    this.maxRangeMeters = 3.0,
    this.safetyThresholdMeters = 1.0,
  }) : super(key: key);

  @override
  State<RadarWidget> createState() => _RadarWidgetState();
}

class _RadarWidgetState extends State<RadarWidget> {
  /// Persistence ring buffer (historical points with timestamps)
  final Queue<RadarPointWithTime> _persistenceBuffer = Queue();

  /// Last telemetry timestamp
  int _lastTelemetryTimestamp = 0;

  /// Time of last repaint (for throttling)
  int _lastRepaintTime = 0;

  /// Throttle interval (ms) - 20 FPS = 50ms
  static const int _throttleIntervalMs = 50;

  /// ValueNotifier for efficient repaints without rebuilding tree
  late final ValueNotifier<int> _repaintTrigger;

  /// Timer for periodic cleanup and freeze detection
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();
    _repaintTrigger = ValueNotifier<int>(0);
    _lastTelemetryTimestamp = DateTime.now().millisecondsSinceEpoch;

    // Start cleanup timer (runs every 100ms)
    _cleanupTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _cleanupOldPoints();
      _checkForFreeze();
    });
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    _repaintTrigger.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RadarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if telemetry has actually changed
    if (oldWidget.telemetry != widget.telemetry) {
      _updatePersistenceBuffer();
      _throttledRepaint();
    }
  }

  /// Update persistence buffer with new sweep points
  void _updatePersistenceBuffer() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _lastTelemetryTimestamp = now;

    // Add current sweep points to persistence buffer
    for (final point in widget.telemetry.tofSweep) {
      _persistenceBuffer.addLast(
        RadarPointWithTime(
          point: point,
          timestampMs: now,
        ),
      );
    }

    // Limit buffer size (max 1000 points to prevent memory issues)
    while (_persistenceBuffer.length > 1000) {
      _persistenceBuffer.removeFirst();
    }
  }

  /// Remove points older than persistence duration
  void _cleanupOldPoints() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoffTime = now - RadarPainter.persistenceDurationMs;

    while (_persistenceBuffer.isNotEmpty &&
           _persistenceBuffer.first.timestampMs < cutoffTime) {
      _persistenceBuffer.removeFirst();
    }
  }

  /// Check if radar should freeze (no recent telemetry)
  void _checkForFreeze() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final timeSinceLastUpdate = now - _lastTelemetryTimestamp;

    // If approaching freeze threshold, trigger repaint to show NO SIGNAL
    if (timeSinceLastUpdate > RadarPainter.freezeThresholdMs) {
      _throttledRepaint();
    }
  }

  /// Trigger repaint with 20 FPS throttling
  void _throttledRepaint() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final timeSinceLastRepaint = now - _lastRepaintTime;

    if (timeSinceLastRepaint >= _throttleIntervalMs) {
      _lastRepaintTime = now;
      _repaintTrigger.value++;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<int>(
        valueListenable: _repaintTrigger,
        builder: (context, _, __) {
          final now = DateTime.now().millisecondsSinceEpoch;
          final timeSinceLastUpdate = now - _lastTelemetryTimestamp;

          // Extract current servo angle from sweep
          // Use the angle of the last point in sweep as current servo position
          final currentServoAngle = widget.telemetry.tofSweep.isNotEmpty
              ? widget.telemetry.tofSweep.last.angle
              : 0.0;

          return CustomPaint(
            painter: RadarPainter(
              currentSweep: widget.telemetry.tofSweep,
              persistenceBuffer: _persistenceBuffer,
              currentServoAngle: currentServoAngle,
              maxRangeMeters: widget.maxRangeMeters,
              safetyThresholdMeters: widget.safetyThresholdMeters,
              timeSinceLastUpdate: timeSinceLastUpdate,
            ),
            child: Container(),
          );
        },
      ),
    );
  }
}
