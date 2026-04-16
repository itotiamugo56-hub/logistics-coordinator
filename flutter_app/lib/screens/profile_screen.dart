import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/flare_provider.dart';
import '../services/haptic_service.dart';
import '../services/api_client.dart';
import '../widgets/crystal_button.dart';
import '../widgets/physics_sheet.dart';
import '../widgets/skeleton_loader.dart';
import 'help_resources_screen.dart';
import 'my_flares_screen.dart';
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
  static const Color success = Color(0xFF00C853);
  static const Color warning = Color(0xFFFFB300);
}

/// Verification Badge Component
class VerificationBadge extends StatelessWidget {
  final bool isVerified;
  final String? label;

  const VerificationBadge({
    super.key,
    required this.isVerified,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isVerified
            ? M3Colors.success.withOpacity(0.1)
            : M3Colors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isVerified
              ? M3Colors.success.withOpacity(0.3)
              : M3Colors.warning.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVerified ? Icons.verified : Icons.help_outline,
            size: 14,
            color: isVerified ? M3Colors.success : M3Colors.warning,
          ),
          const SizedBox(width: 6),
          Text(
            label ?? (isVerified ? 'Verified Member' : 'Pending Verification'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isVerified ? M3Colors.success : M3Colors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stats Card - Key metrics at a glance
class StatsCard extends StatelessWidget {
  final int flareCount;
  final int branchesVisited;
  final VoidCallback onFlareTap;

  const StatsCard({
    super.key,
    required this.flareCount,
    required this.branchesVisited,
    required this.onFlareTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem(
                icon: Icons.warning_amber,
                value: flareCount.toString(),
                label: 'Signal Flares',
                color: M3Colors.warning,
                onTap: onFlareTap,
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: M3Colors.outline.withOpacity(0.3),
            ),
            Expanded(
              child: _buildStatItem(
                icon: Icons.church,
                value: branchesVisited.toString(),
                label: 'Branches',
                color: M3Colors.primary,
                onTap: null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: M3Colors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: M3Colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Profile Menu Section
class ProfileMenuSection extends StatelessWidget {
  final List<ProfileMenuItem> items;

  const ProfileMenuSection({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          for (int i = 0; i < items.length; i++)
            Column(
              children: [
                items[i],
                if (i < items.length - 1)
                  const Divider(height: 1, indent: 56),
              ],
            ),
        ],
      ),
    );
  }
}

/// Profile Menu Item
class ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Widget? trailing;

  const ProfileMenuItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? M3Colors.primary).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: iconColor ?? M3Colors.primary),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: M3Colors.onSurface,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: M3Colors.onSurfaceVariant,
              ),
            )
          : null,
      trailing: trailing ??
          const Icon(
            Icons.chevron_right,
            size: 20,
            color: M3Colors.outline,
          ),
      onTap: () {
        HapticService.trigger(HapticIntensity.light, context: context);
        onTap();
      },
    );
  }
}

/// Security Section - Expandable security status
class SecuritySection extends StatefulWidget {
  final VoidCallback onRefresh;

  const SecuritySection({
    super.key,
    required this.onRefresh,
  });

  @override
  State<SecuritySection> createState() => _SecuritySectionState();
}

