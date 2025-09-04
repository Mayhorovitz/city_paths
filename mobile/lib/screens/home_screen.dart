// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:city_path/screens/destination_search_screen.dart';
import 'package:city_path/screens/route_results_screen.dart';
import 'package:city_path/screens/navigation_screen.dart';
import 'package:city_path/services/route_service.dart';
import 'package:city_path/services/location_service.dart';
import 'package:city_path/services/map_report_service.dart';
import 'package:city_path/screens/profile_screen.dart';

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
  Map<String, dynamic>? _selectedRouteData;

  // Current location
  List<double>? _currentLocation;
  bool _loadingReports = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    final location = await LocationService.getCurrentLocation();
    setState(() {
      _currentLocation = location;
    });

    if (_mapController != null && _currentLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(_currentLocation![0], _currentLocation![1]),
        ),
      );
    }

    _loadNearbyReports();
  }

  Future<void> _loadNearbyReports() async {
    if (_currentLocation == null) return;

    setState(() {
      _loadingReports = true;
    });

    try {
      final reportMarkers = await MapReportService.getReportMarkersNearby(
        latitude: _currentLocation![0],
        longitude: _currentLocation![1],
        radiusKm: 2.0,
        onReportTap: _showReportDetails,
      );

      setState(() {
        // Remove old report markers, keep others
        _markers.removeWhere(
          (marker) => marker.markerId.value.startsWith('report_'),
        );
        _markers.addAll(reportMarkers);
        _loadingReports = false;
      });
    } catch (e) {
      print("Error loading reports: $e");
      setState(() {
        _loadingReports = false;
      });
    }
  }

  void _showReportDetails(Map<String, dynamic> report) {
    MapReportService.showReportDetailsBottomSheet(
      context: context,
      report: report,
      isInNavigation: false,
    );
  }

  @override
  Widget build(BuildContext context) {
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
        actions: [
          IconButton(
            onPressed: _loadingReports ? null : _loadNearbyReports,
            icon:
                _loadingReports
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Reports',
          ),
        ],
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
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  markers: _markers,
                  polylines: _polylines,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSearchField(),
            if (_selectedRouteData != null) ...[
              const SizedBox(height: 12),
              _buildNavigationButton(),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildSearchField() {
    return TextField(
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
          borderSide: BorderSide(color: Colors.teal.shade300, width: 1.5),
        ),
      ),
      onTap: _handleDestinationSearch,
    );
  }

  Widget _buildNavigationButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => NavigationScreen(
                    selectedRoute: _selectedRouteData!,
                    destinationAddress: _selectedDestination!,
                  ),
            ),
          );
        },
        icon: const Icon(Icons.navigation, size: 24),
        label: Text(
          'Start Navigation to ${_selectedDestination ?? 'Destination'}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      selectedItemColor: Colors.teal,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
      currentIndex: _selectedIndex,
      onTap: (index) {
        if (index == 1) {
          // Profile tab
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        } else {
          setState(() {
            _selectedIndex = index;
          });
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }

  Future<void> _handleDestinationSearch() async {
    final selected = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DestinationSearchScreen()),
    );

    if (selected != null && selected is Map) {
      setState(() {
        _selectedDestination = selected["address"];
        _selectedLatLng = List<double>.from(selected["latlng"]);
      });

      if (_selectedLatLng != null) {
        _showLoadingDialog();

        try {
          final routeData = await RouteService.fetchSafeRoutes(
            origin: _currentLocation!,
            destination: _selectedLatLng!,
          );

          Navigator.of(context).pop();

          final routes = List<Map<String, dynamic>>.from(
            routeData['routes'] ?? [],
          );

          if (routes.isNotEmpty) {
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

            if (result != null && result is Map) {
              _handleRouteResult(result);
            }
          } else {
            _showSnackBar('No routes found for this destination');
          }
        } catch (e) {
          Navigator.of(context).pop();
          _showSnackBar('Failed to calculate routes: $e');
        }
      }
    }
  }

  void _handleRouteResult(Map result) {
    final action = result['action'];
    final selectedRoute = result['route'];

    if (action == 'select') {
      _displaySelectedRoute(selectedRoute);
      _selectedRouteData = selectedRoute;
    } else if (action == 'navigate') {
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

  void _displaySelectedRoute(Map<String, dynamic> selectedRoute) {
    try {
      final List<dynamic> path = selectedRoute['path'] ?? [];

      if (path.isNotEmpty) {
        final polylinePoints =
            path.map<LatLng>((coord) => LatLng(coord[0], coord[1])).toList();

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

          // Remove old destination marker and add new one
          _markers.removeWhere(
            (marker) => marker.markerId.value == 'destination',
          );
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

        if (polylinePoints.isNotEmpty && _mapController != null) {
          _fitMapToRoute(polylinePoints);
        }

        _showSnackBar('Route selected! Safety: ${selectedRoute['score']}%');
      }
    } catch (e) {
      print("Error displaying route: $e");
      _showSnackBar('Error displaying route on map');
    }
  }

  Color _getRouteColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

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
        100.0,
      ),
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
