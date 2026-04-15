import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/flare_provider.dart';
import '../providers/auth_provider.dart';
import '../services/haptic_service.dart';
import '../services/api_client.dart';
import '../widgets/crystal_button.dart';
import '../widgets/physics_sheet.dart';
import '../widgets/skeleton_loader.dart';
import '../main.dart';

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
  static const Color warning = Color(0xFFFFB300);
}

/// Flare Status Badge Component
class FlareStatusBadge extends StatelessWidget {
  final String status;
  final int? etaSeconds;

  const FlareStatusBadge({
    super.key,
    required this.status,
    this.etaSeconds,
  });

  Color _getColor() {
    switch (status.toLowerCase()) {
      case 'active':
        return M3Colors.warning;
      case 'assigned':
        return M3Colors.primary;
      case 'resolved':
        return M3Colors.success;
      default:
        return M3Colors.outline;
    }
  }

  String _getText() {
    switch (status.toLowerCase()) {
      case 'active':
        return 'AWAITING';
      case 'assigned':
        if (etaSeconds != null && etaSeconds! > 0) {
          final minutes = etaSeconds! ~/ 60;
          return 'ETA ${minutes}MIN';
        }
        return 'ASSIGNED';
      case 'resolved':
        return 'RESOLVED';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getColor().withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status.toLowerCase() == 'active')
            AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: M3Colors.warning,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: M3Colors.warning.withOpacity(0.8),
                    blurRadius: 4,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          if (status.toLowerCase() == 'active') const SizedBox(width: 6),
          Text(
            _getText(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _getColor(),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Active Flare Card - High visibility for current emergency
class ActiveFlareCard extends StatelessWidget {
  final dynamic flare;
  final VoidCallback onCancel;
  final VoidCallback onRefresh;

  const ActiveFlareCard({
    super.key,
    required this.flare,
    required this.onCancel,
    required this.onRefresh,
  });

  String _formatTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }

  @override
  Widget build(BuildContext context) {
    final isAssigned = flare.status?.toLowerCase() == 'assigned';
    final etaSeconds = flare.etaSeconds as int?;
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            M3Colors.errorContainer,
            M3Colors.errorContainer.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: M3Colors.error.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: M3Colors.error.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: M3Colors.error.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeInOut,
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: M3Colors.error,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: M3Colors.error.withOpacity(0.8),
                          blurRadius: 6,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ACTIVE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: M3Colors.error,
                        ),
                      ),
                      Text(
                        _formatTime(flare.serverReceivedTime),
                        style: TextStyle(
                          fontSize: 10,
                          color: M3Colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FlareStatusBadge(
                  status: flare.status ?? 'active',
                  etaSeconds: etaSeconds,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            
            // Status timeline - simplified
            Row(
              children: [
                _buildTimelineStep(
                  icon: Icons.warning_amber,
                  label: 'Sent',
                  isCompleted: true,
                  isActive: true,
                ),
                Expanded(
                  child: Container(
                    height: 2,
                    color: isAssigned
                        ? M3Colors.primary
                        : M3Colors.outline.withOpacity(0.3),
                  ),
                ),
                _buildTimelineStep(
                  icon: Icons.person,
                  label: 'Assigned',
                  isCompleted: isAssigned,
                  isActive: isAssigned,
                ),
                Expanded(
                  child: Container(
                    height: 2,
                    color: flare.status?.toLowerCase() == 'resolved'
                        ? M3Colors.success
                        : M3Colors.outline.withOpacity(0.3),
                  ),
                ),
                _buildTimelineStep(
                  icon: Icons.check_circle,
                  label: 'Done',
                  isCompleted: flare.status?.toLowerCase() == 'resolved',
                  isActive: false,
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // ETA display (if assigned)
            if (isAssigned && etaSeconds != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: M3Colors.surface.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.timer,
                      size: 16,
                      color: M3Colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ETA: ${etaSeconds ~/ 60} min',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: M3Colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: CrystalButton(
                    onPressed: onRefresh,
                    label: 'REFRESH',
                    variant: CrystalButtonVariant.outlined,
                    icon: Icons.refresh,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CrystalButton(
                    onPressed: onCancel,
                    label: 'CANCEL',
                    variant: CrystalButtonVariant.filled,
                    icon: Icons.cancel,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep({
    required IconData icon,
    required String label,
    required bool isCompleted,
    required bool isActive,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isCompleted
                ? (isActive ? M3Colors.primary : M3Colors.success)
                : M3Colors.surfaceVariant,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 14,
            color: isCompleted ? Colors.white : M3Colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: isCompleted ? FontWeight.w600 : FontWeight.w400,
            color: isCompleted ? M3Colors.primary : M3Colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// History Flare Card - Compact view for past flares
class HistoryFlareCard extends StatelessWidget {
  final dynamic flare;
  final VoidCallback onTap;

  const HistoryFlareCard({
    super.key,
    required this.flare,
    required this.onTap,
  });

  String _formatDate(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final flareDay = DateTime(time.year, time.month, time.day);
    
    if (flareDay == today) return 'Today';
    if (flareDay == today.subtract(const Duration(days: 1))) return 'Yest';
    
    return DateFormat('MMM d').format(time);
  }

  String _formatTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }

  @override
  Widget build(BuildContext context) {
    final status = flare.status?.toLowerCase() ?? 'unknown';
    final etaSeconds = flare.etaSeconds as int?;
    
    return GestureDetector(
      onTap: () {
        HapticService.trigger(HapticIntensity.light, context: context);
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: M3Colors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: status == 'resolved'
                      ? M3Colors.success.withOpacity(0.1)
                      : M3Colors.outline.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  status == 'resolved' ? Icons.check_circle : Icons.warning_amber,
                  size: 16,
                  color: status == 'resolved' ? M3Colors.success : M3Colors.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _formatDate(flare.serverReceivedTime),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: M3Colors.onSurface,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: M3Colors.outline,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatTime(flare.serverReceivedTime),
                          style: const TextStyle(
                            fontSize: 11,
                            color: M3Colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Flare ${flare.id.substring(0, 6)}...',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: M3Colors.onSurface,
                      ),
                    ),
                    if (etaSeconds != null && status == 'assigned')
                      Text(
                        'ETA: ${etaSeconds ~/ 60}m',
                        style: const TextStyle(
                          fontSize: 10,
                          color: M3Colors.primary,
                        ),
                      ),
                  ],
                ),
              ),
              FlareStatusBadge(
                status: status,
                etaSeconds: etaSeconds,
              ),
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: M3Colors.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Flare Detail Sheet - Expandable view for past flare details
class FlareDetailSheet extends StatelessWidget {
  final dynamic flare;
  final VoidCallback onRefresh;

  const FlareDetailSheet({
    super.key,
    required this.flare,
    required this.onRefresh,
  });

  String _formatFullDate(DateTime time) {
    return DateFormat('MMM d, h:mm a').format(time);
  }

  @override
  Widget build(BuildContext context) {
    final status = flare.status?.toLowerCase() ?? 'unknown';
    final etaSeconds = flare.etaSeconds as int?;
    
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
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: status == 'resolved'
                                ? M3Colors.success.withOpacity(0.1)
                                : M3Colors.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            status == 'resolved'
                                ? Icons.check_circle
                                : Icons.warning_amber,
                            size: 24,
                            color: status == 'resolved'
                                ? M3Colors.success
                                : M3Colors.warning,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                status == 'resolved' ? 'Resolved' : 'Signal Flare',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatFullDate(flare.serverReceivedTime),
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
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // Details
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildDetailRow(
                          Icons.assignment_outlined,
                          'Flare ID',
                          flare.id.substring(0, 12),
                        ),
                        const SizedBox(height: 14),
                        _buildDetailRow(
                          Icons.timer_outlined,
                          'Status',
                          flare.status?.toUpperCase() ?? 'Unknown',
                        ),
                        if (etaSeconds != null && status == 'assigned') ...[
                          const SizedBox(height: 14),
                          _buildDetailRow(
                            Icons.directions_car,
                            'ETA',
                            '${etaSeconds ~/ 60} minutes',
                          ),
                        ],
                        const SizedBox(height: 14),
                        _buildDetailRow(
                          Icons.security,
                          'Encryption',
                          'End-to-end',
                          iconColor: M3Colors.success,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Action button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: CrystalButton(
                      onPressed: onRefresh,
                      label: 'REFRESH STATUS',
                      variant: CrystalButtonVariant.outlined,
                      icon: Icons.refresh,
                      isExpanded: true,
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
    Color iconColor = M3Colors.onSurfaceVariant,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: M3Colors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
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
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: M3Colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Empty State - No flares yet
class EmptyFlaresState extends StatelessWidget {
  final VoidCallback onSendFlare;

  const EmptyFlaresState({
    super.key,
    required this.onSendFlare,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: M3Colors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_amber_outlined,
              size: 48,
              color: M3Colors.outline,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Signal Flares',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: M3Colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the red button to send',
            style: TextStyle(
              fontSize: 13,
              color: M3Colors.outline,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          CrystalButton(
            onPressed: onSendFlare,
            label: 'SEND FLARE',
            variant: CrystalButtonVariant.filled,
            icon: Icons.warning,
          ),
        ],
      ),
    );
  }
}

/// Main My Flares Screen - Stripe/Apple Grade
class MyFlaresScreen extends StatefulWidget {
  const MyFlaresScreen({super.key});

  @override
  State<MyFlaresScreen> createState() => _MyFlaresScreenState();
}

class _MyFlaresScreenState extends State<MyFlaresScreen> {
  bool _isRefreshing = false;
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
    // Simulate initial loading
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      final flareProvider = context.read<FlareProvider>();
      final flares = flareProvider.flares;
      final hasActiveFlare = flares.any(
        (f) => f.status?.toLowerCase() != 'resolved',
      );
      
      if (hasActiveFlare && mounted) {
        // Refresh the first active flare's status
        final activeFlare = flares.firstWhere(
          (f) => f.status?.toLowerCase() != 'resolved',
        );
        flareProvider.refreshStatus(activeFlare.id);
      }
    });
  }

  Future<void> _refreshFlares() async {
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() => _isRefreshing = false);
      await HapticService.trigger(HapticIntensity.light, context: context);
    }
    _startAutoRefresh();
  }

  Future<void> _cancelFlare(String flareId) async {
    await HapticService.trigger(HapticIntensity.heavy, context: context);
    await _refreshFlares();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Flare cancelled'),
          backgroundColor: M3Colors.success,
        ),
      );
    }
  }

  void _showFlareDetails(dynamic flare) {
    HapticService.trigger(HapticIntensity.light, context: context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PhysicsSheet(
        child: FlareDetailSheet(
          flare: flare,
          onRefresh: _refreshFlares,
        ),
        minChildSize: 0.45,
        maxChildSize: 0.75,
        initialChildSize: 0.5,
      ),
    );
  }

  void _sendNewFlare() {
    HapticService.trigger(HapticIntensity.medium, context: context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tap the red SIGNAL FLARE button'),
        backgroundColor: M3Colors.primary,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final motionPrefs = Provider.of<MotionPreferences>(context);
    final reduceMotion = motionPrefs.disableAnimations;
    
    return Scaffold(
      backgroundColor: M3Colors.background,
      appBar: AppBar(
        title: const Text('My Flares'),
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
            onPressed: _isRefreshing ? null : () {
              HapticService.trigger(HapticIntensity.light, context: context);
              _refreshFlares();
            },
          ),
        ],
      ),
      body: Consumer<FlareProvider>(
        builder: (context, flareProvider, _) {
          final flares = flareProvider.flares;
          final activeFlare = flares.isNotEmpty
              ? flares.firstWhere(
                  (f) => f.status?.toLowerCase() != 'resolved',
                  orElse: () => flares.first,
                )
              : null;
          final hasActiveFlare = activeFlare != null && activeFlare.status?.toLowerCase() != 'resolved';
          final historyFlares = flares.where(
            (f) => f.status?.toLowerCase() == 'resolved',
          ).toList();

          if (_isLoading) {
            return ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(16),
              itemCount: 3,
              itemBuilder: (context, index) => const FlareCardSkeleton(),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshFlares,
            child: CustomScrollView(
              slivers: [
                if (hasActiveFlare && activeFlare != null)
                  SliverToBoxAdapter(
                    child: ActiveFlareCard(
                      flare: activeFlare,
                      onCancel: () => _cancelFlare(activeFlare.id),
                      onRefresh: _refreshFlares,
                    ),
                  ),
                
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 12,
                          color: M3Colors.outline,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'End-to-end encrypted',
                          style: TextStyle(
                            fontSize: 10,
                            color: M3Colors.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                if (historyFlares.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          const Text(
                            'History',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: M3Colors.onSurface,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: M3Colors.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${historyFlares.length}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: M3Colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final flare = historyFlares[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: HistoryFlareCard(
                          flare: flare,
                          onTap: () => _showFlareDetails(flare),
                        ),
                      );
                    },
                    childCount: historyFlares.length,
                  ),
                ),
                
                if (flares.isEmpty)
                  SliverFillRemaining(
                    child: EmptyFlaresState(
                      onSendFlare: _sendNewFlare,
                    ),
                  ),
                
                const SliverToBoxAdapter(
                  child: SizedBox(height: 32),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}