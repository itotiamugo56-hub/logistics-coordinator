import 'package:flutter/material.dart';

class MotionTokens {
  // Color tokens
  static const Color primary = Color(0xFF0055FF);
  static const Color success = Color(0xFF00C853);
  static const Color error = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFFF9800);
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF5F5F5);
  static const Color overlay = Color(0x80000000);
  
  // Spacing scale
  static const List<double> spacingScale = [0, 4, 8, 12, 16, 20, 24, 32, 40, 48];
  static const double spacingXS = 4;
  static const double spacingSM = 8;
  static const double spacingMD = 12;
  static const double spacingLG = 16;
  static const double spacingXL = 20;
  static const double spacingXXL = 24;
  static const double spacingXXXL = 32;
  
  // Sheet snap points (as fractions of screen height)
  static const double sheetSnapMin = 0.3;
  static const double sheetSnapMid = 0.6;
  static const double sheetSnapMax = 0.95;
  
  // Typography
  static const String fontFamily = 'system-ui, -apple-system, sans-serif';
  static const List<double> fontSizeScale = [12, 14, 16, 18, 20, 24, 30, 36];
  static const FontWeight fontWeightRegular = FontWeight.w400;
  static const FontWeight fontWeightMedium = FontWeight.w500;
  static const FontWeight fontWeightSemiBold = FontWeight.w600;
  static const FontWeight fontWeightBold = FontWeight.w700;
  
  // Motion durations (ms)
  static const int durationInstant = 0;
  static const int durationFast = 150;
  static const int durationMedium = 250;
  static const int durationSlow = 400;
  
  // Motion easing curves
  static const Curve easingStandard = Curves.easeInOutCubic;
  static const Curve easingAccelerate = Curves.easeInCubic;
  static const Curve easingDecelerate = Curves.easeOutCubic;
  
  // Spring configurations
  static const SpringDescription springConfirm = SpringDescription(
    mass: 1.0,
    stiffness: 500.0,
    damping: 30.0,
  );
  
  static const SpringDescription springDelete = SpringDescription(
    mass: 1.0,
    stiffness: 300.0,
    damping: 25.0,
  );
  
  static const SpringDescription springError = SpringDescription(
    mass: 1.0,
    stiffness: 200.0,
    damping: 20.0,
  );
  
  static const SpringDescription springSheet = SpringDescription(
    mass: 1.0,
    stiffness: 400.0,
    damping: 35.0,
  );
  
  // Shadows
  static List<BoxShadow> shadowSm = const [
    BoxShadow(offset: Offset(0, 1), blurRadius: 2, color: Color(0x0D000000))
  ];
  
  static List<BoxShadow> shadowMd = const [
    BoxShadow(offset: Offset(0, 4), blurRadius: 8, color: Color(0x1A000000))
  ];
  
  static List<BoxShadow> shadowLg = const [
    BoxShadow(offset: Offset(0, 8), blurRadius: 16, color: Color(0x26000000))
  ];
}
