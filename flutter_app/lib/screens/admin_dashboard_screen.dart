import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../services/haptic_service.dart';
import '../services/api_client.dart';
import '../services/branch_service.dart';
import '../models/branch.dart';
import '../widgets/crystal_button.dart';
import '../widgets/role_guard.dart';

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

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  
  final List<Widget> _tabs = [
    const OverviewTab(),
    const CreateRegionalAdminTab(),
    const CreateBranchPastorTab(),
    const UserManagementTab(),
  ];
  
  final List<String> _tabTitles = ['Overview', 'Create Regional', 'Create Pastor', 'Users'];
  
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: M3Colors.primary,
        actions: [
          if (authProvider.isGlobalAdmin)
            TextButton(
              onPressed: () {
                // TODO: Global admin settings
              },
              child: const Text('Settings'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Role badge
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: M3Colors.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings, size: 16, color: M3Colors.primary),
                const SizedBox(width: 6),
                Text(
                  authProvider.isGlobalAdmin ? 'Global Admin' : 'Regional Admin',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: M3Colors.primary,
                  ),
                ),
              ],
            ),
          ),
          
          // Tab Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<int>(
              segments: _tabTitles.asMap().entries.map((entry) {
                return ButtonSegment<int>(
                  value: entry.key,
                  label: Text(entry.value),
                );
              }).toList(),
              selected: {_selectedIndex},
              onSelectionChanged: (Set<int> newSelection) {
                setState(() {
                  _selectedIndex = newSelection.first;
                });
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) {
                      return M3Colors.primary;
                    }
                    return Colors.transparent;
                  },
                ),
                foregroundColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) {
                      return M3Colors.onPrimary;
                    }
                    return M3Colors.onSurfaceVariant;
                  },
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Tab content
          Expanded(child: _tabs[_selectedIndex]),
        ],
      ),
    );
  }
}

// Overview Tab - Fetches real data from backend
class OverviewTab extends StatefulWidget {
  const OverviewTab({super.key});

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  final ApiClient _apiClient = ApiClient();
  int _totalBranches = 0;
  int _totalClergy = 0;
  int _totalMembers = 0;
  int _activeFlares = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    
    try {
      final token = await _apiClient.getToken();
      if (token == null) throw Exception('Not authenticated');
      
      final headers = {'Authorization': 'Bearer $token'};
      
      // Fetch branches
      final branchesResponse = await http.get(
        Uri.parse('${ApiClient.baseUrl}/v1/branches'),
        headers: headers,
      );
      if (branchesResponse.statusCode == 200) {
        final List<dynamic> branches = jsonDecode(branchesResponse.body);
        _totalBranches = branches.length;
      }
      
      // Fetch clergy users
      final clergyResponse = await http.get(
        Uri.parse('${ApiClient.baseUrl}/v1/admin/clergy'),
        headers: headers,
      );
      if (clergyResponse.statusCode == 200) {
        final List<dynamic> clergy = jsonDecode(clergyResponse.body);
        _totalClergy = clergy.length;
      }
      
      // Fetch members
      final membersResponse = await http.get(
        Uri.parse('${ApiClient.baseUrl}/v1/members'),
        headers: headers,
      );
      if (membersResponse.statusCode == 200) {
        final List<dynamic> members = jsonDecode(membersResponse.body);
        _totalMembers = members.length;
      }
      
      // Fetch active flares
      final flaresResponse = await http.get(
        Uri.parse('${ApiClient.baseUrl}/v1/flares/active'),
        headers: headers,
      );
      if (flaresResponse.statusCode == 200) {
        final List<dynamic> flares = jsonDecode(flaresResponse.body);
        _activeFlares = flares.length;
      }
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: M3Colors.error),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: M3Colors.error)),
            const SizedBox(height: 16),
            CrystalButton(
              onPressed: _loadStats,
              label: 'RETRY',
              variant: CrystalButtonVariant.outlined,
            ),
          ],
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildStatCard('Total Branches', _totalBranches.toString(), Icons.church),
          const SizedBox(height: 12),
          _buildStatCard('Total Clergy', _totalClergy.toString(), Icons.person),
          const SizedBox(height: 12),
          _buildStatCard('Verified Members', _totalMembers.toString(), Icons.verified),
          const SizedBox(height: 12),
          _buildStatCard('Active Flares', _activeFlares.toString(), Icons.warning),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: M3Colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: M3Colors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: M3Colors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: M3Colors.onSurface,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: M3Colors.onSurfaceVariant,
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
}

