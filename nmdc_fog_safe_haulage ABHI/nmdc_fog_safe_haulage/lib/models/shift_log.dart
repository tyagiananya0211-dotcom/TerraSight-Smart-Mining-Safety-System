import 'package:cloud_firestore/cloud_firestore.dart';

class ShiftLog {
  final String id;
  final String driverId;
  final DateTime startTime;
  final DateTime? endTime;
  final int distanceCovered; // in meters
  final double averageSpeed; // in km/h
  final double safetyScore;
  final int hazardsReported;

  ShiftLog({
    required this.id,
    required this.driverId,
    required this.startTime,
    this.endTime,
    this.distanceCovered = 0,
    this.averageSpeed = 0.0,
    this.safetyScore = 100.0,
    this.hazardsReported = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'distanceCovered': distanceCovered,
      'averageSpeed': averageSpeed,
      'safetyScore': safetyScore,
      'hazardsReported': hazardsReported,
    };
  }

  factory ShiftLog.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return ShiftLog(
      id: doc.id,
      driverId: data['driverId'] ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: data['endTime'] != null ? (data['endTime'] as Timestamp).toDate() : null,
      distanceCovered: data['distanceCovered'] ?? 0,
      averageSpeed: (data['averageSpeed'] ?? 0.0).toDouble(),
      safetyScore: (data['safetyScore'] ?? 100.0).toDouble(),
      hazardsReported: data['hazardsReported'] ?? 0,
    );
  }
}
