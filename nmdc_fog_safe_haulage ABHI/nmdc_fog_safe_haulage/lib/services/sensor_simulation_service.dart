import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/sensor_data.dart';

class SensorSimulationService {
  static final SensorSimulationService _instance = SensorSimulationService._internal();
  factory SensorSimulationService() => _instance;
  SensorSimulationService._internal();

  final _sensorController = StreamController<SensorData>.broadcast();
  Stream<SensorData> getSensorData() => _sensorController.stream;

  WebSocketChannel? _channel;
  bool _isConnected = false;

  void connectToHardware(String ipAddress) {
    if (_isConnected) {
      _channel?.sink.close();
    }

    try {
      final wsUrl = Uri.parse('ws://$ipAddress:81');
      _channel = WebSocketChannel.connect(wsUrl);
      _isConnected = true;

      _channel!.stream.listen((message) {
        try {
          final decoded = jsonDecode(message);
          _sensorController.add(SensorData(
            obstacleDistance: decoded['obstacleDistance']?.toDouble() ?? 50.0,
            visibility: decoded['visibility']?.toDouble() ?? 100.0,
            humidity: decoded['humidity']?.toDouble() ?? 65.0,
            windSpeed: decoded['windSpeed']?.toDouble() ?? 12.0,
            rainfall: decoded['rainfall']?.toDouble() ?? 0.0,
            roadFriction: decoded['roadFriction']?.toDouble() ?? 0.8,
            temperature: decoded['temperature']?.toInt() ?? 25,
          ));
        } catch (e) {
          print("Error parsing sensor data: $e");
        }
      }, onDone: () {
        _isConnected = false;
        print("Hardware connection closed.");
      }, onError: (error) {
        _isConnected = false;
        print("Hardware connection error: $error");
      });
    } catch (e) {
      _isConnected = false;
      print("Could not connect to hardware: $e");
    }
  }

  void disconnectHardware() {
    _channel?.sink.close();
    _isConnected = false;
  }

  // Keep these empty for backward compatibility in UI,
  // or they could send commands to the hardware via websocket.
  void triggerFog() {}
  void clearFog() {}
  void resetSimulation() {}
}