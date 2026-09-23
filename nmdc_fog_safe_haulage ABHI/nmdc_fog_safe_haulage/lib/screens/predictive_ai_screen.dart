import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../widgets/glass_card.dart';
import '../services/sensor_simulation_service.dart';
import '../services/groq_service.dart';
import 'dart:math' as math;

class PredictiveAIScreen extends StatefulWidget {
  const PredictiveAIScreen({super.key});

  @override
  State<PredictiveAIScreen> createState() => _PredictiveAIScreenState();
}

class _PredictiveAIScreenState extends State<PredictiveAIScreen> {
  double _visibility = 100.0;
  StreamSubscription? _sensorSub;
  
  // AI Integration state
  final GroqService _groqService = GroqService();
  List<String> _aiAdjustments = [];
  bool _isLoadingAI = false;
  int _lastProbability = 0;

  @override
  void initState() {
    super.initState();
    _sensorSub = SensorSimulationService().getSensorData().listen((data) {
      if (mounted) {
        setState(() {
          _visibility = data.visibility;
        });
        
        // Calculate probability
        double rawRisk = (100 - _visibility);
        int probability = math.max(10, math.min(100, rawRisk.toInt()));
        
        // Fetch AI prediction initially or if probability changes by > 10%
        if (_aiAdjustments.isEmpty || (probability - _lastProbability).abs() > 10) {
          _lastProbability = probability;
          _fetchAIPredictions();
        }
      }
    });
  }
  
  Future<void> _fetchAIPredictions() async {
    if (_isLoadingAI) return;
    setState(() => _isLoadingAI = true);
    
    try {
      final adjustments = await _groqService.getPredictiveAdjustments(_visibility, _lastProbability);
      if (mounted) {
        setState(() {
          _aiAdjustments = adjustments;
          _isLoadingAI = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAI = false);
      }
    }
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate simulated risk: lower visibility = higher risk
    double rawRisk = (100 - _visibility);
    int probability = math.max(10, math.min(100, rawRisk.toInt()));
    bool isHighRisk = probability > 70;
    
    Color statusColor = isHighRisk ? AppColors.statusCritical : (probability > 40 ? AppColors.statusWarning : AppColors.statusSafe);
    String riskLabel = isHighRisk ? 'High Probability' : (probability > 40 ? 'Moderate Probability' : 'Low Probability');
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Predictive AI Analytics', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Fog Formation Risk', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            const SizedBox(height: 12),
            
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud, color: statusColor, size: 32),
                      const SizedBox(width: 12),
                      Text('$probability%', style: TextStyle(color: statusColor, fontSize: 32, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Text(riskLabel, style: TextStyle(color: statusColor, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(isHighRisk ? 'Estimated onset: < 15 mins' : 'Estimated onset: N/A', style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                  const Text('Sector: North Pit', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // AI Chart Placeholder
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Probability Forecast (Next 24h)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 150,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildChartBar('Now', probability / 100, isHighRisk: probability > 70),
                        _buildChartBar('+1h', math.min(1.0, (probability + 10) / 100), isHighRisk: (probability + 10) > 70),
                        _buildChartBar('+2h', math.min(1.0, (probability + 20) / 100), isHighRisk: (probability + 20) > 70),
                        _buildChartBar('+3h', math.max(0.1, (probability - 10) / 100), isHighRisk: (probability - 10) > 70),
                        _buildChartBar('+4h', math.max(0.1, (probability - 30) / 100), isHighRisk: (probability - 30) > 70),
                        _buildChartBar('+5h', math.max(0.1, (probability - 40) / 100), isHighRisk: (probability - 40) > 70),
                      ],
                    ),
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Predictive Fleet Adjustments', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                if (_isLoadingAI) 
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                else 
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppColors.textMuted, size: 20),
                    onPressed: _fetchAIPredictions,
                    tooltip: 'Refresh AI Predictions',
                  )
              ],
            ),
            const SizedBox(height: 12),
            
            if (_aiAdjustments.isEmpty && !_isLoadingAI)
               const Text('No adjustments generated yet.', style: TextStyle(color: AppColors.textMuted))
            else
               ..._aiAdjustments.map((adjustment) => Padding(
                 padding: const EdgeInsets.only(bottom: 12.0),
                 child: _buildAdjustmentCard(adjustment, Icons.smart_toy_outlined, AppColors.statusInfo),
               )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildChartBar(String label, double heightRatio, {bool isHighRisk = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 20,
          height: 100 * heightRatio,
          decoration: BoxDecoration(
            color: isHighRisk ? AppColors.statusHigh : AppColors.primary.withOpacity(0.5),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
      ],
    );
  }

  Widget _buildAdjustmentCard(String text, IconData icon, Color color) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          ),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color),
            ),
            child: const Text('APPLY'),
          )
        ],
      ),
    );
  }
}

