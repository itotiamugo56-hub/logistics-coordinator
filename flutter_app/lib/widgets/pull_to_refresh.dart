import 'package:flutter/material.dart';
import '../constants/motion_tokens.dart';
import '../services/haptic_service.dart';

class CustomPullToRefresh extends StatelessWidget {
  final RefreshCallback onRefresh;
  final Widget child;
  final Color? color;

  const CustomPullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await HapticService.trigger(HapticIntensity.light, context: context);
        await onRefresh();
      },
      color: color ?? MotionTokens.primary,
      backgroundColor: Colors.white,
      strokeWidth: 2,
      displacement: 40,
      child: child,
    );
  }
}