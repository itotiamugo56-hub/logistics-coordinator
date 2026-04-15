import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/branch.dart';
import '../services/branch_service.dart';
import '../services/haptic_service.dart';
import '../main.dart';
import '../widgets/physics_sheet.dart';
import '../widgets/crystal_button.dart';

// Material Design 3 Color Scheme - Consistent with app
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
  static const Color live = Color(0xFF00C853);
  static const Color upcoming = Color(0xFF6750A4);
  static const Color ended = Color(0xFF9E9E9E);
}

/// Event Status Enum
enum EventStatus { live, upcoming, ended }

/// Global Event Model
class GlobalEvent {
  final String id;
  final String branchId;
  final String branchName;
  final String branchAddress;
  final String name;
  final String? description;
  final DateTime eventDate;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;

  GlobalEvent({
    required this.id,
    required this.branchId,
    required this.branchName,
    required this.branchAddress,
    required this.name,
    this.description,
    required this.eventDate,
    this.latitude,
    this.longitude,
    this.distanceKm,
  });

  EventStatus get status {
    final now = DateTime.now();
    if (now.isAfter(eventDate.subtract(const Duration(minutes: 30))) &&
        now.isBefore(eventDate.add(const Duration(hours: 2)))) {
      return EventStatus.live;
    } else if (now.isBefore(eventDate)) {
      return EventStatus.upcoming;
    } else {
      return EventStatus.ended;
    }
  }

  String get formattedTime {
    final hour = eventDate.hour % 12 == 0 ? 12 : eventDate.hour % 12;
    final minute = eventDate.minute.toString().padLeft(2, '0');
    final ampm = eventDate.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $ampm';
  }

  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
    
    if (eventDay == today) return 'Today';
    if (eventDay == today.add(const Duration(days: 1))) return 'Tomorrow';
    
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[eventDate.month - 1]} ${eventDate.day}';
  }

  Duration get timeRemaining {
    if (status != EventStatus.upcoming) return Duration.zero;
    return eventDate.difference(DateTime.now());
  }

  String get timeRemainingText {
    if (status == EventStatus.live) return 'LIVE NOW';
    if (status == EventStatus.ended) return 'Ended';
    
    final remaining = timeRemaining;
    if (remaining.inHours > 0) {
      return 'Starts in ${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
    }
    return 'Starts in ${remaining.inMinutes}m';
  }

  String get walkingTime {
    if (distanceKm == null) return '';
    int minutes = (distanceKm! * 12).round();
    if (minutes < 1) return '<1 min';
    if (minutes == 1) return '1 min';
    return '$minutes min';
  }
}

