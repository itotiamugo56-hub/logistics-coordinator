/// Simple Geohash encoder
class SimpleGeohash {
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
  
  /// Encode latitude and longitude to a geohash string
  static String encode(double latitude, double longitude, {int precision = 12}) {
    double latMin = -90.0;
    double latMax = 90.0;
    double lonMin = -180.0;
    double lonMax = 180.0;
    
    String geohash = '';
    bool isEven = true;
    int bit = 0;
    int ch = 0;
    
    while (geohash.length < precision) {
      if (isEven) {
        final double lonMid = (lonMin + lonMax) / 2.0;
        if (longitude > lonMid) {
          ch |= (1 << (4 - bit));
          lonMin = lonMid;
        } else {
          lonMax = lonMid;
        }
      } else {
        final double latMid = (latMin + latMax) / 2.0;
        if (latitude > latMid) {
          ch |= (1 << (4 - bit));
          latMin = latMid;
        } else {
          latMax = latMid;
        }
      }
      
      isEven = !isEven;
      
      if (bit < 4) {
        bit++;
      } else {
        geohash += _base32[ch];
        bit = 0;
        ch = 0;
      }
    }
    
    return geohash;
  }
  
  /// Decode geohash to latitude and longitude
  static (double latitude, double longitude) decode(String geohash) {
    double latMin = -90.0;
    double latMax = 90.0;
    double lonMin = -180.0;
    double lonMax = 180.0;
    bool isEven = true;
    
    for (int i = 0; i < geohash.length; i++) {
      final int ch = _base32.indexOf(geohash[i]);
      if (ch == -1) break;
      
      for (int bit = 4; bit >= 0; bit--) {
        final int mask = 1 << bit;
        if (isEven) {
          final double lonMid = (lonMin + lonMax) / 2.0;
          if ((ch & mask) != 0) {
            lonMin = lonMid;
          } else {
            lonMax = lonMid;
          }
        } else {
          final double latMid = (latMin + latMax) / 2.0;
          if ((ch & mask) != 0) {
            latMin = latMid;
          } else {
            latMax = latMid;
          }
        }
        isEven = !isEven;
      }
    }
    
    return ((latMin + latMax) / 2.0, (lonMin + lonMax) / 2.0);
  }
}
