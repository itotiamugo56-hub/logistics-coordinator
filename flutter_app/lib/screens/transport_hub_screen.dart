import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
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
  static const Color success = Color(0xFF00C853);
}

/// Global Pickup Point Model
class GlobalPickupPoint {
  final String id;
  final String branchId;
  final String branchName;
  final String branchAddress;
  final String name;
  final double? latitude;
  final double? longitude;
  final String pickupTime;
  final String? transportManagerName;
  final String? transportManagerPhone;
  final double? distanceKm;

  GlobalPickupPoint({
    required this.id,
    required this.branchId,
    required this.branchName,
    required this.branchAddress,
    required this.name,
    this.latitude,
    this.longitude,
    required this.pickupTime,
    this.transportManagerName,
    this.transportManagerPhone,
    this.distanceKm,
  });

  /// Calculate walking time (approx 12 min per km)
  String get walkingTime {
    if (distanceKm == null) return '';
    int minutes = (distanceKm! * 12).round();
    if (minutes < 1) return '<1 min';
    if (minutes == 1) return '1 min';
    return '$minutes min';
  }
}

/// Premium Pickup Point Card - Apple/Stripe grade
class PickupPointCard extends StatelessWidget {
  final GlobalPickupPoint point;
  final VoidCallback onTap;
  final VoidCallback? onCall;
  final VoidCallback? onDirections;

