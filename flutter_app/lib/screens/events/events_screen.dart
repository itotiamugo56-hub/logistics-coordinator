import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../constants/motion_tokens.dart';
import '../../widgets/crystal_button.dart';
import '../../widgets/inline_feedback.dart';
import '../../widgets/draggable_snap_sheet.dart';
import '../../services/haptic_service.dart';
import 'event_form_sheet.dart';

class Event {
  final String id;
  final String name;
  final DateTime eventDate;
  final String? description;
  final double? latitude;
  final double? longitude;
  final bool isActive;
  
  Event({
    required this.id,
    required this.name,
    required this.eventDate,
    this.description,
    this.latitude,
    this.longitude,
    this.isActive = true,
  });
  
  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'],
      name: json['name'],
      eventDate: DateTime.fromMillisecondsSinceEpoch(json['event_date'] * 1000),
      description: json['description'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      isActive: json['is_active'] ?? true,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'event_date': eventDate.millisecondsSinceEpoch ~/ 1000,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});
  
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> with SingleTickerProviderStateMixin {
  List<Event> _events = [];
  bool _isLoading = true;
  String? _feedbackMessage;
  FeedbackType? _feedbackType;
  bool _showFormSheet = false;
  String? _branchId;
  
  late AnimationController _refreshController;
  
  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: MotionTokens.durationMedium),
    );
    _loadBranchId();
    _loadEvents();
    HapticService.init();
  }
  
  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }
  
  Future<void> _loadBranchId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _branchId = prefs.getString('branch_id'));
  }
  
  Future<void> _loadEvents() async {
    if (_branchId == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8080/v1/clergy/events/$_branchId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _events = data.map((json) => Event.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load events');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _showFeedback('Failed to load events. Pull down to retry.', FeedbackType.error);
      });
    }
  }
  
  Future<void> _createEvent(Event event) async {
    final tempId = const Uuid().v4();
    final tempEvent = Event(
      id: tempId,
      name: event.name,
      eventDate: event.eventDate,
      description: event.description,
      latitude: event.latitude,
      longitude: event.longitude,
    );
    
    // Optimistic insert
    setState(() {
      _events.insert(0, tempEvent);
      _showFormSheet = false;
      _showFeedback('Adding event...', FeedbackType.info, autoDismiss: true);
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8080/v1/clergy/events/$_branchId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(event.toJson()),
      );
      
      if (response.statusCode == 201) {
        await _loadEvents(); // Refresh to get real ID
        await HapticService.trigger(HapticIntensity.medium, context: context);
        _showFeedback('Event added successfully!', FeedbackType.success, autoDismiss: true);
      } else {
        throw Exception('Failed to create event');
      }
    } catch (e) {
      // Rollback with elastic animation
      setState(() {
        _events.removeWhere((e) => e.id == tempId);
        _showFeedback('Failed to add event. Please try again.', FeedbackType.error);
      });
      await HapticService.trigger(HapticIntensity.error, context: context);
    }
  }
  
  Future<void> _deleteEvent(Event event) async {
    // Optimistic delete
    setState(() {
      _events.removeWhere((e) => e.id == event.id);
      _showFeedback('Deleting event...', FeedbackType.info, autoDismiss: true);
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      final response = await http.delete(
        Uri.parse('http://127.0.0.1:8080/v1/clergy/events/$_branchId/${event.id}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (response.statusCode == 200) {
        await HapticService.trigger(HapticIntensity.heavy, context: context);
        _showFeedback('Event deleted', FeedbackType.success, autoDismiss: true);
      } else {
        throw Exception('Failed to delete event');
      }
    } catch (e) {
      // Rollback with animation
      setState(() {
        _events.insert(0, event);
        _showFeedback('Failed to delete event. Please try again.', FeedbackType.error);
      });
      await HapticService.trigger(HapticIntensity.error, context: context);
    }
  }
  
  void _showFeedback(String message, FeedbackType type, {bool autoDismiss = false}) {
    setState(() {
      _feedbackMessage = message;
      _feedbackType = type;
    });
    
    if (autoDismiss) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _feedbackMessage == message) {
          setState(() {
            _feedbackMessage = null;
            _feedbackType = null;
          });
        }
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    
    return Scaffold(
      backgroundColor: MotionTokens.background,
      appBar: AppBar(
        title: const Text('Events', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: MotionTokens.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => setState(() => _showFormSheet = true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadEvents,
        child: Stack(
          children: [
            Column(
              children: [
                if (_feedbackMessage != null)
                  InlineFeedback(
                    message: _feedbackMessage!,
                    type: _feedbackType!,
                    onRetry: _feedbackType == FeedbackType.error ? _loadEvents : null,
                    autoDismissDuration: const Duration(seconds: 3),
                  ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _events.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: MotionTokens.spacingLG),
                                  Text(
                                    'No events yet',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: MotionTokens.spacingMD),
                                  CrystalButton(
                                    label: 'Create First Event',
                                    onPressed: () => setState(() => _showFormSheet = true),
                                    variant: CrystalButtonVariant.outlined,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _events.length,
                              itemBuilder: (context, index) {
                                final event = _events[index];
                                return _buildEventCard(event);
                              },
                            ),
                ),
              ],
            ),
            if (_showFormSheet)
              DraggableSnapSheet(
                initialSnapPoint: MotionTokens.sheetSnapMid,
                onMinimize: () => setState(() => _showFormSheet = false),
                child: EventFormSheet(
                  onSubmit: (event) async {
                    await _createEvent(event);
                  },
                  onCancel: () => setState(() => _showFormSheet = false),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEventCard(Event event) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: MotionTokens.spacingLG,
        vertical: MotionTokens.spacingSM,
      ),
      child: ListTile(
        title: Text(
          event.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: MotionTokens.spacingXS),
            Text(
              '${event.eventDate.day}/${event.eventDate.month}/${event.eventDate.year}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            if (event.description != null)
              Text(
                event.description!,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: MotionTokens.error),
          onPressed: () => _confirmDelete(event),
        ),
      ),
    );
  }
  
  void _confirmDelete(Event event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Delete "${event.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteEvent(event);
            },
            style: TextButton.styleFrom(foregroundColor: MotionTokens.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
