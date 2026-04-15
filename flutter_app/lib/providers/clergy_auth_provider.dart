import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ClergyAuthProvider extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;
  String? _branchId;
  String? _clergyName;
  
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get branchId => _branchId;
  String? get clergyName => _clergyName;
  
  Future<bool> login(String email, String otp) async {
    _setState(true, null);
    
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8080/v1/clergy/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': otp}),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _storage.write(key: 'clergy_token', value: data['token']);
        await _storage.write(key: 'clergy_branch_id', value: data['branch_id']);
        await _storage.write(key: 'clergy_name', value: data['name']);
        
        _branchId = data['branch_id'];
        _clergyName = data['name'];
        _isAuthenticated = true;
        _setState(false, null);
        return true;
      } else {
        _setState(false, 'Invalid credentials');
        return false;
      }
    } catch (e) {
      _setState(false, 'Network error: $e');
      return false;
    }
  }
  
  Future<void> logout() async {
    await _storage.deleteAll();
    _isAuthenticated = false;
    _branchId = null;
    _clergyName = null;
    notifyListeners();
  }
  
  Future<void> checkAuth() async {
    final token = await _storage.read(key: 'clergy_token');
    if (token != null) {
      _branchId = await _storage.read(key: 'clergy_branch_id');
      _clergyName = await _storage.read(key: 'clergy_name');
      _isAuthenticated = true;
      notifyListeners();
    }
  }
  
  void _setState(bool loading, String? error) {
    _isLoading = loading;
    _error = error;
    notifyListeners();
  }
}
