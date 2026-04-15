class GeohashHelper {
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
  
  static String encode(double latitude, double longitude, int precision) {
    double latMin = -90.0;
    double latMax = 90.0;
    double lngMin = -180.0;
    double lngMax = 180.0;
    
    String geohash = '';
    bool isEven = true;
    int bit = 0;
    int ch = 0;
    
    while (geohash.length < precision) {
      if (isEven) {
        double mid = (lngMin + lngMax) / 2;
        if (longitude > mid) {
          ch |= (1 << bit);
          lngMin = mid;
        } else {
          lngMax = mid;
        }
      } else {
        double mid = (latMin + latMax) / 2;
        if (latitude > mid) {
          ch |= (1 << bit);
          latMin = mid;
        } else {
          latMax = mid;
        }
      }
      
      isEven = !isEven;
      bit++;
      
      if (bit == 5) {
        geohash += _base32[ch];
        bit = 0;
        ch = 0;
      }
    }
    
    return geohash;
  }
}
