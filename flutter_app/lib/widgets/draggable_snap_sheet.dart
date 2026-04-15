import 'package:flutter/material.dart';
import '../constants/motion_tokens.dart';

class DraggableSnapSheet extends StatefulWidget {
  final Widget child;
  final double initialSnapPoint;
  final VoidCallback? onMinimize;
  final VoidCallback? onMaximize;
  final Color? backgroundColor;
  
  const DraggableSnapSheet({
    super.key,
    required this.child,
    this.initialSnapPoint = MotionTokens.sheetSnapMid,
    this.onMinimize,
    this.onMaximize,
    this.backgroundColor,
  });
  
  @override
  State<DraggableSnapSheet> createState() => _DraggableSnapSheetState();
}

class _DraggableSnapSheetState extends State<DraggableSnapSheet> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragStartOffset = 0;
  double _currentSnapPoint = 0;
  
  final List<double> _snapPoints = [
    MotionTokens.sheetSnapMin,
    MotionTokens.sheetSnapMid,
    MotionTokens.sheetSnapMax,
  ];
  
  @override
  void initState() {
    super.initState();
    _currentSnapPoint = widget.initialSnapPoint;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: MotionTokens.durationMedium),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  double _getSheetHeight(Size screenSize) {
    return screenSize.height * _currentSnapPoint;
  }
  
  void _animateToSnapPoint(double targetPoint, {double? velocity}) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    
    if (reduceMotion) {
      setState(() => _currentSnapPoint = targetPoint);
      _notifySnapChange(targetPoint);
      return;
    }
    
    _controller.stop();
    _controller.reset();
    
    setState(() => _currentSnapPoint = targetPoint);
    _controller.forward().then((_) => _notifySnapChange(targetPoint));
  }
  
  void _notifySnapChange(double point) {
    if (point == MotionTokens.sheetSnapMin) {
      widget.onMinimize?.call();
    } else if (point == MotionTokens.sheetSnapMax) {
      widget.onMaximize?.call();
    }
  }
  
  double _calculateNearestSnapPoint(double currentHeight, Size screenSize) {
    final currentFraction = currentHeight / screenSize.height;
    double nearest = _snapPoints.reduce(
      (a, b) => (a - currentFraction).abs() < (b - currentFraction).abs() ? a : b
    );
    return nearest;
  }
  
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onVerticalDragStart: (details) {
          _dragStartOffset = details.globalPosition.dy;
        },
        onVerticalDragUpdate: (details) {
          final delta = details.globalPosition.dy - _dragStartOffset;
          final newHeight = (_getSheetHeight(screenSize) - delta).clamp(
            screenSize.height * MotionTokens.sheetSnapMin,
            screenSize.height * MotionTokens.sheetSnapMax,
          );
          setState(() => _currentSnapPoint = newHeight / screenSize.height);
          _dragStartOffset = details.globalPosition.dy;
        },
        onVerticalDragEnd: (details) {
          final nearest = _calculateNearestSnapPoint(_getSheetHeight(screenSize), screenSize);
          _animateToSnapPoint(nearest, velocity: details.primaryVelocity);
        },
        child: Container(
          height: _getSheetHeight(screenSize),
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? MotionTokens.background,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            boxShadow: MotionTokens.shadowLg,
          ),
          child: Column(
            children: [
              _buildDragHandle(),
              Expanded(child: widget.child),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: MotionTokens.spacingSM),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}