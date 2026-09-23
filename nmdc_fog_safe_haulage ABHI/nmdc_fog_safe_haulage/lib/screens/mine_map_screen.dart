import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/telemetry_service.dart';
import '../services/sensor_simulation_service.dart';
import '../core/constants/app_colors.dart';
import '../widgets/glass_card.dart';

class MineMapScreen extends StatefulWidget {
  final bool isEmbedded;
  const MineMapScreen({super.key, this.isEmbedded = false});

  @override
  State<MineMapScreen> createState() => _MineMapScreenState();
}

class _MineMapScreenState extends State<MineMapScreen> {
  final TelemetryService _telemetryService = TelemetryService();
  final SensorSimulationService _sensorService = SensorSimulationService();
  
  StreamSubscription? _telemetrySub;
  StreamSubscription? _sensorSub;
  
  final MapController _mapController = MapController();

  // State for map objects
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  String _mapStyle = 'normal';

  double _visibility = 30.0;
  Color _routeColor = AppColors.statusSafe;
  Color _markerColor = Colors.green;

  @override
  void initState() {
    super.initState();
    _updateRouteColor();
    _initPolylines();
    _initMarkers();

    // Listen to visibility changes to update route color dynamically
    _sensorSub = _sensorService.getSensorData().listen((data) {
      if (mounted) {
        setState(() {
          _visibility = data.visibility;
          _updateRouteColor();
        });
      }
    });

    // Listen to telemetry for live truck location
    _telemetrySub = _telemetryService.telemetryStream.listen((data) {
      if (mounted) {
        setState(() {
          _updateMyTruckMarker(data);
        });
      }
    });
  }

  void _updateRouteColor() {
    // Fog intelligence
    if (_visibility > 50) {
      _routeColor = AppColors.statusSafe;
      _markerColor = Colors.green;
    } else if (_visibility > 20) {
      _routeColor = AppColors.statusWarning;
      _markerColor = Colors.orange;
    } else if (_visibility > 8) {
      _routeColor = AppColors.statusHigh;
      _markerColor = Colors.deepOrange;
    } else {
      _routeColor = AppColors.statusCritical;
      _markerColor = Colors.red;
    }
    _initPolylines();
    _initMarkers(); // Refresh marker colors based on risk
  }

  void _initPolylines() {
    _polylines = [
      Polyline(
        points: _telemetryService.currentRoute,
        strokeWidth: 6,
        color: _routeColor,
        strokeJoin: StrokeJoin.round,
      )
    ];
  }

  void _initMarkers() {
    _markers = [
      // Mock other trucks
      Marker(
        point: const LatLng(18.7550, 81.2520),
        width: 40,
        height: 40,
        child: Icon(Icons.local_shipping, color: _markerColor, size: 30),
      ),
      Marker(
        point: const LatLng(18.7470, 81.2360),
        width: 40,
        height: 40,
        child: Icon(Icons.local_shipping, color: _markerColor, size: 30),
      ),
      Marker(
        point: const LatLng(18.7390, 81.2230),
        width: 40,
        height: 40,
        child: Icon(Icons.local_shipping, color: _markerColor, size: 30),
      ),
      Marker(
        point: const LatLng(18.7580, 81.2600),
        width: 40,
        height: 40,
        child: Icon(Icons.local_shipping, color: _markerColor, size: 30),
      ),
    ];
    
    // Add current pos
    _updateMyTruckMarker(_telemetryService.currentData);
  }

  void _updateMyTruckMarker(TelemetryData data) {
    // Remove old 'YOU' marker by key if we had one, but since we recreate it, we just keep the first 4 mock markers
    if (_markers.length > 4) {
      _markers.removeLast();
    }
    
    _markers.add(
      Marker(
        point: LatLng(data.latitude, data.longitude),
        width: 60,
        height: 60,
        child: Transform.rotate(
          angle: data.heading * (3.14159 / 180),
          child: const Icon(Icons.navigation, color: Colors.blue, size: 40),
        ),
      )
    );
  }

  void _cycleMapType() {
    setState(() {
      if (_mapStyle == 'normal') {
        _mapStyle = 'satellite'; // OSM doesn't have native satellite, we would need a different tile provider
      } else {
        _mapStyle = 'normal';
      }
    });
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    _sensorSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapContent = Stack(
      children: [
        // MAP BACKGROUND
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(_telemetryService.currentData.latitude, _telemetryService.currentData.longitude),
              initialZoom: 14.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.nmdc_fog_safe_haulage',
              ),
              PolylineLayer(
                polylines: _polylines,
              ),
              MarkerLayer(
                markers: _markers,
              ),
            ],
          ),
        ),

        // LEGEND
        if (!widget.isEmbedded)
        Positioned(
          top: 16,
          left: 16,
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            borderRadius: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLegendItem('Safe Zone', AppColors.statusSafe),
                const SizedBox(height: 4),
                _buildLegendItem('Moderate', AppColors.statusWarning),
                const SizedBox(height: 4),
                _buildLegendItem('High Risk', AppColors.statusHigh),
                const SizedBox(height: 4),
                _buildLegendItem('Critical', AppColors.statusCritical),
              ],
            ),
          ),
        ),

        // ROUTE INFORMATION BOTTOM CARD
        if (!widget.isEmbedded)
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Route Information', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('${_telemetryService.currentRouteName} ', style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('(Active)', style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.8), fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildRouteStat('Distance', _telemetryService.currentRouteName == 'Route B' ? '4.2' : '3.8', 'km'),
                    _buildRouteStat('ETA', _telemetryService.currentRouteName == 'Route B' ? '12' : '10', 'min'),
                    _buildRouteStat('Visibility', _visibility.toStringAsFixed(0), 'm', color: _routeColor),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _telemetryService.changeRoute();
                        _initPolylines();
                        // Auto center on new route
                        _mapController.move(
                          _telemetryService.currentRoute[0],
                          14.5,
                        );
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Change Route', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return mapContent;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Live Map', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        actions: [
          IconButton(
            onPressed: _cycleMapType,
            icon: const Icon(Icons.layers_outlined, color: AppColors.textPrimary),
            tooltip: 'Toggle Map Layers',
          ),
          IconButton(
            onPressed: () {
              // Recenter map on user
              _mapController.move(
                LatLng(_telemetryService.currentData.latitude, _telemetryService.currentData.longitude),
                _mapController.camera.zoom,
              );
            },
            icon: const Icon(Icons.my_location, color: AppColors.textPrimary),
            tooltip: 'Recenter on Vehicle',
          ),
        ],
      ),
      body: mapContent,
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Icon(Icons.circle, color: color, size: 10),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
      ],
    );
  }

  Widget _buildRouteStat(String label, String value, String unit, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: TextStyle(color: color ?? AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(width: 2),
            Text(unit, style: TextStyle(color: color ?? AppColors.textSecondary, fontSize: 12)),
          ],
        )
      ],
    );
  }
}