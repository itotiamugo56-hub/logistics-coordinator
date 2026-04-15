import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/branch.dart';
import '../mixins/optimistic_operation.dart';
import '../services/haptic_service.dart';
import '../widgets/inline_feedback.dart';
import '../widgets/crystal_button.dart';
import '../widgets/physics_sheet.dart';

class ServiceTimesEditor extends StatefulWidget {
  final Branch branch;
  final VoidCallback onSaved;
  
  const ServiceTimesEditor({super.key, required this.branch, required this.onSaved});

  @override
  State<ServiceTimesEditor> createState() => _ServiceTimesEditorState();
}

class _ServiceTimesEditorState extends State<ServiceTimesEditor> with OptimisticOperation<Map<String, dynamic>> {
  late Map<String, List<String>> _serviceTimes;
  final List<String> _days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  
  final List<String> _timeSlots = [
    '6:00 AM', '6:30 AM', '7:00 AM', '7:30 AM', '8:00 AM', '8:30 AM', '9:00 AM', '9:30 AM',
    '10:00 AM', '10:30 AM', '11:00 AM', '11:30 AM', '12:00 PM', '12:30 PM',
    '1:00 PM', '1:30 PM', '2:00 PM', '2:30 PM', '3:00 PM', '3:30 PM', '4:00 PM', '4:30 PM',
    '5:00 PM', '5:30 PM', '6:00 PM', '6:30 PM', '7:00 PM', '7:30 PM', '8:00 PM', '8:30 PM', '9:00 PM'
  ];
  
  bool _isSaving = false;
  OverlayEntry? _feedbackOverlay;
  
  final Uuid _uuid = const Uuid();
  
  @override
  List<Map<String, dynamic>> get items => [];
  
  @override
  void notifyListeners() {
    if (mounted) {
      setState(() {});
    }
  }
  
  @override
  String _getId(Map<String, dynamic> item) {
    return item['id'].toString();
  }
  
  @override
  void initState() {
    super.initState();
    // Create a fresh copy of service times
    _serviceTimes = {};
    widget.branch.serviceTimes.forEach((day, times) {
      _serviceTimes[day] = List<String>.from(times);
    });
  }
  
  @override
  void dispose() {
    _removeFeedbackOverlay();
    super.dispose();
  }
  
  void _showFeedback(String message, FeedbackType type, {VoidCallback? onRetry}) {
    _removeFeedbackOverlay();
    
    final overlay = Overlay.of(context);
    _feedbackOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 0,
        right: 0,
        child: InlineFeedback(
          message: message,
          type: type,
          onRetry: onRetry,
          autoDismissDuration: const Duration(seconds: 3),
          onDismiss: () => _removeFeedbackOverlay(),
        ),
      ),
    );
    
    overlay.insert(_feedbackOverlay!);
  }
  
  void _removeFeedbackOverlay() {
    _feedbackOverlay?.remove();
    _feedbackOverlay = null;
  }
  
  void _addTimeSlot(String day) {
    HapticService.trigger(HapticIntensity.light, context: context);
    setState(() {
      if (!_serviceTimes.containsKey(day)) {
        _serviceTimes[day] = [];
      }
      _serviceTimes[day]!.add('9:00 AM');
    });
  }
  
  void _removeTimeSlot(String day, int index) {
    HapticService.trigger(HapticIntensity.medium, context: context);
    setState(() {
      _serviceTimes[day]!.removeAt(index);
      if (_serviceTimes[day]!.isEmpty) {
        _serviceTimes.remove(day);
      }
    });
  }
  
  void _updateTimeSlot(String day, int index, String? newTime) {
    if (newTime != null) {
      HapticService.trigger(HapticIntensity.light, context: context);
      setState(() {
        _serviceTimes[day]![index] = newTime;
      });
    }
  }
  
  Future<void> _saveServiceTimes() async {
    // Light haptic for starting save
    await HapticService.trigger(HapticIntensity.light, context: context);
    
    // Clean up empty days
    final cleanedTimes = <String, List<String>>{};
    _serviceTimes.forEach((day, times) {
      if (times.isNotEmpty) {
        cleanedTimes[day] = times;
      }
    });
    
    setState(() => _isSaving = true);
    
    final tempId = _uuid.v4();
    final tempData = {
      'id': tempId,
      'service_times': cleanedTimes,
      '_optimistic': true,
    };
    
    addOptimistic(
      tempId,
      tempData,
      () => _performSave(cleanedTimes),
      onSuccess: (item) {
        setState(() => _isSaving = false);
        widget.onSaved();
        HapticService.trigger(HapticIntensity.light, context: context);
        _showFeedback('Service times updated successfully', FeedbackType.success);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.pop(context);
        });
      },
      onError: (error) {
        setState(() => _isSaving = false);
        HapticService.trigger(HapticIntensity.error, context: context);
        _showFeedback('Failed to save service times. Tap RETRY to try again.', FeedbackType.error, onRetry: () => _saveServiceTimes());
      },
    );
  }
  
  Future<void> _performSave(Map<String, List<String>> cleanedTimes) async {
    final response = await http.put(
      Uri.parse('http://127.0.0.1:8080/v1/clergy/branch/${widget.branch.id}/service-times'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'service_times': cleanedTimes}),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to save service times');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Edit Service Times',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ..._days.map((day) {
                final times = _serviceTimes[day] ?? [];
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                day,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: Colors.green),
                                onPressed: () => _addTimeSlot(day),
                                tooltip: 'Add time',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...times.asMap().entries.map((entry) {
                            final index = entry.key;
                            final time = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: time,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      items: _timeSlots.map((slot) {
                                        return DropdownMenuItem<String>(
                                          value: slot,
                                          child: Text(slot),
                                        );
                                      }).toList(),
                                      onChanged: (newTime) => _updateTimeSlot(day, index, newTime),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _removeTimeSlot(day, index),
                                  ),
                                ],
                              ),
                            );
                          }),
                          if (times.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                'No services. Tap + to add.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
              CrystalButton(
                onPressed: _isSaving ? null : _saveServiceTimes,
                label: 'SAVE SERVICE TIMES',
                variant: CrystalButtonVariant.filled,
                isLoading: _isSaving,
                isExpanded: true,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
    
    return PhysicsSheet(
      child: content,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      initialChildSize: 0.85,
      onExpanded: () {
        HapticService.trigger(HapticIntensity.light, context: context);
      },
      onCollapsed: () {
        HapticService.trigger(HapticIntensity.light, context: context);
      },
      isCritical: false,
    );
  }
}

// Extension for HapticIntensity.success since it doesn't exist
extension HapticIntensityExtension on HapticIntensity {
  static Future<void> get success async {
    await HapticService.trigger(HapticIntensity.light, context: null);
  }
}