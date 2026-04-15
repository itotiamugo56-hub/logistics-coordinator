import 'package:flutter/material.dart';
import '../constants/motion_tokens.dart';
import '../services/haptic_service.dart';

enum CrystalButtonVariant { filled, outlined, text }

class CrystalButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final CrystalButtonVariant variant;
  final bool isLoading;
  final bool isExpanded;
  final IconData? icon;
  
  const CrystalButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = CrystalButtonVariant.filled,
    this.isLoading = false,
    this.isExpanded = false,
    this.icon,
  });
  
  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    
    Color getBackgroundColor() {
      if (!isEnabled) return Colors.grey.withOpacity(0.4);
      switch (variant) {
        case CrystalButtonVariant.filled:
          return MotionTokens.primary;
        case CrystalButtonVariant.outlined:
        case CrystalButtonVariant.text:
          return Colors.transparent;
      }
    }
    
    Color getForegroundColor() {
      if (!isEnabled) return Colors.grey;
      switch (variant) {
        case CrystalButtonVariant.filled:
          return Colors.white;
        case CrystalButtonVariant.outlined:
        case CrystalButtonVariant.text:
          return MotionTokens.primary;
      }
    }
    
    BorderSide getBorderSide() {
      if (variant == CrystalButtonVariant.outlined && isEnabled) {
        return BorderSide(color: MotionTokens.primary, width: 1.5);
      }
      return BorderSide.none;
    }
    
    Widget buttonChild = Row(
      mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null && !isLoading) ...[
          Icon(icon, size: 18),
          const SizedBox(width: MotionTokens.spacingSM),
        ],
        if (isLoading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(getForegroundColor()),
            ),
          )
        else
          Text(
            label,
            style: TextStyle(
              fontSize: MotionTokens.fontSizeScale[2],
              fontWeight: MotionTokens.fontWeightSemiBold,
              color: getForegroundColor(),
            ),
          ),
      ],
    );
    
    Widget button = GestureDetector(
      onTapDown: isEnabled && !reduceMotion ? (_) {
        // Scale down animation on press
      } : null,
      child: AnimatedContainer(
        duration: Duration(milliseconds: reduceMotion ? 0 : MotionTokens.durationFast),
        curve: MotionTokens.easingStandard,
        padding: const EdgeInsets.symmetric(
          horizontal: MotionTokens.spacingLG,
          vertical: MotionTokens.spacingMD,
        ),
        decoration: BoxDecoration(
          color: getBackgroundColor(),
          borderRadius: BorderRadius.circular(MotionTokens.spacingSM),
          border: getBorderSide(),
          boxShadow: variant == CrystalButtonVariant.filled && isEnabled
              ? MotionTokens.shadowSm
              : null,
        ),
        child: buttonChild,
      ),
    );
    
    return AnimatedScale(
      scale: 1.0,
      duration: Duration(milliseconds: reduceMotion ? 0 : MotionTokens.durationFast),
      curve: MotionTokens.easingStandard,
      child: isExpanded ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
  
  Future<void> _handlePress(BuildContext context) async {
    if (onPressed == null || isLoading) return;
    
    // Trigger haptic based on variant
    final hapticIntensity = variant == CrystalButtonVariant.text 
        ? HapticIntensity.heavy 
        : (variant == CrystalButtonVariant.outlined 
            ? HapticIntensity.light 
            : HapticIntensity.medium);
    
    await HapticService.trigger(hapticIntensity, context: context);
    onPressed!();
  }
}
