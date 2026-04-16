import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../services/haptic_service.dart';
import '../services/branch_service.dart';
import '../services/api_client.dart';
import '../models/branch.dart';
import '../widgets/crystal_button.dart';
import '../widgets/branch_editor.dart';
import '../widgets/service_times_editor.dart';
import '../widgets/events_manager.dart';
import '../widgets/pickup_points_manager.dart';
import '../widgets/alerts_manager.dart';
import '../widgets/photo_manager.dart';
import '../widgets/location_picker.dart';

class ClergyDashboardScreen extends StatefulWidget {
  const ClergyDashboardScreen({super.key});

  @override
  State<ClergyDashboardScreen> createState() => _ClergyDashboardScreenState();
}

class _ClergyDashboardScreenState extends State<ClergyDashboardScreen> {
  bool _isLoading = true;
  Branch? _branch;
  String? _branchId;
  
  @override
  void initState() {
    super.initState();
    _checkBranchStatus();
  }
  
  Future<void> _checkBranchStatus() async {
    setState(() => _isLoading = true);
    
    try {
      final authProvider = context.read<AuthProvider>();
      final memberId = authProvider.memberId;
      
      if (memberId != null) {
        final branches = await BranchService.getAllBranches();
        
        // Find branch where branch_clergy_id matches the logged-in clergy
        Branch? assignedBranch;
        for (var branch in branches) {
          if (branch.branchClergyId == memberId) {
            assignedBranch = branch;
            break;
          }
        }
        
        // If no branch assigned, show create branch view
        _branch = assignedBranch;
        _branchId = _branch?.id;
      }
    } catch (e) {
      debugPrint('Error checking branch status: $e');
    }
    
    setState(() => _isLoading = false);
  }
  
  void _refreshBranch() {
    _checkBranchStatus();
  }
  
  void _showBranchEditor() {
    if (_branch == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BranchEditor(
        branch: _branch!,
        onSaved: () {
          _refreshBranch();
          HapticService.trigger(HapticIntensity.light, context: context);
        },
      ),
    );
  }
  
  void _showServiceTimesEditor() {
    if (_branch == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ServiceTimesEditor(
        branch: _branch!,
        onSaved: _refreshBranch,
      ),
    );
  }
  
  void _showEventsManager() {
    if (_branchId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EventsManager(
        branchId: _branchId!,
        onRefresh: _refreshBranch,
      ),
    );
  }
  
  void _showPickupPointsManager() {
    if (_branchId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PickupPointsManager(
        branchId: _branchId!,
        onRefresh: _refreshBranch,
      ),
    );
  }
  
  void _showAlertsManager() {
    if (_branchId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AlertsManager(
        branchId: _branchId!,
        onRefresh: _refreshBranch,
      ),
    );
  }
  
  void _showPhotoManager() {
    if (_branchId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PhotoManager(
        branchId: _branchId!,
        onRefresh: _refreshBranch,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Clergy Portal',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: M3Colors.tertiary,
        centerTitle: false,
        actions: [
          // Role badge
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: M3Colors.tertiary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.badge, size: 14, color: M3Colors.tertiary),
                const SizedBox(width: 4),
                Text(
                  authProvider.isBranchPastor ? 'Pastor' : 'Staff',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: M3Colors.tertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _branch == null
              ? _buildNoBranchView()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Branch Header Card
                      _buildBranchHeaderCard(),
                      const SizedBox(height: 24),
                      
                      // Section Title
                      const Text(
                        'Manage Branch',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8E8E93),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Management Grid - Stripe/Apple Style
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.1,
                        children: [
                          _buildManagementCard(
                            icon: Icons.schedule,
                            title: 'Service Times',
                            subtitle: 'Set schedules',
                            color: const Color(0xFF6750A4),
                            onTap: _showServiceTimesEditor,
                          ),
                          _buildManagementCard(
                            icon: Icons.event,
                            title: 'Events',
                            subtitle: 'Manage services',
                            color: const Color(0xFF00C853),
                            onTap: _showEventsManager,
                          ),
                          _buildManagementCard(
                            icon: Icons.directions_bus,
                            title: 'Pickup Points',
                            subtitle: 'Transportation',
                            color: const Color(0xFF2196F3),
                            onTap: _showPickupPointsManager,
                          ),
                          _buildManagementCard(
                            icon: Icons.notifications_active,
                            title: 'Alerts',
                            subtitle: 'Announcements',
                            color: const Color(0xFFFFB300),
                            onTap: _showAlertsManager,
                          ),
                          _buildManagementCard(
                            icon: Icons.photo_library,
                            title: 'Photos',
                            subtitle: 'Gallery',
                            color: const Color(0xFF9C27B0),
                            onTap: _showPhotoManager,
                          ),
                          _buildManagementCard(
                            icon: Icons.edit,
                            title: 'Branch Info',
                            subtitle: 'Edit details',
                            color: const Color(0xFF607D8B),
                            onTap: _showBranchEditor,
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Tips Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: M3Colors.primaryContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: M3Colors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.tips_and_updates,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Pro Tip',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: M3Colors.primary,
                                    ),
                                  ),
                                  Text(
                                    'Keep your branch information up to date for members',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: M3Colors.onSurfaceVariant,
                                    ),
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
    );
  }
  
  Widget _buildBranchHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            M3Colors.tertiary,
            M3Colors.primary,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: M3Colors.tertiary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.store,
                  size: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _branch!.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _branch!.address,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.person, size: 14, color: Colors.white.withOpacity(0.8)),
              const SizedBox(width: 6),
              Text(
                _branch!.seniorPastor,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.phone, size: 14, color: Colors.white.withOpacity(0.8)),
              const SizedBox(width: 6),
              Text(
                _branch!.phone,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildManagementCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticService.trigger(HapticIntensity.light, context: context);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1B1F),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNoBranchView() {
    final _nameController = TextEditingController();
    final _addressController = TextEditingController();
    final _pastorController = TextEditingController(text: context.read<AuthProvider>().name);
    final _phoneController = TextEditingController();
    final _emailController = TextEditingController(text: context.read<AuthProvider>().email);
    final _latitudeController = TextEditingController();
    final _longitudeController = TextEditingController();
    bool _isCreating = false;
    
    Future<void> _openLocationPicker() async {
      HapticService.trigger(HapticIntensity.light, context: context);
      
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LocationPicker(
            initialLocation: _latitudeController.text.isNotEmpty && _longitudeController.text.isNotEmpty
                ? latlong.LatLng(
                    double.tryParse(_latitudeController.text) ?? -1.286389,
                    double.tryParse(_longitudeController.text) ?? 36.817223,
                  )
                : const latlong.LatLng(-1.286389, 36.817223),
            initialAddress: _addressController.text,
            onLocationSelected: (lat, lng, address) {
              _latitudeController.text = lat.toString();
              _longitudeController.text = lng.toString();
              _addressController.text = address;
              HapticService.trigger(HapticIntensity.light, context: context);
            },
          ),
        ),
      );
    }
    
