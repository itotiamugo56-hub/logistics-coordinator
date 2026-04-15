import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../mixins/optimistic_operation.dart';
import '../services/haptic_service.dart';
import '../widgets/inline_feedback.dart';
import '../widgets/crystal_button.dart';
import '../widgets/physics_sheet.dart';

class EventsManager extends StatefulWidget {
  final String branchId;
  final VoidCallback onRefresh;
  
  const EventsManager({super.key, required this.branchId, required this.onRefresh});

  @override
  State<EventsManager> createState() => _EventsManagerState();
}

class _EventsManagerState extends State<EventsManager> with OptimisticOperation<Map<String, dynamic>> {
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  bool _isSharingLocation = false;
  OverlayEntry? _feedbackOverlay;
  bool _isAddingEvent = false;
  
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dateController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  LatLng? _sharedLocation;
  String? _sharedLocationAddress;
  DateTime? _selectedDate;
  
  final Uuid _uuid = const Uuid();
  
  @override
  List<Map<String, dynamic>> get items => _events;
  
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
    _loadEvents();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    _descriptionController.dispose();
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
  
  Future<void> _loadEvents() async {
    final response = await http.get(
      Uri.parse('http://127.0.0.1:8080/v1/clergy/events/${widget.branchId}'),
    );
    if (response.statusCode == 200) {
      setState(() {
        _events = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        _isLoading = false;
      });
      // Light haptic for successful load
      await HapticService.trigger(HapticIntensity.light, context: context);
    }
  }
  
