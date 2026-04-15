import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';

/// Velocity-matched draggable sheet with physics-based snapping
/// 
/// Features:
/// - Tracks pan velocity for natural fling gestures
/// - Snaps to logical positions based on velocity and content height
/// - Spring animations for smooth transitions
/// - Haptic feedback on snap completion
/// - Preserves context with non-modal behavior
class PhysicsSheet extends StatefulWidget {
  final Widget child;
  final double minChildSize;
  final double maxChildSize;
  final double initialChildSize;
  final VoidCallback? onExpanded;
  final VoidCallback? onCollapsed;
  final bool isCritical; // Higher friction for destructive actions
  
  const PhysicsSheet({
    super.key,
    required this.child,
    this.minChildSize = 0.3,
    this.maxChildSize = 0.95,
    this.initialChildSize = 0.5,
    this.onExpanded,
    this.onCollapsed,
    this.isCritical = false,
  });

  @override
  State<PhysicsSheet> createState() => _PhysicsSheetState();
}

class _PhysicsSheetState extends State<PhysicsSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  double _dragStartSize = 0.0;
  double _dragStartOffset = 0.0;
  double _currentSize = 0.0;
  double _velocity = 0.0;
  DateTime? _lastDragTime;
  double _lastDragDelta = 0.0;
  
  static const double _snapThreshold = 0.02; // 2% threshold
  static const double _flingVelocityThreshold = 800.0; // pixels/sec
  
  // Snap points based on content height
  late List<double> _snapPoints;
  
  // Friction based on criticality (higher friction = slower, harder to dismiss)
  double get _friction => widget.isCritical ? 0.92 : 0.96;
  
  @override
  void initState() {
    super.initState();
    _currentSize = widget.initialChildSize;
    _snapPoints = [widget.minChildSize, 0.5, widget.maxChildSize];
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _animation = Tween<double>(
      begin: widget.initialChildSize,
      end: widget.initialChildSize,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    
    _animation.addListener(_onAnimationTick);
  }
  
  void _onAnimationTick() {
    setState(() {
      _currentSize = _animation.value;
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  void _animateToSize(double targetSize, {double velocity = 0.0}) {
    if (_controller.isAnimating) return;
    
    // Clamp target
    targetSize = targetSize.clamp(widget.minChildSize, widget.maxChildSize);
    
    // Find nearest snap point
    final nearestSnap = _findNearestSnapPoint(targetSize);
    
    // Calculate duration based on velocity and distance
    final distance = (nearestSnap - _currentSize).abs();
    var duration = Duration(milliseconds: (distance * 400).toInt().clamp(100, 500));
    
    // If velocity is significant, use spring physics
    if (velocity.abs() > _flingVelocityThreshold) {
      duration = const Duration(milliseconds: 200);
      _animateWithSpring(nearestSnap, velocity);
      return;
    }
    
    _controller.duration = duration;
    _animation = Tween<double>(begin: _currentSize, end: nearestSnap).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _animation.addListener(_onAnimationTick);
    _controller.forward(from: 0.0);
    
    _onSnapComplete(nearestSnap);
  }
  
  void _animateWithSpring(double target, double velocity) {
    // Spring simulation
    const stiffness = 500.0;
    const damping = 30.0;
    
    double value = _currentSize;
    double vel = velocity / 1000; // Normalize velocity
    
    void update(double deltaTime) {
      const dt = 0.016; // ~60fps
      final force = -stiffness * (value - target) - damping * vel;
      vel += force * dt;
      value += vel * dt;
      
      // Clamp and stop when settled
      if ((value - target).abs() < _snapThreshold && vel.abs() < 10) {
        setState(() => _currentSize = target.clamp(widget.minChildSize, widget.maxChildSize));
        _onSnapComplete(target);
        return;
      }
      
      setState(() => _currentSize = value.clamp(widget.minChildSize, widget.maxChildSize));
      Future.delayed(const Duration(milliseconds: 16), () => update(dt));
    }
    
    update(0.016);
  }
  
  double _findNearestSnapPoint(double size) {
    return _snapPoints.reduce((a, b) => (a - size).abs() < (b - size).abs() ? a : b);
  }
  
  void _onSnapComplete(double size) {
    // Haptic feedback on snap
    if (size == widget.maxChildSize) {
      _lightHaptic();
      widget.onExpanded?.call();
    } else if (size == widget.minChildSize) {
      _lightHaptic();
      widget.onCollapsed?.call();
    }
    
    // Semantic motion: duration signals operation weight
    // Expanded = fast, Collapsed = moderate
  }
  
  void _lightHaptic() {
    if (widget.isCritical) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }
  
  void _handleDragStart(DragStartDetails details) {
    _dragStartSize = _currentSize;
    _dragStartOffset = details.globalPosition.dy;
    _velocity = 0.0;
    _lastDragTime = DateTime.now();
    _lastDragDelta = 0.0;
    if (_controller.isAnimating) {
      _controller.stop();
    }
  }
  
  void _handleDragUpdate(DragUpdateDetails details) {
    final delta = details.globalPosition.dy - _dragStartOffset;
    final screenHeight = MediaQuery.of(context).size.height;
    final deltaFraction = delta / screenHeight;
    
    // Apply friction based on criticality
    var newSize = _dragStartSize + deltaFraction * _friction;
    newSize = newSize.clamp(widget.minChildSize, widget.maxChildSize);
    
    setState(() => _currentSize = newSize);
    
    // Track velocity for fling
    final now = DateTime.now();
    if (_lastDragTime != null) {
      final deltaTime = now.difference(_lastDragTime!).inMilliseconds;
      if (deltaTime > 0) {
        _velocity = details.primaryDelta!.abs() / deltaTime * 1000;
      }
    }
    _lastDragTime = now;
    _lastDragDelta = details.primaryDelta ?? 0.0;
  }
  
  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? _velocity;
    
    // Determine target based on velocity and current position
    double targetSize;
    
    if (velocity.abs() > _flingVelocityThreshold) {
      // Fling gesture
      if (velocity > 0) {
        targetSize = widget.minChildSize; // Fling down = collapse
      } else {
        targetSize = widget.maxChildSize; // Fling up = expand
      }
    } else {
      // No fling, snap to nearest logical position
      targetSize = _findNearestSnapPoint(_currentSize);
    }
    
    _animateToSize(targetSize, velocity: velocity);
    _lastDragTime = null;
  }
  
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = screenHeight * _currentSize;
    
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onVerticalDragStart: _handleDragStart,
        onVerticalDragUpdate: _handleDragUpdate,
        onVerticalDragEnd: _handleDragEnd,
        child: AnimatedContainer(
          duration: _controller.isAnimating 
              ? const Duration(milliseconds: 16) 
              : Duration.zero,
          height: sheetHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Content
              Expanded(child: widget.child),
            ],
          ),
        ),
      ),
    );
  }
}