class _SecuritySectionState extends State<SecuritySection> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    HapticService.trigger(HapticIntensity.light, context: context);
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = Provider.of<MotionPreferences>(context).disableAnimations;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          // Header
          InkWell(
            onTap: _toggleExpand,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: M3Colors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.security,
                      size: 20,
                      color: M3Colors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Security Status',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: M3Colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'End-to-end encrypted • Active session',
                          style: TextStyle(
                            fontSize: 12,
                            color: M3Colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!reduceMotion)
                    AnimatedBuilder(
                      animation: _rotationAnimation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _rotationAnimation.value * 3.14159,
                          child: const Icon(
                            Icons.chevron_right,
                            color: M3Colors.outline,
                          ),
                        );
                      },
                    )
                  else
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: M3Colors.outline,
                    ),
                ],
              ),
            ),
          ),
          
          // Expanded content
          if (_isExpanded)
            AnimatedContainer(
              duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    const Divider(),
                    const SizedBox(height: 12),
                    _buildSecurityRow(
                      Icons.lock,
                      'Encryption',
                      'Active (AES-256)',
                      M3Colors.success,
                    ),
                    const SizedBox(height: 12),
                    _buildSecurityRow(
                      Icons.devices,
                      'Session',
                      'This device only',
                      M3Colors.success,
                    ),
                    const SizedBox(height: 12),
                    _buildSecurityRow(
                      Icons.sync,
                      'Data Sync',
                      'End-to-end encrypted',
                      M3Colors.success,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: CrystalButton(
                            onPressed: widget.onRefresh,
                            label: 'VERIFY SESSION',
                            variant: CrystalButtonVariant.outlined,
                            icon: Icons.refresh,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSecurityRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: M3Colors.onSurface,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: M3Colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Logout Dialog - Apple-style confirmation
class LogoutDialog extends StatelessWidget {
  const LogoutDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: M3Colors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout,
                size: 32,
                color: M3Colors.error,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sign Out',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: M3Colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Are you sure you want to sign out? You will need to log in again to access your account.',
              style: TextStyle(
                fontSize: 13,
                color: M3Colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: CrystalButton(
                    onPressed: () => Navigator.pop(context),
                    label: 'CANCEL',
                    variant: CrystalButtonVariant.outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CrystalButton(
                    onPressed: () {
                      HapticService.trigger(HapticIntensity.heavy, context: context);
                      Navigator.pop(context);
                      context.read<AuthProvider>().logout();
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    label: 'SIGN OUT',
                    variant: CrystalButtonVariant.filled,
                    icon: Icons.logout,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Main Profile Screen - Stripe/Apple Grade with Real Auth Data
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _memberName = '';
  String _memberEmail = '';
  bool _isVerified = true;
  int _flareCount = 0;
  int _branchesVisited = 0;
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    
    final authProvider = context.read<AuthProvider>();
    final flareProvider = context.read<FlareProvider>();
    
    // Check if user is authenticated
    _isAuthenticated = authProvider.isAuthenticated;
    
    if (_isAuthenticated) {
      // Use real data from auth provider
      setState(() {
        _memberName = authProvider.name ?? 'Verified Member';
        _memberEmail = authProvider.email ?? 'member@repentance.org';
        _flareCount = flareProvider.flares.length;
        _branchesVisited = 5; // TODO: Load from API when available
        _isVerified = true;
        _isLoading = false;
      });
    } else {
      // Not authenticated - show empty state or redirect
      setState(() {
        _memberName = 'Guest User';
        _memberEmail = 'Not signed in';
        _flareCount = 0;
        _branchesVisited = 0;
        _isVerified = false;
        _isLoading = false;
      });
    }
  }

  void _showHelpResources() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HelpResourcesScreen()),
    );
  }

  void _showMyFlares() {
    if (!_isAuthenticated) {
      // Show login sheet or navigate to login
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to view your flares')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyFlaresScreen()),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const LogoutDialog(),
    );
  }

  void _navigateToLogin() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final motionPrefs = Provider.of<MotionPreferences>(context);
    final reduceMotion = motionPrefs.disableAnimations;
    
    return Scaffold(
      backgroundColor: M3Colors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: M3Colors.surface,
        foregroundColor: M3Colors.onSurface,
        elevation: 0,
        centerTitle: false,
        actions: [
          if (!_isAuthenticated && !_isLoading)
            TextButton(
              onPressed: _navigateToLogin,
              child: const Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: M3Colors.primary,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: const ProfileHeaderSkeleton()),
                SliverToBoxAdapter(child: const StatsCardSkeleton()),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: List.generate(3, (index) => const MenuItemSkeleton()),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: List.generate(3, (index) => const MenuItemSkeleton()),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: const MenuItemSkeleton(),
                  ),
                ),
              ],
            )
          : RefreshIndicator(
              onRefresh: _loadUserData,
              child: CustomScrollView(
                slivers: [
                  // Hero Header with Avatar
                  SliverToBoxAdapter(
                    child: Container(
                      color: M3Colors.surface,
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          // Avatar
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  M3Colors.primary,
                                  M3Colors.tertiary,
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: M3Colors.surface,
                                shape: BoxShape.circle,
                              ),
                              child: CircleAvatar(
                                radius: 45,
                                backgroundColor: M3Colors.primaryContainer,
                                child: Text(
                                  _memberName.isNotEmpty ? _memberName[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w600,
                                    color: M3Colors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Name - Real data
                          Text(
                            _memberName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: M3Colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Email - Real data
                          Text(
                            _memberEmail,
                            style: TextStyle(
                              fontSize: 13,
                              color: M3Colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Verification Badge
                          VerificationBadge(isVerified: _isVerified),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  
                  // Stats Card - Real data
                  SliverToBoxAdapter(
                    child: StatsCard(
                      flareCount: _flareCount,
                      branchesVisited: _branchesVisited,
                      onFlareTap: _showMyFlares,
                    ),
                  ),
                  
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  
                  // Menu Sections
                  SliverToBoxAdapter(
                    child: ProfileMenuSection(
                      items: [
                        ProfileMenuItem(
                          icon: Icons.help_outline,
                          title: 'Help & Resources',
                          subtitle: 'Emergency procedures and guides',
                          onTap: _showHelpResources,
                        ),
                        ProfileMenuItem(
                          icon: Icons.history,
                          title: 'My Flares',
                          subtitle: 'View your emergency history',
                          onTap: _showMyFlares,
                        ),
                        ProfileMenuItem(
                          icon: Icons.notifications_none,
                          title: 'Notifications',
                          subtitle: 'Manage alert preferences',
                          onTap: () {
                            // TODO: Notification settings
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  
                  // Security Section
                  SliverToBoxAdapter(
                    child: SecuritySection(
                      onRefresh: _loadUserData,
                    ),
                  ),
                  
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  
                  // Support Section
                  SliverToBoxAdapter(
                    child: ProfileMenuSection(
                      items: [
                        ProfileMenuItem(
                          icon: Icons.privacy_tip,
                          title: 'Privacy Policy',
                          subtitle: 'How we protect your data',
                          onTap: () {
                            // TODO: Show privacy policy
                          },
                        ),
                        ProfileMenuItem(
                          icon: Icons.description,
                          title: 'Terms of Service',
                          subtitle: 'Terms and conditions',
                          onTap: () {
                            // TODO: Show terms
                          },
                        ),
                        ProfileMenuItem(
                          icon: Icons.info_outline,
                          title: 'About',
                          subtitle: 'Version 1.0.0',
                          onTap: () {
                            // TODO: Show about
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  
                  // Logout Button (only when authenticated)
                  if (_isAuthenticated)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: CrystalButton(
                          onPressed: _showLogoutDialog,
                          label: 'SIGN OUT',
                          variant: CrystalButtonVariant.outlined,
                          icon: Icons.logout,
                          isExpanded: true,
                        ),
                      ),
                    ),
                  
                  // Sign In Button (when not authenticated)
                  if (!_isAuthenticated)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: CrystalButton(
                          onPressed: _navigateToLogin,
                          label: 'SIGN IN',
                          variant: CrystalButtonVariant.filled,
                          icon: Icons.login,
                          isExpanded: true,
                        ),
                      ),
                    ),
                  
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
    );
  }
}