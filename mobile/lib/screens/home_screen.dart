import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:city_path/services/map_layer_service.dart';
import 'package:city_path/screens/destination_search_screen.dart';
import 'package:city_path/services/route_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String? _selectedDestination;
  List<double>? _selectedLatLng;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // Example fixed current location (can be replaced with real geolocator)
  final List<double> _currentLocation = [32.0853, 34.7818];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F2E9),
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: const Text('City Path', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_currentLocation[0], _currentLocation[1]),
                    zoom: 14,
                  ),
                  onMapCreated: (controller) async {
                    _mapController = controller;
                    try {
                      final geoJson = await MapLayerService.fetchLayer('crime');
                      final features = geoJson['features'] as List;
                      Set<Marker> newMarkers = {};
                      for (var feature in features) {
                        final geometry = feature['geometry'];
                        final props = feature['properties'];
                        final coords = geometry['coordinates'];
                        final lat = coords[1];
                        final lng = coords[0];
                        final marker = Marker(
                          markerId: MarkerId('$lat$lng'),
                          position: LatLng(lat, lng),
                          infoWindow: InfoWindow(
                            title: props['description'] ?? 'Crime point',
                            snippet: 'Level: ${props['level'] ?? 'unknown'}',
                          ),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueRed,
                          ),
                        );
                        newMarkers.add(marker);
                      }
                      setState(() {
                        _markers = newMarkers;
                      });
                    } catch (e) {
                      print("Error loading crime layer: $e");
                    }
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  markers: _markers,
                  polylines: _polylines,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              readOnly: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Colors.black54),
                hintText: _selectedDestination ?? 'Where would you like to go?',
                hintStyle: const TextStyle(color: Colors.black54),
                filled: true,
                fillColor: const Color(0xFFF9F2E9),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 20,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.teal.shade300,
                    width: 1.5,
                  ),
                ),
              ),
              onTap: () async {
                final selected = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DestinationSearchScreen(),
                  ),
                );
                if (selected != null && selected is Map) {
                  setState(() {
                    _selectedDestination = selected["address"];
                    _selectedLatLng = List<double>.from(selected["latlng"]);
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Selected: $_selectedDestination')),
                  );

                  if (_selectedLatLng != null) {
                    // Call the server to get routes
                    try {
                      final routes = await RouteService.fetchSafeRoutes(
                        origin: _currentLocation,
                        destination: _selectedLatLng!,
                      );

                      // Example: Draw the first route on the map
                      if (routes.isNotEmpty && routes[0]['path'] != null) {
                        final List<dynamic> path = routes[0]['path'];
                        final polylinePoints =
                            path
                                .map<LatLng>(
                                  (coord) => LatLng(coord[0], coord[1]),
                                )
                                .toList();

                        setState(() {
                          _polylines = {
                            Polyline(
                              polylineId: const PolylineId('route_1'),
                              color: Colors.blue,
                              width: 6,
                              points: polylinePoints,
                            ),
                          };
                        });
                      }
                    } catch (e) {
                      print("Failed to fetch or draw route: $e");
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.report), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
