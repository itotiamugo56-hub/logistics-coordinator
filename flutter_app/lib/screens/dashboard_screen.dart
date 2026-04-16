import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
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
import '../widgets/success_animation.dart';
import '../widgets/login_sheet.dart';
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
  
  // Animation for tab content transition
  int _previousTabIndex = 0;
  
  // For ambient background animation
  double _ambientOffset = 0;
  late Timer _ambientTimer;
  
  // For hidden admin access (long press counter)
  Timer? _longPressTimer;
  bool _isLongPressing = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: DashboardTab.values.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _getCurrentLocation();
    
    // Subtle ambient animation for the app bar gradient
    _ambientTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) {
        setState(() {
          _ambientOffset += 0.01;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _ambientTimer.cancel();
    _longPressTimer?.cancel();
    super.dispose();
  }
  
  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      _previousTabIndex = DashboardTab.values.indexOf(_currentTab);
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
  
  /// Hidden admin access - triggered by long press on church icon (3 seconds)
  void _startLongPressTimer() {
    _longPressTimer?.cancel();
    _isLongPressing = true;
    _longPressTimer = Timer(const Duration(seconds: 3), () async {
      if (mounted && _isLongPressing) {
        await HapticService.trigger(HapticIntensity.heavy, context: context);
        
        final authProvider = context.read<AuthProvider>();
        if (authProvider.isAdmin) {
          // Show success haptic and navigate
          await HapticService.trigger(HapticIntensity.light, context: context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Admin access granted'),
              backgroundColor: M3Colors.success,
              duration: Duration(seconds: 1),
            ),
          );
          Navigator.pushNamed(context, '/admin');
        } else {
          await HapticService.trigger(HapticIntensity.error, context: context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Admin access required'),
              backgroundColor: M3Colors.error,
            ),
          );
        }
        _isLongPressing = false;
      }
    });
  }
  
  void _cancelLongPressTimer() {
    _longPressTimer?.cancel();
    _isLongPressing = false;
  }
  
  Future<void> _sendFlare() async {
    // Check if user is authenticated
    final authProvider = context.read<AuthProvider>();
    
    if (!authProvider.isAuthenticated) {
      // Show login sheet first
      final loggedIn = await LoginSheet.show(context);
      if (!loggedIn || !mounted) return;
      // Re-check auth after login
      if (!context.read<AuthProvider>().isAuthenticated) return;
    }
    
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
      
      // Show success animation with checkmark
      await SuccessAnimation.show(
        context,
        message: 'Signal Flare Sent',
      );
      
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
  
  /// Get filled icon (when selected) - Cupertino style for selected state
  IconData _getFilledIcon(DashboardTab tab) {
    switch (tab) {
      case DashboardTab.map:
        return CupertinoIcons.map_fill;
      case DashboardTab.schedule:
        return CupertinoIcons.calendar;
      case DashboardTab.transport:
        return CupertinoIcons.bus;
      case DashboardTab.flares:
        return CupertinoIcons.exclamationmark_triangle_fill;
      case DashboardTab.profile:
        return CupertinoIcons.person_solid;
    }
  }
  
  /// Get outlined icon (when not selected) - Cupertino outline style
  IconData _getOutlinedIcon(DashboardTab tab) {
    switch (tab) {
      case DashboardTab.map:
        return CupertinoIcons.map;
      case DashboardTab.schedule:
        return CupertinoIcons.calendar;
      case DashboardTab.transport:
        return CupertinoIcons.bus;
      case DashboardTab.flares:
        return CupertinoIcons.exclamationmark_triangle;
      case DashboardTab.profile:
        return CupertinoIcons.person;
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
  
  void _showProfileMenu(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final isAuthenticated = authProvider.isAuthenticated;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: M3Colors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Enhanced drag handle with shadow
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: M3Colors.outline,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Header with user info - enhanced
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Animated Avatar
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0.8, end: 1.0),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.elasticOut,
                    builder: (context, double scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: isAuthenticated
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      M3Colors.primary,
                                      M3Colors.tertiary,
                                    ],
                                  )
                                : null,
                            color: isAuthenticated ? null : M3Colors.surfaceVariant,
                            shape: BoxShape.circle,
                            boxShadow: isAuthenticated
                                ? [
                                    BoxShadow(
                                      color: M3Colors.primary.withOpacity(0.3),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: isAuthenticated
                                ? Text(
                                    authProvider.name?.isNotEmpty == true
                                        ? authProvider.name![0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.person_outline, size: 26, color: M3Colors.onSurfaceVariant),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAuthenticated
                              ? (authProvider.name ?? 'Member')
                              : 'Guest User',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: M3Colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isAuthenticated
                              ? (authProvider.email ?? '')
                              : 'Sign in to access all features',
                          style: TextStyle(
                            fontSize: 12,
                            color: M3Colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            const Divider(height: 1, indent: 20, endIndent: 20),
            
            // Menu Items - ONLY show sign-in options when NOT authenticated
            if (!isAuthenticated) ...[
              _buildMenuItem(
                icon: Icons.person_outline,
                title: 'Sign in as Member',
                subtitle: 'Access flares, history, and profile',
                onTap: () {
                  HapticService.trigger(HapticIntensity.light, context: context);
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/login');
                },
                iconColor: M3Colors.primary,
              ),
              
              _buildMenuItem(
                icon: Icons.church,
                title: 'Sign in as Clergy',
                subtitle: 'Manage your branch and congregation',
                onTap: () {
                  HapticService.trigger(HapticIntensity.light, context: context);
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/clergy-login');
                },
                iconColor: M3Colors.tertiary,
              ),
              
              const Divider(height: 1, indent: 20, endIndent: 20),
              
              _buildMenuItem(
                icon: Icons.person_add,
                title: 'Create Account',
                subtitle: 'Sign up for a new account',
                onTap: () {
                  HapticService.trigger(HapticIntensity.light, context: context);
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/register');
                },
                iconColor: M3Colors.success,
              ),
            ],
            
            // Conditional menu items (only show if authenticated)
            if (isAuthenticated) ...[
              _buildMenuItem(
                icon: Icons.person,
                title: 'My Profile',
                subtitle: authProvider.email ?? 'View your profile',
                onTap: () {
                  HapticService.trigger(HapticIntensity.light, context: context);
                  Navigator.pop(context);
                  _tabController.animateTo(DashboardTab.profile.index);
                },
                iconColor: M3Colors.primary,
              ),
              _buildMenuItem(
                icon: Icons.history,
                title: 'My Flares',
                subtitle: 'View your emergency history',
                onTap: () {
                  HapticService.trigger(HapticIntensity.light, context: context);
                  Navigator.pop(context);
                  _tabController.animateTo(DashboardTab.flares.index);
                },
                iconColor: M3Colors.primary,
              ),
            ],
            
            // Role-specific menu items
            if (isAuthenticated && authProvider.isClergy) ...[
              const Divider(height: 1, indent: 20, endIndent: 20),
              _buildMenuItem(
                icon: Icons.admin_panel_settings,
                title: 'Clergy Portal',
                subtitle: 'Manage your branch',
                onTap: () {
                  HapticService.trigger(HapticIntensity.light, context: context);
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/clergy');
                },
                iconColor: M3Colors.tertiary,
              ),
            ],
            
            if (isAuthenticated && authProvider.isAdmin) ...[
              const Divider(height: 1, indent: 20, endIndent: 20),
              _buildMenuItem(
                icon: Icons.admin_panel_settings,
                title: 'Admin Dashboard',
                subtitle: 'Manage users and regions',
                onTap: () {
                  HapticService.trigger(HapticIntensity.light, context: context);
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/admin');
                },
                iconColor: M3Colors.primary,
              ),
            ],
            
            if (isAuthenticated) ...[
              const Divider(height: 1, indent: 20, endIndent: 20),
              _buildMenuItem(
                icon: Icons.logout,
                title: 'Sign Out',
                subtitle: 'Log out of your account',
                onTap: () {
                  HapticService.trigger(HapticIntensity.light, context: context);
                  Navigator.pop(context);
                  _showLogoutConfirmation(context);
                },
                iconColor: M3Colors.error,
                isDestructive: true,
              ),
            ],
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (iconColor ?? M3Colors.primary).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: iconColor ?? M3Colors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDestructive ? M3Colors.error : M3Colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: M3Colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: isDestructive ? M3Colors.error : M3Colors.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out? You will need to log in again to access your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              await HapticService.trigger(HapticIntensity.medium, context: context);
              context.read<AuthProvider>().logout();
              if (mounted) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: M3Colors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('SIGN OUT'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final motionPrefs = Provider.of<MotionPreferences>(context);
    final reduceMotion = motionPrefs.disableAnimations;
    final authProvider = context.watch<AuthProvider>();
    final isAuthenticated = authProvider.isAuthenticated;
    
    // Ambient gradient animation
    final gradientStart = Color.lerp(
      Colors.white.withOpacity(0.98),
      M3Colors.primaryContainer.withOpacity(0.3),
      (sin(_ambientOffset) + 1) / 4,
    );
    
    final gradientEnd = Color.lerp(
      Colors.white.withOpacity(0.96),
      M3Colors.tertiary.withOpacity(0.2),
      (cos(_ambientOffset) + 1) / 4,
    );
    
    return Scaffold(
      body: Column(
        children: [
          // Enhanced Glassmorphic App Bar with ambient gradient
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 2,
              left: 14,
              right: 12,
              bottom: 6,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: reduceMotion
                    ? [Colors.white.withOpacity(0.96), Colors.white.withOpacity(0.96)]
                    : [gradientStart ?? Colors.white, gradientEnd ?? Colors.white],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Hidden admin access: Long press on church icon (3 seconds)
                GestureDetector(
                  onLongPressStart: (_) => _startLongPressTimer(),
                  onLongPressEnd: (_) => _cancelLongPressTimer(),
                  onLongPressCancel: _cancelLongPressTimer,
                  child: TweenAnimationBuilder(
                    tween: Tween<double>(begin: 1.0, end: 1.0),
                    duration: const Duration(milliseconds: 1500),
                    builder: (context, double scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [M3Colors.primary, M3Colors.tertiary],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.church,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Zero-Trust Logistics',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                          color: M3Colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 1),
                      if (_isLoadingLocation)
                        const Text(
                          'Acquiring GPS...',
                          style: TextStyle(fontSize: 9, color: M3Colors.onSurfaceVariant),
                        )
                      else if (_locationError != null)
                        Text(
                          _locationError!,
                          style: const TextStyle(fontSize: 9, color: M3Colors.error),
                        )
                      else
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: M3Colors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Ready • ${_currentPosition?.latitude.toStringAsFixed(4)}°, ${_currentPosition?.longitude.toStringAsFixed(4)}°',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: M3Colors.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                // Subtle Clergy Icon Button (replaces avatar)
                TweenAnimationBuilder(
                  tween: Tween<double>(begin: 1.0, end: 1.0),
                  duration: const Duration(milliseconds: 2000),
                  builder: (context, double scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: GestureDetector(
                        onTap: () {
                          HapticService.trigger(HapticIntensity.light, context: context);
                          _showProfileMenu(context);
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: isAuthenticated
                                ? const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [M3Colors.primary, M3Colors.tertiary],
                                  )
                                : null,
                            color: isAuthenticated ? null : M3Colors.surfaceVariant,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isAuthenticated ? Colors.white : M3Colors.outline,
                              width: 1.5,
                            ),
                            boxShadow: isAuthenticated
                                ? [
                                    BoxShadow(
                                      color: M3Colors.primary.withOpacity(0.3),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: isAuthenticated
                                ? Text(
                                    authProvider.name?.isNotEmpty == true
                                        ? authProvider.name![0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(CupertinoIcons.person, size: 16, color: M3Colors.onSurfaceVariant),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Responsive Tab Bar with Animated Morphing Icons (Cupertino style)
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxWidth < 500;
              
              return Container(
                margin: const EdgeInsets.only(top: 0),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: isSmallScreen,
                  dividerColor: Colors.transparent,
                  indicatorColor: M3Colors.primary,
                  indicatorWeight: 2.5,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: M3Colors.primary,
                  unselectedLabelColor: M3Colors.onSurface,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  splashFactory: reduceMotion ? NoSplash.splashFactory : null,
                  padding: isSmallScreen 
                      ? const EdgeInsets.symmetric(horizontal: 16)
                      : const EdgeInsets.symmetric(horizontal: 0),
                  tabs: DashboardTab.values.map((tab) {
                    final isSelected = _currentTab == tab;
                    return Tab(
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return ScaleTransition(
                            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                              CurvedAnimation(parent: animation, curve: Curves.elasticOut),
                            ),
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: Icon(
                          isSelected ? _getFilledIcon(tab) : _getOutlinedIcon(tab),
                          key: ValueKey(isSelected),
                          size: isSelected ? 24 : 22,
                        ),
                      ),
                      text: _getTabTitle(tab),
                    );
                  }).toList(),
                ),
              );
            },
          ),
          
          // Animated Tab Content with spring transition
          Expanded(
            child: AnimatedSwitcher(
              duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
              child: _buildTabContent(_currentTab),
            ),
          ),
        ],
      ),
      // Sleek Flare FAB with enhanced shadow
      floatingActionButton: _shouldShowFlareFAB()
          ? TweenAnimationBuilder(
              tween: Tween<double>(begin: 1.0, end: 1.0),
              duration: const Duration(milliseconds: 1000),
              builder: (context, double scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: FloatingActionButton.extended(
                      onPressed: _isLoadingLocation || _locationError != null ? null : _sendFlare,
                      icon: const Icon(Icons.warning, size: 18),
                      label: const Text(
                        'FLARE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                      extendedPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                );
              },
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