    Future<void> _createBranch() async {
      if (_nameController.text.isEmpty || _addressController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in branch name and address')),
        );
        return;
      }
      
      setState(() => _isCreating = true);
      
      try {
        final authProvider = context.read<AuthProvider>();
        final token = await authProvider.token;
        
        if (token == null) throw Exception('Not authenticated');
        
        final response = await http.post(
          Uri.parse('${ApiClient.baseUrl}/v1/branches'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'name': _nameController.text,
            'address': _addressController.text,
            'latitude': double.tryParse(_latitudeController.text) ?? -1.286389,
            'longitude': double.tryParse(_longitudeController.text) ?? 36.817223,
            'senior_pastor': _pastorController.text,
            'phone': _phoneController.text,
            'email': _emailController.text,
            'service_times': {},
          }),
        );
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          await _checkBranchStatus();
          HapticService.trigger(HapticIntensity.light, context: context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Branch created successfully!')),
          );
        } else {
          throw Exception('Failed to create branch');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      
      setState(() => _isCreating = false);
    }
    
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: M3Colors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.church,
                size: 48,
                color: M3Colors.outline,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Create Your Branch',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: M3Colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'As a clergy member, you can create your branch.',
              style: TextStyle(color: M3Colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Branch Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Branch Name *',
                prefixIcon: Icon(Icons.store),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            
            // Address with Location Picker
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address *',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            
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
                        color: M3Colors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.map, size: 20, color: M3Colors.primary),
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
                                  ? M3Colors.onSurface
                                  : M3Colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 20, color: M3Colors.outline),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Senior Pastor
            TextField(
              controller: _pastorController,
              decoration: const InputDecoration(
                labelText: 'Senior Pastor *',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            
            // Phone
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            
            // Email
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),
            
            // Create Button
            CrystalButton(
              onPressed: _isCreating ? null : _createBranch,
              label: 'CREATE BRANCH',
              variant: CrystalButtonVariant.filled,
              isLoading: _isCreating,
              isExpanded: true,
            ),
          ],
        ),
      ),
    );
  }
}

// M3Colors for consistency
class M3Colors {
  static const Color primary = Color(0xFF6750A4);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFEADDFF);
  static const Color secondary = Color(0xFF625B71);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color tertiary = Color(0xFF7D5260);
  static const Color surface = Color(0xFFFEF7FF);
  static const Color surfaceVariant = Color(0xFFE7E0EC);
  static const Color background = Color(0xFFFFFBFE);
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onSurface = Color(0xFF1C1B1F);
  static const Color onSurfaceVariant = Color(0xFF49454F);
  static const Color outline = Color(0xFF79747E);
  static const Color outlineVariant = Color(0xFFCAC4D0);
  static const Color success = Color(0xFF00C853);
  static const Color warning = Color(0xFFFFB300);
}