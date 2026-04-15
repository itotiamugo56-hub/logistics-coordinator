import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/branch.dart';
import '../providers/clergy_auth_provider.dart';
import '../services/branch_service.dart';
import '../widgets/pickup_points_manager.dart';
import '../widgets/events_manager.dart';
import '../widgets/alerts_manager.dart';
import '../widgets/branch_editor.dart';
import '../widgets/service_times_editor.dart';
import '../widgets/photo_manager.dart';
import '../main.dart';

// Material Design 3 Color Scheme
class M3Colors {
  static const Color primary = Color(0xFF6750A4);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFEADDFF);
  static const Color secondary = Color(0xFF625B71);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color tertiary = Color(0xFF7D5260);
  static const Color surface = Color(0xFFFEF7FF);
  static const Color surfaceVariant = Color(0xFFE7E0EC);
  static const Color background = Color(0xFFFFFBFE);
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onSurface = Color(0xFF1C1B1F);
  static const Color onSurfaceVariant = Color(0xFF49454F);
  static const Color outline = Color(0xFF79747E);
  static const Color outlineVariant = Color(0xFFCAC4D0);
  static const Color live = Color(0xFF00C853); // Green for live indicator
}

enum ServiceStatus { live, upcoming, ended }

class ServiceStatusChip extends StatefulWidget {
  final String day;
  final List<String> times;
  
  const ServiceStatusChip({super.key, required this.day, required this.times});

  @override
  State<ServiceStatusChip> createState() => _ServiceStatusChipState();
}

class _ServiceStatusChipState extends State<ServiceStatusChip> {
  Timer? _timer;
  ServiceStatus _status = ServiceStatus.upcoming;
  Duration _timeRemaining = Duration.zero;
  String _nextServiceTime = '';
  
  @override
  void initState() {
    super.initState();
    _updateStatus();
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted) {
        _updateStatus();
      }
    });
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  
  void _updateStatus() {
    final now = DateTime.now();
    final today = _getTodayServiceTime(now);
    
    if (today != null) {
      final serviceDateTime = DateTime(
        now.year, now.month, now.day,
        today.hour, today.minute,
      );
      
      if (now.isAfter(serviceDateTime.subtract(const Duration(minutes: 30))) &&
          now.isBefore(serviceDateTime.add(const Duration(hours: 2)))) {
        if (mounted) setState(() => _status = ServiceStatus.live);
      } else if (now.isBefore(serviceDateTime)) {
        if (mounted) {
          setState(() {
            _status = ServiceStatus.upcoming;
            _timeRemaining = serviceDateTime.difference(now);
            _nextServiceTime = _formatTime(serviceDateTime);
          });
        }
      } else {
        if (mounted) setState(() => _status = ServiceStatus.ended);
      }
    }
  }
  
  TimeOfDay? _getTodayServiceTime(DateTime now) {
    final dayName = _getDayName(now.weekday);
    if (widget.day == dayName && widget.times.isNotEmpty) {
      final timeParts = widget.times.first.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1].split(' ')[0]);
      final isPM = timeParts[1].contains('PM') && hour != 12;
      final finalHour = isPM ? hour + 12 : (hour == 12 && timeParts[1].contains('AM') ? 0 : hour);
      return TimeOfDay(hour: finalHour, minute: minute);
    }
    return null;
  }
  
  String _getDayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }
  
  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final ampm = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $ampm';
  }
  
  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    }
    return '${duration.inMinutes}m';
  }
  
  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case ServiceStatus.live:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: M3Colors.live.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: M3Colors.live,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: M3Colors.live.withOpacity(0.8),
                      blurRadius: 4,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'LIVE NOW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: M3Colors.live,
                ),
              ),
            ],
          ),
        );
      case ServiceStatus.upcoming:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: M3Colors.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Starts in ${_formatDuration(_timeRemaining)}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: M3Colors.primary,
            ),
          ),
        );
      case ServiceStatus.ended:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: M3Colors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Ended at $_nextServiceTime',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: M3Colors.onSurfaceVariant,
            ),
          ),
        );
    }
  }
}

class BranchDetailsScreen extends StatefulWidget {
  final Branch branch;
  
  const BranchDetailsScreen({
    super.key, 
    required this.branch,
  });

  @override
  State<BranchDetailsScreen> createState() => _BranchDetailsScreenState();
}

class _BranchDetailsScreenState extends State<BranchDetailsScreen> with SingleTickerProviderStateMixin {
  late Branch _branch;
  List<dynamic> _pickupPoints = [];
  List<dynamic> _events = [];
  List<dynamic> _alerts = [];
  List<String> _photos = [];
  bool _isLoading = true;
  late TabController _tabController;
  late PageController _photoPageController;
  int _currentPhotoIndex = 0;
  
