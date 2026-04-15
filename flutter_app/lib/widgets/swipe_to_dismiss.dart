import 'package:flutter/material.dart';
import '../constants/motion_tokens.dart';
import '../services/haptic_service.dart';

class SwipeToDismissWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback onDismissed;
  final String? confirmTitle;
  final bool requireConfirmation;

  const SwipeToDismissWrapper({
    super.key,
    required this.child,
    required this.onDismissed,
    this.confirmTitle,
    this.requireConfirmation = true,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.endToStart,
      confirmDismiss: requireConfirmation ? (direction) async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(confirmTitle ?? 'Delete Item'),
            content: const Text('Are you sure you want to delete this?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  HapticService.trigger(HapticIntensity.heavy, context: context);
                  Navigator.pop(context, true);
                },
                style: TextButton.styleFrom(foregroundColor: MotionTokens.error),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        return confirm ?? false;
      } : null,
      background: Container(
        color: MotionTokens.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: MotionTokens.spacingLG),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        HapticService.trigger(HapticIntensity.heavy);
        onDismissed();
      },
      child: child,
    );
  }
}