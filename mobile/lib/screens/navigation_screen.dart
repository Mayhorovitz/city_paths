// lib/screens/navigation_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:city_path/screens/report_hazard_screen.dart';
import 'package:city_path/screens/route_feedback_screen.dart';
import 'package:city_path/services/location_service.dart';
import 'package:city_path/services/navigation_service.dart';
import 'package:city_path/services/map_report_service.dart';
import 'package:city_path/services/report_service.dart';
import 'dart:async';

class NavigationScreen extends StatefulWidget {
  final Map<String, dynamic> selectedRoute;
  final String destinationAddress;

  const NavigationScreen({
    super.key,
    required this.selectedRoute,
    required this.destinationAddress,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionStreamSubscription;
  late NavigationService _navigationService;

  // Current user location
  LatLng? _currentLocation;
  Set<Marker> _markers = {};

  // Map settings
  double _currentZoom = 18.0;
  double _currentBearing = 0.0;

  // Navigation tracking for feedback
  late DateTime _navigationStartTime;
  List<Map<String, dynamic>> _encounteredReports = [];
  bool _hasArrived = false;

  @override
  void initState() {
    super.initState();
    _navigationStartTime = DateTime.now(); // Record navigation start time
    _navigationService = NavigationService();
    _initializeNavigation();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  void _initializeNavigation() {
    _navigationService.initializeRoute(
      widget.selectedRoute,
      widget.destinationAddress,
    );
    _addDestinationMarker();
  }

  void _addDestinationMarker() {
    if (_navigationService.routePoints.isNotEmpty) {
      setState(() {
        _markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: _navigationService.routePoints.last,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
            infoWindow: InfoWindow(
              title: 'Destination',
              snippet: widget.destinationAddress,
            ),
          ),
        );
      });
    }
  }

  void _startLocationTracking() {
    _positionStreamSubscription = LocationService.startLocationStream(
      onLocationUpdate: _handleLocationUpdate,
    );
  }

  void _handleLocationUpdate(Position position) {
    final newLocation = LatLng(position.latitude, position.longitude);

    setState(() {
      _currentLocation = newLocation;
      _currentBearing = position.heading;
    });

    _navigationService.updateLocation(newLocation);
    _updateMapCamera();
    _loadNearbyReports();

    // Check if arrived at destination
    _checkArrivalAtDestination(newLocation);
  }

  // Check if user has arrived at destination
  void _checkArrivalAtDestination(LatLng currentLocation) {
    if (_hasArrived || _navigationService.routePoints.isEmpty) return;

    final destination = _navigationService.routePoints.last;
    final distanceToDestination = Geolocator.distanceBetween(
      currentLocation.latitude,
      currentLocation.longitude,
      destination.latitude,
      destination.longitude,
    );

    // If within 50 meters of destination, consider arrived
    if (distanceToDestination < 50.0) {
      _handleArrivalAtDestination();
    }
  }

  // Handle arrival at destination - navigate to feedback screen
  void _handleArrivalAtDestination() {
    if (_hasArrived) return; // Prevent multiple triggers

    setState(() {
      _hasArrived = true;
    });

    // Stop location tracking
    _positionStreamSubscription?.cancel();

    // Calculate actual duration
    final actualDuration = DateTime.now().difference(_navigationStartTime);

    // Navigate to feedback screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (context) => RouteFeedbackScreen(
              routeData: widget.selectedRoute,
              destinationAddress: widget.destinationAddress,
              actualDuration: actualDuration,
              encounteredReports: _encounteredReports,
            ),
      ),
    );
  }

  Future<void> _loadNearbyReports() async {
    if (_currentLocation == null) return;

    try {
      // Get report markers for display
      final reportMarkers = await MapReportService.getReportMarkersNearby(
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        radiusKm: 0.5,
        onReportTap: _showReportDetails,
      );

      // Track encountered reports for feedback (closer range)
      final result = await ReportService.getReportsNearby(
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        radiusKm: 0.1, // 100m range for encounter tracking
      );

      if (result['success']) {
        final nearbyReports = List<Map<String, dynamic>>.from(
          result['reports'] ?? [],
        );

        // Add unique reports to encountered list
        for (final report in nearbyReports) {
          if (!_encounteredReports.any((r) => r['id'] == report['id'])) {
            _encounteredReports.add(report);
            print(
              "Encountered report: ${report['category']} at ${report['latitude']}, ${report['longitude']}",
            );
          }
        }
      }

      setState(() {
        // Keep destination marker, replace report markers
        final nonReportMarkers =
            _markers
                .where((marker) => !marker.markerId.value.startsWith('report_'))
                .toSet();
        _markers = nonReportMarkers..addAll(reportMarkers);
      });
    } catch (e) {
      print("Error loading reports in navigation: $e");
    }
  }

  void _showReportDetails(Map<String, dynamic> report) {
    MapReportService.showReportDetailsBottomSheet(
      context: context,
      report: report,
      isInNavigation: true,
    );
  }

  void _updateMapCamera() {
    if (_mapController == null || _currentLocation == null) return;

    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentLocation!,
          zoom: _currentZoom,
          bearing: _currentBearing,
          tilt: 60.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              if (_currentLocation != null) {
                _updateMapCamera();
              }
            },
            initialCameraPosition: CameraPosition(
              target:
                  _navigationService.routePoints.isNotEmpty
                      ? _navigationService.routePoints.first
                      : const LatLng(32.0853, 34.7818),
              zoom: _currentZoom,
              bearing: _currentBearing,
              tilt: 60.0,
            ),
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: _markers,
            polylines: {
              Polyline(
                polylineId: const PolylineId('route'),
                points: _navigationService.routePoints,
                color: Colors.blue,
                width: 6,
              ),
            },
          ),

          _buildInstructionPanel(),
          _buildInfoPanel(),
          _buildExitButton(),
        ],
      ),
      floatingActionButton: _buildReportButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildInstructionPanel() {
    // Show arrival message if close to destination
    String instruction = _navigationService.currentInstruction;
    if (_navigationService.totalDistanceRemaining < 100 &&
        _navigationService.totalDistanceRemaining > 0) {
      instruction = "Approaching destination - ${widget.destinationAddress}";
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: Card(
        color: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getInstructionIcon(instruction),
                    size: 32,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          instruction,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_navigationService.distanceToNextStep > 0)
                          Text(
                            "in ${LocationService.formatDistance(_navigationService.distanceToNextStep)}",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_navigationService.nextInstruction.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    "Then: ${_navigationService.nextInstruction}",
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Positioned(
      bottom: 20,
      left: 16,
      right: 16,
      child: Card(
        color: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoColumn(
                Icons.access_time,
                Colors.blue,
                LocationService.formatTime(
                  _navigationService.estimatedTimeRemaining,
                ),
                "Remaining",
              ),
              _buildInfoColumn(
                Icons.straighten,
                Colors.green,
                LocationService.formatDistance(
                  _navigationService.totalDistanceRemaining,
                ),
                "Distance",
              ),
              _buildInfoColumn(
                Icons.report,
                Colors.orange,
                "${_encounteredReports.length}",
                "Reports Seen",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(
    IconData icon,
    Color color,
    String value,
    String label,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildExitButton() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      child: Card(
        color: Colors.white,
        shape: const CircleBorder(),
        child: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _buildReportButton() {
    return FloatingActionButton(
      onPressed: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReportHazardScreen()),
        );

        if (result == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Report submitted! Thank you for helping keep routes safe.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          _loadNearbyReports();
        }
      },
      backgroundColor: Colors.red.shade600,
      foregroundColor: Colors.white,
      elevation: 8,
      child: const Icon(Icons.report_problem, size: 28),
    );
  }

  IconData _getInstructionIcon(String instruction) {
    if (instruction.contains("right")) return Icons.turn_right;
    if (instruction.contains("left")) return Icons.turn_left;
    if (instruction.contains("straight")) return Icons.straight;
    if (instruction.contains("arrived") || instruction.contains("Approaching"))
      return Icons.location_on;
    return Icons.navigation;
  }
}
