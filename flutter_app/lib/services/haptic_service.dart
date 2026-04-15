import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

enum HapticIntensity { light, medium, heavy, error }

class HapticService {
  static final MethodChannel _channel = const MethodChannel('flutter/haptic');
  
  static Future<void> init() async {
    // No initialization needed for native haptics
  }
  
  static Future<void> trigger(HapticIntensity intensity, {BuildContext? context}) async {
    // Check for motion reduction
    if (context != null && MediaQuery.of(context).disableAnimations) {
      return;
    }
    
    switch (intensity) {
      case HapticIntensity.light:
        // Light impact (selection feedback)
        await HapticFeedback.lightImpact();
        break;
        
      case HapticIntensity.medium:
        // Medium impact (button press)
        await HapticFeedback.mediumImpact();
        break;
        
      case HapticIntensity.heavy:
        // Heavy impact (delete confirmation)
        await HapticFeedback.heavyImpact();
        break;
        
      case HapticIntensity.error:
        // Error feedback (buzz pattern)
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 50));
        await HapticFeedback.heavyImpact();
        break;
    }
  }
}
