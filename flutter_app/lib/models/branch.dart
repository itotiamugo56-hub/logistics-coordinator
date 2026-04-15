import 'dart:math';

class Branch {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String seniorPastor;
  final String phone;
  final String email;
  final Map<String, List<String>> serviceTimes;
  final String? announcement;
  final bool isVerified;
  final DateTime lastUpdated;
  
  Branch({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.seniorPastor,
    required this.phone,
    required this.email,
    required this.serviceTimes,
    this.announcement,
    required this.isVerified,
    required this.lastUpdated,
  });
  
  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      seniorPastor: json['senior_pastor'],
      phone: json['phone'],
      email: json['email'],
      serviceTimes: Map.from(json['service_times']).map(
        (k, v) => MapEntry(k, List<String>.from(v))
      ),
      announcement: json['announcement'],
      isVerified: json['is_verified'],
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(json['last_updated'] * 1000),
    );
  }
  
  double distanceFrom(double userLat, double userLng) {
    const double R = 6371; // Earth radius in km
    double dLat = _toRadians(latitude - userLat);
    double dLng = _toRadians(longitude - userLng);
    double a = sin(dLat / 2) * sin(dLat / 2) +
               cos(_toRadians(userLat)) * cos(_toRadians(latitude)) *
               sin(dLng / 2) * sin(dLng / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
  
  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }
  
  String getFormattedDistance(double userLat, double userLng) {
    double km = distanceFrom(userLat, userLng);
    if (km < 1) {
      return '${(km * 1000).toInt()} m';
    }
    return '${km.toStringAsFixed(1)} km';
  }
}
