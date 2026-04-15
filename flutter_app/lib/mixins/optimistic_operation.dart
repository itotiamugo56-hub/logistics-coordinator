import 'package:flutter/material.dart';
import '../constants/motion_tokens.dart';

mixin OptimisticOperation<T> {
  final List<T> items = [];
  final Map<String, T> _optimisticItems = {};
  final Map<String, VoidCallback> _rollbackCallbacks = {};
  
  @protected
  void addOptimistic(String tempId, T item, Future<void> Function() apiCall, {
    required void Function(T) onSuccess,
    required void Function(String) onError,
  }) async {
    // Add optimistic item
    items.insert(0, item);
    _optimisticItems[tempId] = item;
    
    // Trigger UI update
    notifyListeners();
    
    try {
      await apiCall();
      onSuccess(item);
      _optimisticItems.remove(tempId);
    } catch (e) {
      // Rollback with animation
      await _rollbackWithAnimation(tempId);
      onError(e.toString());
    }
  }
  
  @protected
  Future<void> deleteOptimistic(String id, T item, Future<void> Function() apiCall, {
    required void Function() onSuccess,
    required void Function(String) onError,
  }) async {
    // Remove optimistic item
    final index = items.indexWhere((i) => _getId(i) == id);
    if (index != -1) {
      items.removeAt(index);
      notifyListeners();
    }
    
    try {
      await apiCall();
      onSuccess();
    } catch (e) {
      // Rollback with animation
      await _rollbackWithInsertion(item, index);
      onError(e.toString());
    }
  }
  
  Future<void> _rollbackWithAnimation(String tempId) async {
    // Elastic bounce animation on rollback
    await Future.delayed(const Duration(milliseconds: MotionTokens.durationFast));
    final item = _optimisticItems[tempId];
    if (item != null) {
      items.remove(item);
      _optimisticItems.remove(tempId);
      notifyListeners();
    }
  }
  
  Future<void> _rollbackWithInsertion(T item, int index) async {
    await Future.delayed(const Duration(milliseconds: MotionTokens.durationFast));
    items.insert(index, item);
    notifyListeners();
  }
  
  String _getId(T item);
  void notifyListeners();
}