/// Premium Event Card - Stripe/Apple grade
class EventCard extends StatelessWidget {
  final GlobalEvent event;
  final VoidCallback onTap;
  final VoidCallback? onDirections;

  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
    this.onDirections,
  });

  Color _getStatusColor() {
    switch (event.status) {
      case EventStatus.live:
        return M3Colors.live;
      case EventStatus.upcoming:
        return M3Colors.upcoming;
      case EventStatus.ended:
        return M3Colors.ended;
    }
  }

  String _getStatusText() {
    switch (event.status) {
      case EventStatus.live:
        return 'LIVE';
      case EventStatus.upcoming:
        return event.timeRemainingText;
      case EventStatus.ended:
        return 'Ended';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: M3Colors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Branch header with status
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _getStatusColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          event.status == EventStatus.live
                              ? Icons.fiber_manual_record
                              : Icons.event,
                          size: 20,
                          color: _getStatusColor(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.branchName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: M3Colors.onSurface,
                              ),
                            ),
                            if (event.distanceKm != null)
                              Row(
                                children: [
                                  Icon(
                                    Icons.directions_walk,
                                    size: 12,
                                    color: M3Colors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${event.distanceKm!.toStringAsFixed(1)} km · ${event.walkingTime} walk',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: M3Colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _getStatusColor().withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (event.status == EventStatus.live)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 800),
                                curve: Curves.easeInOut,
                                width: 6,
                                height: 6,
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
                            if (event.status == EventStatus.live)
                              const SizedBox(width: 6),
                            Text(
                              _getStatusText(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _getStatusColor(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  
                  // Event name
                  Text(
                    event.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: M3Colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Event time and date
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: M3Colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        event.formattedDate,
                        style: TextStyle(
                          fontSize: 13,
                          color: M3Colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: M3Colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        event.formattedTime,
                        style: TextStyle(
                          fontSize: 13,
                          color: M3Colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  
                  // Description (if available)
                  if (event.description != null && event.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      event.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: M3Colors.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  
                  // Action buttons row
                  Row(
                    children: [
                      Expanded(
                        child: CrystalButton(
                          onPressed: onDirections,
                          label: 'DIRECTIONS',
                          variant: CrystalButtonVariant.outlined,
                          icon: Icons.directions,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CrystalButton(
                          onPressed: onTap,
                          label: 'DETAILS',
                          variant: CrystalButtonVariant.filled,
                          icon: Icons.info_outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Expandable detail sheet for event - Stripe-grade detail view
class EventDetailSheet extends StatelessWidget {
  final GlobalEvent event;
  
  const EventDetailSheet({
    super.key,
    required this.event,
  });

  Color _getStatusColor() {
    switch (event.status) {
      case EventStatus.live:
        return M3Colors.live;
      case EventStatus.upcoming:
        return M3Colors.upcoming;
      case EventStatus.ended:
        return M3Colors.ended;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: M3Colors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: M3Colors.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Header with icon
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _getStatusColor().withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            event.status == EventStatus.live
                                ? Icons.fiber_manual_record
                                : Icons.event,
                            size: 28,
                            color: _getStatusColor(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                event.branchName,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: M3Colors.onSurfaceVariant,
                                ),
                              ),
                              if (event.distanceKm != null)
                                Text(
                                  '${event.distanceKm!.toStringAsFixed(1)} km away · ${event.walkingTime} walk',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: M3Colors.primary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // Status banner
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _getStatusColor().withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (event.status == EventStatus.live)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeInOut,
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: M3Colors.live,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: M3Colors.live.withOpacity(0.8),
                                  blurRadius: 6,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                          ),
                        if (event.status == EventStatus.live)
                          const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            event.timeRemainingText,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Details section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildDetailRow(
                          Icons.calendar_today,
                          'Date',
                          event.formattedDate,
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow(
                          Icons.access_time,
                          'Time',
                          event.formattedTime,
                        ),
                        if (event.description != null && event.description!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildDetailRow(
                            Icons.description_outlined,
                            'Description',
                            event.description!,
                            isMultiline: true,
                          ),
                        ],
                        const SizedBox(height: 16),
                        _buildDetailRow(
                          Icons.location_on_outlined,
                          'Branch Address',
                          event.branchAddress,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: CrystalButton(
                            onPressed: () => _openDirections(event),
                            label: 'GET DIRECTIONS',
                            variant: CrystalButtonVariant.outlined,
                            icon: Icons.directions,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(IconData icon, String label, String value, {
    bool isMultiline = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: M3Colors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: M3Colors.onSurfaceVariant),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: M3Colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: M3Colors.onSurface,
                ),
                maxLines: isMultiline ? 5 : 1,
                overflow: isMultiline ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  void _openDirections(GlobalEvent event) async {
    if (event.latitude != null && event.longitude != null) {
      final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${event.latitude},${event.longitude}'
      );
      if (await canLaunchUrl(url)) await launchUrl(url);
    } else if (event.branchAddress.isNotEmpty) {
      final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(event.branchAddress)}'
      );
      if (await canLaunchUrl(url)) await launchUrl(url);
    }
  }
}

/// Time-aware empty state message
class TimeAwareEmptyState extends StatelessWidget {
  final int radiusKm;
  final VoidCallback onIncreaseRadius;
  
  const TimeAwareEmptyState({
    super.key,
    required this.radiusKm,
    required this.onIncreaseRadius,
  });

  String _getTimeBasedMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 64,
            color: M3Colors.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No events this $_getTimeBasedMessage()',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: M3Colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No events within $radiusKm km. Try increasing the radius.',
            style: TextStyle(
              fontSize: 13,
              color: M3Colors.outline,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          CrystalButton(
            onPressed: onIncreaseRadius,
            label: 'INCREASE RADIUS',
            variant: CrystalButtonVariant.outlined,
            icon: Icons.radar,
          ),
        ],
      ),
    );
  }
}

/// Radius selector - Apple-style segmented control
class RadiusSelector extends StatelessWidget {
  final int selectedRadius;
  final List<int> radiusOptions;
  final Function(int) onRadiusChanged;
  
  const RadiusSelector({
    super.key,
    required this.selectedRadius,
    required this.radiusOptions,
    required this.onRadiusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: radiusOptions.map((radius) {
          final isSelected = selectedRadius == radius;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text('$radius km'),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  HapticService.trigger(HapticIntensity.light, context: context);
                  onRadiusChanged(radius);
                }
              },
              backgroundColor: M3Colors.surfaceVariant,
              selectedColor: M3Colors.primaryContainer,
              checkmarkColor: M3Colors.primary,
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? M3Colors.primary : M3Colors.onSurfaceVariant,
              ),
              shape: StadiumBorder(
                side: isSelected
                    ? BorderSide(color: M3Colors.primary, width: 1)
                    : BorderSide.none,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Main Today's Schedule Screen - Stripe/Apple Grade
class TodayScheduleScreen extends StatefulWidget {
  const TodayScheduleScreen({super.key});

  @override
  State<TodayScheduleScreen> createState() => _TodayScheduleScreenState();
}

class _TodayScheduleScreenState extends State<TodayScheduleScreen> {
  List<GlobalEvent> _allEvents = [];
  List<GlobalEvent> _filteredEvents = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  
  int _radiusKm = 10;
  final List<int> _radiusOptions = [5, 10, 20, 50];
  
  Timer? _debounceTimer;
  
  @override
  void initState() {
    super.initState();
    _initialize();
  }
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _initialize() async {
    await _getLocationAndLoad();
  }
  
  Future<void> _getLocationAndLoad() async {
    setState(() {
      _isLoadingLocation = true;
      _error = null;
    });
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = 'Location services disabled. Enable GPS to find events near you.';
          _isLoadingLocation = false;
          _isLoading = false;
        });
        return;
      }
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Location permission needed to find events near you.';
          _isLoadingLocation = false;
          _isLoading = false;
        });
        return;
      }
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 15));
      
      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });
      
      await _loadAllEvents();
    } catch (e) {
      setState(() {
        _error = 'Unable to get your location. Please check GPS settings.';
        _isLoadingLocation = false;
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadAllEvents() async {
    setState(() => _isLoading = true);
    
    try {
      final branches = await BranchService.getAllBranches();
      final List<GlobalEvent> allEvents = [];
      
      for (final branch in branches) {
        try {
          final response = await http.get(
            Uri.parse('http://127.0.0.1:8080/v1/clergy/events/${branch.id}'),
          ).timeout(const Duration(seconds: 5));
          
          if (response.statusCode == 200) {
            final List<dynamic> events = jsonDecode(response.body);
            
            for (final event in events) {
              final eventDate = DateTime.fromMillisecondsSinceEpoch(event['event_date'] * 1000);
              
              // Only show today's events or upcoming
              final today = DateTime.now();
              final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
              final threeDaysAgo = today.subtract(const Duration(days: 3));
              
              // Show events from today and future, plus recent (within 3 days)
              if (eventDay.isAfter(threeDaysAgo)) {
                double? distanceKm;
                if (_currentPosition != null && branch.latitude != null && branch.longitude != null) {
                  distanceKm = _calculateDistance(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                    branch.latitude,
                    branch.longitude,
                  );
                }
                
                allEvents.add(GlobalEvent(
                  id: event['id'].toString(),
                  branchId: branch.id,
                  branchName: branch.name,
                  branchAddress: branch.address,
                  name: event['name'],
                  description: event['description'],
                  eventDate: eventDate,
                  latitude: branch.latitude,
                  longitude: branch.longitude,
                  distanceKm: distanceKm,
                ));
              }
            }
          }
        } catch (e) {
          debugPrint('Error loading events for ${branch.name}: $e');
        }
      }
      
      setState(() {
        _allEvents = allEvents;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load events. Please try again.';
        _isLoading = false;
      });
    }
  }
  
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double R = 6371;
    double dLat = (lat2 - lat1) * pi / 180;
    double dLng = (lng2 - lng1) * pi / 180;
    double a = sin(dLat / 2) * sin(dLat / 2) +
               cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
               sin(dLng / 2) * sin(dLng / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
  
  void _applyFilters() {
    if (_currentPosition == null) {
      _filteredEvents = _allEvents;
      return;
    }
    
    // Filter by radius
    var filtered = _allEvents.where((event) {
      if (event.distanceKm == null) return true;
      return event.distanceKm! <= _radiusKm;
    }).toList();
    
    // Sort by: Live first, then upcoming (closest time), then ended (most recent)
    filtered.sort((a, b) {
      // Status priority
      final statusOrder = {
        EventStatus.live: 0,
        EventStatus.upcoming: 1,
        EventStatus.ended: 2,
      };
      final statusCompare = statusOrder[a.status]!.compareTo(statusOrder[b.status]!);
      if (statusCompare != 0) return statusCompare;
      
      // For upcoming, sort by time (soonest first)
      if (a.status == EventStatus.upcoming) {
        return a.eventDate.compareTo(b.eventDate);
      }
      
      // For ended, sort by time (most recent first)
      if (a.status == EventStatus.ended) {
        return b.eventDate.compareTo(a.eventDate);
      }
      
      // For distance as tiebreaker
      final distA = a.distanceKm ?? double.infinity;
      final distB = b.distanceKm ?? double.infinity;
      return distA.compareTo(distB);
    });
    
    setState(() {
      _filteredEvents = filtered;
    });
  }
  
  void _onRadiusChanged(int newRadius) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() => _radiusKm = newRadius);
      _applyFilters();
      HapticService.trigger(HapticIntensity.light, context: context);
    });
  }
  
  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    await _loadAllEvents();
    setState(() => _isRefreshing = false);
  }
  
  void _showEventDetails(GlobalEvent event) {
    HapticService.trigger(HapticIntensity.light, context: context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PhysicsSheet(
        child: EventDetailSheet(event: event),
        minChildSize: 0.45,
        maxChildSize: 0.85,
        initialChildSize: 0.55,
        onExpanded: () => HapticService.trigger(HapticIntensity.light, context: context),
        onCollapsed: () => HapticService.trigger(HapticIntensity.light, context: context),
      ),
    );
  }
  
  void _openDirections(GlobalEvent event) async {
    await HapticService.trigger(HapticIntensity.medium, context: context);
    if (event.latitude != null && event.longitude != null) {
      final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${event.latitude},${event.longitude}'
      );
      if (await canLaunchUrl(url)) await launchUrl(url);
    } else if (event.branchAddress.isNotEmpty) {
      final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(event.branchAddress)}'
      );
      if (await canLaunchUrl(url)) await launchUrl(url);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final motionPrefs = Provider.of<MotionPreferences>(context);
    final reduceMotion = motionPrefs.disableAnimations;
    
    return Scaffold(
      backgroundColor: M3Colors.background,
      appBar: AppBar(
        title: const Text('Today\'s Schedule'),
        backgroundColor: M3Colors.surface,
        foregroundColor: M3Colors.onSurface,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: AnimatedRotation(
              duration: const Duration(milliseconds: 500),
              turns: _isRefreshing ? 1.0 : 0.0,
              child: const Icon(Icons.refresh),
            ),
            onPressed: _isRefreshing ? null : _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // Radius selector
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: BoxDecoration(
              color: M3Colors.surface,
              border: Border(
                bottom: BorderSide(
                  color: M3Colors.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.radar, size: 18, color: M3Colors.primary),
                const SizedBox(width: 12),
                const Text(
                  'Show within',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RadiusSelector(
                    selectedRadius: _radiusKm,
                    radiusOptions: _radiusOptions,
                    onRadiusChanged: _onRadiusChanged,
                  ),
                ),
              ],
            ),
          ),
          
          // Result count header
          if (!_isLoading && _filteredEvents.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: M3Colors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_filteredEvents.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: M3Colors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'event${_filteredEvents.length != 1 ? 's' : ''} found',
                    style: TextStyle(
                      fontSize: 13,
                      color: M3Colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          
          // Main content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Finding events near you...',
                          style: TextStyle(color: M3Colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_off,
                              size: 64,
                              color: M3Colors.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: TextStyle(
                                color: M3Colors.onSurfaceVariant,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            CrystalButton(
                              onPressed: _getLocationAndLoad,
                              label: 'TRY AGAIN',
                              variant: CrystalButtonVariant.outlined,
                              icon: Icons.refresh,
                            ),
                          ],
                        ),
                      )
                    : _filteredEvents.isEmpty
                        ? TimeAwareEmptyState(
                            radiusKm: _radiusKm,
                            onIncreaseRadius: () => _onRadiusChanged(20),
                          )
                        : RefreshIndicator(
                            onRefresh: _refresh,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredEvents.length,
                              itemBuilder: (context, index) {
                                final event = _filteredEvents[index];
                                return EventCard(
                                  event: event,
                                  onTap: () => _showEventDetails(event),
                                  onDirections: () => _openDirections(event),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}