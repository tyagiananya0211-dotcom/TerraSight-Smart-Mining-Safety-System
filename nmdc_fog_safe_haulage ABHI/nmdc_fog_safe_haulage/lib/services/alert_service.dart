import 'dart:async';
import 'package:flutter/material.dart';
import 'firestore_service.dart';
import '../models/hazard_report.dart';

class SafetyAlert {
  final String id;
  final String type; // Critical, Warning, Info
  final String title;
  final String description;
  final String location;
  final DateTime timestamp;
  bool isAcknowledged;

  SafetyAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.location,
    required this.timestamp,
    this.isAcknowledged = false,
  });
}

class AlertService {
  final _alertsController = StreamController<List<SafetyAlert>>.broadcast();
  List<SafetyAlert> _alerts = [];
  StreamSubscription? _hazardsSubscription;

  Stream<List<SafetyAlert>> get alertsStream => _alertsController.stream;
  List<SafetyAlert> get currentAlerts => _alerts;

  AlertService() {
    _initMockAlerts();
    _listenToLiveHazards();
  }

  void _initMockAlerts() {
    _alerts = [
      SafetyAlert(
        id: 'A1',
        type: 'Warning',
        title: 'Low Visibility Zone',
        description: 'Visibility dropped below 15m ahead.',
        location: 'Route B',
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
    ];
    _alertsController.add(_alerts);
  }

  void _listenToLiveHazards() {
    _hazardsSubscription = FirestoreService().streamActiveHazards().listen((hazards) {
      // Remove previous live hazards
      _alerts.removeWhere((a) => a.id.startsWith('live_'));

      // Add new live hazards
      for (var hazard in hazards) {
        _alerts.insert(
          0,
          SafetyAlert(
            id: 'live_${hazard.id}',
            type: 'Critical',
            title: 'HAZARD: ${hazard.type}',
            description: 'Reported by ${hazard.reporterId}',
            location: 'Lat: ${hazard.latitude.toStringAsFixed(4)}, Lng: ${hazard.longitude.toStringAsFixed(4)}',
            timestamp: hazard.timestamp,
          ),
        );
      }
      
      _alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _alertsController.add(_alerts);
    });
  }

  void acknowledgeAlert(String id) {
    final index = _alerts.indexWhere((a) => a.id == id);
    if (index != -1) {
      _alerts[index].isAcknowledged = true;
      _alertsController.add(_alerts);
    }
  }

  void acknowledgeAll() {
    for (var a in _alerts) {
      a.isAcknowledged = true;
    }
    _alertsController.add(_alerts);
  }

  void simulateNewAlert(SafetyAlert newAlert) {
    _alerts.insert(0, newAlert);
    _alertsController.add(_alerts);
  }

  void dispose() {
    _hazardsSubscription?.cancel();
    _alertsController.close();
  }
}