// Create Regional Admin Tab (Global Admin only)
class CreateRegionalAdminTab extends StatefulWidget {
  const CreateRegionalAdminTab({super.key});

  @override
  State<CreateRegionalAdminTab> createState() => _CreateRegionalAdminTabState();
}

class _CreateRegionalAdminTabState extends State<CreateRegionalAdminTab> {
  final ApiClient _apiClient = ApiClient();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _regionController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  Future<void> _createRegionalAdmin() async {
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();
    final region = _regionController.text.trim();
    
    if (email.isEmpty || name.isEmpty || region.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final token = await _apiClient.getToken();
      if (token == null) throw Exception('Not authenticated');
      
      final response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/v1/admin/create-regional'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'email': email,
          'name': name,
          'region': region,
        }),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Regional admin created successfully!')),
        );
        _emailController.clear();
        _nameController.clear();
        _regionController.clear();
        HapticService.trigger(HapticIntensity.light, context: context);
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${error['message'] ?? response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    if (!authProvider.isGlobalAdmin) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 64, color: M3Colors.outline),
            SizedBox(height: 16),
            Text(
              'Global Admin Access Required',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text('This section is only visible to Global Administrators'),
          ],
        ),
      );
    }
    
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.admin_panel_settings, size: 64, color: M3Colors.primary),
            const SizedBox(height: 16),
            const Text(
              'Create Regional Admin',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _regionController,
              decoration: const InputDecoration(
                labelText: 'Region',
                prefixIcon: Icon(Icons.map),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            CrystalButton(
              onPressed: _createRegionalAdmin,
              label: 'CREATE REGIONAL ADMIN',
              variant: CrystalButtonVariant.filled,
              isLoading: _isLoading,
              isExpanded: true,
            ),
          ],
        ),
      ),
    );
  }
}

// Create Branch Pastor Tab (Regional Admin+)
class CreateBranchPastorTab extends StatefulWidget {
  const CreateBranchPastorTab({super.key});

  @override
  State<CreateBranchPastorTab> createState() => _CreateBranchPastorTabState();
}

class _CreateBranchPastorTabState extends State<CreateBranchPastorTab> {
  final ApiClient _apiClient = ApiClient();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _branchNameController = TextEditingController();
  String? _selectedBranchId;
  List<Branch> _branches = [];
  bool _isLoadingBranches = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _branchNameController.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    setState(() => _isLoadingBranches = true);
    