  final List<Map<String, dynamic>> _tabs = [
    {'title': 'Info', 'icon': Icons.info_outline},
    {'title': 'Events', 'icon': Icons.event_available_outlined},
    {'title': 'Pickup', 'icon': Icons.directions_bus_outlined},
    {'title': 'Alerts', 'icon': Icons.notifications_none},
    {'title': 'Photos', 'icon': Icons.photo_library_outlined},
  ];
  
  @override
  void initState() {
    super.initState();
    _branch = widget.branch;
    _tabController = TabController(length: _tabs.length, vsync: this);
    _photoPageController = PageController();
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _photoPageController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final allBranches = await BranchService.getAllBranches();
      if (!mounted) return;
      
      final refreshedBranch = allBranches.firstWhere(
        (b) => b.id == widget.branch.id,
        orElse: () => widget.branch,
      );
      _branch = refreshedBranch;
      
      final pickupResponse = await http.get(
        Uri.parse('http://127.0.0.1:8080/v1/clergy/pickup-points/${widget.branch.id}'),
      );
      if (mounted && pickupResponse.statusCode == 200) {
        _pickupPoints = jsonDecode(pickupResponse.body);
      }
      
      final eventsResponse = await http.get(
        Uri.parse('http://127.0.0.1:8080/v1/clergy/events/${widget.branch.id}'),
      );
      if (mounted && eventsResponse.statusCode == 200) {
        _events = jsonDecode(eventsResponse.body);
      }
      
      final alertsResponse = await http.get(
        Uri.parse('http://127.0.0.1:8080/v1/clergy/alerts/${widget.branch.id}'),
      );
      if (mounted && alertsResponse.statusCode == 200) {
        _alerts = jsonDecode(alertsResponse.body);
      }
      
      final photosResponse = await http.get(
        Uri.parse('http://127.0.0.1:8080/v1/clergy/photos/${widget.branch.id}'),
      );
      if (mounted && photosResponse.statusCode == 200) {
        _photos = List<String>.from(jsonDecode(photosResponse.body));
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _launchPhone(String phone) async {
    final Uri uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
  
  Future<void> _launchEmail(String email) async {
    final Uri uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
  
  Future<void> _openDirections(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
  
  void _showPickupPointsManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: M3Colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => PickupPointsManager(
        branchId: _branch.id,
        onRefresh: _loadData,
      ),
    );
  }
  
  void _showEventsManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: M3Colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => EventsManager(
        branchId: _branch.id,
        onRefresh: _loadData,
      ),
    );
  }
  
  void _showAlertsManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: M3Colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => AlertsManager(
        branchId: _branch.id,
        onRefresh: _loadData,
      ),
    );
  }
  
  void _showBranchEditor() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: M3Colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => BranchEditor(
        branch: _branch,
        onSaved: _loadData,
      ),
    );
  }
  
  void _showServiceTimesEditor() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: M3Colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => ServiceTimesEditor(
        branch: _branch,
        onSaved: _loadData,
      ),
    );
  }
  
  void _showPhotoManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: M3Colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => PhotoManager(
        branchId: _branch.id,
        onRefresh: _loadData,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // Get motion reduction preference
    final motionPrefs = Provider.of<MotionPreferences>(context);
    final reduceMotion = motionPrefs.disableAnimations;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _branch.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: M3Colors.surface,
        foregroundColor: M3Colors.onSurface,
        elevation: 0,
        centerTitle: false,
        actions: [
          Consumer<ClergyAuthProvider>(
            builder: (context, auth, _) {
              if (auth.isAuthenticated && auth.branchId == _branch.id) {
                return PopupMenuButton<String>(
                  icon: const Icon(Icons.admin_panel_settings),
                  color: M3Colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: M3Colors.outlineVariant),
                  ),
                  onSelected: (String value) {
                    switch (value) {
                      case 'edit_branch':
                        _showBranchEditor();
                        break;
                      case 'service_times':
                        _showServiceTimesEditor();
                        break;
                      case 'photos':
                        _showPhotoManager();
                        break;
                      case 'pickup':
                        _showPickupPointsManager();
                        break;
                      case 'events':
                        _showEventsManager();
                        break;
                      case 'alerts':
                        _showAlertsManager();
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'edit_branch',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 12),
                          Text('Edit Branch Details'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'service_times',
                      child: Row(
                        children: [
                          Icon(Icons.schedule, size: 20),
                          SizedBox(width: 12),
                          Text('Edit Service Times'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'photos',
                      child: Row(
                        children: [
                          Icon(Icons.photo_library, size: 20),
                          SizedBox(width: 12),
                          Text('Manage Photos'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'pickup',
                      child: Row(
                        children: [
                          Icon(Icons.directions_bus, size: 20),
                          SizedBox(width: 12),
                          Text('Manage Pickup Points'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'events',
                      child: Row(
                        children: [
                          Icon(Icons.event, size: 20),
                          SizedBox(width: 12),
                          Text('Manage Events'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'alerts',
                      child: Row(
                        children: [
                          Icon(Icons.notifications_active, size: 20),
                          SizedBox(width: 12),
                          Text('Manage Alerts'),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            height: 48,
            decoration: BoxDecoration(
              color: M3Colors.surfaceVariant,
              borderRadius: BorderRadius.circular(32),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: M3Colors.primary,
                borderRadius: BorderRadius.circular(32),
              ),
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: M3Colors.onPrimary,
              unselectedLabelColor: M3Colors.onSurfaceVariant.withOpacity(0.6),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              splashFactory: reduceMotion ? NoSplash.splashFactory : null,
              tabs: _tabs.map((tab) {
                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tab['icon'] as IconData, size: 18),
                      const SizedBox(width: 8),
                      Text(tab['title'] as String),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildInfoTab(),
                      _buildEventsTab(),
                      _buildPickupPointsTab(),
                      _buildAlertsTab(),
                      _buildPhotosTab(),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDirections(_branch.latitude, _branch.longitude),
        icon: const Icon(Icons.directions),
        label: const Text('Directions'),
        backgroundColor: M3Colors.primary,
        foregroundColor: M3Colors.onPrimary,
      ),
    );
  }
  
  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Alerts Banner
          if (_alerts.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: M3Colors.errorContainer,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: M3Colors.error.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: M3Colors.error, size: 20),
                      SizedBox(width: 12),
                      Text(
                        'Active Alerts',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: M3Colors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._alerts.map((alert) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert['message'],
                          style: const TextStyle(fontSize: 14),
                        ),
                        if (alert['affected_service'] != null)
                          Text(
                            'Affects: ${alert['affected_service']}',
                            style: TextStyle(fontSize: 12, color: M3Colors.onSurfaceVariant),
                          ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          
          // Branch Info Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: M3Colors.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: M3Colors.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.location_on, color: M3Colors.primary, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _branch.address,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: M3Colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.person, color: M3Colors.onSurfaceVariant, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Text(_branch.seniorPastor),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: M3Colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.phone, color: M3Colors.onSurfaceVariant, size: 20),
                      ),
                      const SizedBox(width: 14),
                      InkWell(
                        onTap: () => _launchPhone(_branch.phone),
                        borderRadius: BorderRadius.circular(8),
                        child: Text(
                          _branch.phone,
                          style: const TextStyle(color: M3Colors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: M3Colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.email, color: M3Colors.onSurfaceVariant, size: 20),
                      ),
                      const SizedBox(width: 14),
                      InkWell(
                        onTap: () => _launchEmail(_branch.email),
                        borderRadius: BorderRadius.circular(8),
                        child: Text(
                          _branch.email,
                          style: const TextStyle(color: M3Colors.primary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Service Times Card WITH LIVE STATUS
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: M3Colors.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: M3Colors.tertiary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.schedule, color: M3Colors.tertiary, size: 20),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'Service Times',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._branch.serviceTimes.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 90,
                              child: Text(
                                entry.key,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                entry.value.join(' • '),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Live status chip for each service time
                        ServiceStatusChip(
                          day: entry.key,
                          times: entry.value,
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
          
          // Privacy Badge - Transactional Confidence
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 12, color: M3Colors.outline),
                const SizedBox(width: 6),
                Text(
                  'End-to-end encrypted • Information only visible to assigned clergy',
                  style: TextStyle(fontSize: 10, color: M3Colors.outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEventsTab() {
    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: M3Colors.outline),
            const SizedBox(height: 16),
            Text(
              'No upcoming events',
              style: TextStyle(color: M3Colors.onSurfaceVariant, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for special services',
              style: TextStyle(color: M3Colors.outline, fontSize: 14),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final event = _events[index];
        final eventDate = DateTime.fromMillisecondsSinceEpoch(event['event_date'] * 1000);
        final isLive = eventDate.isBefore(DateTime.now()) && 
                       eventDate.add(const Duration(hours: 2)).isAfter(DateTime.now());
        final isUpcoming = eventDate.isAfter(DateTime.now());
        
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: M3Colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isLive ? M3Colors.live.withOpacity(0.15) : M3Colors.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: isLive ? Border.all(color: M3Colors.live, width: 2) : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isLive)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeInOut,
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: M3Colors.live,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: M3Colors.live.withOpacity(0.8),
                                blurRadius: 4,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        )
                      else ...[
                        Text(
                          '${eventDate.day}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isUpcoming ? M3Colors.primary : M3Colors.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          _getMonthAbbr(eventDate.month),
                          style: TextStyle(
                            fontSize: 10,
                            color: isUpcoming ? M3Colors.primary : M3Colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event['name'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isLive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: M3Colors.live,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (event['description'] != null)
                        Text(
                          event['description'],
                          style: TextStyle(
                            fontSize: 13,
                            color: M3Colors.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        isLive ? 'Happening now!' : '${eventDate.hour}:${eventDate.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isLive ? M3Colors.live : M3Colors.tertiary,
                          fontWeight: isLive ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildPickupPointsTab() {
    if (_pickupPoints.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_bus, size: 64, color: M3Colors.outline),
            const SizedBox(height: 16),
            Text(
              'No pickup points',
              style: TextStyle(color: M3Colors.onSurfaceVariant, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Transportation info coming soon',
              style: TextStyle(color: M3Colors.outline, fontSize: 14),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pickupPoints.length,
      itemBuilder: (context, index) {
        final point = _pickupPoints[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: M3Colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: M3Colors.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.location_on, color: M3Colors.secondary, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        point['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 16, color: M3Colors.tertiary),
                          const SizedBox(width: 8),
                          Text('Pickup: ${point['pickup_time']}'),
                        ],
                      ),
                      if (point['transport_manager_name'] != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.person, size: 16, color: M3Colors.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Text(point['transport_manager_name']),
                          ],
                        ),
                      ],
                      if (point['transport_manager_phone'] != null) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _launchPhone(point['transport_manager_phone']),
                          child: Row(
                            children: [
                              const Icon(Icons.phone, size: 16, color: M3Colors.primary),
                              const SizedBox(width: 8),
                              Text(
                                point['transport_manager_phone'],
                                style: const TextStyle(color: M3Colors.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildAlertsTab() {
    if (_alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off, size: 64, color: M3Colors.outline),
            const SizedBox(height: 16),
            Text(
              'No active alerts',
              style: TextStyle(color: M3Colors.onSurfaceVariant, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'All systems operating normally',
              style: TextStyle(color: M3Colors.outline, fontSize: 14),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _alerts.length,
      itemBuilder: (context, index) {
        final alert = _alerts[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: M3Colors.error.withOpacity(0.3)),
          ),
          color: M3Colors.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: M3Colors.error,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.warning, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert['message'],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (alert['affected_service'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Affects: ${alert['affected_service']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: M3Colors.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildPhotosTab() {
    if (_photos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library, size: 64, color: M3Colors.outline),
            const SizedBox(height: 16),
            Text(
              'No photos yet',
              style: TextStyle(color: M3Colors.onSurfaceVariant, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Gallery coming soon',
              style: TextStyle(color: M3Colors.outline, fontSize: 14),
            ),
          ],
        ),
      );
    }
    
    // Get motion reduction preference for carousel animations
    final motionPrefs = Provider.of<MotionPreferences>(context);
    final reduceMotion = motionPrefs.disableAnimations;
    
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Constrained Carousel - NOT flexed across entire screen
            Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: 280,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _photoPageController,
                    itemCount: _photos.length,
                    onPageChanged: (index) {
                      if (mounted) {
                        setState(() => _currentPhotoIndex = index);
                      }
                    },
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                _photos[index],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: M3Colors.surfaceVariant,
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.broken_image, size: 48, color: M3Colors.outline),
                                        SizedBox(height: 8),
                                        Text(
                                          'Failed to load image',
                                          style: TextStyle(fontSize: 12, color: M3Colors.outline),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              // Gradient overlay
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.3),
                                    ],
                                  ),
                                ),
                              ),
                              // Image counter badge
                              Positioned(
                                bottom: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${index + 1} / ${_photos.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  // Left navigation arrow
                  if (_photos.length > 1)
                    Positioned(
                      left: 4,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            if (_currentPhotoIndex > 0) {
                              _photoPageController.previousPage(
                                duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chevron_left,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Right navigation arrow
                  if (_photos.length > 1)
                    Positioned(
                      right: 4,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            if (_currentPhotoIndex < _photos.length - 1) {
                              _photoPageController.nextPage(
                                duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Dot indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _photos.length,
                (index) => GestureDetector(
                  onTap: () {
                    _photoPageController.animateToPage(
                      index,
                      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: AnimatedContainer(
                    duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPhotoIndex == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: _currentPhotoIndex == index ? M3Colors.primary : M3Colors.outline.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Optional: Photo count text
            Text(
              '${_photos.length} photo${_photos.length != 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: M3Colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getMonthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}