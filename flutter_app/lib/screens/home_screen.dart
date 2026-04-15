import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/auth_provider.dart';
import '../providers/flare_provider.dart';
import '../utils/geohash_helper.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Position? _currentPosition;
  String? _currentGeohash;
  bool _isLoadingLocation = true;
  String? _locationError;
  
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }
  
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'Location services are disabled.';
          _isLoadingLocation = false;
        });
        return;
      }
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = 'Location permissions are denied.';
            _isLoadingLocation = false;
          });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = 'Location permissions are permanently denied.';
          _isLoadingLocation = false;
        });
        return;
      }
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      final geohash = GeohashHelper.encode(
        position.latitude,
        position.longitude,
        10,
      );
      
      setState(() {
        _currentPosition = position;
        _currentGeohash = geohash;
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _locationError = 'Error getting location: $e';
        _isLoadingLocation = false;
      });
    }
  }
  
  Future<void> _sendFlare() async {
    if (_currentPosition == null || _currentGeohash == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for GPS fix...')),
      );
      return;
    }
    
    final flareProvider = context.read<FlareProvider>();
    
    final result = await flareProvider.submitFlare(
      lat: _currentPosition!.latitude,
      lng: _currentPosition!.longitude,
      geohash10: _currentGeohash!,
    );
    
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Signal Flare sent! ID: ${result['flare_id'].toString().substring(0, 8)}...'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (flareProvider.lastError != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(flareProvider.lastError!)),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zero-Trust Logistics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getCurrentLocation,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthProvider>().logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Icon(
                  _isLoadingLocation ? Icons.gps_off : (_locationError != null ? Icons.gps_not_fixed : Icons.gps_fixed),
                  color: _locationError != null ? Colors.red : (_isLoadingLocation ? Colors.orange : Colors.green),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _isLoadingLocation
                      ? const Text('Acquiring GPS signal...')
                      : _locationError != null
                          ? Text(_locationError!, style: const TextStyle(color: Colors.red))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Lat: ${_currentPosition?.latitude.toStringAsFixed(6)}'),
                                Text('Lng: ${_currentPosition?.longitude.toStringAsFixed(6)}'),
                                Text('Geohash: $_currentGeohash', style: const TextStyle(fontSize: 10)),
                              ],
                            ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: Container(
              color: Colors.grey.shade200,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Map View (MapLibre)'),
                    Text('Will show nearby branches and clergy location', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
          
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Consumer<FlareProvider>(
              builder: (context, flareProvider, _) {
                if (flareProvider.flares.isEmpty) {
                  return const Center(
                    child: Text('No recent Signal Flares'),
                  );
                }
                
                return ListView.builder(
                  itemCount: flareProvider.flares.length,
                  itemBuilder: (context, index) {
                    final flare = flareProvider.flares[index];
                    return ListTile(
                      leading: Icon(Icons.warning, color: flare.statusColor),
                      title: Text('Flare: ${flare.id.substring(0, 8)}...'),
                      subtitle: Text(
                        'Status: ${flare.status} • ${DateFormat('HH:mm').format(flare.serverReceivedTime)}',
                      ),
                      trailing: flare.etaSeconds != null
                          ? Text('ETA: ${flare.etaSeconds! ~/ 60}m')
                          : null,
                      onTap: () {
                        // Show flare details
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoadingLocation || _locationError != null ? null : _sendFlare,
        icon: const Icon(Icons.warning),
        label: const Text('SIGNAL FLARE'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
