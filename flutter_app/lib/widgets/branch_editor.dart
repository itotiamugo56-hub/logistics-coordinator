import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:latlong2/latlong.dart';
import '../models/branch.dart';
import '../mixins/optimistic_operation.dart';
import '../services/haptic_service.dart';
import '../widgets/inline_feedback.dart';
import '../widgets/crystal_button.dart';
import '../widgets/physics_sheet.dart';
import '../widgets/success_animation.dart';
import '../widgets/location_picker.dart';

class BranchEditor extends StatefulWidget {
  final Branch branch;
  final VoidCallback onSaved;
  
  const BranchEditor({super.key, required this.branch, required this.onSaved});

  @override
  State<BranchEditor> createState() => _BranchEditorState();
}

class _BranchEditorState extends State<BranchEditor> with OptimisticOperation<Map<String, dynamic>> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _pastorController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;
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
    _nameController = TextEditingController(text: widget.branch.name);
    _addressController = TextEditingController(text: widget.branch.address);
    _pastorController = TextEditingController(text: widget.branch.seniorPastor);
    _phoneController = TextEditingController(text: widget.branch.phone);
    _emailController = TextEditingController(text: widget.branch.email);
    _latitudeController = TextEditingController(text: widget.branch.latitude.toString());
    _longitudeController = TextEditingController(text: widget.branch.longitude.toString());
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _pastorController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
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
  
  Future<void> _openLocationPicker() async {
    HapticService.trigger(HapticIntensity.light, context: context);
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPicker(
          initialLocation: _latitudeController.text.isNotEmpty && _longitudeController.text.isNotEmpty
              ? LatLng(
                  double.tryParse(_latitudeController.text) ?? widget.branch.latitude,
                  double.tryParse(_longitudeController.text) ?? widget.branch.longitude,
                )
              : LatLng(widget.branch.latitude, widget.branch.longitude),
          initialAddress: _addressController.text,
          onLocationSelected: (lat, lng, address) {
            setState(() {
              _latitudeController.text = lat.toString();
              _longitudeController.text = lng.toString();
              _addressController.text = address;
            });
            HapticService.trigger(HapticIntensity.light, context: context);
          },
        ),
      ),
    );
  }
  
  Future<void> _saveBranch() async {
    if (!_formKey.currentState!.validate()) {
      await HapticService.trigger(HapticIntensity.error, context: context);
      return;
    }
    
    await HapticService.trigger(HapticIntensity.medium, context: context);
    
    final Map<String, dynamic> updates = {};
    if (_nameController.text != widget.branch.name) updates['name'] = _nameController.text;
    if (_addressController.text != widget.branch.address) updates['address'] = _addressController.text;
    if (_pastorController.text != widget.branch.seniorPastor) updates['senior_pastor'] = _pastorController.text;
    if (_phoneController.text != widget.branch.phone) updates['phone'] = _phoneController.text;
    if (_emailController.text != widget.branch.email) updates['email'] = _emailController.text;
    
    // Check if latitude/longitude changed
    final newLat = double.tryParse(_latitudeController.text);
    final newLng = double.tryParse(_longitudeController.text);
    if (newLat != null && newLat != widget.branch.latitude) updates['latitude'] = newLat;
    if (newLng != null && newLng != widget.branch.longitude) updates['longitude'] = newLng;
    
    if (updates.isEmpty) {
      await HapticService.trigger(HapticIntensity.light, context: context);
      if (mounted) Navigator.pop(context);
      return;
    }
    
    setState(() => _isSaving = true);
    
    final tempId = _uuid.v4();
    final tempData = {
      'id': tempId,
      'updates': updates,
      '_optimistic': true,
    };
    
    addOptimistic(
      tempId,
      tempData,
      () => _performSave(updates),
      onSuccess: (item) {
        setState(() => _isSaving = false);
        widget.onSaved();
        HapticService.trigger(HapticIntensity.light, context: context);
        
        // Show success animation
        SuccessAnimation.show(
          context,
          message: 'Changes Saved',
        );
        
        _showFeedback('Branch updated successfully', FeedbackType.success);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.pop(context);
        });
      },
      onError: (error) {
        setState(() => _isSaving = false);
        HapticService.trigger(HapticIntensity.error, context: context);
        _showFeedback('Failed to update branch. Tap RETRY to try again.', FeedbackType.error, onRetry: () => _saveBranch());
      },
    );
  }
  
  Future<void> _performSave(Map<String, dynamic> updates) async {
    final response = await http.put(
      Uri.parse('http://127.0.0.1:8080/v1/clergy/branch/${widget.branch.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(updates),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to update branch');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final content = Form(
      key: _formKey,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Edit Branch Details',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Branch Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.store),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  onTap: () {
                    HapticService.trigger(HapticIntensity.light, context: context);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  onTap: () {
                    HapticService.trigger(HapticIntensity.light, context: context);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pastorController,
                  decoration: const InputDecoration(
                    labelText: 'Senior Pastor Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  onTap: () {
                    HapticService.trigger(HapticIntensity.light, context: context);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  onTap: () {
                    HapticService.trigger(HapticIntensity.light, context: context);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onTap: () {
                    HapticService.trigger(HapticIntensity.light, context: context);
                  },
                ),
                const SizedBox(height: 16),
                
                // Location Picker Button
                InkWell(
                  onTap: _openLocationPicker,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6750A4).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.map, size: 20, color: Color(0xFF6750A4)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Branch Location',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _latitudeController.text.isNotEmpty && _longitudeController.text.isNotEmpty
                                    ? '${_latitudeController.text}, ${_longitudeController.text}'
                                    : 'Tap to select location on map',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _latitudeController.text.isNotEmpty
                                      ? const Color(0xFF1C1B1F)
                                      : const Color(0xFF49454F),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 20, color: Color(0xFF79747E)),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                CrystalButton(
                  onPressed: _isSaving ? null : _saveBranch,
                  label: 'SAVE CHANGES',
                  variant: CrystalButtonVariant.filled,
                  isLoading: _isSaving,
                  isExpanded: true,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
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