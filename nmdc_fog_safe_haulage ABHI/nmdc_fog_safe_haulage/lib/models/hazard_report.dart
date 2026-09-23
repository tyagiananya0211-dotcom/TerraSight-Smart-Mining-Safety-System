import 'package:cloud_firestore/cloud_firestore.dart';

class HazardReport {
  final String id;
  final String reporterId;
  final String type; // e.g., 'Fallen Rock', 'Zero Visibility', 'Vehicle Breakdown'
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final bool isActive;

  HazardReport({
    required this.id,
    required this.reporterId,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.isActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'reporterId': reporterId,
      'type': type,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': Timestamp.fromDate(timestamp),
      'isActive': isActive,
    };
  }

  factory HazardReport.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return HazardReport(
      id: doc.id,
      reporterId: data['reporterId'] ?? '',
      type: data['type'] ?? 'Unknown Hazard',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
    );
  }
}
