import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;
  String? _token;
  String? _memberId;
  String? _role;
  String? _name;
  String? _email;
  int? _roleLevel;
  
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get token => _token;
  String? get memberId => _memberId;
  String? get role => _role;
  String? get name => _name;
  String? get email => _email;
  int? get roleLevel => _roleLevel;
  
  // Role-based access helpers
  bool get isGlobalAdmin => _role?.toLowerCase() == 'globaladmin' || _roleLevel == 0;
  bool get isRegionalAdmin => _role?.toLowerCase() == 'regionaladmin' || _roleLevel == 1;
  bool get isBranchPastor => _role?.toLowerCase() == 'branchpastor' || _roleLevel == 2;
  bool get isBranchStaff => _role?.toLowerCase() == 'branchstaff' || _roleLevel == 3;
  bool get isBranchClergy => _role?.toLowerCase() == 'branchclergy' || _roleLevel == 2;  // ADD THIS
  bool get isVerifiedMember => _role?.toLowerCase() == 'verifiedmember' || _roleLevel == 4;
  bool get isClergy => isBranchPastor || isBranchStaff || isBranchClergy;  // UPDATE THIS
  bool get isAdmin => isGlobalAdmin || isRegionalAdmin;
  
  int _getRoleLevel(String role) {
    switch (role.toLowerCase()) {
      case 'globaladmin': return 0;
      case 'regionaladmin': return 1;
      case 'branchpastor': return 2;
      case 'branchclergy': return 2;  // ADD THIS
      case 'branchstaff': return 3;
      case 'verifiedmember': return 4;
      default: return 4;
    }
  }
  
  Future<void> checkAuthStatus() async {
    _isAuthenticated = await AuthService.isAuthenticated();
    if (_isAuthenticated) {
      final userInfo = await AuthService.getUserInfo();
      _token = await AuthService.getToken();
      _memberId = userInfo['memberId'];
      _role = userInfo['role'];
      _roleLevel = _role != null ? _getRoleLevel(_role!) : 4;
      _name = userInfo['name'];
    }
    notifyListeners();
  }
  
  /// Register new member (sends OTP to email)
  Future<bool> register(String email, String name) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiClient.register(email, name);
      _memberId = response['member_id'];
      _email = email;
      _name = name;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Verify OTP after registration
  Future<bool> verifyRegistration(String memberId, String otp) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final data = await _apiClient.verifyOtp(memberId, otp);
      _isAuthenticated = true;
      _token = data['access_token'];
      _role = data['role'];
      _roleLevel = _getRoleLevel(_role!);
      _memberId = memberId;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Login for existing verified members or clergy
  Future<bool> login(String email, String otp) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final data = await _apiClient.login(email, otp);
      _isAuthenticated = true;
      _token = data['access_token'];
      _memberId = data['member_id'];
      _role = data['role'];
      _roleLevel = _getRoleLevel(_role!);
      _name = data['name'];
      _email = email;
      
      print('✅ Login successful - Role: $_role, RoleLevel: $_roleLevel');  // Debug
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  Future<void> logout() async {
    await AuthService.logout();
    await _apiClient.clearToken();
    _isAuthenticated = false;
    _token = null;
    _memberId = null;
    _role = null;
    _roleLevel = null;
    _name = null;
    _email = null;
    _error = null;
    notifyListeners();
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
}