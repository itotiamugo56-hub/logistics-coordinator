import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/auth_provider.dart';
import '../providers/flare_provider.dart';
import '../utils/geohash_helper.dart';
import 'map_screen.dart';
import 'branch_details_screen.dart';
import 'transport_hub_screen.dart';
import 'today_schedule_screen.dart';
import 'my_flares_screen.dart';
import 'help_resources_screen.dart';
import 'profile_screen.dart';
import '../widgets/crystal_button.dart';
import '../services/haptic_service.dart';
import '../main.dart'; // For MotionPreferences

enum DashboardTab {
  map,
  schedule,
  transport,
  flares,
  profile,
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DashboardTab _currentTab = DashboardTab.map;
  
  // Location state (shared across tabs)
  Position? _currentPosition;
  String? _currentGeohash;
  bool _isLoadingLocation = true;
  String? _locationError;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: DashboardTab.values.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _getCurrentLocation();
  }
  
  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }
  
  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentTab = DashboardTab.values[_tabController.index];
      });
    }
  }
  
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'Location services are disabled.';
          _isLoadingLocation = false;
        });
        return;
      }
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = 'Location permissions are denied.';
            _isLoadingLocation = false;
          });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = 'Location permissions are permanently denied.';
          _isLoadingLocation = false;
        });
        return;
      }
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      final geohash = GeohashHelper.encode(
        position.latitude,
        position.longitude,
        10,
      );
      
      setState(() {
        _currentPosition = position;
        _currentGeohash = geohash;
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _locationError = 'Error getting location: $e';
        _isLoadingLocation = false;
      });
    }
  }
  
  /// Determine if Flare FAB should be shown based on current tab
  bool _shouldShowFlareFAB() {
    switch (_currentTab) {
      case DashboardTab.map:
      case DashboardTab.schedule:
      case DashboardTab.transport:
        return true;
      case DashboardTab.flares:
      case DashboardTab.profile:
        return false;
    }
  }
  
  Future<void> _sendFlare() async {
    if (_currentPosition == null || _currentGeohash == null) {
      await HapticService.trigger(HapticIntensity.light, context: context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for GPS fix...')),
      );
      return;
    }
    
    await HapticService.trigger(HapticIntensity.heavy, context: context);
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticService.trigger(HapticIntensity.heavy, context: context);
    
    final flareProvider = context.read<FlareProvider>();
    
    final result = await flareProvider.submitFlare(
      lat: _currentPosition!.latitude,
      lng: _currentPosition!.longitude,
      geohash10: _currentGeohash!,
    );
    
    if (result != null && mounted) {
      await HapticService.trigger(HapticIntensity.light, context: context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Signal Flare sent! ID: ${result['flare_id'].toString().substring(0, 8)}...'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (flareProvider.lastError != null && mounted) {
      await HapticService.trigger(HapticIntensity.error, context: context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(flareProvider.lastError!)),
      );
    }
  }
  
  String _getTabTitle(DashboardTab tab) {
    switch (tab) {
      case DashboardTab.map:
        return 'Map';
      case DashboardTab.schedule:
        return 'Today';
      case DashboardTab.transport:
        return 'Transit';
      case DashboardTab.flares:
        return 'Safety';
      case DashboardTab.profile:
        return 'Me';
    }
  }
  
  IconData _getTabIcon(DashboardTab tab) {
    switch (tab) {
      case DashboardTab.map:
        return Icons.map_outlined;
      case DashboardTab.schedule:
        return Icons.calendar_today_outlined;
      case DashboardTab.transport:
        return Icons.directions_bus_outlined;
      case DashboardTab.flares:
        return Icons.warning_amber_outlined;
      case DashboardTab.profile:
        return Icons.person_outline;
    }
  }
  
  void _navigateToHelpResources() {
    HapticService.trigger(HapticIntensity.light, context: context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HelpResourcesScreen()),
    );
  }
  
  Widget _buildTabContent(DashboardTab tab) {
    switch (tab) {
      case DashboardTab.map:
        return const MapScreen();
      case DashboardTab.schedule:
        return const TodayScheduleScreen();
      case DashboardTab.transport:
        return const TransportationHubScreen();
      case DashboardTab.flares:
        return const MyFlaresScreen();
      case DashboardTab.profile:
        return const ProfileScreen();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final motionPrefs = Provider.of<MotionPreferences>(context);
    final reduceMotion = motionPrefs.disableAnimations;
    
    return Scaffold(
      body: Column(
        children: [
          // Custom App Bar with location status
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              left: 16,
              right: 16,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.church, color: M3Colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Zero-Trust Logistics',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: M3Colors.onSurface,
                        ),
                      ),
                      if (_isLoadingLocation)
                        const Text(
                          'Acquiring GPS...',
                          style: TextStyle(fontSize: 11, color: M3Colors.onSurfaceVariant),
                        )
                      else if (_locationError != null)
                        Text(
                          _locationError!,
                          style: const TextStyle(fontSize: 11, color: M3Colors.error),
                        )
                      else
                        Text(
                          'Ready • ${_currentPosition?.latitude.toStringAsFixed(4)}°, ${_currentPosition?.longitude.toStringAsFixed(4)}°',
                          style: const TextStyle(fontSize: 11, color: M3Colors.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _getCurrentLocation,
                  tooltip: 'Refresh location',
                ),
                IconButton(
                  icon: const Icon(Icons.logout, size: 20),
                  onPressed: () async {
                    await HapticService.trigger(HapticIntensity.medium, context: context);
                    context.read<AuthProvider>().logout();
                    if (mounted) {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  },
                  tooltip: 'Logout',
                ),
              ],
            ),
          ),
          
          // Tab Bar
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: M3Colors.outline.withOpacity(0.2)),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              dividerColor: Colors.transparent,
              indicatorColor: M3Colors.primary,
              labelColor: M3Colors.primary,
              unselectedLabelColor: M3Colors.onSurfaceVariant,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              splashFactory: reduceMotion ? NoSplash.splashFactory : null,
              tabs: DashboardTab.values.map((tab) {
                return Tab(
                  icon: Icon(_getTabIcon(tab)),
                  text: _getTabTitle(tab),
                );
              }).toList(),
            ),
          ),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: DashboardTab.values.map((tab) => _buildTabContent(tab)).toList(),
            ),
          ),
        ],
      ),
      // Contextual Flare FAB - only appears on Map, Today, and Transit tabs
      floatingActionButton: _shouldShowFlareFAB()
          ? FloatingActionButton.extended(
              onPressed: _isLoadingLocation || _locationError != null ? null : _sendFlare,
              icon: const Icon(Icons.warning),
              label: const Text('SIGNAL FLARE'),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// M3Colors for consistency (since dashboard uses it)
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
  static const Color warning = Color(0xFFFFB300);
}