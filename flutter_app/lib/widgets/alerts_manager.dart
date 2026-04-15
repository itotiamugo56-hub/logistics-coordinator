import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../mixins/optimistic_operation.dart';
import '../services/haptic_service.dart';
import '../widgets/inline_feedback.dart';
import '../widgets/crystal_button.dart';
import '../widgets/physics_sheet.dart';

class AlertsManager extends StatefulWidget {
  final String branchId;
  final VoidCallback onRefresh;
  
  const AlertsManager({super.key, required this.branchId, required this.onRefresh});

  @override
  State<AlertsManager> createState() => _AlertsManagerState();
}

class _AlertsManagerState extends State<AlertsManager> with OptimisticOperation<Map<String, dynamic>> {
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;
  bool _isAddingAlert = false;
  OverlayEntry? _feedbackOverlay;
  
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  String? _affectedService;
  DateTime? _expiryDate;
  
  final List<String> _serviceOptions = ['All Services', 'Sunday 8:00 AM', 'Sunday 10:00 AM', 'Sunday 12:00 PM', 'Wednesday 6:00 PM', 'Friday 5:00 PM'];
  
  final Uuid _uuid = const Uuid();
  
  @override
  List<Map<String, dynamic>> get items => _alerts;
  
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
    _loadAlerts();
  }
  
  @override
  void dispose() {
    _messageController.dispose();
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
  
  Future<void> _loadAlerts() async {
    final response = await http.get(
      Uri.parse('http://127.0.0.1:8080/v1/clergy/alerts/${widget.branchId}'),
    );
    if (response.statusCode == 200) {
      setState(() {
        _alerts = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        _isLoading = false;
      });
      await HapticService.trigger(HapticIntensity.light, context: context);
    }
  }
  
  Future<void> _selectExpiry() async {
    await HapticService.trigger(HapticIntensity.light, context: context);
    
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date != null) {
      await HapticService.trigger(HapticIntensity.light, context: context);
      setState(() {
        _expiryDate = date;
      });
    }
  }
  
  Future<void> _addAlert() async {
    if (!_formKey.currentState!.validate() || _expiryDate == null) {
      if (_expiryDate == null) {
        await HapticService.trigger(HapticIntensity.error, context: context);
        _showFeedback('Please select expiry date', FeedbackType.warning);
      }
      return;
    }
    
    setState(() => _isAddingAlert = true);
    await HapticService.trigger(HapticIntensity.medium, context: context);
    
    final tempId = _uuid.v4();
    final tempAlert = {
      'id': tempId,
      'message': _messageController.text,
      'affected_service': _affectedService == 'All Services' ? null : _affectedService,
      'expires_at': _expiryDate!.millisecondsSinceEpoch ~/ 1000,
      '_optimistic': true,
    };
    
    addOptimistic(
      tempId,
      tempAlert,
      () => _performAddAlert(),
      onSuccess: (item) {
        setState(() => _isAddingAlert = false);
        _clearForm();
        widget.onRefresh();
        _loadAlerts();
        HapticService.trigger(HapticIntensity.light, context: context);
        _showFeedback('Alert posted successfully', FeedbackType.success);
      },
      onError: (error) {
        setState(() => _isAddingAlert = false);
        HapticService.trigger(HapticIntensity.error, context: context);
        _showFeedback('Failed to post alert. Tap RETRY to try again.', FeedbackType.error, onRetry: () => _addAlert());
      },
    );
  }
  
  Future<void> _performAddAlert() async {
    final response = await http.post(
      Uri.parse('http://127.0.0.1:8080/v1/clergy/alerts/${widget.branchId}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'message': _messageController.text,
        'affected_service': _affectedService == 'All Services' ? null : _affectedService,
        'expires_at': _expiryDate!.millisecondsSinceEpoch ~/ 1000,
      }),
    );
    
    if (response.statusCode != 201) {
      throw Exception('Failed to post alert');
    }
  }
  
  Future<void> _deleteAlert(Map<String, dynamic> alert) async {
    await HapticService.trigger(HapticIntensity.heavy, context: context);
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticService.trigger(HapticIntensity.heavy, context: context);
    
    deleteOptimistic(
      alert['id'].toString(),
      alert,
      () => _performDeleteAlert(alert['id'].toString()),
      onSuccess: () {
        widget.onRefresh();
        _loadAlerts();
        HapticService.trigger(HapticIntensity.light, context: context);
        _showFeedback('Alert deleted', FeedbackType.info);
      },
      onError: (error) {
        HapticService.trigger(HapticIntensity.error, context: context);
        _showFeedback('Failed to delete alert', FeedbackType.error);
      },
    );
  }
  
  Future<void> _performDeleteAlert(String alertId) async {
    final response = await http.delete(
      Uri.parse('http://127.0.0.1:8080/v1/clergy/alerts/${widget.branchId}/$alertId'),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to delete alert');
    }
  }
  
  void _clearForm() {
    _messageController.clear();
    setState(() {
      _affectedService = null;
      _expiryDate = null;
    });
    HapticService.trigger(HapticIntensity.light, context: context);
  }
  
  bool _isOptimisticAlert(Map<String, dynamic> alert) {
    return alert['_optimistic'] == true;
  }
  
  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Manage Service Alerts',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_alerts.isNotEmpty) ...[
                const Text('Active Alerts', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._alerts.map((alert) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    elevation: _isOptimisticAlert(alert) ? 2 : 1,
                    color: _isOptimisticAlert(alert)
                        ? Colors.green[50]
                        : Colors.red[50],
                    child: ListTile(
                      title: Text(
                        alert['message'],
                        style: TextStyle(
                          fontWeight: _isOptimisticAlert(alert) ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        '${alert['affected_service'] ?? 'All services'} • Expires ${DateTime.fromMillisecondsSinceEpoch(alert['expires_at'] * 1000).toString().substring(0, 10)}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteAlert(alert),
                      ),
                    ),
                  ),
                )),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
              ],
              
              const Text('Post New Alert', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        labelText: 'Alert Message',
                        hintText: 'e.g., Sunday 10 AM service moved to 11 AM',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      onTap: () {
                        HapticService.trigger(HapticIntensity.light, context: context);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Affected Service',
                        border: OutlineInputBorder(),
                      ),
                      value: _affectedService,
                      items: _serviceOptions.map((option) {
                        return DropdownMenuItem(value: option, child: Text(option));
                      }).toList(),
                      onChanged: (value) {
                        HapticService.trigger(HapticIntensity.light, context: context);
                        setState(() => _affectedService = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _selectExpiry,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Expiry Date',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _expiryDate != null
                              ? '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}'
                              : 'Select expiry date',
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    CrystalButton(
                      onPressed: _isAddingAlert ? null : _addAlert,
                      label: 'POST ALERT',
                      variant: CrystalButtonVariant.filled,
                      isLoading: _isAddingAlert,
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
      initialChildSize: _alerts.isEmpty ? 0.6 : 0.85,
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