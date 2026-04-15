import 'package:flutter/material.dart';
import '../constants/motion_tokens.dart';
import '../services/haptic_service.dart';

class AnimatedListView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext, T, int, Animation<double>) itemBuilder;
  final VoidCallback? onItemInserted;
  final VoidCallback? onItemRemoved;

  const AnimatedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.onItemInserted,
    this.onItemRemoved,
  });

  @override
  State<AnimatedListView<T>> createState() => _AnimatedListViewState<T>();
}

class _AnimatedListViewState<T> extends State<AnimatedListView<T>> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();
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

  void insertItem(int index, T item) {
    _listKey.currentState?.insertItem(index);
    HapticService.trigger(HapticIntensity.light);
    widget.onItemInserted?.call();
  }

  void removeItem(int index) {
    final removedItem = widget.items[index];
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => widget.itemBuilder(context, removedItem, index, animation),
    );
    HapticService.trigger(HapticIntensity.medium);
    widget.onItemRemoved?.call();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedList(
      key: _listKey,
      initialItemCount: widget.items.length,
      itemBuilder: (context, index, animation) {
        return widget.itemBuilder(context, widget.items[index], index, animation);
      },
    );
  }
}