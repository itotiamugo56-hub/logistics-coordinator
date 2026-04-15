class Branch {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String seniorPastor;
  final String phone;
  final String email;
  final Map<String, List<String>> serviceTimes; // {"Sunday": ["8:00 AM", "10:00 AM"]}
  final String? announcement;
  final bool isVerified;
  
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
    this.isVerified = true,
  });
  
  double distanceFrom(double userLat, double userLng) {
    // Haversine formula
    const double R = 6371; // Earth radius in km
    double dLat = (latitude - userLat) * 3.14159 / 180;
    double dLng = (longitude - userLng) * 3.14159 / 180;
    double a = (dLat / 2).sin() * (dLat / 2).sin() +
               userLat.toRadians().cos() * latitude.toRadians().cos() *
               (dLng / 2).sin() * (dLng / 2).sin();
    double c = 2 * a.sqrt().atan2((1 - a).sqrt());
    return R * c;
  }
}
