import 'dart:async';
import 'dart:math';
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
import 'branch_details_screen.dart';
import '../main.dart';
import '../services/haptic_service.dart';
import '../widgets/physics_sheet.dart';
import '../widgets/modern_marker.dart';

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
  static const Color onSurface = Color(0xFF1C1B1F);
  static const Color onSurfaceVariant = Color(0xFF49454F);
  static const Color outline = Color(0xFF79747E);
}

/// Animated GPS Lock Indicator with pulsing effect
class GpsLockIndicator extends StatelessWidget {
  final bool isLocked;
  final bool isAcquiring;
  
  const GpsLockIndicator({
    super.key,
    required this.isLocked,
    required this.isAcquiring,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isLocked ? M3Colors.primary : M3Colors.surfaceVariant,
        shape: BoxShape.circle,
        boxShadow: isLocked
            ? [
                BoxShadow(
                  color: M3Colors.primary.withOpacity(0.5),
                  blurRadius: 12,
                  spreadRadius: 4,
                ),
              ]
            : null,
      ),
      child: isAcquiring
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: M3Colors.primary,
              ),
            )
          : Icon(
              isLocked ? Icons.my_location : Icons.location_searching,
              color: isLocked ? Colors.white : M3Colors.onSurfaceVariant,
              size: 16,
            ),
    );
  }
}

/// Premium expandable sheet using PhysicsSheet with proper scrolling
class BranchPreviewSheet extends StatelessWidget {
  final Branch branch;
  final double? distanceKm;
  
  const BranchPreviewSheet({
    super.key,
    required this.branch,
    this.distanceKm,
  });

  String _getWalkingTime() {
    if (distanceKm == null) return '';
    int minutes = (distanceKm! * 12).round();
    if (minutes < 1) return '<1 min walk';
    if (minutes == 1) return '1 min walk';
    return '$minutes min walk';
  }

  String _getNextService() {
    final now = DateTime.now();
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final today = dayNames[now.weekday - 1];
    
    if (branch.serviceTimes.containsKey(today) && branch.serviceTimes[today]!.isNotEmpty) {
      return 'Today at ${branch.serviceTimes[today]!.first}';
    }
    
    for (var day in dayNames) {
      if (branch.serviceTimes.containsKey(day) && branch.serviceTimes[day]!.isNotEmpty) {
        return '$day at ${branch.serviceTimes[day]!.first}';
      }
    }
    return 'Service times unavailable';
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
          
          // Content that scrolls naturally upward
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Branch icon and name
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: M3Colors.primaryContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.location_on, color: M3Colors.primary, size: 22),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                branch.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (distanceKm != null)
                                Text(
                                  '${distanceKm!.toStringAsFixed(1)} km away • ${_getWalkingTime()}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: M3Colors.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Divider
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // Details section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildDetailRow(Icons.location_on, branch.address),
                        const SizedBox(height: 12),
                        _buildDetailRow(Icons.schedule, _getNextService()),
                        if (branch.phone.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildDetailRow(Icons.phone, branch.phone),
                        ],
                        if (branch.seniorPastor.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildDetailRow(Icons.person, branch.seniorPastor),
                        ],
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
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _openDirections(branch.latitude, branch.longitude, context);
                            },
                            icon: const Icon(Icons.directions, size: 18),
                            label: const Text('DIRECTIONS'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => BranchDetailsScreen(branch: branch)),
                              );
                            },
                            icon: const Icon(Icons.info_outline, size: 18),
                            label: const Text('DETAILS'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: M3Colors.primary,
                              foregroundColor: M3Colors.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
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
  
  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: M3Colors.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
  
  static void _openDirections(double lat, double lng, BuildContext context) async {
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }
}

/// Compact nearest branch chip - Stripe-ified
class NearestBranchChip extends StatelessWidget {
  final Branch branch;
  final double distanceKm;
  final VoidCallback onTap;
  
  const NearestBranchChip({
    super.key,
    required this.branch,
    required this.distanceKm,
    required this.onTap,
  });

