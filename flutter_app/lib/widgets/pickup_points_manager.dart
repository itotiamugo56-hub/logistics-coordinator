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

class PickupPointsManager extends StatefulWidget {
  final String branchId;
  final VoidCallback onRefresh;
  
  const PickupPointsManager({super.key, required this.branchId, required this.onRefresh});

  @override
  State<PickupPointsManager> createState() => _PickupPointsManagerState();
}

class _PickupPointsManagerState extends State<PickupPointsManager> with OptimisticOperation<Map<String, dynamic>> {
  List<Map<String, dynamic>> _points = [];
  bool _isLoading = true;
  bool _isSharingLocation = false;
  bool _isAddingPoint = false;
  OverlayEntry? _feedbackOverlay;
  
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _pickupTimeController = TextEditingController();
  final _managerNameController = TextEditingController();
  final _managerPhoneController = TextEditingController();
  
  LatLng? _sharedLocation;
  String? _sharedLocationAddress;
  
  final Uuid _uuid = const Uuid();
  
  @override
  List<Map<String, dynamic>> get items => _points;
  
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
    _loadPoints();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _pickupTimeController.dispose();
    _managerNameController.dispose();
    _managerPhoneController.dispose();
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
  
  Future<void> _loadPoints() async {
    final response = await http.get(
      Uri.parse('http://127.0.0.1:8080/v1/clergy/pickup-points/${widget.branchId}'),
    );
    if (response.statusCode == 200) {
      setState(() {
        _points = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        _isLoading = false;
      });
      await HapticService.trigger(HapticIntensity.light, context: context);
    }
  }
  
