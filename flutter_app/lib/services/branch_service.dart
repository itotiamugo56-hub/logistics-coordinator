import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/branch.dart';

class BranchService {
  static const String baseUrl = 'http://127.0.0.1:8080';
  
  static Future<List<Branch>> getAllBranches() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/v1/branches'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Branch.fromJson(json)).toList();
      } else {
        print('Failed to load branches: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Network error fetching branches: $e');
      return [];
    }
  }
}
