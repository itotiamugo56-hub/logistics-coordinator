import 'package:flutter/material.dart';
import '../constants/motion_tokens.dart';
import '../services/haptic_service.dart';

enum ToastType { success, error, warning, info }

class ToastMessage {
  static OverlayEntry? _currentOverlay;

  static void show({
    required BuildContext context,
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 2),
  }) {
    _currentOverlay?.remove();

    final overlay = Overlay.of(context);
    
    // Create the entry first without referencing itself
    late OverlayEntry entry;
    
    entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        type: type,
        onDismiss: () {
          entry.remove();
          if (_currentOverlay == entry) _currentOverlay = null;
        },
      ),
    );

    _currentOverlay = entry;
    overlay.insert(entry);

    Future.delayed(duration, () {
      if (entry.mounted) {
        entry.remove();
        if (_currentOverlay == entry) _currentOverlay = null;
      }
    });

    // Haptic feedback based on type
    switch (type) {
      case ToastType.success:
        HapticService.trigger(HapticIntensity.light);
        break;
      case ToastType.error:
        HapticService.trigger(HapticIntensity.error);
        break;
      case ToastType.warning:
        HapticService.trigger(HapticIntensity.medium);
        break;
      case ToastType.info:
        HapticService.trigger(HapticIntensity.light);
        break;
    }
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: MotionTokens.durationFast),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getColor() {
    switch (widget.type) {
      case ToastType.success:
        return MotionTokens.success;
      case ToastType.error:
        return MotionTokens.error;
      case ToastType.warning:
        return MotionTokens.warning;
      case ToastType.info:
        return MotionTokens.primary;
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case ToastType.success:
        return Icons.check_circle;
      case ToastType.error:
        return Icons.error;
      case ToastType.warning:
        return Icons.warning;
      case ToastType.info:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: MotionTokens.spacingLG,
      right: MotionTokens.spacingLG,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: MotionTokens.spacingLG,
                vertical: MotionTokens.spacingMD,
              ),
              decoration: BoxDecoration(
                color: _getColor(),
                borderRadius: BorderRadius.circular(MotionTokens.spacingSM),
                boxShadow: MotionTokens.shadowMd,
              ),
              child: Row(
                children: [
                  Icon(_getIcon(), color: Colors.white, size: 20),
                  const SizedBox(width: MotionTokens.spacingMD),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _controller.reverse().then((_) => widget.onDismiss());
                    },
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}