import 'dart:async';

class FleetAnalytics {
  final int totalIncidentsPrevented;
  final int activeVehicles;
  final double averageSpeed;
  final double networkUptime;

  FleetAnalytics({
    required this.totalIncidentsPrevented,
    required this.activeVehicles,
    required this.averageSpeed,
    required this.networkUptime,
  });
}

class AnalyticsService {
  Future<FleetAnalytics> getDailyAnalytics() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    return FleetAnalytics(
      totalIncidentsPrevented: 14,
      activeVehicles: 24,
      averageSpeed: 18.5,
      networkUptime: 99.8,
    );
  }
}
