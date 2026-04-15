import 'dart:async';
import 'package:flutter/material.dart';
import '../services/haptic_service.dart';

// Material Design 3 Color Scheme - Complete definition
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

/// Modern 2026 Marker - Stripe/Apple Grade
/// Tooltip appears on tap, auto-dismisses after 3 seconds
class ModernMarker extends StatefulWidget {
  final String name;
  final String address;
  final bool isNearby;
  final bool isNearest;
  final double? distanceKm;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool showTooltip;
  final VoidCallback? onTooltipAction;

  const ModernMarker({
    super.key,
    required this.name,
    required this.address,
    this.isNearby = false,
    this.isNearest = false,
    this.distanceKm,
    required this.onTap,
    this.onLongPress,
    this.showTooltip = false,
    this.onTooltipAction,
  });

  @override
  State<ModernMarker> createState() => _ModernMarkerState();
}

class _ModernMarkerState extends State<ModernMarker>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  bool _isPressed = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _showLocalTooltip = false;
  Timer? _tooltipTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isNearby || widget.isNearest) {
      _pulseController.repeat(reverse: true);
    }

    if (widget.showTooltip) {
      _showTooltip();
    }
  }

  void _showTooltip() {
    _tooltipTimer?.cancel();
    setState(() => _showLocalTooltip = true);
    _tooltipTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showLocalTooltip = false);
      }
    });
  }

  void _hideTooltip() {
    _tooltipTimer?.cancel();
    if (mounted) {
      setState(() => _showLocalTooltip = false);
    }
  }

  @override
  void didUpdateWidget(ModernMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isNearby != oldWidget.isNearby ||
        widget.isNearest != oldWidget.isNearest) {
      if (widget.isNearby || widget.isNearest) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
    
    if (widget.showTooltip != oldWidget.showTooltip) {
      if (widget.showTooltip) {
        _showTooltip();
      } else {
        _hideTooltip();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tooltipTimer?.cancel();
    super.dispose();
  }

  Color _getMarkerColor() {
    if (widget.isNearest) return const Color(0xFF7D5260);
    if (widget.isNearby) return const Color(0xFF00C853);
    return const Color(0xFF6750A4);
  }

  double _getMarkerSize() {
    if (widget.isNearest) return 56;
    if (widget.isNearby) return 48;
    return 44;
  }

  double _getIconSize() {
    if (widget.isNearest) return 28;
    if (widget.isNearby) return 24;
    return 20;
  }

  String _getDistanceText() {
    if (widget.distanceKm == null) return '';
    if (widget.distanceKm! < 1) {
      return '${(widget.distanceKm! * 1000).round()}m away';
    }
    return '${widget.distanceKm!.toStringAsFixed(1)}km away';
  }

  String _getWalkingTime() {
    if (widget.distanceKm == null) return '';
    int minutes = (widget.distanceKm! * 12).round();
    if (minutes < 1) return '<1 min';
    if (minutes == 1) return '1 min';
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final markerColor = _getMarkerColor();
    final markerSize = _getMarkerSize();
    final iconSize = _getIconSize();
    final shouldAnimate = widget.isNearby || widget.isNearest;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Tooltip (rendered above marker)
        if (_showLocalTooltip)
          Positioned(
            bottom: markerSize + 8,
            child: GestureDetector(
              onTap: () {
                HapticService.trigger(HapticIntensity.light, context: context);
                widget.onTooltipAction?.call();
              },
              child: Container(
                width: 220,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: M3Colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: markerColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Branch name
                    Text(
                      widget.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: M3Colors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Address
                    Text(
                      widget.address,
                      style: TextStyle(
                        fontSize: 11,
                        color: M3Colors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.distanceKm != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.directions_walk, size: 12, color: markerColor),
                          const SizedBox(width: 4),
                          Text(
                            '${_getDistanceText()} • ${_getWalkingTime()} walk',
                            style: TextStyle(
                              fontSize: 11,
                              color: markerColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              HapticService.trigger(HapticIntensity.medium, context: context);
                              widget.onTooltipAction?.call();
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              minimumSize: const Size(0, 32),
                            ),
                            child: const Text('VIEW', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              HapticService.trigger(HapticIntensity.medium, context: context);
                              widget.onTooltipAction?.call();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: markerColor,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              minimumSize: const Size(0, 32),
                            ),
                            child: const Text('DETAILS', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        
        // Main marker
        GestureDetector(
          onTapDown: (_) {
            setState(() => _isPressed = true);
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) setState(() => _isPressed = false);
            });
          },
          onTap: () {
            HapticService.trigger(HapticIntensity.light, context: context);
            widget.onTap();
          },
          onLongPress: widget.onLongPress != null
              ? () {
                  HapticService.trigger(HapticIntensity.medium, context: context);
                  widget.onLongPress!();
                }
              : null,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovering = true),
            onExit: (_) => setState(() => _isHovering = false),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: shouldAnimate && _pulseController.isAnimating
                      ? _pulseAnimation.value
                      : (_isPressed ? 0.95 : (_isHovering ? 1.05 : 1.0)),
                  child: Container(
                    width: markerSize,
                    height: markerSize,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          markerColor,
                          markerColor.withOpacity(0.85),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: markerColor.withOpacity(0.5),
                          blurRadius: _isHovering ? 20 : 12,
                          spreadRadius: _isHovering ? 4 : 2,
                          offset: Offset(0, _isHovering ? 4 : 2),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        widget.isNearest
                            ? Icons.star
                            : (widget.isNearby
                                ? Icons.bolt
                                : Icons.location_on),
                        size: iconSize,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Cluster Marker for multiple branches - 2026 modern style
class ModernClusterMarker extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const ModernClusterMarker({
    super.key,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticService.trigger(HapticIntensity.medium, context: context);
        onTap();
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                M3Colors.primary,
                M3Colors.tertiary,
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: M3Colors.primary.withOpacity(0.4),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.15),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
              Text(
                count > 99 ? '99+' : count.toString(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}