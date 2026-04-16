import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/haptic_service.dart';
import '../widgets/crystal_button.dart';

class LocationPicker extends StatefulWidget {
  final Function(double lat, double lng, String address) onLocationSelected;
  final LatLng? initialLocation;
  final String? initialAddress;

  const LocationPicker({
    super.key,
    required this.onLocationSelected,
    this.initialLocation,
    this.initialAddress,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  late MapController _mapController;
  late LatLng _selectedLocation;
  String _selectedAddress = '';
  bool _isLoading = false;
  final _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedLocation = widget.initialLocation ?? const LatLng(-1.286389, 36.817223);
    _selectedAddress = widget.initialAddress ?? 'Nairobi, Kenya';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final encodedQuery = Uri.encodeComponent(query);
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=5'),
        headers: {'User-Agent': 'MinistryOfRepentance/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _searchResults = data;
          _showSearchResults = true;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _selectSearchResult(dynamic result) {
    final lat = double.parse(result['lat']);
    final lng = double.parse(result['lon']);
    final displayName = result['display_name'];

    setState(() {
      _selectedLocation = LatLng(lat, lng);
      _selectedAddress = displayName;
      _showSearchResults = false;
      _searchController.clear();
    });

    _mapController.move(_selectedLocation, 16);
    HapticService.trigger(HapticIntensity.light, context: context);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services')),
        );
        setState(() => _isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        setState(() => _isLoading = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Reverse geocode to get address
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json'),
        headers: {'User-Agent': 'MinistryOfRepentance/1.0'},
      );

      String address = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        address = data['display_name'] ?? address;
      }

      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _selectedAddress = address;
        _isLoading = false;
      });

      _mapController.move(_selectedLocation, 16);
      HapticService.trigger(HapticIntensity.medium, context: context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location updated to current position')),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }

  void _onMapTap(TapPosition, LatLng point) {
    setState(() {
      _selectedLocation = point;
    });
    _reverseGeocode(point);
    HapticService.trigger(HapticIntensity.light, context: context);
  }

  Future<void> _reverseGeocode(LatLng point) async {
    try {
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=${point.latitude}&lon=${point.longitude}&format=json'),
        headers: {'User-Agent': 'MinistryOfRepentance/1.0'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _selectedAddress = data['display_name'] ?? '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
        });
      }
    } catch (e) {
      setState(() {
        _selectedAddress = '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
      });
    }
  }

  void _confirmLocation() {
    HapticService.trigger(HapticIntensity.medium, context: context);
    widget.onLocationSelected(
      _selectedLocation.latitude,
      _selectedLocation.longitude,
      _selectedAddress,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Select Location'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: M3Colors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _useCurrentLocation,
            tooltip: 'Use my current location',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for a location...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _searchLocation,
            ),
          ),

          // Search Results
          if (_showSearchResults && _searchResults.isNotEmpty)
            Container(
              height: 200,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return ListTile(
                    leading: const Icon(Icons.location_on, color: M3Colors.primary),
                    title: Text(
                      result['display_name'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    onTap: () => _selectSearchResult(result),
                  );
                },
              ),
            ),

          // Map
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation,
                    initialZoom: 14,
                    onTap: _onMapTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLocation,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: M3Colors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: M3Colors.primary.withOpacity(0.5),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Center crosshair
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: M3Colors.primary.withOpacity(0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: M3Colors.primary, width: 2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Selected Location Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: M3Colors.outline.withOpacity(0.3)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: M3Colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedAddress,
                        style: const TextStyle(fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Lat: ${_selectedLocation.latitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 11, color: M3Colors.onSurfaceVariant),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Lng: ${_selectedLocation.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 11, color: M3Colors.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CrystalButton(
                  onPressed: _confirmLocation,
                  label: 'CONFIRM LOCATION',
                  variant: CrystalButtonVariant.filled,
                  isExpanded: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// M3Colors for consistency
class M3Colors {
  static const Color primary = Color(0xFF6750A4);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFEADDFF);
  static const Color secondary = Color(0xFF625B71);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color tertiary = Color(0xFF7D5260);
  static const Color surface = Color(0xFFFEF7FF);
  static const Color surfaceVariant = Color(0xFFE7E0EC);
  static const Color background = Color(0xFFFFFBFE);
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onSurface = Color(0xFF1C1B1F);
  static const Color onSurfaceVariant = Color(0xFF49454F);
  static const Color outline = Color(0xFF79747E);
  static const Color outlineVariant = Color(0xFFCAC4D0);
  static const Color success = Color(0xFF00C853);
  static const Color warning = Color(0xFFFFB300);
}