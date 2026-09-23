import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/telemetry.dart';

class RoverIngestService {
  final String roverWsUrl;
  
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  
  final _telemetryController = StreamController<Telemetry>.broadcast();
  Stream<Telemetry> get telemetryStream => _telemetryController.stream;
  
  final ValueNotifier<bool> isRoverConnected = ValueNotifier<bool>(false);

  Timer? _reconnectTimer;
  int _reconnectDelayMs = 1000;
  final int _maxReconnectDelayMs = 10000;
  bool _isDisposed = false;

  RoverIngestService({this.roverWsUrl = 'ws://192.168.4.1:81'}) {
    _connect();
  }

  void _connect() {
    if (_isDisposed) return;
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(roverWsUrl));
      
      _subscription = _channel!.stream.listen(
        (message) {
          if (!isRoverConnected.value) {
            isRoverConnected.value = true;
            _reconnectDelayMs = 1000; // Reset delay on successful connection
          }
          
          try {
            final data = jsonDecode(message);
            final telemetry = Telemetry.fromJson(data);
            _telemetryController.add(telemetry);
          } catch (e) {
            // Ignore malformed payloads to keep stream alive
          }
        },
        onError: (error) {
          _scheduleReconnect();
        },
        onDone: () {
          _scheduleReconnect();
        }
      );
    } catch (e) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    isRoverConnected.value = false;
    _subscription?.cancel();
    _channel?.sink.close();
    
    if (_isDisposed) return;
    
    if (_reconnectTimer?.isActive ?? false) return;
    
    _reconnectTimer = Timer(Duration(milliseconds: _reconnectDelayMs), () {
      _connect();
    });
    
    // Exponential backoff
    _reconnectDelayMs *= 2;
    if (_reconnectDelayMs > _maxReconnectDelayMs) {
      _reconnectDelayMs = _maxReconnectDelayMs;
    }
  }

  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _telemetryController.close();
    isRoverConnected.dispose();
  }
}
