import 'package:flutter/material.dart';
import '../services/api_client.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _tokenData;
  
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  Future<bool> login({
    required String memberId,
    required String role,
    required int expiresInSeconds,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _tokenData = await _apiClient.issueToken(
        delegateToRole: role,
        subjectMemberId: memberId,
        expiresInSeconds: expiresInSeconds,
      );
      
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  Future<void> logout() async {
    await _apiClient.clearToken();
    _isAuthenticated = false;
    _tokenData = null;
    notifyListeners();
  }
  
  String? get token => _tokenData?['access_token'];
}