  Future<void> _shareCurrentLocation() async {
    setState(() => _isSharingLocation = true);
    
    await HapticService.trigger(HapticIntensity.medium, context: context);
    
    try {
      PermissionStatus permission = await Permission.location.request();
      if (!permission.isGranted) {
        await HapticService.trigger(HapticIntensity.error, context: context);
        _showFeedback('Location permission required to share location', FeedbackType.warning);
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
      
      await HapticService.trigger(HapticIntensity.light, context: context);
      _showFeedback('Location shared: $_sharedLocationAddress', FeedbackType.success);
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
    HapticService.trigger(HapticIntensity.light, context: context);
  }
  
  Future<void> _addPickupPoint() async {
    if (!_formKey.currentState!.validate()) {
      await HapticService.trigger(HapticIntensity.error, context: context);
      return;
    }
    
    setState(() => _isAddingPoint = true);
    await HapticService.trigger(HapticIntensity.medium, context: context);
    
    final tempId = _uuid.v4();
    final Map<String, dynamic> tempPoint = {
      'id': tempId,
      'name': _nameController.text,
      'pickup_time': _pickupTimeController.text,
      'transport_manager_name': _managerNameController.text.isEmpty ? null : _managerNameController.text,
      'transport_manager_phone': _managerPhoneController.text.isEmpty ? null : _managerPhoneController.text,
      '_optimistic': true,
    };
    
    if (_sharedLocation != null) {
      tempPoint['latitude'] = _sharedLocation!.latitude;
      tempPoint['longitude'] = _sharedLocation!.longitude;
    }
    
    addOptimistic(
      tempId,
      tempPoint,
      () => _performAddPoint(),
      onSuccess: (item) {
        setState(() => _isAddingPoint = false);
        _clearForm();
        widget.onRefresh();
        _loadPoints();
        HapticService.trigger(HapticIntensity.light, context: context);
        _showFeedback('Pickup point added successfully', FeedbackType.success);
      },
      onError: (error) {
        setState(() => _isAddingPoint = false);
        HapticService.trigger(HapticIntensity.error, context: context);
        _showFeedback('Failed to add pickup point. Tap RETRY to try again.', FeedbackType.error, onRetry: () => _addPickupPoint());
      },
    );
  }
  
  Future<void> _performAddPoint() async {
    final Map<String, dynamic> data = {
      'name': _nameController.text,
      'pickup_time': _pickupTimeController.text,
      'transport_manager_name': _managerNameController.text.isEmpty ? null : _managerNameController.text,
      'transport_manager_phone': _managerPhoneController.text.isEmpty ? null : _managerPhoneController.text,
    };
    
    if (_sharedLocation != null) {
      data['latitude'] = _sharedLocation!.latitude;
      data['longitude'] = _sharedLocation!.longitude;
    }
    
    final response = await http.post(
      Uri.parse('http://127.0.0.1:8080/v1/clergy/pickup-points/${widget.branchId}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    
    if (response.statusCode != 201) {
      throw Exception('Failed to add pickup point');
    }
  }
  
  Future<void> _deletePickupPoint(Map<String, dynamic> point) async {
    await HapticService.trigger(HapticIntensity.heavy, context: context);
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticService.trigger(HapticIntensity.heavy, context: context);
    
    deleteOptimistic(
      point['id'].toString(),
      point,
      () => _performDeletePoint(point['id'].toString()),
      onSuccess: () {
        widget.onRefresh();
        _loadPoints();
        HapticService.trigger(HapticIntensity.light, context: context);
        _showFeedback('Pickup point deleted', FeedbackType.info);
      },
      onError: (error) {
        HapticService.trigger(HapticIntensity.error, context: context);
        _showFeedback('Failed to delete pickup point', FeedbackType.error);
      },
    );
  }
  
  Future<void> _performDeletePoint(String pointId) async {
    final response = await http.delete(
      Uri.parse('http://127.0.0.1:8080/v1/clergy/pickup-points/${widget.branchId}/$pointId'),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to delete pickup point');
    }
  }
  
  void _clearForm() {
    _nameController.clear();
    _pickupTimeController.clear();
    _managerNameController.clear();
    _managerPhoneController.clear();
    setState(() {
      _sharedLocation = null;
      _sharedLocationAddress = null;
    });
    HapticService.trigger(HapticIntensity.light, context: context);
  }
  
  bool _isOptimisticPoint(Map<String, dynamic> point) {
    return point['_optimistic'] == true;
  }
  
  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Manage Pickup Points',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_points.isNotEmpty) ...[
                const Text('Current Pickup Points', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._points.map((point) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    elevation: _isOptimisticPoint(point) ? 2 : 1,
                    color: _isOptimisticPoint(point)
                        ? Colors.green[50]
                        : Colors.white,
                    child: ListTile(
                      leading: const Icon(Icons.directions_bus, color: Colors.green),
                      title: Text(
                        point['name'],
                        style: TextStyle(
                          fontWeight: _isOptimisticPoint(point) ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('🕒 ${point['pickup_time']}'),
                          if (point['transport_manager_name'] != null)
                            Text('👤 ${point['transport_manager_name']}'),
                          if (point['transport_manager_phone'] != null)
                            Text('📞 ${point['transport_manager_phone']}'),
                          if (point['latitude'] != null)
                            const Text('📍 Location shared', style: TextStyle(fontSize: 11, color: Colors.green)),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deletePickupPoint(point),
                      ),
                    ),
                  ),
                )),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
              ],
              
              const Text('Add New Pickup Point', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Pickup Point Name *',
                        hintText: 'e.g., CBD Stage, Westlands Mall',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.place),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      onTap: () {
                        HapticService.trigger(HapticIntensity.light, context: context);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pickupTimeController,
                      decoration: const InputDecoration(
                        labelText: 'Pickup Time *',
                        hintText: '7:30 AM',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      onTap: () {
                        HapticService.trigger(HapticIntensity.light, context: context);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _managerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Transport Manager Name (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      onTap: () {
                        HapticService.trigger(HapticIntensity.light, context: context);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _managerPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'Transport Manager Phone (Optional)',
                        hintText: '0712345678',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
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
                                  'Only if you are at the pickup point',
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
                      onPressed: _isAddingPoint ? null : _addPickupPoint,
                      label: 'ADD PICKUP POINT',
                      variant: CrystalButtonVariant.filled,
                      isLoading: _isAddingPoint,
                      isExpanded: true,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
    
    return PhysicsSheet(
      child: content,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      initialChildSize: _points.isEmpty ? 0.6 : 0.8,
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

class LatLng {
  final double latitude;
  final double longitude;
  
  LatLng(this.latitude, this.longitude);
}