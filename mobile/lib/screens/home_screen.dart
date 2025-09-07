// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:city_path/screens/destination_search_screen.dart';
import 'package:city_path/screens/route_results_screen.dart';
import 'package:city_path/screens/navigation_screen.dart';
import 'package:city_path/services/route_service.dart';
import 'package:city_path/services/location_service.dart';
import 'package:city_path/services/map_report_service.dart';
import 'package:city_path/services/auth_service.dart';
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

  // User data
  Map<String, dynamic>? _currentUser;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _initializeUserAndLocation();
  }

  Future<void> _initializeUserAndLocation() async {
    // Load user profile first
    await _loadUserProfile();

    // Then initialize location
    await _initializeLocation();
  }

  Future<void> _loadUserProfile() async {
    try {
      final result = await AuthService.getUserProfile();
      if (result['success']) {
        setState(() {
          _currentUser = result['user'];
          _isLoadingUser = false;
        });
        print(
          "User loaded: ${_currentUser?['firstName']} ${_currentUser?['lastName']}",
        );
        print("User preferences: ${_currentUser?['preferences']}");
      } else {
        setState(() {
          _isLoadingUser = false;
        });
        print("Failed to load user profile: ${result['message']}");
      }
    } catch (e) {
      setState(() {
        _isLoadingUser = false;
      });
      print("Error loading user profile: $e");
    }
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
    if (_currentLocation == null || _isLoadingUser) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9F2E9),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F2E9),
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: Row(
          children: [
            const Text('City Path', style: TextStyle(color: Colors.white)),
            if (_currentUser != null) ...[
              const Spacer(),
              Text(
                'Hi, ${_currentUser!['firstName']}!',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ],
        ),
        centerTitle: false,
        actions: [
          if (_currentUser?['preferences'] != null)
            IconButton(
              onPressed: () => _showUserPreferences(),
              icon: const Icon(Icons.tune, color: Colors.white),
              tooltip: 'Your Safety Preferences',
            ),
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
            // User preferences banner (if available)
            if (_currentUser?['preferences'] != null) _buildPreferencesBanner(),

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

  Widget _buildPreferencesBanner() {
    final prefs = _currentUser!['preferences'];
    final lightingPct = (prefs['lighting'] * 100).round();
    final businessPct = (prefs['business'] * 100).round();
    final crimePct = (prefs['crime'] * 100).round();
    final reportsPct = (prefs['reports'] * 100).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune, color: Colors.blue, size: 18),
              SizedBox(width: 8),
              Text(
                'Your Safety Priorities',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPrefChip('💡 ${lightingPct}%', Colors.amber),
              _buildPrefChip('🏪 ${businessPct}%', Colors.green),
              _buildPrefChip('🛡️ ${crimePct}%', Colors.red),
              _buildPrefChip('📢 ${reportsPct}%', Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrefChip(String text, Color color) {
    Color darkColor;
    switch (color) {
      case Colors.amber:
        darkColor = Colors.amber[700]!;
        break;
      case Colors.green:
        darkColor = Colors.green[700]!;
        break;
      case Colors.red:
        darkColor = Colors.red[700]!;
        break;
      case Colors.blue:
        darkColor = Colors.blue[700]!;
        break;
      default:
        darkColor = Colors.grey[700]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: darkColor,
        ),
      ),
    );
  }

  void _showUserPreferences() {
    final prefs = _currentUser!['preferences'];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Safety Preferences',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text('Routes are calculated based on your priorities:'),
                const SizedBox(height: 12),

                _buildPrefRow(
                  'Street Lighting',
                  prefs['lighting'],
                  Icons.lightbulb_outline,
                  Colors.amber,
                ),
                _buildPrefRow(
                  'Open Businesses',
                  prefs['business'],
                  Icons.store,
                  Colors.green,
                ),
                _buildPrefRow(
                  'Crime Avoidance',
                  prefs['crime'],
                  Icons.security,
                  Colors.red,
                ),
                _buildPrefRow(
                  'Community Reports',
                  prefs['reports'],
                  Icons.people,
                  Colors.blue,
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Modify Preferences'),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildPrefRow(String title, double value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(title)),
          Text(
            '${(value * 100).round()}%',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
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
          // Pass user ID if available
          final userId = _currentUser?['id'];

          final routeData = await RouteService.fetchSafeRoutes(
            origin: _currentLocation!,
            destination: _selectedLatLng!,
            userId: userId, // Pass user ID for preferences
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
                      scoringInfo: routeData['scoringInfo'],
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

        final prefsUsed =
            selectedRoute['userPreferences'] != null
                ? 'personalized'
                : 'default';
        _showSnackBar(
          'Route selected! Safety: ${selectedRoute['score']}% ($prefsUsed preferences)',
        );
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