  const PickupPointCard({
    super.key,
    required this.point,
    required this.onTap,
    this.onCall,
    this.onDirections,
  });

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
                  // Branch header with distance
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: M3Colors.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.directions_bus,
                          size: 20,
                          color: M3Colors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              point.branchName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: M3Colors.onSurface,
                              ),
                            ),
                            if (point.distanceKm != null)
                              Row(
                                children: [
                                  Icon(
                                    Icons.directions_walk,
                                    size: 12,
                                    color: M3Colors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${point.distanceKm!.toStringAsFixed(1)} km · ${point.walkingTime} walk',
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
                      // Distance badge
                      if (point.distanceKm != null && point.distanceKm! < 2)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: M3Colors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bolt,
                                size: 12,
                                color: M3Colors.success,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Nearby',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: M3Colors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Pickup point name
                  Text(
                    point.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: M3Colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Pickup time with icon
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: M3Colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pickup: ${point.pickupTime}',
                        style: TextStyle(
                          fontSize: 13,
                          color: M3Colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  
                  // Transport manager (if available)
                  if (point.transportManagerName != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: M3Colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          point.transportManagerName!,
                          style: TextStyle(
                            fontSize: 13,
                            color: M3Colors.onSurfaceVariant,
                          ),
                        ),
                      ],
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
                      if (point.transportManagerPhone != null)
                        Expanded(
                          child: CrystalButton(
                            onPressed: onCall,
                            label: 'CALL',
                            variant: CrystalButtonVariant.filled,
                            icon: Icons.phone,
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

/// Expandable detail sheet for pickup point - Stripe-grade detail view
class PickupPointDetailSheet extends StatelessWidget {
  final GlobalPickupPoint point;
  
  const PickupPointDetailSheet({
    super.key,
    required this.point,
  });

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
                            color: M3Colors.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.directions_bus,
                            size: 28,
                            color: M3Colors.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                point.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                point.branchName,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: M3Colors.onSurfaceVariant,
                                ),
                              ),
                              if (point.distanceKm != null)
                                Text(
                                  '${point.distanceKm!.toStringAsFixed(1)} km away · ${point.walkingTime} walk',
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
                  
                  // Details section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildDetailRow(
                          Icons.access_time,
                          'Pickup Time',
                          point.pickupTime,
                        ),
                        const SizedBox(height: 16),
                        if (point.transportManagerName != null)
                          _buildDetailRow(
                            Icons.person_outline,
                            'Transport Manager',
                            point.transportManagerName!,
                          ),
                        if (point.transportManagerPhone != null) ...[
                          const SizedBox(height: 16),
                          _buildDetailRow(
                            Icons.phone_outlined,
                            'Contact Number',
                            point.transportManagerPhone!,
                            isClickable: true,
                            onTap: () => _launchPhone(point.transportManagerPhone!),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _buildDetailRow(
                          Icons.location_on_outlined,
                          'Branch Address',
                          point.branchAddress,
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
                            onPressed: () => _openDirections(point),
                            label: 'GET DIRECTIONS',
                            variant: CrystalButtonVariant.outlined,
                            icon: Icons.directions,
                          ),
                        ),
                        if (point.transportManagerPhone != null) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: CrystalButton(
                              onPressed: () => _launchPhone(point.transportManagerPhone!),
                              label: 'CALL MANAGER',
                              variant: CrystalButtonVariant.filled,
                              icon: Icons.phone,
                            ),
                          ),
                        ],
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
    bool isClickable = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: isClickable ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
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
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isClickable ? FontWeight.w600 : FontWeight.normal,
                      color: isClickable ? M3Colors.primary : M3Colors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (isClickable)
              Icon(
                Icons.chevron_right,
                size: 20,
                color: M3Colors.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
  
  void _launchPhone(String phone) async {
    final Uri uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
  
  void _openDirections(GlobalPickupPoint point) async {
    if (point.latitude != null && point.longitude != null) {
      final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${point.latitude},${point.longitude}'
      );
      if (await canLaunchUrl(url)) await launchUrl(url);
    }
  }
}

/// Radius selector chip row - Apple-style segmented control
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

/// Main Transportation Hub Screen - Stripe/Apple Grade
class TransportationHubScreen extends StatefulWidget {
  const TransportationHubScreen({super.key});

  @override
  State<TransportationHubScreen> createState() => _TransportationHubScreenState();
}

class _TransportationHubScreenState extends State<TransportationHubScreen> {
  List<GlobalPickupPoint> _allPickupPoints = [];
  List<GlobalPickupPoint> _filteredPickupPoints = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  
  int _radiusKm = 5;
  final List<int> _radiusOptions = [2, 5, 10, 20];
  
  // For debouncing radius changes
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
          _error = 'Location services disabled. Enable GPS to find pickup points near you.';
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
          _error = 'Location permission needed to find pickup points near you.';
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
      
      await _loadAllPickupPoints();
    } catch (e) {
      setState(() {
        _error = 'Unable to get your location. Please check GPS settings.';
        _isLoadingLocation = false;
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadAllPickupPoints() async {
    setState(() => _isLoading = true);
    
    try {
      final branches = await BranchService.getAllBranches();
      final List<GlobalPickupPoint> allPoints = [];
      
      for (final branch in branches) {
        try {
          final response = await http.get(
            Uri.parse('http://127.0.0.1:8080/v1/clergy/pickup-points/${branch.id}'),
          ).timeout(const Duration(seconds: 5));
          
          if (response.statusCode == 200) {
            final List<dynamic> points = jsonDecode(response.body);
            
            for (final point in points) {
              double? distanceKm;
              if (_currentPosition != null && point['latitude'] != null && point['longitude'] != null) {
                distanceKm = _calculateDistance(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  point['latitude'].toDouble(),
                  point['longitude'].toDouble(),
                );
              }
              
              allPoints.add(GlobalPickupPoint(
                id: point['id'].toString(),
                branchId: branch.id,
                branchName: branch.name,
                branchAddress: branch.address,
                name: point['name'],
                latitude: point['latitude']?.toDouble(),
                longitude: point['longitude']?.toDouble(),
                pickupTime: point['pickup_time'],
                transportManagerName: point['transport_manager_name'],
                transportManagerPhone: point['transport_manager_phone'],
                distanceKm: distanceKm,
              ));
            }
          }
        } catch (e) {
          debugPrint('Error loading pickup points for ${branch.name}: $e');
        }
      }
      
      setState(() {
        _allPickupPoints = allPoints;
        _applyRadiusFilter();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load pickup points. Please try again.';
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
  
  void _applyRadiusFilter() {
    if (_currentPosition == null) {
      _filteredPickupPoints = _allPickupPoints;
      return;
    }
    
    _filteredPickupPoints = _allPickupPoints.where((point) {
      if (point.distanceKm == null) return true;
      return point.distanceKm! <= _radiusKm;
    }).toList();
    
    _filteredPickupPoints.sort((a, b) {
      final distA = a.distanceKm ?? double.infinity;
      final distB = b.distanceKm ?? double.infinity;
      return distA.compareTo(distB);
    });
    
    setState(() {});
  }
  
  void _onRadiusChanged(int newRadius) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() => _radiusKm = newRadius);
      _applyRadiusFilter();
      HapticService.trigger(HapticIntensity.light, context: context);
    });
  }
  
  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    await _loadAllPickupPoints();
    setState(() => _isRefreshing = false);
  }
  
  void _showPickupPointDetails(GlobalPickupPoint point) {
    HapticService.trigger(HapticIntensity.light, context: context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PhysicsSheet(
        child: PickupPointDetailSheet(point: point),
        minChildSize: 0.45,
        maxChildSize: 0.85,
        initialChildSize: 0.55,
        onExpanded: () => HapticService.trigger(HapticIntensity.light, context: context),
        onCollapsed: () => HapticService.trigger(HapticIntensity.light, context: context),
      ),
    );
  }
  
  void _callManager(String? phone) async {
    if (phone == null) return;
    await HapticService.trigger(HapticIntensity.medium, context: context);
    final Uri uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
  
  void _openDirections(GlobalPickupPoint point) async {
    await HapticService.trigger(HapticIntensity.medium, context: context);
    if (point.latitude != null && point.longitude != null) {
      final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${point.latitude},${point.longitude}'
      );
      if (await canLaunchUrl(url)) await launchUrl(url);
    } else if (point.branchAddress.isNotEmpty) {
      final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(point.branchAddress)}'
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
        title: const Text('Transportation Hub'),
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
          // Radius selector - Apple-style segmented control
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
          if (!_isLoading && _filteredPickupPoints.isNotEmpty)
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
                      '${_filteredPickupPoints.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: M3Colors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'pickup point${_filteredPickupPoints.length != 1 ? 's' : ''} available',
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
                          'Finding pickup points near you...',
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
                    : _filteredPickupPoints.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.directions_bus,
                                  size: 64,
                                  color: M3Colors.outline,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No pickup points within $_radiusKm km',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: M3Colors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Try increasing the search radius',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: M3Colors.outline,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                CrystalButton(
                                  onPressed: () => _onRadiusChanged(10),
                                  label: 'INCREASE RADIUS',
                                  variant: CrystalButtonVariant.outlined,
                                  icon: Icons.radar,
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _refresh,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredPickupPoints.length,
                              itemBuilder: (context, index) {
                                final point = _filteredPickupPoints[index];
                                return PickupPointCard(
                                  point: point,
                                  onTap: () => _showPickupPointDetails(point),
                                  onCall: point.transportManagerPhone != null
                                      ? () => _callManager(point.transportManagerPhone)
                                      : null,
                                  onDirections: () => _openDirections(point),
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