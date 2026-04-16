import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'access_token';
  static const _memberIdKey = 'member_id';
  static const _roleKey = 'role';
  static const _nameKey = 'name';
  static const _expiresAtKey = 'expires_at';

  /// Save authentication data after successful login
  static Future<void> saveAuthData({
    required String token,
    required String memberId,
    required String role,
    required String name,
    required int expiresIn,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _memberIdKey, value: memberId);
    await _storage.write(key: _roleKey, value: role);
    await _storage.write(key: _nameKey, value: name);
    await _storage.write(key: _expiresAtKey, value: 
        (DateTime.now().millisecondsSinceEpoch + expiresIn * 1000).toString());
  }

  /// Get stored access token
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Get stored member ID
  static Future<String?> getMemberId() async {
    return await _storage.read(key: _memberIdKey);
  }

  /// Get stored role
  static Future<String?> getRole() async {
    return await _storage.read(key: _roleKey);
  }

  /// Get stored name
  static Future<String?> getName() async {
    return await _storage.read(key: _nameKey);
  }

  /// Check if token is expired
  static Future<bool> isTokenExpired() async {
    final expiresAtStr = await _storage.read(key: _expiresAtKey);
    if (expiresAtStr == null) return true;
    
    final expiresAt = int.tryParse(expiresAtStr) ?? 0;
    return DateTime.now().millisecondsSinceEpoch > expiresAt;
  }

  /// Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final token = await getToken();
    if (token == null) return false;
    return !(await isTokenExpired());
  }

  /// Get user info as map
  static Future<Map<String, String>> getUserInfo() async {
    return {
      'memberId': await getMemberId() ?? '',
      'role': await getRole() ?? '',
      'name': await getName() ?? 'Verified Member',
    };
  }

  /// Get auth headers for API requests
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    if (token == null) return {};
    return {'Authorization': 'Bearer $token'};
  }

  /// Clear all auth data (logout)
  static Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _memberIdKey);
    await _storage.delete(key: _roleKey);
    await _storage.delete(key: _nameKey);
    await _storage.delete(key: _expiresAtKey);
  }
  
  /// Simple login method for backward compatibility
  static Future<bool> login(String email, String otp) async {
    // This is a simplified version - in production, call the API
    // For now, return true for demo purposes
    return otp == '123456';
  }
}