import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../models/flare_model.dart';

class FlareProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  
  List<FlareModel> _flares = [];
  bool _isSubmitting = false;
  String? _lastError;
  
  List<FlareModel> get flares => _flares;
  bool get isSubmitting => _isSubmitting;
  String? get lastError => _lastError;
  
  Future<Map<String, dynamic>?> submitFlare({
    required double lat,
    required double lng,
    required String geohash10,
  }) async {
    _isSubmitting = true;
    _lastError = null;
    notifyListeners();
    
    try {
      final result = await _apiClient.submitFlare(
        lat: lat,
        lng: lng,
        geohash10: geohash10,
      );
      
      final flare = FlareModel.fromJson(result);
      _flares.insert(0, flare);
      
      _isSubmitting = false;
      notifyListeners();
      return result;
    } catch (e) {
      _lastError = e.toString();
      _isSubmitting = false;
      notifyListeners();
      return null;
    }
  }
  
  Future<void> refreshStatus(String flareId) async {
    try {
      final status = await _apiClient.getFlareStatus(flareId);
      final index = _flares.indexWhere((f) => f.id == flareId);
      if (index != -1) {
        _flares[index].updateFromJson(status);
        notifyListeners();
      }
    } catch (e) {
      // Silent fail for background refresh
    }
  }
}