    try {
      final branches = await BranchService.getAllBranches();
      setState(() {
        _branches = branches;
        _isLoadingBranches = false;
      });
    } catch (e) {
      setState(() => _isLoadingBranches = false);
    }
  }

  Future<void> _createBranchClergy() async {
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text.trim();
    final branchName = _branchNameController.text.trim();
    
    if (email.isEmpty || name.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    try {
      final token = await _apiClient.getToken();
      if (token == null) throw Exception('Not authenticated');
      
      // First, create the branch if a new branch name is provided
      String? branchId = _selectedBranchId;
      
      if (branchName.isNotEmpty && branchId == null) {
        final createBranchResponse = await http.post(
          Uri.parse('${ApiClient.baseUrl}/v1/branches'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'name': branchName,
            'address': 'To be updated',
            'latitude': -1.286389,
            'longitude': 36.817223,
            'senior_pastor': name,
            'phone': '',
            'email': email,
            'service_times': {},
          }),
        );
        
        if (createBranchResponse.statusCode == 200 || createBranchResponse.statusCode == 201) {
          final branchData = jsonDecode(createBranchResponse.body);
          branchId = branchData['id'];
        } else {
          throw Exception('Failed to create branch');
        }
      }
      
      if (branchId == null) {
        throw Exception('Please select a branch or provide a branch name');
      }
      
      // Create the clergy user
      final response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/v1/admin/create-clergy'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'email': email,
          'name': name,
          'password': password,
          'role': 'branch_clergy',
          'branch_id': branchId,
        }),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Branch clergy created successfully!')),
        );
        _emailController.clear();
        _nameController.clear();
        _passwordController.clear();
        _branchNameController.clear();
        setState(() => _selectedBranchId = null);
        HapticService.trigger(HapticIntensity.light, context: context);
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${error['message'] ?? response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
    
    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    if (!authProvider.isAdmin) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 64, color: M3Colors.outline),
            SizedBox(height: 16),
            Text('Admin Access Required'),
          ],
        ),
      );
    }
    
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.person_add, size: 64, color: M3Colors.primary),
            const SizedBox(height: 16),
            const Text(
              'Create Branch Clergy',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            
            // Email Field
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address *',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            
            // Full Name Field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            
            // Password Field
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Temporary Password *',
                hintText: 'User will be prompted to change on first login',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            
            // Branch Selection
            _isLoadingBranches
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Assign to Existing Branch (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedBranchId,
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('-- Create a new branch instead --'),
                      ),
                      ..._branches.map((branch) {
                        return DropdownMenuItem<String>(
                          value: branch.id,
                          child: Text(branch.name),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedBranchId = value;
                        if (value != null) {
                          _branchNameController.clear();
                        }
                      });
                    },
                  ),
            const SizedBox(height: 12),
            
            // New Branch Name Field (shown when no existing branch selected)
            if (_selectedBranchId == null)
              TextField(
                controller: _branchNameController,
                decoration: const InputDecoration(
                  labelText: 'Or Create New Branch *',
                  hintText: 'e.g., Nairobi Central, Westlands Worship Centre',
                  prefixIcon: Icon(Icons.store),
                  border: OutlineInputBorder(),
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Submit Button
            CrystalButton(
              onPressed: _createBranchClergy,
              label: 'CREATE BRANCH CLERGY',
              variant: CrystalButtonVariant.filled,
              isLoading: _isSubmitting,
              isExpanded: true,
            ),
            
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: M3Colors.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: M3Colors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The clergy will receive their credentials and can log in to manage their branch.',
                      style: TextStyle(fontSize: 12, color: M3Colors.onSurfaceVariant),
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
}

// User Management Tab - Fetches real users from backend
class UserManagementTab extends StatefulWidget {
  const UserManagementTab({super.key});

  @override
  State<UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<UserManagementTab> {
  final ApiClient _apiClient = ApiClient();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    
    try {
      final token = await _apiClient.getToken();
      if (token == null) throw Exception('Not authenticated');
      
      final headers = {'Authorization': 'Bearer $token'};
      
      // Fetch clergy users
      final clergyResponse = await http.get(
        Uri.parse('${ApiClient.baseUrl}/v1/admin/clergy'),
        headers: headers,
      );
      
      if (clergyResponse.statusCode == 200) {
        final List<dynamic> clergy = jsonDecode(clergyResponse.body);
        for (var user in clergy) {
          _users.add({
            'id': user['id'],
            'name': user['name'],
            'email': user['email'],
            'role': user['role'] ?? 'Branch Clergy',
            'branch': user['branch_name'] ?? 'Not assigned',
          });
        }
      }
      
      // Fetch members
      final membersResponse = await http.get(
        Uri.parse('${ApiClient.baseUrl}/v1/members'),
        headers: headers,
      );
      
      if (membersResponse.statusCode == 200) {
        final List<dynamic> members = jsonDecode(membersResponse.body);
        for (var member in members) {
          _users.add({
            'id': member['id'],
            'name': member['name'],
            'email': member['email'],
            'role': 'Verified Member',
            'branch': member['branch_name'] ?? 'N/A',
          });
        }
      }
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: M3Colors.error),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: M3Colors.error)),
            const SizedBox(height: 16),
            CrystalButton(
              onPressed: _loadUsers,
              label: 'RETRY',
              variant: CrystalButtonVariant.outlined,
            ),
          ],
        ),
      );
    }
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _users.map((user) {
        return _buildUserTile(
          user['name'] ?? 'Unknown',
          user['role'] ?? 'User',
          user['branch'] ?? 'N/A',
        );
      }).toList(),
    );
  }
  
  Widget _buildUserTile(String name, String role, String branch) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: M3Colors.primaryContainer,
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', 
              style: const TextStyle(color: M3Colors.primary)),
        ),
        title: Text(name),
        subtitle: Text('$role • $branch'),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            // TODO: Implement edit/reset/suspend actions
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'reset', child: Text('Reset Password')),
            const PopupMenuItem(value: 'suspend', child: Text('Suspend')),
          ],
        ),
      ),
    );
  }
}