  Future<void> _selectDateTime() async {
    // Light haptic when opening date picker
    await HapticService.trigger(HapticIntensity.light, context: context);
    
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      // Light haptic on date selection
      await HapticService.trigger(HapticIntensity.light, context: context);
      
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null) {
        // Light haptic on time selection
        await HapticService.trigger(HapticIntensity.light, context: context);
        
        setState(() {
          _selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
          _dateController.text = '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year} ${time.format(context)}';
        });
      }
    }
  }
  
  Future<void> _shareCurrentLocation() async {
    setState(() => _isSharingLocation = true);
    
    // Medium haptic for starting location share
    await HapticService.trigger(HapticIntensity.medium, context: context);
    
    try {
      PermissionStatus permission = await Permission.location.request();
      if (!permission.isGranted) {
        await HapticService.trigger(HapticIntensity.error, context: context);
        _showFeedback('Location permission required', FeedbackType.warning);
        setState(() => _isSharingLocation = false);
        return;
      }
      
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await HapticService.trigger(HapticIntensity.error, context: context);
        _showFeedback('Please enable location services', FeedbackType.warning);
        setState(() => _isSharingLocation = false);
        return;
      }
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _sharedLocation = LatLng(position.latitude, position.longitude);
        _sharedLocationAddress = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        _isSharingLocation = false;
      });
      
      // Success haptic (using light for positive feedback)
      await HapticService.trigger(HapticIntensity.light, context: context);
      _showFeedback('Location shared', FeedbackType.success);
    } catch (e) {
      setState(() => _isSharingLocation = false);
      await HapticService.trigger(HapticIntensity.error, context: context);
      _showFeedback('Failed to get location: $e', FeedbackType.error);
    }
  }
  
  void _removeSharedLocation() {
    setState(() {
      _sharedLocation = null;
      _sharedLocationAddress = null;
    });
    // Light haptic for removal
    HapticService.trigger(HapticIntensity.light, context: context);
  }
  
  Future<void> _addEvent() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null) {
      if (_selectedDate == null) {
        // Error haptic for validation failure
        await HapticService.trigger(HapticIntensity.error, context: context);
        _showFeedback('Please select date and time', FeedbackType.warning);
      } else {
        // Light haptic for field validation
        await HapticService.trigger(HapticIntensity.light, context: context);
      }
      return;
    }
    
    setState(() => _isAddingEvent = true);
    // Medium haptic for starting add operation
    await HapticService.trigger(HapticIntensity.medium, context: context);
    
    final tempId = _uuid.v4();
    final Map<String, dynamic> tempEvent = {
      'id': tempId,
      'name': _nameController.text,
      'event_date': _selectedDate!.millisecondsSinceEpoch ~/ 1000,
      'description': _descriptionController.text.isEmpty ? null : _descriptionController.text,
      '_optimistic': true,
    };
    
    if (_sharedLocation != null) {
      tempEvent['latitude'] = _sharedLocation!.latitude;
      tempEvent['longitude'] = _sharedLocation!.longitude;
    }
    
    addOptimistic(
      tempId,
      tempEvent,
      () => _performAddEvent(),
      onSuccess: (item) {
        setState(() => _isAddingEvent = false);
        _clearForm();
        widget.onRefresh();
        _loadEvents();
        // Success haptic (using light for positive feedback)
        HapticService.trigger(HapticIntensity.light, context: context);
        _showFeedback('Event added successfully', FeedbackType.success);
      },
      onError: (error) {
        setState(() => _isAddingEvent = false);
        // Error haptic for failure
        HapticService.trigger(HapticIntensity.error, context: context);
        _showFeedback('Failed to add event. Tap RETRY to try again.', FeedbackType.error, onRetry: () => _addEvent());
      },
    );
  }
  
  Future<void> _performAddEvent() async {
    final Map<String, dynamic> data = {
      'name': _nameController.text,
      'event_date': _selectedDate!.millisecondsSinceEpoch ~/ 1000,
      'description': _descriptionController.text.isEmpty ? null : _descriptionController.text,
    };
    
    if (_sharedLocation != null) {
      data['latitude'] = _sharedLocation!.latitude;
      data['longitude'] = _sharedLocation!.longitude;
    }
    
    final response = await http.post(
      Uri.parse('http://127.0.0.1:8080/v1/clergy/events/${widget.branchId}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    
    if (response.statusCode != 201) {
      throw Exception('Failed to add event');
    }
  }
  
  Future<void> _deleteEvent(Map<String, dynamic> event) async {
    // Heavy haptic for destructive action
    await HapticService.trigger(HapticIntensity.heavy, context: context);
    
    // Show confirmation haptic pattern (double heavy)
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticService.trigger(HapticIntensity.heavy, context: context);
    
    deleteOptimistic(
      event['id'].toString(),
      event,
      () => _performDeleteEvent(event['id'].toString()),
      onSuccess: () {
        widget.onRefresh();
        _loadEvents();
        // Light haptic for successful delete
        HapticService.trigger(HapticIntensity.light, context: context);
        _showFeedback('Event deleted', FeedbackType.info);
      },
      onError: (error) {
        // Error haptic for failure
        HapticService.trigger(HapticIntensity.error, context: context);
        _showFeedback('Failed to delete event', FeedbackType.error);
      },
    );
  }
  
  Future<void> _performDeleteEvent(String eventId) async {
    final response = await http.delete(
      Uri.parse('http://127.0.0.1:8080/v1/clergy/events/${widget.branchId}/$eventId'),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to delete event');
    }
  }
  
  void _clearForm() {
    _nameController.clear();
    _dateController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedDate = null;
      _sharedLocation = null;
      _sharedLocationAddress = null;
    });
    // Light haptic for form clear
    HapticService.trigger(HapticIntensity.light, context: context);
  }
  
  bool _isOptimisticEvent(Map<String, dynamic> event) {
    return event['_optimistic'] == true;
  }
  
  @override
  Widget build(BuildContext context) {
    // Build the content widget that will be placed inside PhysicsSheet
    final sheetContent = Column(
      children: [
        if (_events.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Upcoming Events', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _events.length,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) {
                final event = _events[index];
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    elevation: _isOptimisticEvent(event) ? 2 : 1,
                    color: _isOptimisticEvent(event)
                        ? Colors.green[50]
                        : Colors.white,
                    child: ListTile(
                      leading: const Icon(Icons.event, color: Colors.amber),
                      title: Text(
                        event['name'],
                        style: TextStyle(
                          fontWeight: _isOptimisticEvent(event) ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('📅 ${DateTime.fromMillisecondsSinceEpoch(event['event_date'] * 1000).toString().substring(0, 16)}'),
                          if (event['description'] != null)
                            Text('📝 ${event['description']}'),
                          if (event['latitude'] != null)
                            const Text('📍 Location shared', style: TextStyle(fontSize: 11, color: Colors.green)),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteEvent(event),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
        ],
        
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Add New Event', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Event Name *',
                    hintText: 'e.g., Easter Crusade, Youth Conference',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.celebration),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  onTap: () {
                    HapticService.trigger(HapticIntensity.light, context: context);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dateController,
                  decoration: const InputDecoration(
                    labelText: 'Event Date & Time *',
                    hintText: 'Tap to select',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  readOnly: true,
                  onTap: _selectDateTime,
                  validator: (v) => v == null || v.isEmpty ? 'Select date' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 3,
                  onTap: () {
                    HapticService.trigger(HapticIntensity.light, context: context);
                  },
                ),
                
                const SizedBox(height: 16),
                
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.grey, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Share Location (Optional)',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Only if you are at the event venue',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      if (_sharedLocation == null)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: CrystalButton(
                            onPressed: _isSharingLocation ? null : _shareCurrentLocation,
                            label: _isSharingLocation ? 'GETTING LOCATION...' : 'SHARE MY CURRENT LOCATION',
                            variant: CrystalButtonVariant.outlined,
                            isLoading: _isSharingLocation,
                            icon: Icons.my_location,
                            isExpanded: true,
                          ),
                        ),
                      if (_sharedLocation != null)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green[200]!),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Location shared: $_sharedLocationAddress',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 16),
                                      onPressed: _removeSharedLocation,
                                      tooltip: 'Remove location',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                CrystalButton(
                  onPressed: _isAddingEvent ? null : _addEvent,
                  label: 'ADD EVENT',
                  variant: CrystalButtonVariant.filled,
                  isLoading: _isAddingEvent,
                  isExpanded: true,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
    
    // Wrap content in SingleChildScrollView for scrolling when sheet is small
    final scrollableContent = SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: sheetContent,
    );
    
    // Return PhysicsSheet instead of DraggableScrollableSheet
    return PhysicsSheet(
      child: scrollableContent,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      initialChildSize: _events.isEmpty ? 0.5 : 0.7,
      onExpanded: () {
        // Optional: Called when sheet expands to max size
        HapticService.trigger(HapticIntensity.light, context: context);
      },
      onCollapsed: () {
        // Optional: Called when sheet collapses to min size
        HapticService.trigger(HapticIntensity.light, context: context);
      },
      isCritical: false,
    );
  }
}

class LatLng {
  final double latitude;
  final double longitude;
  
  LatLng(this.latitude, this.longitude);
}