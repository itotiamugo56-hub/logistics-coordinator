import 'package:flutter/material.dart';
import '../constants/motion_tokens.dart';
import '../services/haptic_service.dart';

enum FeedbackType { success, error, warning, info }

class InlineFeedback extends StatefulWidget {
  final String message;
  final FeedbackType type;
  final VoidCallback? onRetry;
  final Duration? autoDismissDuration;
  final VoidCallback? onDismiss;
  
  const InlineFeedback({
    super.key,
    required this.message,
    required this.type,
    this.onRetry,
    this.autoDismissDuration,
    this.onDismiss,
  });
  
  @override
  State<InlineFeedback> createState() => _InlineFeedbackState();
}

class _InlineFeedbackState extends State<InlineFeedback> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    
    _controller = AnimationController(
      duration: Duration(milliseconds: reduceMotion ? 0 : MotionTokens.durationFast),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: MotionTokens.easingStandard),
    );
    
    _controller.forward();
    
    if (widget.autoDismissDuration != null) {
      Future.delayed(widget.autoDismissDuration!, () {
        if (mounted) _dismiss();
      });
    }
    
    // Trigger haptic for error/warning
    if (widget.type == FeedbackType.error) {
      HapticService.trigger(HapticIntensity.error, context: context);
    } else if (widget.type == FeedbackType.warning) {
      HapticService.trigger(HapticIntensity.medium, context: context);
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  void _dismiss() {
    _controller.reverse().then((_) {
      if (mounted && widget.onDismiss != null) {
        widget.onDismiss!();
      }
    });
  }
  
  Color _getBackgroundColor() {
    switch (widget.type) {
      case FeedbackType.success:
        return MotionTokens.success;
      case FeedbackType.error:
        return MotionTokens.error;
      case FeedbackType.warning:
        return MotionTokens.warning;
      case FeedbackType.info:
        return MotionTokens.primary;
    }
  }
  
  IconData _getIcon() {
    switch (widget.type) {
      case FeedbackType.success:
        return Icons.check_circle_outline;
      case FeedbackType.error:
        return Icons.error_outline;
      case FeedbackType.warning:
        return Icons.warning_amber_outlined;
      case FeedbackType.info:
        return Icons.info_outline;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            elevation: 2,
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(
                horizontal: MotionTokens.spacingLG,
                vertical: MotionTokens.spacingSM,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: MotionTokens.spacingLG,
                vertical: MotionTokens.spacingMD,
              ),
              decoration: BoxDecoration(
                color: _getBackgroundColor(),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (widget.onRetry != null)
                    TextButton(
                      onPressed: () {
                        _dismiss();
                        widget.onRetry!();
                      },
                      child: const Text(
                        'RETRY',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: _dismiss,
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}