  String _getWalkingTime() {
    int minutes = (distanceKm * 12).round();
    if (minutes < 1) return '<1 min';
    if (minutes == 1) return '1 min';
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: M3Colors.surface,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: M3Colors.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: M3Colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star, color: M3Colors.primary, size: 14),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  branch.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                ),
                Text(
                  '${distanceKm.toStringAsFixed(1)} km • ${_getWalkingTime()} walk',
                  style: TextStyle(
                    fontSize: 10,
                    color: M3Colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: M3Colors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey _nearestCardKey = GlobalKey();

  List<Branch> _branches = [];
  List<Branch> _filteredBranches = [];
  Branch? _nearestBranch;
  bool _isLoading = true;
  bool _isLoadingLocation = false;
  bool _isRefreshing = false;
  bool _isSearching = false;
  bool _isGeocoding = false;
  String? _error;
  Position? _currentPosition;
  LatLng? _currentLatLng;
  String _searchQuery = '';
  List<String> _searchSuggestions = [];
  LatLng? _searchedLocation;
  double _nearestCardHeight = 0;
  
  bool _gpsLocked = false;
  bool _hasCenteredMap = false;
  
  bool _showRecenterButton = false;
  bool _showNearestDetails = false;
  
  // For tooltip state
  Branch? _selectedBranch;
  double _selectedDistance = 0;
  Timer? _tooltipCloseTimer;

  static const LatLng _defaultLatLng = LatLng(-1.286389, 36.817223);
  static const double _nearbyRadiusKm = 2.0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _tooltipCloseTimer?.cancel();
    super.dispose();
  }

  void _showBranchTooltip(Branch branch, double distanceKm) {
    // Cancel any existing timer
    _tooltipCloseTimer?.cancel();
    
    setState(() {
      _selectedBranch = branch;
      _selectedDistance = distanceKm;
    });
    
    // Auto-hide after 3 seconds
    _tooltipCloseTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _selectedBranch = null;
        });
      }
    });
  }

  void _hideBranchTooltip() {
    _tooltipCloseTimer?.cancel();
    setState(() {
      _selectedBranch = null;
    });
  }

  Future<void> _initialize() async {
    await _loadBranches();
    await _tryGetLocation();
    setState(() => _isLoading = false);
  }

  Future<void> _tryGetLocation() async {
    setState(() { 
      _isLoadingLocation = true;
      _gpsLocked = false;
    });
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Location services disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _showError('Location permission denied');
        return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best)
          .timeout(const Duration(seconds: 10));

      setState(() {
        _currentPosition = position;
        _currentLatLng = LatLng(position.latitude, position.longitude);
        _error = null;
        _isLoadingLocation = false;
        _gpsLocked = true;
      });

      if (!_hasCenteredMap) {
        _hasCenteredMap = true;
        _mapController.move(_currentLatLng!, 14);
      }
      
      _updateNearestAndFilter();
    } catch (e) {
      _showError('Could not get your location');
    }
  }

  void _showError(String message) {
    setState(() {
      _error = message;
      _isLoadingLocation = false;
      _gpsLocked = false;
      _currentLatLng = _defaultLatLng;
    });
    _updateNearestAndFilter();
  }

  bool _isBranchNearby(Branch branch) {
    if (_currentPosition == null) return false;
    final distance = branch.distanceFrom(_currentPosition!.latitude, _currentPosition!.longitude);
    return distance <= _nearbyRadiusKm;
  }

  void _updateNearestAndFilter() {
    if (_branches.isEmpty) return;

    List<Branch> workingList = List.from(_branches);

    if (_searchQuery.isNotEmpty) {
      workingList = workingList.where((branch) {
        return branch.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               branch.address.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               branch.seniorPastor.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    if (_searchedLocation != null) {
      workingList.sort((a, b) {
        final distA = _calculateDistance(_searchedLocation!.latitude, _searchedLocation!.longitude, a.latitude, a.longitude);
        final distB = _calculateDistance(_searchedLocation!.latitude, _searchedLocation!.longitude, b.latitude, b.longitude);
        return distA.compareTo(distB);
      });
    } else if (_currentPosition != null) {
      workingList.sort((a, b) {
        final distA = a.distanceFrom(_currentPosition!.latitude, _currentPosition!.longitude);
        final distB = b.distanceFrom(_currentPosition!.latitude, _currentPosition!.longitude);
        return distA.compareTo(distB);
      });
    }

    setState(() {
      _filteredBranches = workingList;
      _nearestBranch = workingList.isNotEmpty ? workingList.first : null;
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureNearestCardHeight();
    });
  }

  void _measureNearestCardHeight() {
    final RenderBox? renderBox = _nearestCardKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final double newHeight = renderBox.size.height;
      if (_nearestCardHeight != newHeight) {
        setState(() {
          _nearestCardHeight = newHeight;
        });
      }
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

  Future<void> _geocodeLocation(String location) async {
    if (location.isEmpty) return;
    setState(() => _isGeocoding = true);

    try {
      final encodedLocation = Uri.encodeComponent(location);
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?q=$encodedLocation&format=json&limit=1'),
        headers: {'User-Agent': 'MinistryOfRepentance/1.0'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lng = double.parse(data[0]['lon']);

          setState(() {
            _searchedLocation = LatLng(lat, lng);
            _isGeocoding = false;
          });

          _mapController.move(_searchedLocation!, 13);
          _updateNearestAndFilter();
        } else {
          setState(() => _isGeocoding = false);
        }
      } else {
        setState(() => _isGeocoding = false);
      }
    } catch (e) {
      setState(() => _isGeocoding = false);
    }
  }

  void _updateSuggestions(String query) {
    if (query.isEmpty) {
      setState(() => _searchSuggestions = []);
      return;
    }

    final lowerQuery = query.toLowerCase();
    final suggestions = <String>{};

    for (var branch in _branches) {
      if (branch.name.toLowerCase().contains(lowerQuery)) suggestions.add(branch.name);
      if (branch.address.toLowerCase().contains(lowerQuery)) suggestions.add(branch.address);
    }

    setState(() => _searchSuggestions = suggestions.take(5).toList());
  }

  void _searchBranches(String query) {
    setState(() {
      _searchQuery = query;
      _isSearching = query.isNotEmpty;
    });
    _updateSuggestions(query);

    if (query.length > 3 && !_branches.any((b) => b.name.toLowerCase().contains(query.toLowerCase()))) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (_searchQuery == query && query.isNotEmpty) _geocodeLocation(query);
      });
    } else {
      _updateNearestAndFilter();
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _isSearching = false;
      _searchSuggestions = [];
      _searchedLocation = null;
    });
    _updateNearestAndFilter();
    _mapController.move(_currentLatLng ?? _defaultLatLng, 13);
  }

  void _selectSuggestion(String suggestion) {
    _searchController.text = suggestion;
    _searchBranches(suggestion);
    _searchFocusNode.unfocus();
    setState(() => _searchSuggestions = []);
  }

  Future<void> _loadBranches() async {
    final branches = await BranchService.getAllBranches();
    setState(() => _branches = branches);
    _updateNearestAndFilter();
  }

  Future<void> _refreshBranches() async {
    setState(() => _isRefreshing = true);
    await _loadBranches();
    setState(() => _isRefreshing = false);
  }

  String _getWalkingTime(double distanceKm) {
    int minutes = (distanceKm * 12).round();
    if (minutes < 1) return '<1 min walk';
    if (minutes == 1) return '1 min walk';
    return '$minutes min walk';
  }

  void _showNearestBranchDetails() {
    if (_nearestBranch == null || _currentPosition == null) return;
    
    HapticService.trigger(HapticIntensity.light, context: context);
    final distance = _nearestBranch!.distanceFrom(_currentPosition!.latitude, _currentPosition!.longitude);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PhysicsSheet(
        child: BranchPreviewSheet(
          branch: _nearestBranch!,
          distanceKm: distance,
        ),
        minChildSize: 0.4,
        maxChildSize: 0.8,
        initialChildSize: 0.5,
        onExpanded: () {
          HapticService.trigger(HapticIntensity.light, context: context);
        },
        onCollapsed: () {
          HapticService.trigger(HapticIntensity.light, context: context);
        },
      ),
    );
  }

  void _showBranchSchedule(Branch branch) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BranchDetailsScreen(branch: branch),
      ),
    );
  }

  void _showBranchPickupPoints(Branch branch) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BranchDetailsScreen(branch: branch),
      ),
    );
  }

  void _goToNearestBranch() {
    if (_nearestBranch != null) {
      _openDirections(_nearestBranch!.latitude, _nearestBranch!.longitude);
    }
  }

  void _showSearchResultsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: M3Colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: M3Colors.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _searchQuery.isNotEmpty ? 'Results for "$_searchQuery"' : 'All Branches',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _filteredBranches.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final branch = _filteredBranches[index];
                    final isNearest = _nearestBranch?.id == branch.id;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: isNearest ? 2 : 0,
                      color: isNearest ? M3Colors.primaryContainer : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isNearest ? M3Colors.primary : M3Colors.outline.withOpacity(0.3),
                          width: isNearest ? 1.5 : 1,
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isNearest ? M3Colors.primary : M3Colors.surfaceVariant,
                          foregroundColor: isNearest ? M3Colors.onPrimary : M3Colors.onSurfaceVariant,
                          child: Text('${index + 1}'),
                        ),
                        title: Text(
                          branch.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: isNearest ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          branch.address,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isNearest
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: M3Colors.primary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'NEAREST',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: M3Colors.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          _mapController.move(LatLng(branch.latitude, branch.longitude), 15);
                          _showBranchDetails(branch);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBranchDetails(Branch branch) {
    _hideBranchTooltip();
    Navigator.push(context, MaterialPageRoute(builder: (_) => BranchDetailsScreen(branch: branch)));
  }

  Future<void> _openDirections(double destLat, double destLng) async {
    _hideBranchTooltip();
    await HapticService.trigger(HapticIntensity.medium, context: context);
    String originParam = '';
    if (_searchedLocation != null) {
      originParam = '&origin=${_searchedLocation!.latitude},${_searchedLocation!.longitude}';
    } else if (_currentPosition != null) {
      originParam = '&origin=${_currentPosition!.latitude},${_currentPosition!.longitude}';
    }

    final url = Uri.parse('https://www.google.com/maps/dir/?api=1$originParam&destination=$destLat,$destLng');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  void _checkAndShowRecenterButton(LatLng center) {
    if (_currentLatLng == null) return;
    
    final distance = _calculateDistance(
      center.latitude, center.longitude,
      _currentLatLng!.latitude, _currentLatLng!.longitude,
    );
    
    final shouldShow = distance > 1.0;
    
    if (shouldShow != _showRecenterButton) {
      setState(() {
        _showRecenterButton = shouldShow;
      });
    }
  }

  void _recenterMap() async {
    if (_currentLatLng != null) {
      await HapticService.trigger(HapticIntensity.light, context: context);
      _mapController.move(_currentLatLng!, 14);
      setState(() {
        _showRecenterButton = false;
      });
    }
  }

  void _onMarkerTap(Branch branch, double distanceKm) {
    HapticService.trigger(HapticIntensity.light, context: context);
    _showBranchTooltip(branch, distanceKm);
  }

  @override
  Widget build(BuildContext context) {
    final motionPrefs = Provider.of<MotionPreferences>(context);
    final reduceMotion = motionPrefs.disableAnimations;
    
    return _isLoading
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _defaultLatLng,
                  initialZoom: 12,
                  onPositionChanged: (position, hasGesture) {
                    if (hasGesture && position.center != null) {
                      _checkAndShowRecenterButton(position.center!);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                  ),
                  if (_currentLatLng != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: _currentLatLng!,
                        child: GpsLockIndicator(
                          isLocked: _gpsLocked,
                          isAcquiring: _isLoadingLocation,
                        ),
                      ),
                    ]),
                  // Modern 2026 Markers
                  MarkerLayer(
                    markers: (_filteredBranches.isNotEmpty ? _filteredBranches : _branches).map((branch) {
                      final isNearest = _nearestBranch?.id == branch.id;
                      final isNearby = _isBranchNearby(branch);
                      final distance = _currentPosition != null 
                          ? branch.distanceFrom(_currentPosition!.latitude, _currentPosition!.longitude)
                          : 0.0;
                      
                      return Marker(
                        point: LatLng(branch.latitude, branch.longitude),
                        child: ModernMarker(
                          name: branch.name,
                          address: branch.address,
                          isNearby: isNearby && !_isSearching,
                          isNearest: isNearest && !_isSearching,
                          distanceKm: distance,
                          onTap: () => _onMarkerTap(branch, distance),
                          onLongPress: () => _openDirections(branch.latitude, branch.longitude),
                          showTooltip: false,
                          onTooltipAction: () => _showBranchDetails(branch),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              
              // Tooltip rendered as a floating widget at the bottom of the Stack (highest z-index)
              if (_selectedBranch != null)
                Positioned(
                  bottom: 120,
                  left: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => _showBranchDetails(_selectedBranch!),
                    child: Material(
                      elevation: 24,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: M3Colors.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 24,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: (_selectedBranch?.id == _nearestBranch?.id ? M3Colors.tertiary : M3Colors.primary).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (_selectedBranch?.id == _nearestBranch?.id ? M3Colors.tertiary : M3Colors.primary).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _selectedBranch?.id == _nearestBranch?.id ? Icons.star : Icons.location_on,
                                    size: 18,
                                    color: _selectedBranch?.id == _nearestBranch?.id ? M3Colors.tertiary : M3Colors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedBranch?.name ?? '',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: M3Colors.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        _selectedBranch?.address ?? '',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: M3Colors.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (_selectedDistance > 0) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.directions_walk, size: 14, color: M3Colors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_selectedDistance.toStringAsFixed(1)} km away',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: M3Colors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _showBranchDetails(_selectedBranch!),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      side: const BorderSide(color: M3Colors.primary),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('VIEW DETAILS'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _openDirections(_selectedBranch!.latitude, _selectedBranch!.longitude),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: M3Colors.primary,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('DIRECTIONS'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: SearchBar(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      hintText: 'Search branches or location...',
                      leading: const Icon(Icons.search),
                      trailing: _searchQuery.isNotEmpty
                          ? [
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: _clearSearch,
                              ),
                            ]
                          : null,
                      onChanged: _searchBranches,
                    ),
                  ),

                  if (_searchSuggestions.isNotEmpty && _searchFocusNode.hasFocus)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        child: Column(
                          children: _searchSuggestions
                              .map((suggestion) => ListTile(
                                    leading: const Icon(Icons.location_on, size: 18),
                                    title: Text(suggestion),
                                    trailing: const Icon(Icons.arrow_forward, size: 16),
                                    onTap: () => _selectSuggestion(suggestion),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Card(
                        color: M3Colors.error.withOpacity(0.1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber, color: M3Colors.error, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(color: M3Colors.error),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  if (_isSearching && _filteredBranches.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ActionChip(
                        label: Text('${_filteredBranches.length} results found'),
                        onPressed: _showSearchResultsModal,
                        avatar: const Icon(Icons.search, size: 16),
                      ),
                    ),

                  const Spacer(),

                  // Compact Nearest Branch Chip (Stripe-ified)
                  if (_nearestBranch != null && !_isSearching && _currentPosition != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Center(
                        child: NearestBranchChip(
                          branch: _nearestBranch!,
                          distanceKm: _nearestBranch!.distanceFrom(_currentPosition!.latitude, _currentPosition!.longitude),
                          onTap: _showNearestBranchDetails,
                        ),
                      ),
                    ),

                  if (!_isSearching && _filteredBranches.isNotEmpty && !_isLoading)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: M3Colors.surfaceVariant,
                        border: Border(top: BorderSide(color: M3Colors.outline.withOpacity(0.3))),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.store, color: M3Colors.onSurfaceVariant, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                '${_filteredBranches.length} Branches',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: _showSearchResultsModal,
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if ((_nearestBranch != null && !_isSearching && _currentPosition != null) || _showRecenterButton)
                Positioned(
                  bottom: _showRecenterButton ? 140 : 70,
                  right: 16,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: 1.0,
                    child: FloatingActionButton(
                      onPressed: _showRecenterButton ? _recenterMap : _tryGetLocation,
                      child: Icon(_showRecenterButton ? Icons.my_location : Icons.gps_fixed),
                    ),
                  ),
                ),
            ],
          );
  }
}