import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:city_path/screens/destination_search_screen.dart';
import 'package:city_path/screens/route_results_screen.dart';
import 'package:city_path/screens/navigation_screen.dart';
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

  // Current location - will be updated with real GPS coordinates
  List<double>? _currentLocation;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // Get user's current location
  Future<void> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are not enabled, use default location (Tel Aviv)
        setState(() {
          _currentLocation = [32.0853, 34.7818];
        });
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Permissions are denied, use default location
          setState(() {
            _currentLocation = [32.0853, 34.7818];
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permissions are denied forever, use default location
        setState(() {
          _currentLocation = [32.0853, 34.7818];
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = [position.latitude, position.longitude];
      });

      // Update map camera to current location
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
        );
      }
    } catch (e) {
      print("Error getting current location: $e");
      // Use default location if error occurs
      setState(() {
        _currentLocation = [32.0853, 34.7818];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading if current location is not available yet
    if (_currentLocation == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF9F2E9),
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
                    target: LatLng(_currentLocation![0], _currentLocation![1]),
                    zoom: 14,
                  ),
                  onMapCreated: (controller) async {
                    _mapController = controller;
                    // Note: Crime layer loading removed as requested
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

                  if (_selectedLatLng != null) {
                    // Show loading dialog
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return const Center(child: CircularProgressIndicator());
                      },
                    );

                    try {
                      // Call server to get routes from current location to destination
                      final routeData = await RouteService.fetchSafeRoutes(
                        origin: _currentLocation!,
                        destination: _selectedLatLng!,
                      );

                      // Close loading dialog
                      Navigator.of(context).pop();

                      // Extract routes from response
                      final List<Map<String, dynamic>> routes =
                          List<Map<String, dynamic>>.from(
                            routeData['routes'] ?? [],
                          );

                      if (routes.isNotEmpty) {
                        // Navigate to route results screen
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => RouteResultsScreen(
                                  routes: routes,
                                  destinationAddress: _selectedDestination!,
                                ),
                          ),
                        );

                        // Handle the result from route results screen
                        if (result != null && result is Map) {
                          final action = result['action'];
                          final selectedRoute = result['route'];

                          if (action == 'select') {
                            // User wants to see route on map
                            _displaySelectedRoute(selectedRoute);
                          } else if (action == 'navigate') {
                            // User wants to start navigation
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => NavigationScreen(
                                      selectedRoute: selectedRoute,
                                      destinationAddress: _selectedDestination!,
                                    ),
                              ),
                            );
                          }
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'No routes found for this destination',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      // Close loading dialog
                      Navigator.of(context).pop();

                      print("Failed to fetch routes: $e");
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to calculate routes: $e'),
                        ),
                      );
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

  // Display the selected route on the map
  void _displaySelectedRoute(Map<String, dynamic> selectedRoute) {
    try {
      final List<dynamic> path = selectedRoute['path'] ?? [];

      if (path.isNotEmpty) {
        final polylinePoints =
            path.map<LatLng>((coord) => LatLng(coord[0], coord[1])).toList();

        // Route color based on safety level
        Color routeColor = _getRouteColor(selectedRoute['score'] ?? 0);

        setState(() {
          _polylines = {
            Polyline(
              polylineId: PolylineId(
                'selected_route_${selectedRoute['routeId']}',
              ),
              color: routeColor,
              width: 6,
              points: polylinePoints,
            ),
          };

          // Clear existing markers and add destination marker
          _markers.clear();
          if (_selectedLatLng != null) {
            _markers.add(
              Marker(
                markerId: const MarkerId('destination'),
                position: LatLng(_selectedLatLng![0], _selectedLatLng![1]),
                infoWindow: InfoWindow(
                  title: 'Destination',
                  snippet: _selectedDestination,
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),
              ),
            );
          }
        });

        // Focus on the route
        if (polylinePoints.isNotEmpty && _mapController != null) {
          _fitMapToRoute(polylinePoints);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Route selected! Safety: ${selectedRoute['score']}%'),
          ),
        );
      }
    } catch (e) {
      print("Error displaying route: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error displaying route on map')),
      );
    }
  }

  // Determine route color based on safety score
  Color _getRouteColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  // Fit map camera to show the entire route
  void _fitMapToRoute(List<LatLng> points) {
    if (points.isEmpty || _mapController == null) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        100.0, // padding
      ),
    );
  }
}
