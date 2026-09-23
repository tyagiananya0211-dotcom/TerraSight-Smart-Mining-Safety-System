import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_colors.dart';

class LogEntry {
  final DateTime timestamp;
  final String level;
  final String message;
  final Color color;

  LogEntry(this.timestamp, this.level, this.message, this.color);
}

class ServerControlScreen extends StatefulWidget {
  const ServerControlScreen({super.key});

  @override
  State<ServerControlScreen> createState() => _ServerControlScreenState();
}

class _ServerControlScreenState extends State<ServerControlScreen> {
  Timer? _clockTimer;
  Timer? _logTimer;
  Timer? _uptimeTimer;
  
  DateTime _currentTime = DateTime.now();
  final DateTime _bootTime = DateTime.now().subtract(const Duration(hours: 12, minutes: 45, seconds: 33));
  
  String _serverStatus = 'ONLINE'; // ONLINE, OFFLINE, REBOOTING
  int _activeSessions = 18;
  
  final List<LogEntry> _logs = [];
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  String _searchQuery = '';
  String _activeFilter = 'ALL LOGS';

  final Random _rnd = Random();

  @override
  void initState() {
    super.initState();
    _initLogs();
    
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() { _currentTime = DateTime.now(); });
    });

    _uptimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _serverStatus == 'ONLINE') {
        setState(() {}); // Just force rebuild for uptime
      }
    });

    _startLogSimulation();
  }

  void _initLogs() {
    final now = DateTime.now();
    _logs.add(LogEntry(now.subtract(const Duration(seconds: 15)), 'INFO', '[MEMORY] Loaded 18 active user sessions from sessions.json', AppColors.statusInfo));
    _logs.add(LogEntry(now.subtract(const Duration(seconds: 14)), 'INFO', '[SYSTEM] Terasight AI Server Engine initialized on port 3000', AppColors.statusInfo));
    _logs.add(LogEntry(now.subtract(const Duration(seconds: 13)), 'UPTIME', 'Server uptime: 12:45:33', AppColors.textPrimary));
    _logs.add(LogEntry(now.subtract(const Duration(seconds: 12)), 'AGENT', 'Terasight AI Agent (Fog Safe Haulage • Grove AI Engine • Live IST)', AppColors.statusSafe));
    _logs.add(LogEntry(now.subtract(const Duration(seconds: 11)), 'INFO', 'Webhook Listener: http://localhost:3000/webhook', AppColors.statusInfo));
    _logs.add(LogEntry(now.subtract(const Duration(seconds: 10)), 'INFO', '[PING SUCCESS] Connected to CBM (PRODUCTION Mode: https://ops.terasight.online)', AppColors.statusSafe));
  }

  void _startLogSimulation() {
    _logTimer?.cancel();
    _logTimer = Timer.periodic(const Duration(seconds: 12), (timer) {
      if (_serverStatus == 'ONLINE') {
        _generateHeartbeatLog();
      }
    });
  }

  void _generateHeartbeatLog() {
    int mem = 740 + _rnd.nextInt(15);
    final log = LogEntry(
      DateTime.now(),
      'HEARTBEAT',
      'Port 3000 | Active Memory: ${mem}MB | Sessions: $_activeSessions | CBM: CONNECTED | Agent Mode: ACTIVE (ON) | Delhi IST: ${DateFormat('hh:mm:ss a').format(DateTime.now())}',
      AppColors.statusAnalytics, // Purple for heartbeat
    );
    setState(() {
      _logs.add(log);
      if (_logs.length > 500) _logs.removeAt(0); // Keep max 500 logs
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _logTimer?.cancel();
    _uptimeTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // --- Handlers ---
  void _handleBoot() {
    if (_serverStatus == 'OFFLINE') {
      setState(() {
        _serverStatus = 'ONLINE';
        _logs.add(LogEntry(DateTime.now(), 'SYSTEM', 'Server Boot Sequence Initiated...', AppColors.statusSafe));
        _logs.add(LogEntry(DateTime.now(), 'SYSTEM', 'Server ONLINE', AppColors.statusSafe));
      });
      _scrollToBottom();
    }
  }

  void _handleShutdown() {
    if (_serverStatus == 'ONLINE') {
      setState(() {
        _serverStatus = 'OFFLINE';
        _logs.add(LogEntry(DateTime.now(), 'SYSTEM', 'Shutdown Sequence Initiated...', AppColors.statusCritical));
        _logs.add(LogEntry(DateTime.now(), 'SYSTEM', 'Server OFFLINE', AppColors.statusCritical));
      });
      _scrollToBottom();
    }
  }

  void _handleReboot() {
    if (_serverStatus == 'ONLINE' || _serverStatus == 'OFFLINE') {
      setState(() {
        _serverStatus = 'REBOOTING';
        _logs.add(LogEntry(DateTime.now(), 'SYSTEM', 'Rebooting Server...', AppColors.primary));
      });
      _scrollToBottom();
      
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _serverStatus = 'ONLINE';
            _logs.add(LogEntry(DateTime.now(), 'SYSTEM', 'Server Reboot Complete. ONLINE.', AppColors.statusSafe));
          });
          _scrollToBottom();
        }
      });
    }
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  // --- UI Builders ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildTopHeader(),
            const SizedBox(height: 16),
            _buildMetricsRow(),
            const SizedBox(height: 16),
            _buildControlBar(),
            const SizedBox(height: 16),
            Expanded(child: _buildTerminalArea()),
            const SizedBox(height: 16),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        width: 1100, // Ensure a minimum width to keep the layout spread out
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.security, color: AppColors.primary, size: 40),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CONTROL CENTER', style: TextStyle(color: AppColors.primary, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                    const Text('Terasight AI Server Engine', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.statusSafe, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        const Text('Back Unit #01 • Port 3000', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            _buildStatusLights(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusLights() {
    return Row(
      children: [
        _buildLight('PWR', AppColors.statusSafe, true),
        _buildLight('LINK', AppColors.primary, _serverStatus != 'OFFLINE'),
        _buildLight('TX/RX', AppColors.statusAnalytics, _serverStatus == 'ONLINE'),
        _buildLight('CBM', AppColors.statusWarning, _serverStatus == 'ONLINE'),
        _buildLight('ALARM', AppColors.statusCritical, false),
      ],
    );
  }

  Widget _buildLight(String label, Color color, bool isOn) {
    return Padding(
      padding: const EdgeInsets.only(left: 24),
      child: Column(
        children: [
          Container(
            width: 16, height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOn ? color : color.withOpacity(0.2),
              boxShadow: isOn ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 10, spreadRadius: 2)] : [],
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMetricsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          SizedBox(
            width: 250,
            child: _buildMetricCard(
              title: 'SYSTEM STATUS',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_serverStatus == 'ONLINE' ? 'SYSTEM ONLINE' : (_serverStatus == 'REBOOTING' ? 'REBOOTING' : 'SYSTEM OFFLINE'), 
                             style: TextStyle(color: _serverStatus == 'ONLINE' ? AppColors.statusSafe : AppColors.statusCritical, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(_serverStatus == 'ONLINE' ? 'All systems operational' : 'System is currently down', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Icon(Icons.shield_outlined, color: _serverStatus == 'ONLINE' ? AppColors.statusSafe.withOpacity(0.5) : AppColors.statusCritical.withOpacity(0.5), size: 36),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 220,
            child: _buildMetricCard(
              title: 'SERVER UPTIME',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_getUptimeString(), style: const TextStyle(color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Since ${DateFormat('dd MMM, hh:mm a').format(_bootTime)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Icon(Icons.access_time, color: AppColors.primary.withOpacity(0.5), size: 36),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 200,
            child: _buildMetricCard(
              title: 'ACTIVE SESSIONS',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$_activeSessions', style: const TextStyle(color: AppColors.statusAnalytics, fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Live connections', style: TextStyle(color: AppColors.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Icon(Icons.people_outline, color: AppColors.statusAnalytics.withOpacity(0.5), size: 36),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 300,
            child: _buildMetricCard(
              title: 'ALERT SUMMARY (24H)',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAlertStat('3', 'Critical', AppColors.statusCritical),
                  _buildAlertStat('7', 'High', AppColors.statusHigh),
                  _buildAlertStat('12', 'Moderate', AppColors.statusWarning),
                  _buildAlertStat('8', 'Safe', AppColors.statusSafe),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 220,
            child: _buildMetricCard(
              title: 'TIMEZONE SYNC',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('IST (KOLKATA)', style: TextStyle(color: AppColors.statusWarning, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(DateFormat('E, dd MMM hh:mm a').format(_currentTime), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Icon(Icons.language, color: AppColors.statusWarning.withOpacity(0.5), size: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getUptimeString() {
    if (_serverStatus != 'ONLINE') return '00:00:00';
    final duration = DateTime.now().difference(_bootTime);
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Widget _buildAlertStat(String val, String label, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
          ],
        )
      ],
    );
  }

  Widget _buildMetricCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildControlBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildControlButton(
            icon: Icons.play_arrow,
            label: 'BOOT SERVER',
            color: AppColors.statusSafe,
            onTap: _handleBoot,
            isActive: _serverStatus == 'ONLINE',
          ),
          const SizedBox(width: 16),
          _buildControlButton(
            icon: Icons.power_settings_new,
            label: 'SHUTDOWN',
            color: AppColors.statusCritical,
            onTap: _handleShutdown,
            isActive: _serverStatus == 'OFFLINE',
          ),
          const SizedBox(width: 16),
          _buildControlButton(
            icon: Icons.refresh,
            label: 'REBOOTING...',
            color: AppColors.blue,
            onTap: _handleReboot,
            isActive: _serverStatus == 'REBOOTING',
          ),
          const SizedBox(width: 64), // Replaced Spacer with fixed width for horizontal scrolling
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: _serverStatus == 'ONLINE' ? AppColors.statusSafe : AppColors.statusCritical),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.wifi, color: _serverStatus == 'ONLINE' ? AppColors.statusSafe : AppColors.statusCritical, size: 16),
                const SizedBox(width: 8),
                Text(_serverStatus == 'ONLINE' ? 'SYSTEM CONNECTED' : 'SYSTEM DISCONNECTED', 
                     style: TextStyle(color: _serverStatus == 'ONLINE' ? AppColors.statusSafe : AppColors.statusCritical, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required String label, required Color color, required VoidCallback onTap, required bool isActive}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.2) : AppColors.card,
          border: Border.all(color: isActive ? color : AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, color: isActive ? color : AppColors.textSecondary, size: 18),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isActive ? color : AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildTerminalArea() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Terminal Header
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('LIVE TERMINAL MATRIX LOGS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                    child: const Text('NODE-PORT 3000', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 48), // Replaced Spacer
                  Row(
                    children: [
                      Checkbox(
                        value: _autoScroll,
                        activeColor: AppColors.primary,
                        onChanged: (val) { setState(() { _autoScroll = val ?? true; }); },
                      ),
                      const Text('Auto-Scroll', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(width: 16),
                      _buildIconBtn(Icons.copy, 'Copy', () {}),
                      const SizedBox(width: 8),
                      _buildIconBtn(Icons.delete_outline, 'Clear', _clearLogs),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Filters
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Container(
                    height: 32,
                    width: 200, // Fixed width instead of Expanded
                    decoration: BoxDecoration(color: const Color(0xFF0A121D), borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.border)),
                    child: TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: 'Filter logs by keyword...',
                        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 16),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: (val) { setState(() { _searchQuery = val.toLowerCase(); }); },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      'ALL LOGS', 'MESSAGES', 'ALERTS', 'AI TOOLS', 'OTP CODES', 'DELIVERIES', 'ERRORS', 'HEARTBEAT'
                    ].map((filter) => _buildFilterBtn(filter)).toList(),
                  ),
                  const SizedBox(width: 16),
                  Text('Showing ${_getFilteredLogs().length} / ${_logs.length}', style: const TextStyle(color: AppColors.primary, fontSize: 10)),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Terminal Body
          Expanded(
            child: Container(
              color: const Color(0xFF04060A),
              padding: const EdgeInsets.all(12),
              child: _buildLogList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 14),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBtn(String label) {
    bool isActive = _activeFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () { setState(() { _activeFilter = label; }); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : Colors.transparent,
            border: Border.all(color: isActive ? AppColors.primary : AppColors.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label, style: TextStyle(color: isActive ? Colors.white : AppColors.textSecondary, fontSize: 10, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
        ),
      ),
    );
  }

  List<LogEntry> _getFilteredLogs() {
    return _logs.where((log) {
      bool matchesSearch = log.message.toLowerCase().contains(_searchQuery) || log.level.toLowerCase().contains(_searchQuery);
      bool matchesFilter = _activeFilter == 'ALL LOGS' || log.level.toUpperCase() == _activeFilter.replaceAll(' ', '');
      if (_activeFilter == 'MESSAGES' && log.level == 'INFO') matchesFilter = true;
      if (_activeFilter == 'ALERTS' && (log.level == 'WARN' || log.level == 'CRITICAL')) matchesFilter = true;
      if (_activeFilter == 'ERRORS' && log.level == 'ERROR') matchesFilter = true;
      if (_activeFilter == 'HEARTBEAT' && log.level == 'HEARTBEAT') matchesFilter = true;
      return matchesSearch && matchesFilter;
    }).toList();
  }

  Widget _buildLogList() {
    final filtered = _getFilteredLogs();
    return ListView.builder(
      controller: _scrollController,
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final log = filtered[index];
        final timeStr = DateFormat('hh:mm:ss a \'IST\'').format(log.timestamp);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('>', style: TextStyle(color: AppColors.primary, fontSize: 13, fontFamily: 'Courier')),
              const SizedBox(width: 8),
              Text('[$timeStr]', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontFamily: 'Courier')),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: Text('[${log.level}]', style: TextStyle(color: log.color, fontSize: 13, fontFamily: 'Courier', fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Text(log.message, style: TextStyle(color: log.level == 'HEARTBEAT' ? AppColors.textSecondary : Colors.white, fontSize: 13, fontFamily: 'Courier')),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildBottomStat(Icons.local_shipping, 'TOTAL VEHICLES', '24', 'Active', Colors.white, Colors.white),
          _buildBottomStat(Icons.check_circle, 'SAFE', '10', '41.7%', AppColors.statusSafe, AppColors.statusSafe),
          _buildBottomStat(Icons.info, 'MODERATE', '6', '25.0%', AppColors.statusWarning, AppColors.statusWarning),
          _buildBottomStat(Icons.warning, 'HIGH RISK', '5', '20.8%', AppColors.statusHigh, AppColors.statusHigh),
          _buildBottomStat(Icons.error, 'CRITICAL', '3', '12.5%', AppColors.statusCritical, AppColors.statusCritical),
          _buildBottomStat(Icons.visibility, 'AVG VISIBILITY', '38 m', 'Live Avg', AppColors.primary, AppColors.primary),
          _buildBottomStat(Icons.sos, 'EMERGENCY', '2', 'Active', AppColors.statusCritical, AppColors.statusCritical),
          _buildBottomStat(Icons.storage, 'LAST BACKUP', DateFormat('hh:mm a').format(DateTime.now()), DateFormat('dd MMM').format(DateTime.now()), AppColors.primary, AppColors.primary),
          _buildBottomStat(Icons.psychology, 'AI ENGINE', 'Healthy', '---', AppColors.statusSafe, AppColors.statusSafe, iconColor: AppColors.statusAnalytics),
        ],
      ),
    );
  }

  Widget _buildBottomStat(IconData icon, String title, String val, String sub, Color accent, Color valColor, {Color? iconColor, Color? subColor}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? accent, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: accent, fontSize: 9, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(val, style: TextStyle(color: valColor, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Text(sub, style: TextStyle(color: subColor ?? AppColors.textSecondary, fontSize: 10)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
