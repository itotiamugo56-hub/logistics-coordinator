import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class ApiClient {
  static const String baseUrl = 'http://127.0.0.1:8080';
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  
  // ============================================================
  // Token Management
  // ============================================================
  
  Future<void> saveToken(String token) async {
    await storage.write(key: 'access_token', value: token);
  }
  
  Future<String?> getToken() async {
    return await storage.read(key: 'access_token');
  }
  
  Future<void> clearToken() async {
    await storage.delete(key: 'access_token');
  }
  
  Future<Map<String, dynamic>> issueToken({
    required String delegateToRole,
    required String subjectMemberId,
    required int expiresInSeconds,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/auth/token/issue'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'delegate_to_role': delegateToRole,
        'subject_member_id': subjectMemberId,
        'expires_in_seconds': expiresInSeconds,
        'constraints': {
          'allowed_branch_geohashes': [],
          'max_pickup_radius_km': 5,
          'can_verify_members': false,
        },
        'delegation_chain_proof': '',
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await saveToken(data['access_token']);
      return data;
    } else {
      throw Exception('Failed to issue token: ${response.statusCode} - ${response.body}');
    }
  }
  
// ============================================================
// Auth Endpoints (OTP Flow)
// ============================================================

/// Register new member (sends OTP to email)
Future<Map<String, dynamic>> register(String email, String name) async {
  final response = await http.post(
    Uri.parse('$baseUrl/v1/auth/register'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'name': name,
    }),
  );
  
  print('📝 Register response: ${response.statusCode} - ${response.body}');
  
  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else if (response.statusCode == 409) {
    throw Exception('Email already registered');
  } else {
    throw Exception('Registration failed: ${response.statusCode}');
  }
}

/// Verify OTP and get access token
Future<Map<String, dynamic>> verifyOtp(String memberId, String otp) async {
  final response = await http.post(
    Uri.parse('$baseUrl/v1/auth/verify'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'member_id': memberId,
      'otp': otp,
    }),
  );
  
  print('🔐 Verify response: ${response.statusCode} - ${response.body}');
  
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    await saveToken(data['access_token']);
    return data;
  } else if (response.statusCode == 401) {
    throw Exception('Invalid OTP');
  } else {
    throw Exception('Verification failed: ${response.statusCode}');
  }
}

/// Login for existing verified members (email + OTP)
Future<Map<String, dynamic>> login(String email, String otp) async {
  final response = await http.post(
    Uri.parse('$baseUrl/v1/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'otp': otp,
    }),
  );
  
  print('🔑 Login response: ${response.statusCode} - ${response.body}');
  
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    await saveToken(data['access_token']);
    return data;
  } else {
    throw Exception('Login failed: ${response.statusCode}');
  }
}
  
  // ============================================================
  // Signal Flare (Anonymous-friendly)
  // ============================================================
  
  Future<Map<String, dynamic>> submitFlare({
    required double lat,
    required double lng,
    required String geohash10,
    String? biometricProof,
  }) async {
    final token = await getToken();
    
    // Build headers - token is optional for anonymous submissions
    final headers = {
      'Content-Type': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    final response = await http.post(
      Uri.parse('$baseUrl/v1/flare/submit'),
      headers: headers,
      body: jsonEncode({
        'lat': lat,
        'lng': lng,
        'geohash10': geohash10,
      }),
    );
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      await clearToken();
      throw Exception('Session expired. Please re-authenticate.');
    } else {
      throw Exception('Failed to submit flare: ${response.statusCode} - ${response.body}');
    }
  }
  
  Future<Map<String, dynamic>> getFlareStatus(String flareId) async {
    final token = await getToken();
    
    final headers = <String, String>{};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    final response = await http.get(
      Uri.parse('$baseUrl/v1/flare/status/$flareId'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get status: ${response.statusCode}');
    }
  }
  
  // ============================================================
  // Proximity
  // ============================================================
  
  Future<Map<String, dynamic>> findNearbyBranches({
    required String geohash10,
    required double radiusKm,
    bool includeClergyContact = false,
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('No token available');
    
    final response = await http.post(
      Uri.parse('$baseUrl/v1/location/proximity'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'geohash_10': geohash10,
        'radius_km': radiusKm,
        'include_clergy_contact': includeClergyContact,
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to find branches: ${response.statusCode}');
    }
  }
  
  // ============================================================
  // Sync (CRDT)
  // ============================================================
  
  Future<Map<String, dynamic>> syncPull(Map<String, int> vectorClock) async {
    final token = await getToken();
    if (token == null) throw Exception('No token available');
    
    final response = await http.post(
      Uri.parse('$baseUrl/v1/sync/pull'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'vector_clock': {'entries': vectorClock},
        'last_sync_token': null,
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to sync pull: ${response.statusCode}');
    }
  }
  
  Future<Map<String, dynamic>> syncPush(List<dynamic> ops, Map<String, int> vectorClock) async {
    final token = await getToken();
    if (token == null) throw Exception('No token available');
    
    final response = await http.post(
      Uri.parse('$baseUrl/v1/sync/push'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'pending_ops': ops,
        'vector_clock': {'entries': vectorClock},
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to sync push: ${response.statusCode}');
    }
  }
  
  // ============================================================
  // Health Check
  // ============================================================
  
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200 && response.body == 'OK';
    } catch (e) {
      return false;
    }
  }
}